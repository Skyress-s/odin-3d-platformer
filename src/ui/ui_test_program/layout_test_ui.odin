package ui_test
import ui "../"
import layout "../layout/"
import "core:fmt"

layout_window_1 :: proc(node: ^layout.Tiling_Node, active_elems: ^layout.Active_Elements) {
	@(static) checkbox_1 := false

	ctx := cast(^ui.Context)node.userdata
	assert(ctx != nil)

	ui.layout_checkbox(fmt.tprint("checkbox_1"), &checkbox_1)
	@(static) text_buf: [256]byte
	text_len := 0
	ui.layout_textbox_immediate2(ctx, text_buf[:], &text_len)


}
