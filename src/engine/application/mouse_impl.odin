package application
import rl "vendor:raylib"


disable_cursor :: proc() {
	rl.DisableCursor()
}
is_window_focused :: proc() -> bool {
	return rl.IsWindowFocused()
}
show_mouse_proc :: proc() {

	rl.EnableCursor()
}
hide_mouse_proc :: proc() {

	rl.DisableCursor()

}
is_cursor_hidden_proc :: proc() -> bool {
	return rl.IsCursorHidden()
}

get_screen_dimentions :: proc() -> [2]f32 {
	return {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
}
