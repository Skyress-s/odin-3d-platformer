package Character

import MotionComponent "../Physics/MotionComponent"
import spat "../Spatial"

Grounded :: struct {
	glide: bool,
}

Airborne :: struct {
	speed: f16,
}

State :: union {
	Grounded,
	Airborne,
}

CharacternData :: struct {
	using motion:           MotionComponent.MotionComponent,
	current_state:          State,
	hooked_position:        spat.Vector,
	is_hooked:              bool,
	start_distance_to_hook: f32,
}
