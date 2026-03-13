package layout

import clay "../clay-odin/"
import hm "core:container/handle_map"

interaction :: proc(ctx: ^Context, allow_interaction: bool) {
	if !allow_interaction do return

	// if ctx.controlling_layout_item != {} do return

	if hm.get(&ctx.lic, ctx.hover_layout_handle) == nil do return // expected, might not hover over any Layout_Item

	hovered_layout_item := hm.get(&ctx.lic, ctx.hover_layout_handle)
	assert(hm.get(&ctx.lic, hovered_layout_item.parent_handle) != nil)

	hovered_element_data := clay.GetElementData(
		clay.GetElementId(clay.MakeString(hovered_layout_item.id)),
	)
	assert(hovered_element_data.found)

	hovered_bounding_box := hovered_element_data.boundingBox

	corner := closest_corner(hovered_bounding_box, ctx.mouse_pos)
	edge := closest_edge(hovered_bounding_box, ctx.mouse_pos)


	// TODO: These != .Released is stupid
	if ctx.resize_click != .Released {
		handle_resize_click(ctx, ctx.resize_click, hovered_layout_item, corner)
	} else if ctx.add_click != .Released {
		handle_add_click(ctx, ctx.add_click, hovered_layout_item, edge)
	} else if ctx.remove_click != .Released {
		handle_remove_click(ctx, ctx.remove_click, hovered_layout_item)
	} else if ctx.move_click != .Released {
		handle_move_click(ctx, ctx.move_click, corner, edge, hovered_layout_item)
	} else if (ctx.pressed_fullscreen_this_frame) {
		if ctx.fullscreen_layout_handle == {} {
			ctx.fullscreen_layout_handle = ctx.hover_layout_handle
		} else {
			ctx.fullscreen_layout_handle = {}
		}
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

		if hm.get(&ctx.lic, x_scalar_item_handle) != nil {
			scale_layout_item(
				ctx,
				x_scalar_item_handle,
				true,
				is_right(corner),
				delta_mouse_move.x,
			)

		}
		if hm.get(&ctx.lic, y_scalar_item_handle) != nil {

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

		scalar_x_parent_bounding_box := get_clay_bounding_box_checked(parent_scalar_x.id)
		neighbour_x_parent_bounding_box := get_clay_bounding_box_checked(
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

	new_item_handle := hm.add(&ctx.lic, make_debug_leaf_layout_item(ctx))
	if (is_horizontal_edge(edge) && parent_layout_item.layout_dir == .LeftToRight) ||
	   (is_vertical_edge(edge) && parent_layout_item.layout_dir == .TopToBottom) {

		insert_item_same_level(
			ctx,
			avg_size,
			index_in_parent,
			edge,
			hovered_layout_item.handle,
			new_item_handle,
		)
	} else {
		insert_item_new_level(
			ctx,
			avg_size,
			index_in_parent,
			edge,
			hovered_layout_item.handle,
			new_item_handle,
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

	remove_leaf_item(ctx, hovered_layout_item.handle, true)
}

handle_move_click :: proc(
	ctx: ^Context,
	pointer_state: clay.PointerDataInteractionState,
	corner: Corner,
	edge: Edge,
	hovered_layout_item: ^Layout_Item,
) {
	parent := get_item_checked(&ctx.lic, hovered_layout_item.parent_handle)

	if pointer_state == .PressedThisFrame && ctx.dragging_handle == {} {
		remove_leaf_item(ctx, hovered_layout_item.handle, false)

		ctx.dragging_handle = hovered_layout_item.handle
		normalize_sizes_recursive(&ctx.lic, ctx.root)
	} else if pointer_state == .ReleasedThisFrame && ctx.dragging_handle != {} {
		dragging_item := get_item_checked(&ctx.lic, ctx.dragging_handle)

		avg_size := get_average_size(&ctx.lic, hovered_layout_item.parent_handle)
		index_in_parent := get_index_in_parent(&ctx.lic, hovered_layout_item.handle)

		if (is_horizontal_edge(edge) && parent.layout_dir == .LeftToRight) ||
		   (is_vertical_edge(edge) && parent.layout_dir == .TopToBottom) {
			insert_item_same_level(
				ctx,
				avg_size,
				index_in_parent,
				edge,
				hovered_layout_item.handle,
				dragging_item.handle,
			)
		} else {
			insert_item_new_level(
				ctx,
				avg_size,
				index_in_parent,
				edge,
				hovered_layout_item.handle,
				dragging_item.handle,
			)
		}

		ctx.dragging_handle = {}

		normalize_sizes_recursive(&ctx.lic, ctx.root)
	}
}
