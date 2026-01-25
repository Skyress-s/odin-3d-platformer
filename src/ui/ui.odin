package ui

import "base:runtime"
import "core:fmt"
import "core:strings"
import textedit "core:text/edit"
import "core:unicode/utf8"

import rl "vendor:raylib"

import ui_rr "../ui/raylib/"
import clay "clay-odin"
import layout "layout2"

// todo this should probably not be a global. But keeping it like this for now.
mouse_buttons_map := [Mouse]rl.MouseButton {
	.LEFT   = .LEFT,
	.RIGHT  = .RIGHT,
	.MIDDLE = .MIDDLE,
}

key_map := [Key][2]rl.KeyboardKey {
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

Color_Configuration :: struct {
	normal, hover: clay.Color,
}

DEFAULT_COLOR_CONFIG :: Color_Configuration {
	normal = layout.COLOR_DARK_GREY,
	hover  = layout.COLOR_GREY,
}

on_hover_update_control :: proc "c" (
	id: clay.ElementId,
	pointerData: clay.PointerData,
	userData: rawptr,
) {
	context = runtime.default_context()
	ctx := cast(^Context)userData
	assert(ctx != nil)

	update_control_2(ctx, id.id, pointerData.state)
}

on_hover_update_control_hold_focus :: proc "c" (
	id: clay.ElementId,
	pointerData: clay.PointerData,
	userData: rawptr,
) {
	context = runtime.default_context()
	ctx := cast(^Context)userData
	assert(ctx != nil)

	update_control_2(ctx, id.id, pointerData.state, true)
}


is_mouse_pressed :: proc(ctx: ^Context) -> bool {
	return Mouse.LEFT in ctx.mouse_pressed_bits
}
is_mouse_down :: proc(ctx: ^Context) -> bool {
	return Mouse.LEFT in ctx.mouse_down_bits
}

layout_dynamic_text_entry :: proc(text: string, text_alignment: clay.TextAlignment = .Left) {
	clay.TextDynamic(
		text,
		clay.TextConfig(
			{
				fontSize = 32,
				fontId = layout.FONT_ID_BODY_16,
				textColor = layout.COLOR_LIGHT,
				textAlignment = text_alignment,
				wrapMode = .Words,
				lineHeight = 32,
			},
		),
	)

}

// Game Window Stats

layout_textbox_immediate :: proc(text_buf: []string, text_buf_length: ^int) {
	@(static) buf: [128]byte
	@(static) buf_len: int
	max_iter := 7
	for key_pressed := rl.GetCharPressed();
	    key_pressed != ' ' && max_iter > 0;
	    key_pressed = rl.GetCharPressed() {
		max_iter -= 1
		if key_pressed == '\b' {
			text_buf_length^ -= 1
		} else {
			// text_buf[4:5] = key_pressed
			text_buf_length^ += 1
		}

	}

}

// todo move to a better place

init :: proc() -> (ctx: Context) {
	strings.builder_init(&ctx.text_input)
	ctx.layout_ctx = layout.init(ui_rr.measure_text)

	return ctx
}
deinit :: proc(ctx: ^Context) {
	strings.builder_destroy(&ctx.text_input)
	layout.deinit(&ctx.layout_ctx)
}

end_frame :: proc(ctx: ^Context) {
	/* check stacks */
	// assert(ctx.container_stack.idx == 0)
	// assert(ctx.clip_stack.idx      == 0)
	// assert(ctx.id_stack.idx        == 0)
	// assert(ctx.layout_stack.idx    == 0)

	/* handle scroll input */
	// if ctx.scroll_target != nil {
	// 	ctx.scroll_target.scroll.x += ctx.scroll_delta.x
	// 	ctx.scroll_target.scroll.y += ctx.scroll_delta.y
	// }

	/* unset focus if focus id was not touched this frame */

	if !ctx.updated_focus {
		ctx.focus_id = 0
	}
	ctx.updated_focus = false

	if !ctx.updated_hover {
		ctx.hover_id = 0
	}
	ctx.updated_hover = false
	// microui.textbox_raw()

	// textedit.end(&ctx.textbox_state)

	/* bring hover root to front if mouse was pressed */
	// if mouse_pressed(ctx) && ctx.next_hover_root != nil &&
	//    ctx.next_hover_root.zindex < ctx.last_zindex &&
	//    ctx.next_hover_root.zindex >= 0 {
	// 	bring_to_front(ctx, ctx.next_hover_root)
	// }

	/* reset input state */
	ctx.key_pressed_bits = {} // clear
	strings.builder_reset(&ctx.text_input)
	ctx.mouse_pressed_bits = {} // clear
	ctx.mouse_released_bits = {} // clear
	ctx.scroll_delta = Vec2{0, 0}
	ctx.last_mouse_pos = ctx.mouse_pos

	/* sort root containers by zindex */
	// n := ctx.root_list.idx
	// sort.quick_sort_proc(ctx.root_list.items[:n], proc(a, b: ^Container) -> int {
	// 	return int(a.zindex) - int(b.zindex)
	// })

	/* set root container jump commands */
	// for i: i32 = 0; i < n; i += 1 {
	// 	cnt := ctx.root_list.items[i]
	// 	/* if this is the first container then make the first command jump to it.
	// 	** otherwise set the previous container's tail to jump to this one */
	// 	if i == 0 {
	// 		cmd := (^Command_Jump)(&ctx.command_list.items[0])
	// 		cmd.dst = rawptr(uintptr(cnt.head) + size_of(Command_Jump))
	// 	} else {
	// 		prev := ctx.root_list.items[i - 1]
	// 		prev.tail.variant.(^Command_Jump).dst = rawptr(uintptr(cnt.head) + size_of(Command_Jump))
	// 	}
	// 	/* make the last container's tail jump to the end of command list */
	// 	if i == n - 1 {
	// 		cnt.tail.variant.(^Command_Jump).dst = rawptr(&ctx.command_list.items[ctx.command_list.idx])
	// 	}
	// }

}

Key :: enum u32 {
	SHIFT,
	CTRL,
	ALT,
	BACKSPACE,
	DELETE,
	RETURN,
	LEFT,
	RIGHT,
	HOME,
	END,
	A,
	X,
	C,
	V,
}

Key_Set :: distinct bit_set[Key;u32]

Mouse :: enum u32 {
	LEFT,
	RIGHT,
	MIDDLE,
}
Mouse_Set :: distinct bit_set[Mouse;u32]

Context :: struct {
	focus_id:                        u32,
	updated_focus:                   bool,
	hover_id:                        u32,
	updated_hover:                   bool,

	// hold_focus:                      bool,
	textbox_state:                   textedit.State,
	text_input:                      strings.Builder,
	// textbox_offset:
	key_down_bits, key_pressed_bits: Key_Set,
	mouse_down_bits:                 Mouse_Set,
	mouse_pressed_bits:              Mouse_Set,
	mouse_released_bits:             Mouse_Set,
	mouse_pos, last_mouse_pos:       Vec2,
	mouse_delta, scroll_delta:       Vec2,

	// ui
	layout_ctx:                      layout.Context,
	// clay_context_data:               Clay_Context_Data,
	// root_node:                       layout.Tiling_Node, // TODO: should these really be in the same context?
}

Clay_Context_Data :: struct {
	arena: clay.Arena,
}

Vec2 :: distinct [2]i32

Text_Input_Context :: struct {
	builder: ^strings.Builder, // huh, we learning today boys!
	id:      string,
}

input_key_down :: proc(ctx: ^Context, key: Key) {
	ctx.key_pressed_bits += {key}
	ctx.key_down_bits += {key}
}
input_key_up :: proc(ctx: ^Context, key: Key) {
	ctx.key_down_bits -= {key}
}

update_key_input :: proc(ctx: ^Context) {
	for keys_rl, key in key_map {
		for key_rl in keys_rl {
			switch {
			case key_rl == .KEY_NULL:
			case rl.IsKeyPressed(key_rl), rl.IsKeyPressedRepeat(key_rl):
				input_key_down(ctx, key)
			case rl.IsKeyReleased(key_rl):
				input_key_up(ctx, key)
			}
		}
	}
}


input_mouse_down :: proc(ctx: ^Context, x, y: i32, btn: Mouse) {
	input_mouse_move(ctx, x, y)
	ctx.mouse_down_bits += {btn}
	ctx.mouse_pressed_bits += {btn}
}

input_mouse_up :: proc(ctx: ^Context, x, y: i32, btn: Mouse) {
	input_mouse_move(ctx, x, y)
	ctx.mouse_down_bits -= {btn}
	ctx.mouse_released_bits += {btn}
}
input_mouse_move :: proc(ctx: ^Context, x, y: i32) {
	ctx.mouse_pos = Vec2{x, y}
}
input_scroll :: proc(ctx: ^Context, x, y: i32) {
	ctx.scroll_delta.x += x
	ctx.scroll_delta.y += y
}

update_mouse_input :: proc(ctx: ^Context) {
	mouse_pos := rl.GetMousePosition()
	mouse_x, mouse_y := i32(mouse_pos.x), i32(mouse_pos.y)
	input_mouse_move(ctx, mouse_x, mouse_y)

	mouse_wheel_pos := rl.GetMouseWheelMoveV()
	input_scroll(ctx, i32(mouse_wheel_pos.x) * 30, i32(mouse_wheel_pos.y) * -30)

	for button_rl, button_mu in mouse_buttons_map {
		switch {
		case rl.IsMouseButtonPressed(button_rl):
			input_mouse_down(ctx, mouse_x, mouse_y, button_mu)
		case rl.IsMouseButtonReleased(button_rl):
			input_mouse_up(ctx, mouse_x, mouse_y, button_mu)
		}
	}
}

update_text_input :: proc(ctx: ^Context) {

	// microui.input_text()
	buf: [512]byte
	n: int
	for n < len(buf) {
		c := rl.GetCharPressed()
		if c == 0 {
			break
		}
		b, w := utf8.encode_rune(c)
		n += copy(buf[n:], b[:w])

		// microui.input_text()
		strings.write_string(&ctx.text_input, string(buf[:n]))
	}
}

update_state :: proc(ctx: ^Context) {
	update_mouse_input(ctx)
	update_key_input(ctx)
	update_text_input(ctx)

	layout.update_state(&ctx.layout_ctx)
}

set_focus :: proc(ctx: ^Context, id: u32) {
	ctx.focus_id = id
	ctx.updated_focus = true
}


set_focus_2 :: proc(ctx: ^Context, id: u32) {
	ctx.focus_id = id
	ctx.updated_focus = true
	// ctx.hold_focus = hold_focus
}

update_control_2 :: proc(
	ctx: ^Context,
	id: u32,
	pointer_state: clay.PointerDataInteractionState,
	hold_focus: bool = false,
	/*, rect: Rect, opt := Options{}*/
) {

	if pointer_state == .Pressed || pointer_state == .PressedThisFrame {
		set_focus_2(ctx, id)
		ctx.focus_id = id
	}

	if ctx.focus_id == id && hold_focus {
		ctx.updated_focus = true
	}

	ctx.hover_id = id
	ctx.updated_hover = true

}

update_control :: proc(
	ctx: ^Context,
	id: u32,
	hold_focus: bool = false,
	/*, rect: Rect, opt := Options{}*/
) {
	// mouseover := microui.mouse_over(ctx, rect)

	// Keep holding focus
	if ctx.focus_id == id {
		ctx.updated_focus = true
	}
	// if .NO_INTERACT in opt {
	// 	return
	// }
	if clay.Hovered() && !is_mouse_down(ctx) {
		ctx.hover_id = id
	}
	//
	//
	if ctx.focus_id == id {
		if is_mouse_pressed(ctx) && !clay.Hovered() {
			// if mouse_pressed(ctx) && !mouseover {
			set_focus(ctx, 0)
		}
		if !is_mouse_down(ctx) && !hold_focus {
			// if !mouse_down(ctx) && .HOLD_FOCUS not_in opt {
			set_focus(ctx, 0)
		}
	}


	if ctx.hover_id == id {
		if is_mouse_pressed(ctx) {
			set_focus(ctx, id)
		} else if !clay.Hovered() {
			ctx.hover_id = 0
		}
	}
}

layout_textbox_immediate2 :: proc(
	ctx: ^Context,
	textbuf: []u8,
	textlen: ^int,
	// id: u32,
	// r: Rect,
	// opt := Options{},
) // res: Result_Set,
{
	// update_control(ctx, id, r, opt | {.HOLD_FOCUS})
	// font := ctx.style.font

	Text_Box_Data :: struct {
		ctx:     ^Context,
		textbuf: []byte,
		textlen: ^int,
	}

	on_hover :: proc "c" (id: clay.ElementId, pointerData: clay.PointerData, userData: rawptr) {
		context = runtime.default_context()

		text_box_data := cast(^Text_Box_Data)userData
		assert(text_box_data != nil)
		ctx := text_box_data.ctx
		textbuf := text_box_data.textbuf
		textlen := text_box_data.textlen

		on_hover_update_control_hold_focus(id, pointerData, ctx)

		if ctx.focus_id == id.id {
			/* create a builder backed by the user's buffer */
			builder := strings.builder_from_bytes(textbuf)
			non_zero_resize(&builder.buf, textlen^)
			ctx.textbox_state.builder = &builder

			if ctx.textbox_state.id != u64(id.id) {
				ctx.textbox_state.id = u64(id.id)
				ctx.textbox_state.selection = {}
			}

			/* check selection bounds */
			if ctx.textbox_state.selection[0] > textlen^ ||
			   ctx.textbox_state.selection[1] > textlen^ {
				ctx.textbox_state.selection = {}
			}

			/* handle text input */
			if strings.builder_len(ctx.text_input) > 0 {
				if textedit.input_text(&ctx.textbox_state, strings.to_string(ctx.text_input)) > 0 {
					textlen^ = strings.builder_len(builder)
					// res += {.CHANGE}
				}
			}
			/* handle ctrl+a */
			if .A in ctx.key_pressed_bits &&
			   .CTRL in ctx.key_down_bits &&
			   .ALT not_in ctx.key_down_bits {
				ctx.textbox_state.selection = {textlen^, 0}
			}
			/* handle ctrl+x */
			if .X in ctx.key_pressed_bits &&
			   .CTRL in ctx.key_down_bits &&
			   .ALT not_in ctx.key_down_bits {
				if textedit.cut(&ctx.textbox_state) {
					textlen^ = strings.builder_len(builder)
					// res += {.CHANGE}
				}
			}
			/* handle ctrl+c */
			if .C in ctx.key_pressed_bits &&
			   .CTRL in ctx.key_down_bits &&
			   .ALT not_in ctx.key_down_bits {
				textedit.copy(&ctx.textbox_state)
			}
			/* handle ctrl+v */
			if .V in ctx.key_pressed_bits &&
			   .CTRL in ctx.key_down_bits &&
			   .ALT not_in ctx.key_down_bits {
				if textedit.paste(&ctx.textbox_state) {
					textlen^ = strings.builder_len(builder)
					// res += {.CHANGE}
				}
			}
			/* handle left/right */
			if .LEFT in ctx.key_pressed_bits {
				move: textedit.Translation = .Word_Left if .CTRL in ctx.key_down_bits else .Left
				if .SHIFT in ctx.key_down_bits {
					textedit.select_to(&ctx.textbox_state, move)
				} else {
					textedit.move_to(&ctx.textbox_state, move)
				}
			}
			if .RIGHT in ctx.key_pressed_bits {
				move: textedit.Translation = .Word_Right if .CTRL in ctx.key_down_bits else .Right
				if .SHIFT in ctx.key_down_bits {
					textedit.select_to(&ctx.textbox_state, move)
				} else {
					textedit.move_to(&ctx.textbox_state, move)
				}
			}
			/* handle home/end */
			if .HOME in ctx.key_pressed_bits {
				if .SHIFT in ctx.key_down_bits {
					textedit.select_to(&ctx.textbox_state, .Start)
				} else {
					textedit.move_to(&ctx.textbox_state, .Start)
				}
			}
			if .END in ctx.key_pressed_bits {
				if .SHIFT in ctx.key_down_bits {
					textedit.select_to(&ctx.textbox_state, .End)
				} else {
					textedit.move_to(&ctx.textbox_state, .End)
				}
			}
			/* handle backspace/delete */
			if .BACKSPACE in ctx.key_pressed_bits && textlen^ > 0 {
				move: textedit.Translation = .Word_Left if .CTRL in ctx.key_down_bits else .Left
				textedit.delete_to(&ctx.textbox_state, move)
				textlen^ = strings.builder_len(builder)
				// res += {.CHANGE}
			}
			if .DELETE in ctx.key_pressed_bits && textlen^ > 0 {
				move: textedit.Translation = .Word_Right if .CTRL in ctx.key_down_bits else .Right
				textedit.delete_to(&ctx.textbox_state, move)
				textlen^ = strings.builder_len(builder)
				// res += {.CHANGE}
			}
			/* handle return */
			if .RETURN in ctx.key_pressed_bits {
				set_focus(ctx, 0)
			}
			/* handle click/drag */
			if .LEFT in ctx.mouse_down_bits {
				idx := textlen^
				// element_data := clay.GetElementData(id).boundingBox
				// for i in 0 ..< textlen^ {
				// 	/* skip continuation bytes */
				// 	if textbuf[i] >= 0x80 && textbuf[i] < 0xc0 {
				// 		continue
				// 	}
				// 	if ctx.mouse_pos.x <
				// 	   element_data.x + ctx.text_width(font, string(textbuf[:i])) { 	// ctx.textbox_offset +
				// 		idx = i
				// 		break
				// 	}
				// }
				ctx.textbox_state.selection[0] = idx
				// if .LEFT in ctx.mouse_pressed_bits && .SHIFT not_in ctx.key_down_bits {
				if pointerData.state == .PressedThisFrame {
					ctx.textbox_state.selection[1] = idx
				}
			}

			/* handle click/drag */
			// if .LEFT in ctx.mouse_down_bits {
			// 	idx := textlen^
			// 	for i in 0 ..< textlen^ {
			// 		/* skip continuation bytes */
			// 		if textbuf[i] >= 0x80 && textbuf[i] < 0xc0 {
			// 			continue
			// 		}
			// 		if ctx.mouse_pos.x <
			// 		   r.x + ctx.textbox_offset + ctx.text_width(font, string(textbuf[:i])) {
			// 			idx = i
			// 			break
			// 		}
			// 	}
			// 	ctx.textbox_state.selection[0] = idx
			// 	if .LEFT in ctx.mouse_pressed_bits && .SHIFT not_in ctx.key_down_bits {
			// 		ctx.textbox_state.selection[1] = idx
			// 	}
			// }
		}
	}

	textstr := string(textbuf[:textlen^])

	if clay.UI()(
		config = clay.ElementDeclaration {
			layout = clay.LayoutConfig {
				layoutDirection = .TopToBottom,
				sizing = clay.Sizing{clay.SizingGrow(), clay.SizingFit()},
			},
			backgroundColor = layout.COLOR_BLUE_DARK,
		},
	) {
		layout_dynamic_text_entry(textstr)

		text_box_data := new(Text_Box_Data, context.allocator) // TODO: Memory leak
		text_box_data.ctx = ctx
		text_box_data.textbuf = textbuf
		text_box_data.textlen = textlen


		// TODO: Ach, the temp allocator is wiped at the end of the frame.

		clay.OnHover(on_hover, text_box_data)
	}


	// /* draw */
	// draw_control_frame(ctx, id, r, .BASE, opt)
	// if ctx.focus_id == id {
	// 	text_color := ctx.style.colors[.TEXT]
	// 	sel_color := ctx.style.colors[.SELECTION_BG]
	// 	textw := ctx.text_width(font, textstr)
	// 	texth := ctx.text_height(font)
	// 	headx := ctx.text_width(font, textstr[:ctx.textbox_state.selection[0]])
	// 	tailx := ctx.text_width(font, textstr[:ctx.textbox_state.selection[1]])
	// 	ofmin := max(ctx.style.padding - headx, r.w - textw - ctx.style.padding)
	// 	ofmax := min(r.w - headx - ctx.style.padding, ctx.style.padding)
	// 	ctx.textbox_offset = clamp(ctx.textbox_offset, ofmin, ofmax)
	// 	textx := r.x + ctx.textbox_offset
	// 	texty := r.y + (r.h - texth) / 2
	// 	push_clip_rect(ctx, r)
	// 	draw_rect(
	// 		ctx,
	// 		Rect{textx + min(headx, tailx), texty, abs(headx - tailx), texth},
	// 		sel_color,
	// 	)
	// 	draw_text(ctx, font, textstr, Vec2{textx, texty}, text_color)
	// 	draw_rect(ctx, Rect{textx + headx, texty, 1, texth}, text_color)
	// 	pop_clip_rect(ctx)
	// } else {
	// 	draw_control_text(ctx, textstr, r, .TEXT, opt)
	// }

	// return
}

layout_button_immediate :: proc(
	ctx: ^Context,
	text: string,
	color_config: Color_Configuration = DEFAULT_COLOR_CONFIG,
) -> bool {
	// id := clay.ID_LOCAL("layout_button_immediate")
	if clay.UI()(
		config = clay.ElementDeclaration {
			layout = {
				layoutDirection = .LeftToRight,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
			},
			backgroundColor = clay.Hovered() ? color_config.hover : color_config.normal,
		},
	) {
		layout_dynamic_text_entry(text)

		clay.OnHover(on_hover_update_control, ctx)

		return clay.Hovered() && is_mouse_pressed(ctx)
	}
	return false
}

// note: I'm not sure why this is not exposed by default (is pressed). I assume its to resolve only the outermost press.
// (If both the parent element and child element has clicking functionality). But lets add it so I can use this and be aware of it.
// Returns on change
layout_checkbox_immediate :: proc(
	ctx: ^Context,
	text: string,
	checked_on: ^bool,
	active: rune = 'x',
	inactive: rune = ' ',
	color_config: Color_Configuration = DEFAULT_COLOR_CONFIG,
) -> bool {


	// id := clay.ID_LOCAL("layout_checkbox_immediate")
	if clay.UI()(
		config = clay.ElementDeclaration {
			layout = {
				layoutDirection = .LeftToRight,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
			},
			backgroundColor = clay.Hovered() ? color_config.hover : color_config.normal,
		},
	) {
		checked_rune := checked_on^ ? active : inactive
		layout_dynamic_text_entry(fmt.tprintf("{} ", checked_rune))
		layout_dynamic_text_entry(text)
		// microui.button()


		// update_control(ctx, id.id)
		clay.OnHover(on_hover_update_control, ctx)
		//
		// update_control(ctx, id.id)

		if clay.Hovered() && is_mouse_pressed(ctx) {
			checked_on^ = !checked_on^
			return true
		}
	}

	return false
}

// layout_checkbox :: proc(
// 	text: string,
// 	checked_on: ^bool,
// 	active: rune = 'x',
// 	inactive: rune = ' ',
// 	color_config: Color_Configuration = DEFAULT_COLOR_CONFIG,
// ) {
// 	if clay.UI()(
// 		config = clay.ElementDeclaration {
// 			layout = {
// 				layoutDirection = .LeftToRight,
// 				sizing = {clay.SizingGrow(), clay.SizingFit()},
// 			},
// 			backgroundColor = clay.Hovered() ? color_config.hover : color_config.normal,
// 		},
// 	) {
//
// 		on_hoover :: proc "c" (
// 			id: clay.ElementId,
// 			pointerData: clay.PointerData,
// 			userData: rawptr,
// 		) {
// 			checked_on := cast(^bool)userData
// 			if pointerData.state == .PressedThisFrame do checked_on^ = !checked_on^
//
// 		}
// 		clay.OnHover(on_hoover, checked_on)
//
// 		checked_rune := checked_on^ ? active : inactive
// 		layout_dynamic_text_entry(fmt.tprintf("[{}] ", checked_rune))
// 		layout_dynamic_text_entry(text)
// 	}
// }

@(deferred_none = clay._CloseElement)
layout_dropdown :: proc(
	ctx: ^Context,
	text: string,
	dropped_down: ^bool,
	color_config: Color_Configuration = DEFAULT_COLOR_CONFIG,
) -> bool {
	layout_checkbox_immediate(ctx, text, dropped_down, 'v', '>')

	clay._OpenElement()
	clay.ConfigureOpenElement(
		config = clay.ElementDeclaration {
			layout = clay.LayoutConfig {
				layoutDirection = .TopToBottom,
				sizing          = {clay.SizingGrow(), clay.SizingFit()},
				// padding = clay.PaddingAll(8),
				padding         = clay.Padding{12, 0, 0, 0}, // indentation
			},
			backgroundColor = clay.Hovered() ? color_config.hover : color_config.normal,
		},
	)


	// mainly here for ergonomics. can use in if
	return dropped_down^
}
