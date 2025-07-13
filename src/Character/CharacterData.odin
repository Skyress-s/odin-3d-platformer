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
	glide: bool,
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
	fmt.println(input_snapshot)
	switch state in character_data.current_state {
	case Airborne:
		fmt.println("AirBorne!")
		handle_movement_input_Airborne(character_data, &input_snapshot, dt)
	case Grounded:
		fmt.println("Grounded!")
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

	// rules
	//	- Cannot change movement beoynd a certain speed that should be very low
	//	- Air strafing should be minimal, only slight changes allowed. (Should be tested and confirm if its fun or not)
	//		- The main fun of the game should be to change the direction with the hook and possibly other stuff 
	velocity_xz: spat.Vector = char_data.verlet_component.velocity
	velocity_xz.y = 0
	speed_xz: f32 = linalg.length(velocity_xz)

	state_airborne: ^Airborne = &char_data.current_state.(Airborne)
	//char_data.verlet_component.velocity += forward * input_snapshot.movement.y


	fmt.printfln(
		"speed_xz %f, allow_gain_max_speed %f",
		speed_xz,
		state_airborne.allow_gain_max_speed,
	)

	if speed_xz < state_airborne.allow_gain_max_speed {

		diff := (state_airborne.allow_gain_max_speed - speed_xz)

		added_vel: spat.Vector =
			(input_snapshot.movement.x * right + input_snapshot.movement.y * forward) *
			state_airborne.acceleration
		added_vel *= dt
		//added_vel = linalg.clamp_length(added_vel, allowed_speed_to_add)
		//velocity_xz += spat.Vector{added_vel.x, 0, added_vel.y}
		added_vel = linalg.clamp_length(added_vel, diff)

		char_data.verlet_component.velocity.x += added_vel.x
		char_data.verlet_component.velocity.z += added_vel.z


		// gain speed
		fmt.println("added speed!")
	}


	//velocity_xz.y = char_data.verlet_component.velocity.y
	//char_data.verlet_component.velocity = velocity_xz
}
