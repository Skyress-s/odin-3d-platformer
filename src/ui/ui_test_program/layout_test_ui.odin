package ui_test
import ui "../"
import layout "../layout/"
import "core:fmt"

layout_window_1 :: proc(node: ^layout.Tiling_Node, active_elems: ^layout.Active_Elements) {

	ctx := cast(^ui.Context)node.userdata
	assert(ctx != nil)

	@(static) checkbox_1 := false
	ui.layout_checkbox_immediate(ctx, fmt.tprint("checkbox_1"), &checkbox_1)

	@(static) checkbox_2 := false
	ui.layout_checkbox_immediate(ctx, fmt.tprint("checkbox_2"), &checkbox_2)

	@(static) text_buf: [256]byte
	@(static) text_len := 0
	ui.layout_textbox_immediate2(ctx, text_buf[:], &text_len)

	@(static) dropped_down_1 := false
	if ui.layout_dropdown(ctx, fmt.tprint("Dropdown 1"), &dropped_down_1) {
		if ui.layout_button_immediate(ctx, fmt.tprint("Button 1")) {
			fmt.printfln("Dropdown 1 was clicked!")
		}
		if ui.layout_button_immediate(ctx, fmt.tprint("Button 2")) {
			fmt.printfln("Dropdown 2 was clicked!")
		}

		ui.layout_dynamic_text_entry(fmt.tprintf("some text 1"))
	}


}

layout_stats_window :: proc(node: ^layout.Tiling_Node, active_elems: ^layout.Active_Elements) {

	ctx := cast(^ui.Context)node.userdata
	assert(ctx != nil)

	ui.layout_dynamic_text_entry(fmt.tprintf("focus_id {}", ctx.focus_id))
	ui.layout_dynamic_text_entry(fmt.tprintf("hover_id {}", ctx.hover_id))
	ui.layout_dynamic_text_entry(fmt.tprintf("mouse_down_bits {}", ctx.mouse_down_bits))
	ui.layout_dynamic_text_entry(fmt.tprintf("mouse_pressed_bits {}", ctx.mouse_pressed_bits))


}
