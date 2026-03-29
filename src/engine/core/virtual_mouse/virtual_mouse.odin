package virtual_mouse

import "core:math"
import "core:math/linalg"
import "vendor:raylib"
// Some window managers (linux -> wayland). Dont allow raylib to set the cursort position.
// But we can rl.DisableCursor() anywhere. Which locks the cursor to our window.
// But under the hood it still moves on an infinite canvas.
// (0,0) is top left of screen. (screen_dimensions.x, screen_dimensions.y) is bottom right.
// This package will rl.DisableCursor() and provide the interface to use the mouse however we wish.

Vec2 :: [2]f32
Rect :: struct {
	position, dimensions: Vec2,
}

Context :: struct {
	mouse_position:            Vec2,
	mouse_delta:               Vec2,
	mouse_position_last_frame: Vec2,
	mouse_restrict_rect:       Rect,
	mouse_restrict_free:       bool,
	mouse_hidden:              bool,
	disable_cursor_proc:       Disable_Custor_Proc,
	is_window_focused_proc:    Is_Window_Focused_Proc,
	window_focused_last_frame: bool,
	show_cursor_proc:          Show_Cursor_Proc,
	hide_cursor_proc:          Hide_Cursor_Proc,
	is_cursor_hidden_proc:     Is_Cusor_Hidden_Proc,
	screen_dimensions:         Vec2,
}

Is_Window_Focused_Proc :: proc() -> bool

Empty_Proc :: proc()
Disable_Custor_Proc :: Empty_Proc
Hide_Cursor_Proc :: Empty_Proc
Show_Cursor_Proc :: Empty_Proc
Is_Cusor_Hidden_Proc :: proc() -> bool

update :: proc(ctx: ^Context, mouse_delta, screen_dimensions: Vec2) {
	ctx.screen_dimensions = screen_dimensions
	assert(ctx != nil)
	ctx.mouse_position_last_frame = ctx.mouse_position

	assert(ctx.disable_cursor_proc != nil)
	assert(ctx.is_window_focused_proc != nil)

	ctx.mouse_restrict_rect.position = linalg.clamp(
		ctx.mouse_restrict_rect.position,
		Vec2{0, 0},
		screen_dimensions,
	)

	clamp_rect_to_screen_dimensions(&ctx.mouse_restrict_rect, screen_dimensions)

	ctx.mouse_position += mouse_delta
	ctx.mouse_delta = mouse_delta

	clamp_vec_to_rect(&ctx.mouse_position, ctx.mouse_restrict_rect)

	window_focused := ctx.is_window_focused_proc()
	if !ctx.window_focused_last_frame && window_focused {
		ctx.disable_cursor_proc()
	}
	ctx.window_focused_last_frame = window_focused
}

init :: proc(
	screen_dimensions: Vec2,
	disable_cursor_proc: Disable_Custor_Proc,
	is_window_focused_proc: Is_Window_Focused_Proc,
	show_mouse_proc: Show_Cursor_Proc,
	hide_mouse_proc: Hide_Cursor_Proc,
	is_cursor_hidden_proc: Is_Cusor_Hidden_Proc,
) -> (
	ctx: Context,
) {
	ctx.screen_dimensions = screen_dimensions
	ctx.mouse_position = screen_dimensions / 2
	ctx.mouse_position_last_frame = ctx.mouse_position

	assert(disable_cursor_proc != nil)
	assert(is_window_focused_proc != nil)
	assert(show_mouse_proc != nil)
	assert(hide_mouse_proc != nil)
	assert(is_cursor_hidden_proc != nil)

	ctx.disable_cursor_proc = disable_cursor_proc
	ctx.is_window_focused_proc = is_window_focused_proc
	ctx.show_cursor_proc = show_mouse_proc
	ctx.hide_cursor_proc = hide_mouse_proc
	ctx.is_cursor_hidden_proc = is_cursor_hidden_proc

	disable_cursor_proc()

	ctx.mouse_restrict_rect = {
		position   = Vec2{0, 0},
		dimensions = screen_dimensions,
	}

	return
}

deinit :: proc() {

}

free_mouse :: proc(ctx: ^Context) {
	restrict_mouse(ctx, {0, 0}, ctx.screen_dimensions)
}

restrict_mouse :: proc {
	restrict_mouse_min_max,
	restrict_mouse_rect,
	restrict_mouse_pos,
}

restrict_mouse_min_max :: proc(ctx: ^Context, min, max: Vec2) {
	assert(max.x > min.x)
	assert(max.y > min.y)
	assert(ctx != nil)

	rect: Rect
	rect.position = min
	rect.dimensions = max - min
	_restrict_mouse(ctx, rect)
}

restrict_mouse_rect :: proc(ctx: ^Context, rect: Rect) {
	assert(ctx != nil)
	_restrict_mouse(ctx, rect)
}

restrict_mouse_pos :: proc(ctx: ^Context, pos: Vec2) {
	assert(ctx != nil)

	rect: Rect
	rect.position = pos
	rect.dimensions = Vec2{0, 0}
	_restrict_mouse(ctx, rect)
}

@(private)
_restrict_mouse :: proc(ctx: ^Context, restrict_rect: Rect) {
	ctx.mouse_restrict_rect = restrict_rect
}

set_show_visibility :: proc(ctx: ^Context, mouse_visible: bool) {
	ctx.mouse_hidden = !mouse_visible
}

get_mouse_pos :: proc(ctx: Context) -> Vec2 {
	return ctx.mouse_position
}

is_cursor_hidden :: proc(ctx: Context) -> bool {
	return ctx.mouse_hidden
}

hide_cursor :: proc(ctx: ^Context) {
	ctx.mouse_hidden = true
}

show_cursor :: proc(ctx: ^Context) {
	ctx.mouse_hidden = false
}

@(private)
clamp_rect_to_screen_dimensions :: proc(rect: ^Rect, screen_dimensions: Vec2) {
	rect.dimensions =
		linalg.clamp(rect.position + rect.dimensions, Vec2{0, 0}, screen_dimensions) -
		rect.position

}

clamp_vec_to_rect :: proc(vec: ^Vec2, rect: Rect) {
	vec^ = linalg.clamp(vec^, rect.position, rect.position + rect.dimensions)
}
