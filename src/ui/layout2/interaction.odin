package layout

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
		handle_resize_click(ctx, ctx.resize_click, hovered_layout_item, corner)
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

	// TODO: should probaby store what state / hovered node and corner etc.
	// TODO: resize to min size when under min size

	if pointer_state == .Pressed {
		delta_mouse_move := ctx.mouse_pos - ctx.mouse_pos_last_frame

		x_scalar_item_handle, y_scalar_item_handle := get_scalers_x_y(
			&ctx.lic,
			hovered_layout_item.handle,
			is_right(corner),
			is_down(corner),
			delta_mouse_move,
		)

		if hms.valid(ctx.lic, x_scalar_item_handle) {
			scale_layout_item(
				ctx,
				x_scalar_item_handle,
				true,
				is_right(corner),
				delta_mouse_move.x,
			)

		}
		if hms.valid(ctx.lic, y_scalar_item_handle) {

			scale_layout_item(
				ctx,
				y_scalar_item_handle,
				false,
				is_down(corner),
				delta_mouse_move.y,
			)
		}
	}
}

@(private)
scale_layout_item :: proc(
	ctx: ^Context,
	x_scalar_handle: Layout_Item_Handle,
	horizontal: bool,
	after: bool,
	delta_mouse_move: f32,
) {
	x_scalar_item := get_item_checked(&ctx.lic, x_scalar_handle)

	if x_scalar_item != nil {
		parent_scalar_x, ok_parent_scalar_x := get_item(&ctx.lic, x_scalar_item.parent_handle)
		if !ok_parent_scalar_x do return
		neighbour_handle := get_neighbour_with_min_size(
			&ctx.lic,
			x_scalar_item.handle,
			horizontal,
			// is_right(corner),
			after,
			delta_mouse_move > 0,
		)
		neighbour, neighbour_ok := get_item(&ctx.lic, neighbour_handle)
		if !neighbour_ok do return

		input_flip_flop: f32 = after ? 1 : -1

		scalar_x_parent_bounding_box := get_clay_bounding_box(parent_scalar_x.id)
		neighbour_x_parent_bounding_box := get_clay_bounding_box(
			get_item_checked(&ctx.lic, neighbour.parent_handle).id,
		)

		if horizontal {
			percent_change_x_scalar := delta_mouse_move / scalar_x_parent_bounding_box.width
			x_scalar_item.size_percent.x += percent_change_x_scalar * input_flip_flop
			percent_change_x_neighbour := delta_mouse_move / neighbour_x_parent_bounding_box.width
			neighbour.size_percent.x -= percent_change_x_neighbour * input_flip_flop

		} else {
			percent_change_x_scalar := delta_mouse_move / scalar_x_parent_bounding_box.height
			x_scalar_item.size_percent.y += percent_change_x_scalar * input_flip_flop
			percent_change_x_neighbour := delta_mouse_move / neighbour_x_parent_bounding_box.height
			neighbour.size_percent.y -= percent_change_x_neighbour * input_flip_flop

		}

		normalize_sizes_recursive(&ctx.lic, ctx.root)

		// update_min_size_elements(&ctx.lic, ctx.root, {})

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
