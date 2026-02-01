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
	mouse_position_last_frame: Vec2,
	mouse_restrict_rect:       Rect,
	mouse_hidden:              bool,
	disable_cursor_proc:       proc(),
}

update :: proc(ctx: ^Context, mouse_delta, screen_dimensions: Vec2) {
	assert(ctx != nil)
	ctx.mouse_position_last_frame = ctx.mouse_position

	assert(ctx.disable_cursor_proc != nil)
	// ctx.disable_cursor_proc()

	ctx.mouse_restrict_rect.position = linalg.clamp(
		ctx.mouse_restrict_rect.position,
		Vec2{0, 0},
		screen_dimensions,
	)

	clamp_rect_to_screen_dimensions(&ctx.mouse_restrict_rect, screen_dimensions)

	ctx.mouse_position += mouse_delta

	// if ctx.mouse_position.x < 0 ||
	//    ctx.mouse_position.x > screen_dimensions.x ||
	//    ctx.mouse_position.y < 0 ||
	//    ctx.mouse_position.y > screen_dimensions.y {
	// 	raylib.EnableCursor()
	// } else {
	// 	raylib.DisableCursor()
	// }

	clamp_vec_to_rect(&ctx.mouse_position, ctx.mouse_restrict_rect)
}

init :: proc(screen_dimensions: Vec2, disable_cursor_proc: proc()) -> (ctx: Context) {
	ctx.mouse_position = screen_dimensions / 2
	ctx.mouse_position_last_frame = ctx.mouse_position

	assert(disable_cursor_proc != nil)
	disable_cursor_proc()
	ctx.disable_cursor_proc = disable_cursor_proc

	ctx.mouse_restrict_rect = {
		position   = Vec2{0, 0},
		dimensions = screen_dimensions,
	}

	return
}

deinit :: proc() {

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

	ctx.mouse_restrict_rect.position = min
	ctx.mouse_restrict_rect.dimensions = max - min
}

restrict_mouse_rect :: proc(ctx: ^Context, rect: Rect) {
	assert(ctx != nil)
	ctx.mouse_restrict_rect = rect


}

restrict_mouse_pos :: proc(ctx: ^Context, pos: Vec2) {
	assert(ctx != nil)

	ctx.mouse_restrict_rect.position = pos
	ctx.mouse_restrict_rect.dimensions = Vec2{0, 0}
}

set_show_visibility :: proc(ctx: ^Context, mouse_visible: bool) {
	ctx.mouse_hidden = !mouse_visible
}

get_mouse_pos :: proc(ctx: Context) -> Vec2 {
	return ctx.mouse_position
}

is_mouse_hidden :: proc(ctx: Context) -> bool {
	return ctx.mouse_hidden
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
