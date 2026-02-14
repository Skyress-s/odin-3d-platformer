package Character
import col "../color"
import cc "../core/collision_channel"
import cs "../core/collision_scene/"
import csq "../core/collision_scene/query/"
import verlet "../core/physics/verlet"
import spat "../core/spatial"
import ddu "../debug_draw_utils"
import gent "../game/game_entities/"
import "../game_state"
import hms "../handle_map/handle_map_static"
import "../input"
import l "../level"
import "../player_data"
import hm "core:container/handle_map"
import "core:math/linalg"
import "core:time"
import rl "vendor:raylib"


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

Speedrun_Stopwatches_Type :: time.Stopwatch

CharacternData :: struct {
	// using motion:           MotionComponent.MotionComponent,
	current_state:          State,
	hooked_position:        spat.Vector,
	is_hooked:              bool,
	start_distance_to_hook: f32,
	verlet_component:       verlet.Velocity_Verlet_Component,
	using look_angles:      player_data.Player_Look_Data,
	// look_angles:            rl.Vector2,
	radius:                 f32,

	// Cheats
	air_jumping_cheat:      bool,

	// If we pause the game and resume, we want to exclude that period of time -> why its an array of timers
	speedrun_stop_watch:    time.Stopwatch,
	best_time:              f64,
}

start_speedrun :: proc(game_player: ^CharacternData) {
	time.stopwatch_start(&game_player.speedrun_stop_watch)
}


pause_speedrun :: proc(game_player: ^CharacternData) {
	time.stopwatch_stop(&game_player.speedrun_stop_watch)
}

reset_speedrun :: proc(game_player: ^CharacternData) {
	time.stopwatch_reset(&game_player.speedrun_stop_watch)
}

get_current_speedrun_time :: proc(game_player: ^CharacternData) -> f64 {
	return time.duration_seconds(time.stopwatch_duration(game_player.speedrun_stop_watch))
}

update_character :: proc(
	character_data: ^CharacternData,
	level: ^l.Level,
	gamestate: ^game_state.Game_State,
	dt: f32,
) {
	if rl.IsCursorHidden() && rl.GetTime() > 0.1 { 	// Cursor usually enters screen right after we start the game, will cause a large "flick" when starting (since cursor is teleporting to center of screen).
		player_data.update_player_look_data(&character_data.look_angles, rl.GetMouseDelta(), dt)
	}
	rot, forward, right := player_data.calculate_direction_from_look(character_data)

	if rl.IsKeyPressed(.R) {
		reset_run(character_data, &level.start_position, &level.start_look_direction)
		gamestate.finished_level = false
	}


	input_snapshot: input.Input_Snapshot = input.make_input_snapshot()
	switch &state in character_data.current_state {
	case Airborne:
		handle_movement_input_Airborne(character_data, &input_snapshot, dt)
	case Grounded:
		handle_movement_input_Grounded(character_data, &input_snapshot, dt)
	}

	player_position := character_data.verlet_component.position

	if rl.IsMouseButtonPressed(.LEFT) && rl.IsCursorHidden() { 	// TODO USE primary fire!
		if character_data.is_hooked {
			character_data.is_hooked = false
		} else {
			ray := spat.make_ray_with_origin_direction_distance(
				player_position,
				linalg.vector_normalize(forward),
				1000.0,
			)
			ok, id, hook_hit_location := cs.ray_intersect_spatial_hash_grid(
				&level.collsion_scene.spatial_hash_grid,
				&level.entities,
				&level.collsion_scene.collision_meshes,
				&ray,
			)
			entity: ^gent.Entity = hm.get(&level.entities, id)
			assert(entity != nil)

			is_grappable := gent.Trait.Grabable in entity.traits
			if ok && is_grappable {

				character_data.hooked_position = hook_hit_location
				character_data.is_hooked = true
				character_data.start_distance_to_hook = linalg.distance(
					character_data.hooked_position,
					player_position,
				)
			}
		}

	}

	{
		ray := spat.make_ray_with_origin_direction_distance(
			character_data.verlet_component.position,
			spat.Vector{0, -1, 0},
			character_data.radius + 0.5,
		)

		ok, id, location := cs.ray_intersect_spatial_hash_grid(
			&level.collsion_scene.spatial_hash_grid,
			&level.entities,
			&level.collsion_scene.collision_meshes,
			&ray,
		)

		if ok {
			character_data.current_state = Grounded{10, 280}
		} else {
			character_data.current_state = Airborne{10, 60}
		}

	}
}

reset_run :: proc(character_data: ^CharacternData, start_location, start_velocity: ^spat.Vector) {
	reset_speedrun(character_data)
	start_speedrun(character_data)

	character_data.verlet_component.position = start_location^
	character_data.verlet_component.velocity = start_velocity^
	character_data.look_angles = player_data.calculate_look_angles_from_direction(start_velocity^)
	character_data.is_hooked = false
	character_data.hooked_position = spat.ZERO_VEC3
}

notify_level_loaded :: proc(character_data: ^CharacternData) {
	character_data.speedrun_stop_watch = time.Stopwatch{}
	character_data.best_time = 0
}

update_character_physics :: proc(
	character_data: ^CharacternData,
	level: ^l.Level,
	player_hash_cells: ^map[cs.Hash_Key]bool,
	dt: f32,
) {
	copy_comp: verlet.Velocity_Verlet_Component = character_data.verlet_component
	verlet.velocity_verlet_frog(&copy_comp, dt)
	copy_comp.acceleration += {0, -30, 0}
	verlet.velocity_verlet_leap(&copy_comp, dt)

	movement_sphere_trace := spat.Sphere_Trace {
		ray = spat.Ray {
			origin = character_data.verlet_component.position,
			end = copy_comp.position,
		},
		radius = character_data.radius,
	}

	// ddu.enqueue_ins(&ddu.Sphere_Ins{location = character_data.verlet_component.position, radius = character_data.radius * 2, color = col.RED}, 45)
	// ddu.enqueue_ins(&ddu.Cube_Ins{location = copy_comp.position, size = spat.Vector{1,1,10}, color = col.SKYBLUE}, 45)

	// ddu.enqueue_ins(
	// 	&ddu.Wire_Capsule_Ins {
	// 		sphere_trace = movement_sphere_trace,
	// 		color = col.GREEN,
	// 	},
	// 	45,
	// )

	collided_this_frame: bool = false

	movement_hash_cells := spat.calculate_hashes_by_sphere_trace(&movement_sphere_trace)
	defer delete(movement_hash_cells)

	for hash_key in movement_hash_cells {
		object_ids := level.collsion_scene.spatial_hash_grid[hash_key]
		for &collision_object_id in object_ids.objects_ids {

			coll_obj := hms.get(&level.collsion_scene.collision_object_map, collision_object_id)
			// if !cc.is_blocking(coll_obj.collision_channels) do continue
			if coll_obj.collision_channels.player != cc.BLOCK do continue

			transform_matrix := spat.get_matrix_from_transform(coll_obj.transform)


			point := spat.Vector4{1, 1, 1, 1}
			new_point := point * transform_matrix

			for &t in coll_obj.tris {
				// TODO: also implement rotations when the time comes
				tri := t
				for &p in tri.points {
					p = (transform_matrix * spat.Vector4{p.x, p.y, p.z, 1}).xyz // heck yes it works!
					// p += coll_obj.transform.position
				}
				hit, loc := spat.sphere_trace_triangle_intersect(&movement_sphere_trace, &tri, nil)

				if hit {
					dist := linalg.distance(loc, movement_sphere_trace.origin)
					remaining_distance := spat.ray_length(&movement_sphere_trace.ray) - dist
					closest_point := spat.closest_point_on_triangle(
						movement_sphere_trace.radius,
						tri.points.x,
						tri.points.y,
						tri.points.z,
					)

					dist_to_tri, normal := spat.distance_to_tri(&tri, &loc)
					// log.warnf("dist {} loc {}", tri, loc)

					ray_direction := spat.ray_direction(movement_sphere_trace.ray)

					reflected := linalg.reflect(ray_direction, normal)

					end_pos := loc + reflected * remaining_distance

					ddu.enqueue_ins(
						&ddu.Wire_Sphere_Ins{location = loc, radius = 3, color = col.WHITE},
						0.3,
					)

					// character_data.verlet_component.position = end_pos
					character_data.verlet_component.velocity = spat.reflect_dampen(
						character_data.verlet_component.velocity,
						normal,
						0.0,
					)
					// spat.clamp_to_tri(
					// 	&tri,
					// 	&character_data.verlet_component.velocity,
					// 	&character_data.verlet_component.position,
					// 	character_data.radius,
					// 	dt,
					// )

					collided_this_frame = true // TODO we should in reality check against all triangles, find the one that would be hit first and calculate of that.
					// break
				}
				spat.clamp_to_tri(
					&tri,
					&character_data.verlet_component.velocity,
					&character_data.verlet_component.position,
					character_data.radius,
					dt,
				)
			}
			if collided_this_frame do break

			if collided_this_frame do break
		}
		if collided_this_frame do break
	}

	// Jumping
	_, ok := character_data.current_state.(Grounded) // awwwww yes!
	if rl.IsKeyPressed(.SPACE) && (ok || character_data.air_jumping_cheat) {

		character_data.verlet_component.acceleration.y += 15 / dt

	}

	// Grappling Hook
	if character_data.is_hooked &&
	   linalg.length(character_data.verlet_component.velocity) > 0.001 {
		to_hook := (character_data.hooked_position - character_data.verlet_component.position)
		direction_to_hook := linalg.vector_normalize(to_hook)
		distance := linalg.distance(
			character_data.hooked_position,
			character_data.verlet_component.position,
		)
		if distance > character_data.start_distance_to_hook {
			distance_over_max := (distance - character_data.start_distance_to_hook)
			distance_over_max = max(distance_over_max, 0.0)

			// Update character position so rope length is constant
			character_data.verlet_component.position =
				character_data.verlet_component.position + direction_to_hook * distance_over_max

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
			if new_vel_length < linalg.length(character_data.verlet_component.velocity) * 0.8 { 	// If we lose v < 20% of velocity, dont lose anything
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
		} else if distance < character_data.start_distance_to_hook { 	// Shorting rope
			character_data.start_distance_to_hook = distance
		}

	}

	// TODO: When continually swinging without intup, we will very gradually gain total engergy.


}


@(private)
handle_movement_input_Airborne :: proc(
	char_data: ^CharacternData,
	input_snapshot: ^input.Input_Snapshot,
	dt: f32,
) {

	rot, forward, right := player_data.calculate_direction_from_look(char_data)
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

	// log.warnf(" mov before {}", verlet_component)
	verlet_component.velocity.x = new_vel.x
	verlet_component.velocity.z = new_vel.z
	// log.warnf(" mov after {}", verlet_component)
}

handle_movement_input_Grounded :: proc(
	char_data: ^CharacternData,
	input_snapshot: ^input.Input_Snapshot,
	dt: f32,
) {

	rot, forward, right := player_data.calculate_direction_from_look(char_data)
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
