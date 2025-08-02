package Character
import "core:fmt"

import cc "../Physics/collision_channel"
import verlet "../Physics/verlet"
import spat "../Spatial"
import hms "../handle_map/handle_map_static"
import l "../level"
import "../input"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"
import "../player_data"


Grounded :: struct {
	allow_gain_max_speed, acceleration: f32,
}

Airborne :: struct {
	allow_gain_max_speed, acceleration: f32,
}

State :: union #no_nil {
	Grounded,
	Airborne,
}

CharacternData :: struct {
	// using motion:           MotionComponent.MotionComponent,
	current_state:          State,
	hooked_position:        spat.Vector,
	is_hooked:              bool,
	start_distance_to_hook: f32,
	verlet_component:       verlet.Velocity_Verlet_Component,

	using look_angles: player_data.Player_Look_Data,
	// look_angles:            rl.Vector2,
	radius:                 f32,
}


@(private)
cursor_enabled: bool = false

update_character :: proc(
	character_data: ^CharacternData,
	level: ^l.Level,
	dt: f32,
) {
	character_data.look_angles.y -= rl.GetMouseDelta().x * 0.0015 // left and right
	character_data.look_angles.x += rl.GetMouseDelta().y * 0.0015 // up and down
	character_data.look_angles.x = linalg.clamp(
		character_data.look_angles.x,
		-math.PI * 0.499,
		math.PI * 0.499,
	)
	rot, forward, right := player_data.calculate_stuff_from_look(character_data)

	if rl.IsKeyPressed(.R) {
		character_data.verlet_component.position = {1, 5, 1}
		character_data.verlet_component.velocity = {}
	}

	if rl.IsKeyPressed(.TAB) {
		cursor_enabled = !cursor_enabled
		if cursor_enabled {rl.EnableCursor()}
		else {rl.DisableCursor()}
		
	}

	input_snapshot: input.Input_Snapshot = input.make_input_snapshot()
	fmt.println(input_snapshot)
	switch &state in character_data.current_state {
	case Airborne:
		handle_movement_input_Airborne(character_data, &input_snapshot, dt)
	case Grounded:
		handle_movement_input_Grounded(character_data, &input_snapshot, dt)
	}

	player_position := character_data.verlet_component.position

	if rl.IsMouseButtonPressed(.LEFT) {
		if character_data.is_hooked {
			character_data.is_hooked = false
		} else {
			ray := spat.make_ray_with_origin_direction_distance(
				player_position,
				linalg.vector_normalize(forward),
				100.0,
			)
			ok, id, hook_hit_location := spat.ray_intersect_spatial_hash_grid(
				&level.spatial_hash_grid,
				&level.collision_object_map,
				&ray,
			)
			if ok {

				character_data.hooked_position = hook_hit_location
				character_data.is_hooked = true
				character_data.start_distance_to_hook = linalg.distance(
					character_data.hooked_position,
					player_position,
				)
			}
		}

	}
	// Update character specific stuff
	{
		ray := spat.make_ray_with_origin_direction_distance(
			character_data.verlet_component.position,
			spat.Vector{0, -1, 0},
			character_data.radius + 0.5,
		)

		ok, id, location := spat.ray_intersect_spatial_hash_grid(
			&level.spatial_hash_grid,
			&level.collision_object_map,
			&ray,
		)

		if ok {
			character_data.current_state = Grounded{10, 50}
		} else {
			character_data.current_state = Airborne{10, 30}
		}

	}
}

update_character_physics :: proc(
	character_data: ^CharacternData,
	level: ^l.Level,
	active_cell_objects_ids: ^[dynamic]spat.Collision_Object_Id,
	dt: f32,
) {
	fmt.println("update_character_physics")
	for &collision_object_id in active_cell_objects_ids {

		coll_obj := hms.get(&level.collision_object_map, collision_object_id)
		if !cc.is_blocking(coll_obj.collision_channels) do continue

		for &t in coll_obj.tris {
			collide_with_tri(&t, &character_data.verlet_component.velocity, character_data, dt)
		}

	}

	// Jumping
	_, ok := character_data.current_state.(Grounded) // awwwww yes!
	// if rl.IsKeyPressed(.SPACE) && ok {
	if rl.IsKeyPressed(.SPACE) {

		// char_data.verlet_component.velocity.y = 15
		character_data.verlet_component.acceleration.y += 15 / dt

	}

	// Grappling Hook
	if character_data.is_hooked {
		to_hook := (character_data.hooked_position - character_data.verlet_component.position)
		direction_to_hook := linalg.vector_normalize(to_hook)
		distance := linalg.distance(character_data.hooked_position, character_data.verlet_component.position)
		if distance > character_data.start_distance_to_hook {
			distance_over_max := (distance - character_data.start_distance_to_hook)
			distance_over_max = max(distance_over_max, 0.0)


			// huh, this is shit
			right := linalg.vector_cross3(
				character_data.verlet_component.velocity,
				direction_to_hook,
			)
			hook_forward := linalg.vector_cross3(direction_to_hook, right)
			hook_forward = linalg.vector_normalize(hook_forward)


			new_vel_length := linalg.vector_dot(
				character_data.verlet_component.velocity,
				hook_forward,
			)

			// Should we lose momentum or not? Kinda hacky atm.
			target_velocity: spat.Vector
			if new_vel_length < linalg.length(character_data.verlet_component.velocity) * 0.8 {
				//char_data.verlet_component.velocity = hook_forward * new_vel_length
				target_velocity = hook_forward * new_vel_length
			} else {
				//char_data.verlet_component.velocity =
				//hook_forward * linalg.length(char_data.verlet_component.velocity)
				target_velocity =
					hook_forward * linalg.length(character_data.verlet_component.velocity)
			}
			acc := (target_velocity - character_data.verlet_component.velocity) / dt
			character_data.verlet_component.acceleration += acc
			// Enegry is now conserved, but its quite hard coded
			// verlet intergration is supposed to conserve energy, will try to use that for this project perhaps?
			// what i want in a ideal world:
			// - [C]ontinous [C]ollision [D]etection
			// - Energy is conserverd
		} else if distance * 0.995 < character_data.start_distance_to_hook {
			character_data.start_distance_to_hook = distance
		}

	}


	// Add gravity
	character_data.verlet_component.acceleration += {0, -30, 0}

}
collide_with_tri :: proc(
	t: ^spat.Collision_Triangle,
	vel: ^spat.Vector,
	char_data: ^CharacternData,
	dt: f32,
) {
	using char_data

	closest := spat.closest_point_on_triangle(
		verlet_component.position,
		t.points[0],
		t.points[1],
		t.points[2],
	)
	diff := verlet_component.position - closest
	dist := linalg.length(diff)
	normal := diff / dist

	//rl.DrawCubeV(closest, 0.05, dist > char_data.radius ? rl.ORANGE : rl.WHITE)

	if dist < char_data.radius {
		verlet_component.position += normal * (char_data.radius - dist)
		// project velocity to the normal plane, if moving towards it
		vel_normal_dot: f32 = linalg.dot(vel^, normal)
		if vel_normal_dot < 0 {
			diff := (vel^ - normal * vel_normal_dot) - verlet_component.velocity
			acceleration := diff / dt
			//verlet_component.acceleration += acceleration
			verlet_component.velocity -= normal * vel_normal_dot
		}
	}

}


@(private)
handle_movement_input_Airborne :: proc(
	char_data: ^CharacternData,
	input_snapshot: ^input.Input_Snapshot,
	dt: f32,
) {

	rot, forward, right := player_data.calculate_stuff_from_look(char_data)
	forward.y = 0
	forward = linalg.normalize(forward)
	if linalg.is_nan(forward) == true do return

	// rules
	//	- Cannot change movement beoynd a certain speed that should be very low
	//	- Air strafing should be minimal, only slight changes allowed. (Should be tested and confirm if its fun or not)
	//		- The main fun of the game should be to change the direction with the hook and possibly other stuff 
	velocity_before_xz: spat.Vector = char_data.verlet_component.velocity
	velocity_before_xz.y = 0
	speed_xz: f32 = linalg.length(velocity_before_xz)

	state_airborne: ^Airborne = &char_data.current_state.(Airborne)
	verlet_component: ^verlet.Velocity_Verlet_Component = &char_data.verlet_component
	//char_data.verlet_component.velocity += forward * input_snapshot.movement.y

	move_input := forward * input_snapshot.movement.y + right * input_snapshot.movement.x
	move_input = linalg.normalize0(move_input)
	movement_input_velocity: spat.Vector = move_input * state_airborne.acceleration


	new_vel := velocity_before_xz + movement_input_velocity * dt
	// to stop at EXATCT max speed when giving speed

	// We allow the direction to change
	if linalg.length(new_vel) > state_airborne.allow_gain_max_speed {
		new_vel = linalg.clamp_length(new_vel, linalg.length(velocity_before_xz))
	}

	verlet_component.velocity.x = new_vel.x
	verlet_component.velocity.z = new_vel.z
}

handle_movement_input_Grounded :: proc(
	char_data: ^CharacternData,
	input_snapshot: ^input.Input_Snapshot,
	dt: f32,
) {

	rot, forward, right := player_data.calculate_stuff_from_look(char_data)
	forward.y = 0
	forward = linalg.normalize(forward)
	if linalg.is_nan(forward) == true do return

	// rules
	//	- Cannot change movement beoynd a certain speed that should be very low
	//	- Air strafing should be minimal, only slight changes allowed. (Should be tested and confirm if its fun or not)
	//		- The main fun of the game should be to change the direction with the hook and possibly other stuff 
	velocity_before_xz: spat.Vector = char_data.verlet_component.velocity
	velocity_before_xz.y = 0
	speed_xz: f32 = linalg.length(velocity_before_xz)

	state_airborne: ^Grounded = &char_data.current_state.(Grounded)
	verlet_component: ^verlet.Velocity_Verlet_Component = &char_data.verlet_component
	//char_data.verlet_component.velocity += forward * input_snapshot.movement.y


	move_input := forward * input_snapshot.movement.y + right * input_snapshot.movement.x
	move_input = linalg.normalize0(move_input)
	movement_input_velocity: spat.Vector = move_input * state_airborne.acceleration


	new_vel := velocity_before_xz + movement_input_velocity * dt
	// to stop at EXATCT max speed when giving speed

	// We allow the direction to change
	if linalg.length(new_vel) > state_airborne.allow_gain_max_speed {
		new_vel = linalg.clamp_length(new_vel, linalg.length(velocity_before_xz))
	}

	verlet_component.velocity.x = new_vel.x
	verlet_component.velocity.z = new_vel.z
}
