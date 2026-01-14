package layout


import vmem "core:mem/virtual"

import hms "../../handle_map/handle_map_static/"
import clay "../clay-odin/"

Debug_Settings :: struct {
	draw_if_no_content, draw_ids: bool,
}

Context :: struct {
	clay_arena:     clay.Arena,
	lic:            Layout_Item_Container,
	root:           Layout_Item_Handle,
	debug_settings: Debug_Settings,
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

// deletes item.
delete_layout_item :: proc(lic: ^Layout_Item_Container, handle: Layout_Item_Handle) {
	if !hms.valid(lic^, handle) do return
	layout_item := hms.get(lic, handle)

	delete(layout_item.id)
	delete(layout_item.child_nodes)

	hms.remove(lic, handle)
}

delete_handle_from_node :: proc(
	lic: ^Layout_Item_Container,
	handle_to_delete, item_handle: Layout_Item_Handle,
) {
	assert(hms.valid(lic^, item_handle))
	layout_item := hms.get(lic, item_handle)

	for &handle, i in layout_item.child_nodes {
		if handle == handle_to_delete {
			ordered_remove(&layout_item.child_nodes, i)
			break
		}
	}
}

cut_layout_item :: proc(lic: ^Layout_Item_Container, handle: Layout_Item_Handle) {
	if hms.valid(lic^, handle) do return

	layout_item_to_delete := hms.get(lic, handle)
	assert(
		len(layout_item_to_delete.child_nodes) == 0,
		"don't support cutting nodes with children.",
	)

	parent_handle := layout_item_to_delete.parent_handle
	assert(hms.valid(lic^, parent_handle), "are you trying to delete the root?")

	parent_layout_item := hms.get(lic, parent_handle)

	delete_handle_from_node(lic, parent_handle, handle)
	delete_layout_item(lic, handle)

	// parent only has one child, reduce it
	if len(parent_layout_item.child_nodes) == 1 {
		grand_parent_handle := parent_layout_item.parent_handle
		if !hms.valid(lic^, grand_parent_handle) do return // root node

		grand_parent := hms.get(lic, grand_parent_handle)
		for &h in grand_parent.child_nodes {
			if h == parent_handle {
				h = parent_layout_item.child_nodes[0]
				delete_layout_item(lic, parent_handle)
				break
			}
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
delete_layout_item_and_children :: proc(lic: ^Layout_Item_Container, handle: Layout_Item_Handle) {
	if !hms.valid(lic^, handle) do return

	layout_item := hms.get(lic, handle)
	for child_handle in layout_item.child_nodes {
		delete_layout_item(lic, child_handle)
	}

	delete_layout_item(lic, handle)
}

add_layout_node :: proc(
	lic: ^Layout_Item_Container,
	parent_handle: Layout_Item_Handle,
	index: u8,
	layout_item_to_add: Layout_Item,
) {
	if !hms.valid(lic^, parent_handle) do return

	parent_layout_item := hms.get(lic, parent_handle)
	new_handle, add_ok := hms.add(lic, layout_item_to_add)
	assert(add_ok)
	new_layout_item := hms.get(lic, new_handle)
	inject_at(&parent_layout_item.child_nodes, index, new_handle)

	// setup state
	new_layout_item.parent_handle = parent_handle
}

is_valid_tree :: proc(lic: ^Layout_Item_Container) -> bool {
	panic("Not implemented!")
}

leaf_distance :: proc(lic: ^Layout_Item_Container, handle: Layout_Item_Handle, dist: i32) -> i32 {
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
