package input
import "core:math/linalg"
import rl "vendor:raylib"

Input_Snapshot :: struct {
	jump:      Input_state,
	fire_hook: Input_state,
	movement:  Axis_2D,
}

Axis_Float :: f32
Axis_2D :: linalg.Vector2f32

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


