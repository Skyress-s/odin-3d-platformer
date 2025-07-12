package Character
import "core:fmt"

import verlet "../Physics/verlet"
import spat "../Spatial"
import "core:math/linalg"

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
}

handle_input :: proc(character_state: ^State) {
	switch state in character_state {
	case Airborne:
		fmt.println("AirBorne!")
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

handle_movement_input_Airborne :: proc(
	char_data: ^CharacternData,
	input_snapshot: ^Input_Snapshot,
) {

	// rules
	//	- Cannot change movement beoynd a certain speed that should be very low
	//	- Air strafing should be minimal, only slight changes allowed. (Should be tested and confirm if its fun or not)
	//		- The main fun of the game should be to change the direction with the hook and possibly other stuff 
	current_speed_xz := char_data.verlet_component.velocity
	current_speed_xz.y = 0
	speed_xz := linalg.length(current_speed_xz)

	state_airborne := &char_data.current_state.(Airborne)
	if speed_xz < state_airborne.allow_gain_max_speed {
		// gain speed
	}

	// test := state_airborne.speed
}
