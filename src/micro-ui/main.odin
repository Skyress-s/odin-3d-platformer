package gameui

import "core:c"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:strings"
import "core:unicode/utf8"

import mu "vendor:microui"
import rl "vendor:raylib"

state := struct {
	mu_ctx:          mu.Context,
	log_buf:         [1 << 16]byte,
	log_buf_len:     int,
	log_buf_updated: bool,
	bg:              mu.Color,
	atlas_texture:   rl.RenderTexture2D,
	screen_width:    c.int,
	screen_height:   c.int,
	screen_texture:  rl.RenderTexture2D,
} {
	screen_width  = 1500,
	screen_height = 1000,
	bg            = {90, 95, 100, 255},
}

mouse_buttons_map := [mu.Mouse]rl.MouseButton {
	.LEFT   = .LEFT,
	.RIGHT  = .RIGHT,
	.MIDDLE = .MIDDLE,
}

key_map := [mu.Key][2]rl.KeyboardKey {
	.SHIFT     = {.LEFT_SHIFT, .RIGHT_SHIFT},
	.CTRL      = {.LEFT_CONTROL, .RIGHT_CONTROL},
	.ALT       = {.LEFT_ALT, .RIGHT_ALT},
	.BACKSPACE = {.BACKSPACE, .KEY_NULL},
	.DELETE    = {.DELETE, .KEY_NULL},
	.RETURN    = {.ENTER, .KP_ENTER},
	.LEFT      = {.LEFT, .KEY_NULL},
	.RIGHT     = {.RIGHT, .KEY_NULL},
	.HOME      = {.HOME, .KEY_NULL},
	.END       = {.END, .KEY_NULL},
	.A         = {.A, .KEY_NULL},
	.X         = {.X, .KEY_NULL},
	.C         = {.C, .KEY_NULL},
	.V         = {.V, .KEY_NULL},
}
// TODO: Add state for raylib data needed for ui. So we can easily create function for init and (defer) deinit. 


get_text_width :: proc(font: mu.Font, text: string) -> (width: i32) {
	return mu.default_atlas_text_width(font, text)
}

get_text_height :: proc(font: mu.Font) -> (width: i32) {
	return mu.default_atlas_text_height(font)
}

init_game_ui :: proc(ctx: ^mu.Context) {
	ctx := &state.mu_ctx
	mu.init(ctx, set_clipboard = proc(user_data: rawptr, text: string) -> (ok: bool) {
			cstr := strings.clone_to_cstring(text)
			rl.SetClipboardText(cstr)
			delete(cstr)
			return true
		}, get_clipboard = proc(user_data: rawptr) -> (text: string, ok: bool) {
			cstr := rl.GetClipboardText()
			if cstr != nil {
				text = string(cstr)
				ok = true
			}
			return
		})

	ctx.text_width = get_text_width
	ctx.text_height = get_text_height

	state.atlas_texture = rl.LoadRenderTexture(
		c.int(mu.DEFAULT_ATLAS_WIDTH),
		c.int(mu.DEFAULT_ATLAS_HEIGHT),
	)

	image := rl.GenImageColor(
		c.int(mu.DEFAULT_ATLAS_WIDTH),
		c.int(mu.DEFAULT_ATLAS_HEIGHT),
		rl.Color{0, 0, 0, 0},
	)
	defer rl.UnloadImage(image)

	for alpha, i in mu.default_atlas_alpha {
		x := i % mu.DEFAULT_ATLAS_WIDTH
		y := i / mu.DEFAULT_ATLAS_WIDTH
		color := rl.Color{255, 255, 255, alpha}
		rl.ImageDrawPixel(&image, c.int(x), c.int(y), color)
	}

	rl.BeginTextureMode(state.atlas_texture)
	rl.UpdateTexture(state.atlas_texture.texture, rl.LoadImageColors(image))
	rl.EndTextureMode()

	state.screen_texture = rl.LoadRenderTexture(state.screen_width, state.screen_height)
}

deinit_game_ui :: proc() {
	rl.UnloadRenderTexture(state.atlas_texture)
	rl.UnloadRenderTexture(state.screen_texture)
}

main :: proc() {
	rl.ConfigFlags({rl.ConfigFlag.WINDOW_RESIZABLE})
	rl.InitWindow(1000, 1000, "test")
	defer rl.CloseWindow()
	rl.SetTargetFPS(180)

	ctx := &state.mu_ctx

	init_game_ui(&state.mu_ctx)
	defer deinit_game_ui()

	for !rl.WindowShouldClose() {
		free_all(context.temp_allocator)

		if rl.IsKeyPressed(rl.KeyboardKey.F) {

			rl.ToggleBorderlessWindowed()
		}

		if ((rl.GetScreenWidth() != state.screen_width) ||
			   (rl.GetScreenHeight() != state.screen_height)) {
			resize_ui()
		}

		handle_input_micro_ui(ctx)

		mu.begin(ctx)
		all_windows(ctx)
		mu.end(ctx)

		render(ctx)
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		// Draw 3D stuff
		rl.DrawRectangle(0, 0, 200, 300, rl.GREEN)

		draw_ui()

		rl.EndDrawing()
	}
}

resize_ui :: proc() {
	state.screen_width = rl.GetScreenWidth()
	state.screen_height = rl.GetScreenHeight()

	rl.UnloadRenderTexture(state.screen_texture)
	state.screen_texture = rl.LoadRenderTexture(state.screen_width, state.screen_height)
}

handle_input_micro_ui :: proc(ctx: ^mu.Context) {
	mouse_pos := rl.GetMousePosition()
	mouse_x, mouse_y := i32(mouse_pos.x), i32(mouse_pos.y)
	mu.input_mouse_move(ctx, mouse_x, mouse_y)

	mouse_wheel_pos := rl.GetMouseWheelMoveV()
	mu.input_scroll(ctx, i32(mouse_wheel_pos.x) * 30, i32(mouse_wheel_pos.y) * -30)

	for button_rl, button_mu in mouse_buttons_map {
		switch {
		case rl.IsMouseButtonPressed(button_rl):
			mu.input_mouse_down(ctx, mouse_x, mouse_y, button_mu)
		case rl.IsMouseButtonReleased(button_rl):
			mu.input_mouse_up(ctx, mouse_x, mouse_y, button_mu)
		}
	}

	for keys_rl, key_mu in key_map {
		for key_rl in keys_rl {
			switch {
			case key_rl == .KEY_NULL:
			// ignore
			case rl.IsKeyPressed(key_rl), rl.IsKeyPressedRepeat(key_rl):
				mu.input_key_down(ctx, key_mu)
			case rl.IsKeyReleased(key_rl):
				mu.input_key_up(ctx, key_mu)
			}
		}
	}

	{
		buf: [512]byte
		n: int
		for n < len(buf) {
			c := rl.GetCharPressed()
			if c == 0 {
				break
			}
			b, w := utf8.encode_rune(c)
			n += copy(buf[n:], b[:w])
		}
		mu.input_text(ctx, string(buf[:n]))
	}
}

render :: proc "contextless" (ctx: ^mu.Context) {
	render_texture :: proc "contextless" (
		renderer: rl.RenderTexture2D,
		dst: ^rl.Rectangle,
		src: mu.Rect,
		color: rl.Color,
	) {
		dst.width = f32(src.w)
		dst.height = f32(src.h)

		/*
		rl.DrawTexturePro(
			texture = state.atlas_texture.texture,
			source = {f32(src.x), f32(src.y), f32(src.w), f32(src.h)},
			dest = {dst.x, dst.y, 12, 24},
			origin = {0, 0},
			rotation = 0,
			tint = rl.WHITE,
		)
		*/
		rl.DrawTextureRec(
			texture = state.atlas_texture.texture,
			source = {f32(src.x), f32(src.y), f32(src.w), f32(src.h)},
			position = {dst.x, dst.y},
			tint = color,
		)
	}

	to_rl_color :: proc "contextless" (in_color: mu.Color) -> (out_color: rl.Color) {
		return {in_color.r, in_color.g, in_color.b, in_color.a}
	}

	height := rl.GetScreenHeight()

	rl.BeginTextureMode(state.screen_texture)
	rl.EndScissorMode()
	//rl.ClearBackground(to_rl_color(state.bg))
	rl.ClearBackground(rl.BLANK) // blank if ui should be transparent

	command_backing: ^mu.Command
	for variant in mu.next_command_iterator(ctx, &command_backing) {
		switch cmd in variant {
		case ^mu.Command_Text:
			dst := rl.Rectangle{f32(cmd.pos.x), f32(cmd.pos.y), 0, 0}
			for ch in cmd.str {
				if ch & 0xc0 != 0x80 {
					r := min(int(ch), 127)
					src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
					render_texture(state.screen_texture, &dst, src, to_rl_color(cmd.color))
					dst.x += dst.width
				}
			}
		case ^mu.Command_Rect:
			rl.DrawRectangle(
				cmd.rect.x,
				cmd.rect.y,
				cmd.rect.w,
				cmd.rect.h,
				to_rl_color(cmd.color),
			)
		case ^mu.Command_Icon:
			src := mu.default_atlas[cmd.id]
			x := cmd.rect.x + (cmd.rect.w - src.w) / 2
			y := cmd.rect.y + (cmd.rect.h - src.h) / 2
			render_texture(
				state.screen_texture,
				&rl.Rectangle{f32(x), f32(y), 0, 0},
				src,
				to_rl_color(cmd.color),
			)
		case ^mu.Command_Clip:
			rl.BeginScissorMode(
				cmd.rect.x,
				height - (cmd.rect.y + cmd.rect.h),
				cmd.rect.w,
				cmd.rect.h,
			)
		case ^mu.Command_Jump:
			unreachable()
		}
	}
	rl.EndTextureMode()

}

// Should be called after BeginDrawing() and before rl.EndDrawing()
draw_ui :: proc() {

	// Draw our UI on top
	rl.DrawTextureRec(
		texture = state.screen_texture.texture,
		source = {0, 0, f32(state.screen_width), -f32(state.screen_height)},
		position = {0, 0},
		tint = rl.WHITE,
	)
}

u8_slider :: proc(ctx: ^mu.Context, val: ^u8, lo, hi: u8) -> (res: mu.Result_Set) {
	mu.push_id(ctx, uintptr(val))

	@(static) tmp: mu.Real
	tmp = mu.Real(val^)
	res = mu.slider(ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", {.ALIGN_CENTER})
	val^ = u8(tmp)
	mu.pop_id(ctx)
	return
}

write_log :: proc(str: string) {
	state.log_buf_len += copy(state.log_buf[state.log_buf_len:], str)
	state.log_buf_len += copy(state.log_buf[state.log_buf_len:], "\n")
	state.log_buf_updated = true
}

read_log :: proc() -> string {
	return string(state.log_buf[:state.log_buf_len])
}
reset_log :: proc() {
	state.log_buf_updated = true
	state.log_buf_len = 0
}

construct_button_positionts_unit_circle :: proc(
	num: u8,
	size: mu.Vec2,
) -> (
	locations: [dynamic]mu.Vec2,
) {
	// TODO: Add padding, consider just creating the button rect directly?

	center := size / 2
	locations = make([dynamic]mu.Vec2, num)

	for i in 0 ..< num {
		i_f := cast(f32)i
		current_radian := (i_f / cast(f32)num) * (math.PI * 2.0)

		x := cast(i32)(math.cos(current_radian) * cast(f32)center.x) // Center is also the half size
		y := cast(i32)(math.sin(current_radian) * cast(f32)center.y) // Center is also the half size
		x += center.x
		y += center.y

		locations[i] = mu.Vec2{x, y}
	}

	return locations
}

singned_angle :: proc(v1, v2: rl.Vector2) -> f32 {
	dot := v1.x * v2.x + v1.y * v2.y
	det := v1.x * v2.y - v1.y * v2.x // equivalent to 2D cross product (scalar)
	return math.atan2(det, dot) // atan2 returns signed angle
}

which_pie_is_position_in :: proc(
	mouse_position: mu.Vec2,
	center: mu.Vec2,
	num: u8,
	deadzone: f32,
) -> (
	ok: bool,
	index: u8,
) {
	UP :: rl.Vector2{1, 0}
	half_segment := ((math.PI * 2) / cast(f32)num) / 2
	mouse_position_float := rl.Vector2{cast(f32)mouse_position.x, cast(f32)mouse_position.y}
	center_float := rl.Vector2{cast(f32)center.x, cast(f32)center.y}

	if linalg.distance(mouse_position_float, center_float) < deadzone do return false, 0


	//angle := linalg.angle_between(UP, mouse_position_float - center_float)
	angle := singned_angle(UP, mouse_position_float - center_float)

	angle += half_segment
	if angle < 0 do angle = (math.PI * 2) + (angle)

	normalized_angle := angle / (2 * math.PI)
	normalized_angle *= (cast(f32)num)

	//fmt.println("angle ", angle)

	index = cast(u8)normalized_angle
	//fmt.println("index ", index)

	ok = true
	return ok, index
}


all_windows :: proc(ctx: ^mu.Context) {
	@(static) opts := mu.Options{.NO_CLOSE}


	if mu.window(
	ctx,
	"stats",
	mu.Rect{1000, 1000, 350, 700},
	{
		/*
			mu.Opt.NO_FRAME,
			mu.Opt.NO_INTERACT,
			mu.Opt.NO_SCROLL,
			mu.Opt.NO_CLOSE,
			mu.Opt.NO_RESIZE,
			mu.Opt.NO_TITLE,
		*/
	},
	) {
		mu.label(ctx, "hey")

	}

	if mu.window(
		ctx,
		"My cool Pie test window",
		mu.Rect{660, 40, 600, 500},
		{
			mu.Opt.EXPANDED,
			mu.Opt.NO_CLOSE,
			mu.Opt.NO_SCROLL,
			mu.Opt.NO_FRAME,
			mu.Opt.NO_RESIZE,
			mu.Opt.NO_TITLE,
		},
	) {

		WIDGET_SIZE :: mu.Vec2{800, 800}
		center := mu.Vec2{rl.GetScreenWidth() / 2, rl.GetScreenHeight() / 2}
		pie_widget_corner := mu.Rect {
			rl.GetScreenWidth() / 2 - WIDGET_SIZE.x / 2,
			rl.GetScreenHeight() / 2 - WIDGET_SIZE.y / 2,
			WIDGET_SIZE.x,
			WIDGET_SIZE.y,
		}
		BUTTON_WIDTH :: 120
		BUTTON_HEIGHT :: 30

		// We first do this as simple as possible with some buttons. Can possibly be its own control after a while? Or maybe this is enough?
		mu.get_current_container(ctx).rect = pie_widget_corner
		current_container_rect := mu.get_current_container(ctx).rect
		locations := construct_button_positionts_unit_circle(
		8,
		mu.Vec2 {
			current_container_rect.w - BUTTON_WIDTH - 10, // TODO: Some hidden panning, I think microUI has the exact varaible / number somewhere I can use.
			current_container_rect.h - BUTTON_HEIGHT - 10,
		},
		)

		ok, index := which_pie_is_position_in(ctx.mouse_pos, mu.Vec2{center.x, center.y}, 8, 40)
		fmt.printfln("ok {}, index {}", ok, index)


		for &loc, i in locations {
			button_rect := mu.Rect{loc.x, loc.y, BUTTON_WIDTH, BUTTON_HEIGHT}

			screen_space_button_rect := mu.Vec2 {
				button_rect.x + current_container_rect.x,
				button_rect.y + current_container_rect.y,
			}
			message := fmt.aprintf("button {}", i)

			button_id := mu.get_id(ctx, message)

			mu.layout_set_next(ctx, button_rect, true)
			r := mu.layout_next(ctx)
			mu.draw_control_frame(ctx, button_id, r, .BUTTON, {mu.Opt.ALIGN_CENTER})

			mu.layout_set_next(ctx, button_rect, true)
			button_result := mu.button(ctx, message, .NONE, {.NO_FRAME})


			mouse_pos := rl.Vector2 {
				cast(f32)ctx.mouse_pos.x - BUTTON_WIDTH / 2,
				cast(f32)ctx.mouse_pos.y - BUTTON_HEIGHT / 2,
			}

			button_pos := rl.Vector2 {
				cast(f32)screen_space_button_rect.x,
				cast(f32)screen_space_button_rect.y,
			}
			//if (linalg.vector_length(mouse_pos - button_pos)) < 100 {
			if (cast(u8)i == index) {

				ctx.hover_id = button_id
				if ctx.mouse_down_bits != nil {
					mu.set_focus(ctx, button_id)
				}

			}


			if button_result != nil {
				write_log(fmt.aprintf("{} {}", "Bazinga!", message))
			}
		}
	}

	/*
	if mu.window(ctx, "Demo Window", {40, 40, 300, 450}, opts) {
		if .ACTIVE in mu.header(ctx, "Window Info") {
			win := mu.get_current_container(ctx)
			mu.layout_row(ctx, {54, -1}, 0)
			mu.label(ctx, "Position:")
			mu.label(ctx, fmt.tprintf("%d, %d", win.rect.x, win.rect.y))
			mu.label(ctx, "Size:")
			mu.label(ctx, fmt.tprintf("%d, %d", win.rect.w, win.rect.h))
		}

		if .ACTIVE in mu.header(ctx, "Window Options") {
			mu.layout_row(ctx, {120, 120, 120}, 0)
			for opt in mu.Opt {
				state := opt in opts
				if .CHANGE in mu.checkbox(ctx, fmt.tprintf("%v", opt), &state) {
					if state {
						opts += {opt}
					} else {
						opts -= {opt}
					}
				}
			}
		}

		if .ACTIVE in mu.header(ctx, "Test Buttons", {.EXPANDED}) {
			mu.layout_row(ctx, {86, -110, -1})
			mu.label(ctx, "Test buttons 1:")
			if .SUBMIT in mu.button(ctx, "Button 1") {write_log("Pressed button 1")}
			if .SUBMIT in mu.button(ctx, "Button 2") {write_log("Pressed button 2")}
			mu.label(ctx, "Test buttons 2:")
			if .SUBMIT in mu.button(ctx, "Button 3") {write_log("Pressed button 3")}
			if .SUBMIT in mu.button(ctx, "Button 4") {write_log("Pressed button 4")}
		}

		if .ACTIVE in mu.header(ctx, "Tree and Text", {.EXPANDED}) {
			mu.layout_row(ctx, {140, -1})
			mu.layout_begin_column(ctx)
			if .ACTIVE in mu.treenode(ctx, "Test 1") {
				if .ACTIVE in mu.treenode(ctx, "Test 1a") {
					mu.label(ctx, "Hello")
					mu.label(ctx, "world")
				}
				if .ACTIVE in mu.treenode(ctx, "Test 1b") {
					if .SUBMIT in mu.button(ctx, "Button 1") {write_log("Pressed button 1")}
					if .SUBMIT in mu.button(ctx, "Button 2") {write_log("Pressed button 2")}
				}
			}
			if .ACTIVE in mu.treenode(ctx, "Test 2") {
				mu.layout_row(ctx, {53, 53})
				if .SUBMIT in mu.button(ctx, "Button 3") {write_log("Pressed button 3")}
				if .SUBMIT in mu.button(ctx, "Button 4") {write_log("Pressed button 4")}
				if .SUBMIT in mu.button(ctx, "Button 5") {write_log("Pressed button 5")}
				if .SUBMIT in mu.button(ctx, "Button 6") {write_log("Pressed button 6")}
			}
			if .ACTIVE in mu.treenode(ctx, "Test 3") {
				@(static) checks := [3]bool{true, false, true}
				mu.checkbox(ctx, "Checkbox 1", &checks[0])
				mu.checkbox(ctx, "Checkbox 2", &checks[1])
				mu.checkbox(ctx, "Checkbox 3", &checks[2])

			}
			mu.layout_end_column(ctx)

			mu.layout_begin_column(ctx)
			mu.layout_row(ctx, {-1})
			mu.text(
				ctx,
				"Lorem ipsum dolor sit amet, consectetur adipiscing " +
				"elit. Maecenas lacinia, sem eu lacinia molestie, mi risus faucibus " +
				"ipsum, eu varius magna felis a nulla.",
			)
			mu.layout_end_column(ctx)
		}

		if .ACTIVE in mu.header(ctx, "Background Colour", {.EXPANDED}) {
			mu.layout_row(ctx, {-78, -1}, 68)
			mu.layout_begin_column(ctx)
			{
				mu.layout_row(ctx, {46, -1}, 0)
				mu.label(ctx, "Red:");u8_slider(ctx, &state.bg.r, 0, 255)
				mu.label(ctx, "Green:");u8_slider(ctx, &state.bg.g, 0, 255)
				mu.label(ctx, "Blue:");u8_slider(ctx, &state.bg.b, 0, 255)
			}
			mu.layout_end_column(ctx)

			r := mu.layout_next(ctx)
			mu.draw_rect(ctx, r, state.bg)
			mu.draw_box(ctx, mu.expand_rect(r, 1), ctx.style.colors[.BORDER])
			mu.draw_control_text(
				ctx,
				fmt.tprintf("#%02x%02x%02x", state.bg.r, state.bg.g, state.bg.b),
				r,
				.TEXT,
				{.ALIGN_CENTER},
			)
		}
	}


	if mu.window(ctx, "Style Window", {350, 250, 300, 240}) {
		@(static) colors := [mu.Color_Type]string {
			.TEXT         = "text",
			.BORDER       = "border",
			.WINDOW_BG    = "window bg",
			.TITLE_BG     = "title bg",
			.TITLE_TEXT   = "title text",
			.PANEL_BG     = "panel bg",
			.BUTTON       = "button",
			.BUTTON_HOVER = "button hover",
			.BUTTON_FOCUS = "button focus",
			.BASE         = "base",
			.BASE_HOVER   = "base hover",
			.BASE_FOCUS   = "base focus",
			.SCROLL_BASE  = "scroll base",
			.SCROLL_THUMB = "scroll thumb",
			.SELECTION_BG = "selection bg",
		}

		sw := i32(f32(mu.get_current_container(ctx).body.w) * 0.14)
		mu.layout_row(ctx, {80, sw, sw, sw, sw, -1})
		for label, col in colors {
			mu.label(ctx, label)
			u8_slider(ctx, &ctx.style.colors[col].r, 0, 255)
			u8_slider(ctx, &ctx.style.colors[col].g, 0, 255)
			u8_slider(ctx, &ctx.style.colors[col].b, 0, 255)
			u8_slider(ctx, &ctx.style.colors[col].a, 0, 255)
			mu.draw_rect(ctx, mu.layout_next(ctx), ctx.style.colors[col])
		}
	}
*/

	if mu.window(ctx, "Log Window", {350, 40, 300, 200}, opts) {
		mu.layout_row(ctx, {-1}, -28)
		mu.begin_panel(ctx, "Log")
		mu.layout_row(ctx, {-1}, -1)
		mu.text(ctx, read_log())
		if state.log_buf_updated {
			panel := mu.get_current_container(ctx)
			panel.scroll.y = panel.content_size.y
			state.log_buf_updated = false
		}
		mu.end_panel(ctx)

		@(static) buf: [128]byte
		@(static) buf_len: int
		submitted := false
		mu.layout_row(ctx, {-70, -1})
		if .SUBMIT in mu.textbox(ctx, buf[:], &buf_len) {
			mu.set_focus(ctx, ctx.last_id)
			submitted = true
		}
		if .SUBMIT in mu.button(ctx, "Submit") {
			submitted = true
		}
		if submitted {
			write_log(string(buf[:buf_len]))
			buf_len = 0
		}
	}
}
