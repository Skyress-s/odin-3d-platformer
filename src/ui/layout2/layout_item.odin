package layout

import "core:c"
import "core:fmt"
import "core:strings"
import "vendor:raylib"

import mem "core:mem"
import vmem "core:mem/virtual"

import hms "../../handle_map/handle_map_static/"
import clay "../clay-odin/"

MIN_WINDOW_SIZE :: 50 // in pixels TODO: Move to Context or settings

Debug_Settings :: struct {
	draw_if_no_content, draw_ids: bool,
}

Context :: struct {
	arena:                                             vmem.Arena,
	arena_allocator:                                   mem.Allocator,
	clay_arena:                                        clay.Arena,
	lic:                                               Layout_Item_Container,
	root, dragging_handle:                             Layout_Item_Handle,
	debug_settings:                                    Debug_Settings,
	remove_click, add_click, resize_click, move_click: clay.PointerDataInteractionState,

	// Not exposed by clay. So need to cache them here too
	mouse_pos:                                         raylib.Vector2,
	mouse_pos_last_frame:                              raylib.Vector2,
}

Layout_Item :: struct {
	handle:        hms.Handle, // Must be present for Handle Map.
	parent_handle: hms.Handle,
	child_nodes:   [dynamic]hms.Handle,

	// Clay stuff
	id:            string,
	layout_dir:    clay.LayoutDirection,

	// Layout
	size_percent:  [2]f32,
	layout_proc:   proc(parent_node: ^Layout_Item, active_elems: ^Active_Elements),
	userdata:      rawptr,
}


Layout_Item_Handle :: hms.Handle

Layout_Item_Container :: hms.Handle_Map(Layout_Item, hms.Handle, 1024)

// TODO: no nil? #no_nil
Edge :: enum {
	Left,
	Right,
	Top,
	Bottom,
}

Corner :: enum {
	TopLeft,
	TopRight,
	BottomRight,
	BottomLeft,
}

get_item_checked :: proc(lic: ^Layout_Item_Container, handle: Layout_Item_Handle) -> ^Layout_Item {
	assert(hms.valid(lic^, handle))
	return hms.get(lic, handle)
}

get_item :: proc(lic: ^Layout_Item_Container, handle: Layout_Item_Handle) -> (^Layout_Item, bool) {
	if !hms.valid(lic^, handle) do return nil, false
	return hms.get(lic, handle), true
}

@(private)
make_parent_layout_item :: proc(ctx: ^Context) -> Layout_Item {

	@(static) debug_gen_id: u32 = 0
	layout_item := make_layout_item(ctx, fmt.tprintf("parent_{}", debug_gen_id))
	layout_item.size_percent = {0.5, 0.5}
	debug_gen_id += 1
	return layout_item
}

// @(private)
make_debug_leaf_layout_item :: proc(ctx: ^Context) -> Layout_Item {

	@(static) debug_gen_id: u32 = 0
	layout_item := make_layout_item(ctx, fmt.tprintf("leaf_{}", debug_gen_id))
	layout_item.size_percent = {0.5, 0.5}
	debug_gen_id += 1
	return layout_item
}

make_layout_item :: proc(
	ctx: ^Context,
	id: string,
	user_data: rawptr = nil,
	layout_proc: proc(parent_node: ^Layout_Item, active_elems: ^Active_Elements) = nil,
) -> (
	layout_item: Layout_Item,
) {

	layout_item.id = strings.clone(id, ctx.arena_allocator)
	layout_item.layout_proc = layout_proc
	layout_item.userdata = user_data
	layout_item.child_nodes = make([dynamic]hms.Handle, ctx.arena_allocator)

	return
}

// deletes item.
delete_layout_item :: proc(ctx: ^Context, handle: Layout_Item_Handle) {
	if !hms.valid(ctx.lic, handle) do return
	layout_item := hms.get(&ctx.lic, handle)

	delete(layout_item.id, ctx.arena_allocator)
	delete_dynamic_array(layout_item.child_nodes)

	hms.remove(&ctx.lic, handle)
}

// Returns the handle that was hit and not deleted
delete_tail :: proc(ctx: ^Context, item_handle: Layout_Item_Handle) -> Layout_Item_Handle {
	item := get_item_checked(&ctx.lic, item_handle)
	if !hms.valid(ctx.lic, item.parent_handle) do return item.handle // root node

	parent := get_item_checked(&ctx.lic, item.parent_handle)

	if len(parent.child_nodes) == 1 { 	// continue walking
		delete_handle_from_node(&ctx.lic, item.parent_handle, item.handle)
		delete_layout_item(ctx, item.handle)

		return delete_tail(ctx, parent.handle)
	} else if len(parent.child_nodes) > 1 {
		delete_handle_from_node(&ctx.lic, item.parent_handle, item.handle)
		delete_layout_item(ctx, item.handle)

		return parent.handle
	}

	return item.handle
}

clean_upwards :: proc(ctx: ^Context, item_handle: Layout_Item_Handle) {
	item := get_item_checked(&ctx.lic, item_handle)
	parent_item, parent_ok := get_item(&ctx.lic, item.parent_handle)
	if !parent_ok do return
	grand_parent, grandparent_ok := get_item(&ctx.lic, parent_item.parent_handle)
	if !grandparent_ok do return

	if (len(parent_item.child_nodes) == 1 && len(grand_parent.child_nodes) == 1) {
		grand_parent.child_nodes[0] = item.handle
		item.parent_handle = grand_parent.handle
		delete_layout_item(ctx, parent_item.handle)
	}
}

delete_handle_from_node :: proc(
	lic: ^Layout_Item_Container,
	item_handle, handle_to_delete: Layout_Item_Handle,
) {
	layout_item := get_item_checked(lic, item_handle)

	for &handle, i in layout_item.child_nodes {
		if handle == handle_to_delete {
			ordered_remove(&layout_item.child_nodes, i)
			break
		}
	}
}

remove_leaf_item :: proc(ctx: ^Context, handle: Layout_Item_Handle, delete_node: bool) {
	layout_item_to_remove := get_item_checked(&ctx.lic, handle)
	assert(
		len(layout_item_to_remove.child_nodes) == 0,
		"don't support cutting nodes with children.",
	)

	parent_handle := layout_item_to_remove.parent_handle
	if !hms.valid(ctx.lic, parent_handle) do return
	parent_layout_item := hms.get(&ctx.lic, parent_handle)

	{
		root_item := get_item_checked(&ctx.lic, ctx.root)
		if layout_item_to_remove.parent_handle == ctx.root && len(root_item.child_nodes) == 1 {
			return
		}
	}

	delete_handle_from_node(&ctx.lic, parent_handle, handle)
	if delete_node {
		delete_layout_item(ctx, handle)
	} else {
		layout_item_to_remove.parent_handle = {}
	}


	// delete_tail(ctx, parent_handle)


	if len(parent_layout_item.child_nodes) == 1 {
		single_child := get_item_checked(&ctx.lic, parent_layout_item.child_nodes[0])
		grand_parent, grand_parent_ok := get_item(&ctx.lic, parent_layout_item.parent_handle)
		if grand_parent_ok && len(single_child.child_nodes) == 0 {
			index_in_grand_parent := get_index_in_parent(&ctx.lic, parent_layout_item.handle)

			grand_parent.child_nodes[index_in_grand_parent] = single_child.handle
			single_child.parent_handle = grand_parent.handle
			single_child.size_percent = parent_layout_item.size_percent

			delete_layout_item(ctx, parent_layout_item.handle)
		}
	}


	clean_tree(ctx, ctx.root)
	update_layout_dir(&ctx.lic, ctx.root)
	normalize_sizes_recursive(&ctx.lic, ctx.root)

	// Is not the fastest. Could do something more local. But this is simpler.
	clean_tree :: proc(ctx: ^Context, handle: Layout_Item_Handle) {
		item := get_item_checked(&ctx.lic, handle)

		#reverse for child_handle, i in item.child_nodes {
			child := get_item_checked(&ctx.lic, child_handle) // all children
			if len(child.child_nodes) == 1 {
				delete_handle_from_node(&ctx.lic, item.handle, child.handle)
				grand_child := get_item_checked(&ctx.lic, child.child_nodes[0])

				size_percent := child.size_percent

				num_grand_grand_children := len(grand_child.child_nodes)
				for j := 0; j < num_grand_grand_children; j += 1 {
					grand_grand_child := get_item_checked(&ctx.lic, grand_child.child_nodes[j])
					grand_grand_child.parent_handle = item.handle
					grand_grand_child.size_percent *= size_percent // / f32(num_grand_grand_children) //
					inject_at(&item.child_nodes, i + j, grand_grand_child.handle)
				}

				delete_layout_item(ctx, child.handle)
				delete_layout_item(ctx, grand_child.handle)
			}
		}

		for child_handle in item.child_nodes {
			clean_tree(ctx, child_handle)
		}

	}


	// if len(parent_layout_item.child_nodes) == 0 {
	// 	parent_handle = delete_tail(ctx, parent_handle)
	// }
	//
	// clean_upwards(ctx, parent_handle)


	// TODO: make recursive TODO: Make work
	// if len(parent_layout_item.child_nodes) == 0 {
	// 	grand_parent_handle := parent_layout_item.parent_handle
	// 	if !hms.valid(ctx.lic, grand_parent_handle) do return // root node
	// 	delete_handle_from_node(&ctx.lic, grand_parent_handle, parent_handle)
	// 	delete_layout_item(ctx, parent_handle)
	// }

	// if true do return
	// parent only has one child, reduce it
	// if len(parent_layout_item.child_nodes) == 1 {
	// 	grand_parent_handle := parent_layout_item.parent_handle
	// 	if !hms.valid(ctx.lic, grand_parent_handle) do return // root node
	//
	// 	grand_parent := get_item_checked(&ctx.lic, grand_parent_handle)
	// 	for &h in grand_parent.child_nodes {
	// 		if h == parent_handle {
	// 			h = parent_layout_item.child_nodes[0]
	// 			single_child := get_item_checked(&ctx.lic, parent_layout_item.child_nodes[0])
	// 			single_child.parent_handle = grand_parent_handle
	// 			single_child.size_percent = parent_layout_item.size_percent
	// 			delete_layout_item(ctx, parent_handle)
	// 			break
	// 		}
	// 	}
	//
	// 	update_layout_dir(&ctx.lic, grand_parent_handle)
	// 	normalize_sizes_recursive(&ctx.lic, grand_parent_handle)
	// }
}


update_layout_dir :: proc(lic: ^Layout_Item_Container, current_item_handle: Layout_Item_Handle) {
	layout_item := get_item_checked(lic, current_item_handle)
	for &child_item_handle in layout_item.child_nodes {
		child_item := get_item_checked(lic, child_item_handle)
		if (is_leaf(lic, child_item_handle)) {
			child_item.layout_dir = .TopToBottom
		} else {
			child_item.layout_dir =
				layout_item.layout_dir == .LeftToRight ? .TopToBottom : .LeftToRight

			update_layout_dir(lic, child_item_handle)
		}
	}
}

// slice_layout_item :: proc(lic: ^Layout_Item_Container, handle_to_slice: Layout_Item_Handle) {
// 	assert(hms.valid(lic^, handle_to_slice))
// 	layout_item_to_slice := hms.get(lic, handle_to_slice)
//
// 	grand_parent_handle := layout_item_to_slice.parent_handle
// 	if !hms.valid(lic^, grand_parent_handle) do return // root node
//
// 	grand_parent := hms.get(lic, grand_parent_handle)
// 	for &h in grand_parent.child_nodes {
// 		if h == parent_handle {
// 			h = parent_layout_item.child_nodes[0]
//
// 			break
// 		}
// 	}
// 	grand_parent.child_nodes
// }

// delete item and potential children
delete_layout_item_and_children :: proc(ctx: ^Context, handle: Layout_Item_Handle) {
	if !hms.valid(ctx.lic, handle) do return

	layout_item := hms.get(&ctx.lic, handle)
	for child_handle in layout_item.child_nodes {
		delete_layout_item(ctx, child_handle)
	}

	delete_layout_item(ctx, handle)
}


get_parent_layout_item :: proc(
	lic: ^Layout_Item_Container,
	item_handle: Layout_Item_Handle,
) -> ^Layout_Item {
	assert(hms.valid(lic^, item_handle))
	layout_item := hms.get(lic, item_handle)

	assert(hms.valid(lic^, layout_item.parent_handle))
	return hms.get(lic, layout_item.parent_handle)
}

get_index_in_parent :: proc(lic: ^Layout_Item_Container, item_handle: Layout_Item_Handle) -> u8 {
	parent_layout_item := get_parent_layout_item(lic, item_handle)

	for &handle, i in parent_layout_item.child_nodes {
		if handle == item_handle do return u8(i)
	}

	panic("parent's child_nodes does not have the layout item that has it as its parent!")
}

add_layout_node :: proc(
	lic: ^Layout_Item_Container,
	parent_handle: Layout_Item_Handle,
	index: u8,
	layout_item_to_add: Layout_Item,
) -> Layout_Item_Handle {
	parent_layout_item := get_item_checked(lic, parent_handle)

	new_handle, add_ok := hms.add(lic, layout_item_to_add)
	assert(add_ok)
	new_layout_item := hms.get(lic, new_handle)
	inject_at(&parent_layout_item.child_nodes, index, new_handle)

	// setup state
	new_layout_item.parent_handle = parent_handle
	new_layout_item.layout_dir =
		parent_layout_item.layout_dir == .LeftToRight ? .TopToBottom : .LeftToRight
	return new_handle
}

add_layout_item_node :: proc(
	lic: ^Layout_Item_Container,
	parent_handle: Layout_Item_Handle,
	index: u8,
	homeless_item_handle: Layout_Item_Handle,
) {
	homeless_item := get_item_checked(lic, homeless_item_handle)
	parent_layout_item := get_item_checked(lic, parent_handle)

	inject_at(&parent_layout_item.child_nodes, index, homeless_item_handle)

	// setup state
	homeless_item.parent_handle = parent_handle
	homeless_item.layout_dir =
		parent_layout_item.layout_dir == .LeftToRight ? .TopToBottom : .LeftToRight
}

is_valid_tree :: proc(lic: ^Layout_Item_Container) -> bool {
	panic("Not implemented!")
}
max_leaf_distance :: proc(
	lic: ^Layout_Item_Container,
	handle: Layout_Item_Handle,
	dist: i32 = 0,
) -> i32 {
	assert(hms.valid(lic^, handle))
	layout_item := hms.get(lic, handle)

	if len(layout_item.child_nodes) == 0 do return dist
	dist := dist + 1

	max_dist := min(i32)
	for child_handle in layout_item.child_nodes {
		found_dist := max_leaf_distance(lic, child_handle, dist)
		if found_dist > max_dist {
			max_dist = found_dist
		}
	}

	return max_dist
}

leaf_distance :: proc(
	lic: ^Layout_Item_Container,
	handle: Layout_Item_Handle,
	dist: i32 = 0,
) -> i32 {
	assert(hms.valid(lic^, handle))
	layout_item := hms.get(lic, handle)

	if len(layout_item.child_nodes) == 0 do return dist
	dist := dist + 1

	min_dist := max(i32)
	for child_handle in layout_item.child_nodes {
		found_dist := leaf_distance(lic, child_handle, dist)
		if found_dist < min_dist {
			min_dist = found_dist
		}
	}

	return min_dist
}

is_leaf :: proc(lic: ^Layout_Item_Container, handle: Layout_Item_Handle) -> bool {
	return leaf_distance(lic, handle, 0) == 0

}

get_average_size :: proc(
	lic: ^Layout_Item_Container,
	layout_item_handle: Layout_Item_Handle,
) -> (
	avg_size: clay.Vector2,
) {
	layout_item := get_item_checked(lic, layout_item_handle)
	for &handle in layout_item.child_nodes {
		child_layout_item := get_item_checked(lic, handle)

		avg_size += child_layout_item.size_percent
	}

	avg_size /= f32(len(layout_item.child_nodes))

	return
}

// TODO: Add handles that should retain its percent
normalize_sizes :: proc(lic: ^Layout_Item_Container, layout_item_handle: Layout_Item_Handle) {
	layout_item := get_item_checked(lic, layout_item_handle)

	item_handles := layout_item.child_nodes
	total: clay.Vector2 = {}
	for &handle in item_handles {
		assert(hms.valid(lic^, handle))
		layout_item := hms.get(lic, handle)
		total += layout_item.size_percent
	}

	for &handle in item_handles {
		assert(hms.valid(lic^, handle))
		child_layout_item := hms.get(lic, handle)

		if layout_item.layout_dir == .LeftToRight {
			child_layout_item.size_percent.x /= total.x
			child_layout_item.size_percent.y = 1
		} else {
			child_layout_item.size_percent.x = 1
			child_layout_item.size_percent.y /= total.y
		}
	}
}

normalize_sizes_recursive :: proc(
	lic: ^Layout_Item_Container,
	layout_item_handle: Layout_Item_Handle,
) {
	layout_item := get_item_checked(lic, layout_item_handle)

	normalize_sizes(lic, layout_item_handle)
	for &handle in layout_item.child_nodes {
		normalize_sizes_recursive(lic, handle)
	}
}

insert_item_same_level :: proc(
	ctx: ^Context,
	avg_size: clay.Vector2,
	index_in_parent: u8,
	edge: Edge,
	item_handle, item_to_insert_handle: Layout_Item_Handle,
) {
	item := get_item_checked(&ctx.lic, item_handle)
	parent := get_item_checked(&ctx.lic, item.parent_handle)

	insert_after := edge == .Bottom || edge == .Right

	add_layout_item_node(
		&ctx.lic,
		parent.handle,
		index_in_parent + u8(insert_after),
		item_to_insert_handle,
	)

	added_item := get_item_checked(&ctx.lic, item_to_insert_handle)
	added_item.size_percent = avg_size
	normalize_sizes(&ctx.lic, parent.handle)
}

insert_same_level :: proc(
	ctx: ^Context,
	avg_size: clay.Vector2,
	index_in_parent: u8,
	edge: Edge,
	parent_layout_item, hovered_layout_item: ^Layout_Item,
) {

	insert_after := edge == .Bottom || edge == .Right

	added_item_handle := add_layout_node(
		&ctx.lic,
		hovered_layout_item.parent_handle,
		index_in_parent + u8(insert_after),
		make_debug_leaf_layout_item(ctx),
	)

	added_item := get_item_checked(&ctx.lic, added_item_handle)
	added_item.size_percent = avg_size
	normalize_sizes(&ctx.lic, hovered_layout_item.parent_handle)
}

@(private)
insert_item_new_level :: proc(
	ctx: ^Context,
	avg_size: clay.Vector2,
	index_in_parent: u8,
	edge: Edge,
	item_handle, item_to_insert_handle: Layout_Item_Handle,
) {
	item := get_item_checked(&ctx.lic, item_handle)
	parent := get_item_checked(&ctx.lic, item.parent_handle)

	new_parent_handle := hms.add(&ctx.lic, make_parent_layout_item(ctx))
	new_parent := hms.get(&ctx.lic, new_parent_handle)
	new_parent.size_percent = avg_size
	new_parent.layout_dir = parent.layout_dir == .TopToBottom ? .LeftToRight : .TopToBottom

	parent.child_nodes[index_in_parent] = new_parent_handle
	new_parent.parent_handle = parent.handle

	append(&new_parent.child_nodes, item.handle)
	item.parent_handle = new_parent_handle
	item.size_percent = avg_size
	if (is_leaf(&ctx.lic, item.handle)) {
		item.layout_dir = .TopToBottom
	} else {
		item.layout_dir = new_parent.layout_dir == .TopToBottom ? .LeftToRight : .TopToBottom
	}

	b_insert_after := edge == .Right || edge == .Bottom


	add_layout_item_node(
		&ctx.lic,
		new_parent.handle,
		b_insert_after ? 1 : 0,
		item_to_insert_handle,
	)

	added_item := get_item_checked(&ctx.lic, item_to_insert_handle)
	added_item.size_percent = avg_size
	added_item.layout_dir = .TopToBottom

	normalize_sizes(&ctx.lic, new_parent_handle)
	normalize_sizes(&ctx.lic, parent.handle)
}

@(private)
insert_new_level :: proc(
	ctx: ^Context,
	avg_size: clay.Vector2,
	index_in_parent: u8,
	edge: Edge,
	parent_layout_item, hovered_layout_item: ^Layout_Item,
) {
	new_parent_handle := hms.add(&ctx.lic, make_parent_layout_item(ctx))
	new_parent := hms.get(&ctx.lic, new_parent_handle)
	new_parent.size_percent = avg_size
	new_parent.layout_dir =
		parent_layout_item.layout_dir == .TopToBottom ? .LeftToRight : .TopToBottom

	parent_layout_item.child_nodes[index_in_parent] = new_parent_handle
	new_parent.parent_handle = parent_layout_item.handle

	append(&new_parent.child_nodes, hovered_layout_item.handle)
	hovered_layout_item.parent_handle = new_parent_handle
	hovered_layout_item.size_percent = avg_size
	if (is_leaf(&ctx.lic, hovered_layout_item.handle)) {
		hovered_layout_item.layout_dir = .TopToBottom
	} else {
		hovered_layout_item.layout_dir =
			new_parent.layout_dir == .TopToBottom ? .LeftToRight : .TopToBottom

	}

	b_insert_after := edge == .Right || edge == .Bottom

	added_item_handle := add_layout_node(
		&ctx.lic,
		new_parent_handle,
		b_insert_after ? 1 : 0,
		make_debug_leaf_layout_item(ctx),
	)

	added_item := get_item_checked(&ctx.lic, added_item_handle)
	added_item.size_percent = avg_size
	added_item.layout_dir = .TopToBottom

	normalize_sizes(&ctx.lic, new_parent_handle)
	normalize_sizes(&ctx.lic, parent_layout_item.handle)

}

closest_edge :: proc(bounding_box: clay.BoundingBox, pos: clay.Vector2) -> Edge {
	direction :=
		pos -
		clay.Vector2 {
				bounding_box.x + bounding_box.width / 2,
				bounding_box.y + bounding_box.height / 2,
			}
	aspect := bounding_box.width / bounding_box.height
	scaled_direction := direction
	scaled_direction.y = scaled_direction.y * aspect

	if abs(scaled_direction.x) > abs(scaled_direction.y) {
		return scaled_direction.x >= 0 ? .Right : .Left
	} else {

		return scaled_direction.y >= 0 ? .Bottom : .Top
	}
}

closest_corner :: proc(bounding_box: clay.BoundingBox, pos: clay.Vector2) -> Corner {

	tile_center := [2]c.float {
		bounding_box.x + bounding_box.width / 2,
		bounding_box.y + bounding_box.height / 2,
	}

	dir := pos - tile_center

	if dir.x > 0 { 	// Right
		if dir.y > 0 { 	// Lower
			return .BottomRight
		} else { 	// Upper
			return .TopRight
		}
	} else { 	// Left
		if dir.y > 0 { 	// Lower
			return .BottomLeft
		} else { 	// Upper
			return .TopLeft
		}
	}
}


is_horizontal_edge :: proc(edge: Edge) -> bool {
	return edge == .Left || edge == .Right
}

is_vertical_edge :: proc(edge: Edge) -> bool {
	return !is_horizontal_edge(edge) // might be slower? But I think compiler might compansate. Need to test.
}

is_up :: proc(corner: Corner) -> bool {
	return corner == .TopLeft || corner == .TopRight
}

is_down :: proc(corner: Corner) -> bool {
	return !is_up(corner)
}

is_right :: proc(corner: Corner) -> bool {
	return corner == .TopRight || corner == .BottomRight
}

is_left :: proc(corner: Corner) -> bool {
	return !is_right(corner)
}

get_scalers_x_y :: proc(
	lic: ^Layout_Item_Container,
	item_handle: Layout_Item_Handle,
	right, down: bool,
	delta_mouse_move: raylib.Vector2,
) -> (
	x, y: Layout_Item_Handle,
) {
	item := get_item_checked(lic, item_handle)

	x_handle := find_scalar_layout_item(lic, item.handle, true, right, delta_mouse_move.x)
	y_handle := find_scalar_layout_item(lic, item.handle, false, down, delta_mouse_move.y)

	return x_handle, y_handle

}

find_scalar_layout_item :: proc(
	lic: ^Layout_Item_Container,
	item_handle: Layout_Item_Handle,
	horizontal: bool,
	after: bool,
	delta_mouse_move: f32,
) -> Layout_Item_Handle {
	item := get_item_checked(lic, item_handle)
	parent, parent_ok := get_item(lic, item.parent_handle)
	if !parent_ok do return {}

	target_layout_direction: clay.LayoutDirection = horizontal ? .LeftToRight : .TopToBottom

	x: Layout_Item_Handle

	index_in_parent := get_index_in_parent(lic, item.handle)

	neighbour_handle := get_neighbour_with_min_size(
		lic,
		item.handle,
		horizontal,
		after,
		delta_mouse_move > 0,
	)

	neighbour_ok := hms.valid(lic^, neighbour_handle)
	if after {
		if (int(index_in_parent) != (len(parent.child_nodes) - 1)) &&
		   parent.layout_dir == target_layout_direction &&
		   neighbour_ok {
			x = item.handle
		} else {
			x = find_scalar_layout_item(lic, parent.handle, horizontal, after, delta_mouse_move)
		}
	} else { 	// left
		if (index_in_parent != 0 && parent.layout_dir == target_layout_direction) && neighbour_ok {

			x = item.handle
		} else {
			x = find_scalar_layout_item(lic, parent.handle, horizontal, after, delta_mouse_move)
		}
	}

	return x
}

get_neighbour_with_min_size :: proc(
	lic: ^Layout_Item_Container,
	item_handle: Layout_Item_Handle,
	horizontal: bool,
	after: bool,
	dragging_towards_after: bool,
) -> Layout_Item_Handle {
	item := get_item_checked(lic, item_handle)
	parent := get_item_checked(lic, item.parent_handle)

	item_handle := item_handle

	for {
		neighour_handle := get_neighbour(lic, item_handle, after)
		neighour, neighour_ok := get_item(lic, neighour_handle)
		if !neighour_ok do return {} // item is last of first

		element_bounding_box := get_clay_bounding_box(neighour.id)

		if after == dragging_towards_after {
			if horizontal {
				if element_bounding_box.width <= MIN_WINDOW_SIZE {
					item_handle = neighour.handle
					continue
				}
			} else {
				if element_bounding_box.height <= MIN_WINDOW_SIZE {
					item_handle = neighour.handle
					continue
				}


			}
		}


		return neighour.handle
	}
}

// TODO: write desk. Can walk to neibghours, and up the tree.
get_next :: proc(
	lic: ^Layout_Item_Container,
	item_handle: Layout_Item_Handle,
	after: bool,
) -> Layout_Item_Handle {
	item := get_item_checked(lic, item_handle)
	parent := get_item_checked(lic, item.parent_handle)

	index_in_parent := get_index_in_parent(lic, item.handle)
	neighbour_index_in_parent := index_in_parent + (after ? 1 : -1)
	if neighbour_index_in_parent < 0 || int(neighbour_index_in_parent) >= len(parent.child_nodes) {
		grand_parent, grand_parent_ok := get_item(lic, parent.parent_handle)
		if !grand_parent_ok do return {}
		// grand2_parent, grand2_parent_ok := get_item(lic, grand_parent.parent_handle)
		// if !grand2_parent_ok do return {}

		found_next_item_handle := get_next(lic, grand_parent.handle, after)
		return found_next_item_handle
	}

	return parent.child_nodes[neighbour_index_in_parent]
}

get_neighbour :: proc(
	lic: ^Layout_Item_Container,
	item_handle: Layout_Item_Handle,
	after: bool,
) -> Layout_Item_Handle {
	item := get_item_checked(lic, item_handle)
	parent := get_item_checked(lic, item.parent_handle)

	index_in_parent := get_index_in_parent(lic, item.handle)
	neighbour_index_in_parent := index_in_parent + (after ? 1 : -1)
	if neighbour_index_in_parent < 0 || int(neighbour_index_in_parent) >= len(parent.child_nodes) do return {}

	return parent.child_nodes[neighbour_index_in_parent]
}

get_clay_bounding_box :: proc(id: string) -> clay.BoundingBox {
	clay_element_id := clay.GetElementId(clay.MakeString(id))
	element_data := clay.GetElementData(clay_element_id)
	assert(element_data.found)
	return element_data.boundingBox
}

// TODO: Can implement later if wanted
scale_with_min_size :: proc(
	ctx: ^Context,
	item_handle: Layout_Item_Handle,
	delta_mouse: raylib.Vector2,
	corner: Corner,
) {

	wanted_px_change := delta_mouse.x

	px_change_remaining := wanted_px_change

	item := get_item_checked(&ctx.lic, item_handle)
	parent := get_item_checked(&ctx.lic, item.parent_handle)

	item_bounds := get_clay_bounding_box(item.id)
	parent_bounds := get_clay_bounding_box(parent.id)


	after := is_right(corner)

	for {

		next_neighbour, next_neighbour_ok := get_item(
			&ctx.lic,
			get_next(&ctx.lic, item.handle, after),
		)

		if !next_neighbour_ok {
			return
		}

		px_changed := try_resize(&ctx.lic, next_neighbour.handle, px_change_remaining, after)
		px_change_remaining -= px_changed

		if px_change_remaining <= 0 {
			return
		}
	}

	percent_change := (wanted_px_change - px_change_remaining) / parent_bounds.width
	item.size_percent.x += percent_change
	// scale the original box last.
}

try_resize :: proc(
	lic: ^Layout_Item_Container,
	item_handle: Layout_Item_Handle,
	px_change: f32,
	after: bool,
) -> (
	changed: f32,
) {
	item := get_item_checked(lic, item_handle)
	parent, parent_ok := get_item(lic, item.parent_handle)
	if !parent_ok do return px_change


	// TODO: Can implement later if wanted

	return
}
