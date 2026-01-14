package layout

import hms "../../handle_map/handle_map_static/"
import clay "../clay-odin/"


interaction :: proc(
	ctx: ^Context,
	left_click, right_click, middle_click: clay.PointerDataInteractionState,
) {

	hovered_layout_item_handle: Layout_Item_Handle

	// brute force find the if we are hovering a Layout_Item
	for layout_item in ctx.lic.items {
		if hms.skip(layout_item) do continue

		layout_clay_id := clay.GetElementId(clay.MakeString(layout_item.id))

		if clay.PointerOver(layout_clay_id) {
			hovered_layout_item_handle = layout_item.handle
			break
		}
	}

	if !hms.valid(ctx.lic, hovered_layout_item_handle) do return // expected, might not hover over any Layout_Item

	hovered_layout_item := hms.get(&ctx.lic, hovered_layout_item_handle)

	// what corner are we in
	// what action

}
