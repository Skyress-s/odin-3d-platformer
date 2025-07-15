package Character
import "core:fmt"

import verlet "../Physics/verlet"
import spat "../Spatial"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

Axis_Float :: f32
Axis_2D :: linalg.Vector2f32

Grounded :: struct {
	allow_gain_max_speed, acceleration: f32,
}

Airborne :: struct {
	allow_gain_max_speed, acceleration: f32,
}

State :: union {
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
	look_angles:            rl.Vector2,
}

handle_input :: proc(character_data: ^CharacternData, dt: f32) {
	input_snapshot: Input_Snapshot = make_input_snapshot()
	switch state in character_data.current_state {
	case Airborne:
		handle_movement_input_Airborne(character_data, &input_snapshot, dt)
	case Grounded:
		handle_movement_input_Grounded(character_data, &input_snapshot, dt)
	}
}

Nothing :: struct {
}

Pressed :: struct {
}
Pressing :: struct {
	hold_time: f32,
}

Released :: struct {
}

Input_state :: union {
	Nothing,
	Pressed,
	Pressing,
	Released,
}

Input_Snapshot :: struct {
	jump:      Input_state,
	fire_hook: Input_state,
	movement:  Axis_2D,
}

// todo terrible name
calculate_stuff_from_look :: proc(
	character_data: ^CharacternData,
) -> (
	rot: linalg.Quaternionf32,
	forward, right: linalg.Vector3f32,
) {
	rot =
		linalg.quaternion_from_euler_angle_y_f32(character_data.look_angles.y) *
		linalg.quaternion_from_euler_angle_x_f32(character_data.look_angles.x)

	forward = linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{0, 0, 1})
	right = linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{1, 0, 0})


	xz_forward := forward
	xz_forward.y = 0
	xz_forward = linalg.normalize(xz_forward)

	return rot, forward, right
}

make_input_state_from_one_key :: proc(key: rl.KeyboardKey) -> (state: Input_state) {
	if rl.IsKeyDown(key) do state = Pressed{}
	else if rl.IsKeyDown(key) do state = Pressing{}
	else if rl.IsKeyReleased(key) do state = Released{}
	else do state = Nothing{}

	return state
}

make_input_snapshot :: proc() -> (input_snapshot: Input_Snapshot) {

	// Fire hook / main ability 
	if rl.IsMouseButtonPressed(.LEFT) do input_snapshot.fire_hook = Pressed{}
	else if rl.IsMouseButtonDown(.LEFT) do input_snapshot.fire_hook = Pressing{}
	else if rl.IsMouseButtonReleased(.LEFT) do input_snapshot.fire_hook = Released{}
	else do input_snapshot.fire_hook = Nothing{}

	input_snapshot.movement.x = (rl.IsKeyDown(.A) ? 1 : 0) + (rl.IsKeyDown(.D) ? -1 : 0)
	input_snapshot.movement.y = (rl.IsKeyDown(.W) ? 1 : 0) + (rl.IsKeyDown(.S) ? -1 : 0)

	input_snapshot.jump = make_input_state_from_one_key(rl.KeyboardKey.SPACE)


	return input_snapshot
}

handle_movement_input_Airborne :: proc(
	char_data: ^CharacternData,
	input_snapshot: ^Input_Snapshot,
	dt: f32,
) {

	rot, forward, right := calculate_stuff_from_look(char_data)
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
	input_snapshot: ^Input_Snapshot,
	dt: f32,
) {

	rot, forward, right := calculate_stuff_from_look(char_data)
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
