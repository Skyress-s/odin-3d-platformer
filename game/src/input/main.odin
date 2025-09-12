package input
import "core:math/linalg"
import rl "vendor:raylib"

Input_Snapshot :: struct {
	jump:           Input_state,
	crouch:         Input_state,
	primary_click:      Input_state,
	seconday_click: Input_state,
	movement:       Axis_2D,
}

Axis_Float :: f32
Axis_2D :: linalg.Vector2f32

Nothing :: struct {
}

Pressed :: struct {
}
Down :: struct {
	//hold_time: f32,
}

Released :: struct {
}

Input_state :: union {
	Nothing,
	Pressed,
	Down,
	Released,
}

@(private)
make_input_state :: proc {make_input_state_from_one_key, make_input_state_from_one_mouse_button }

@(private)
make_input_state_from_one_key :: proc(key: rl.KeyboardKey) -> (state: Input_state) {
	if rl.IsKeyPressed(key) do state = Pressed{}
	else if rl.IsKeyDown(key) do state = Down{}
	else if rl.IsKeyReleased(key) do state = Released{}
	else do state = Nothing{}

	return state
}

@(private)
make_input_state_from_one_mouse_button :: proc(button: rl.MouseButton) -> (state: Input_state){
	if rl.IsMouseButtonPressed(button) do state = Pressed{}
	else if rl.IsMouseButtonDown(button) do state = Down{}
	else if rl.IsMouseButtonReleased(button) do state = Released{}
	else do state = Nothing{}
	
	return state
}

make_input_snapshot :: proc() -> (input_snapshot: Input_Snapshot) {


	input_snapshot.movement.x = (rl.IsKeyDown(.A) ? 1 : 0) + (rl.IsKeyDown(.D) ? -1 : 0)
	input_snapshot.movement.y = (rl.IsKeyDown(.W) ? 1 : 0) + (rl.IsKeyDown(.S) ? -1 : 0)

	input_snapshot.jump = make_input_state(rl.KeyboardKey.SPACE)
	input_snapshot.crouch = make_input_state(rl.KeyboardKey.LEFT_CONTROL)
	input_snapshot.seconday_click = make_input_state(rl.MouseButton.RIGHT)
	input_snapshot.primary_click = make_input_state(rl.MouseButton.LEFT)

	return input_snapshot
}
