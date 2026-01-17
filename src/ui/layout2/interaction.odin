package layout
import "core:fmt"

import hms "../../handle_map/handle_map_static/"
import clay "../clay-odin/"

interaction :: proc(ctx: ^Context) {

	hovered_layout_item_handle: Layout_Item_Handle

	// brute force find the if we are hovering a Layout_Item
	for layout_item in ctx.lic.items {
		if hms.skip(layout_item) do continue

		if !is_leaf(&ctx.lic, layout_item.handle) do continue

		layout_clay_id := clay.GetElementId(clay.MakeString(layout_item.id))

		if clay.PointerOver(layout_clay_id) {
			hovered_layout_item_handle = layout_item.handle
			break
		}

	}

	if !hms.valid(ctx.lic, hovered_layout_item_handle) do return // expected, might not hover over any Layout_Item

	hovered_layout_item := hms.get(&ctx.lic, hovered_layout_item_handle)
	assert(hms.valid(ctx.lic, hovered_layout_item.parent_handle))

	hovered_element_data := clay.GetElementData(
		clay.GetElementId(clay.MakeString(hovered_layout_item.id)),
	)
	assert(hovered_element_data.found)

	hovered_bounding_box := hovered_element_data.boundingBox


	// priority: Resize, add, remove
	corner := closest_corner(hovered_bounding_box, ctx.mouse_pos)
	edge := closest_edge(hovered_bounding_box, ctx.mouse_pos)

	// TODO: These != .Released is stupid
	if ctx.resize_click != .Released {
		handle_resize_click(ctx, ctx.add_click, hovered_layout_item, corner)

	} else if ctx.add_click != .Released {
		handle_add_click(ctx, ctx.add_click, hovered_layout_item, edge)

	} else if ctx.remove_click != .Released {
		handle_remove_click(ctx, ctx.remove_click, hovered_layout_item)
	}
}

@(private)
handle_resize_click :: proc(
	ctx: ^Context,
	pointer_state: clay.PointerDataInteractionState,
	hovered_layout_item: ^Layout_Item,
	corner: Corner,
) {

	if pointer_state == .PressedThisFrame {


	} else if pointer_state == .Pressed {

	}

}

@(private)
handle_add_click :: proc(
	ctx: ^Context,
	pointer_state: clay.PointerDataInteractionState,
	hovered_layout_item: ^Layout_Item,
	edge: Edge,
) {

	if pointer_state != .PressedThisFrame do return

	parent_layout_item := get_parent_layout_item(&ctx.lic, hovered_layout_item.handle)
	avg_size := get_average_size(&ctx.lic, hovered_layout_item.parent_handle)
	index_in_parent := get_index_in_parent(&ctx.lic, hovered_layout_item.handle)

	if (is_horizontal_edge(edge) && parent_layout_item.layout_dir == .LeftToRight) ||
	   (is_vertical_edge(edge) && parent_layout_item.layout_dir == .TopToBottom) {
		insert_same_level(
			ctx,
			avg_size,
			index_in_parent,
			edge,
			parent_layout_item,
			hovered_layout_item,
		)
	} else {
		insert_new_level(
			ctx,
			avg_size,
			index_in_parent,
			edge,
			parent_layout_item,
			hovered_layout_item,
		)

	}
}

@(private)
handle_remove_click :: proc(
	ctx: ^Context,
	pointer_state: clay.PointerDataInteractionState,
	hovered_layout_item: ^Layout_Item,
) {
	if pointer_state != .PressedThisFrame do return

	remove_leaf_item(ctx, hovered_layout_item.handle)
}
