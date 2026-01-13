package layout


import vmem "core:mem/virtual"

import hms "../../handle_map/handle_map_static/"
import clay "../clay-odin/"

Context :: struct {
	arena: vmem.Arena,
}

Layout_Item :: struct {
	handle:        hms.Handle, // Must be present for Handle Map.
	parent_handle: hms.Handle,
	sub_nodes:     [dynamic]hms.Handle,

	// Clay stuff
	id:            string,
	layout_dir:    clay.LayoutDirection,

	// Layout
	size_percent:  [2]f32,
	layout_proc:   proc(parent_node: ^Tiling_Node, active_elems: ^Active_Elements),
	userdata:      rawptr,
}

Layout_Item_Handle :: hms.Handle

Layout_Item_Container :: hms.Handle_Map(Layout_Item, hms.Handle, 1 >> 8)

get_parent :: proc(
	lic: ^Layout_Item_Container,
	handle: Layout_Item_Handle,
) -> Layout_Item_Handle { 	// TODO: Does this slow it down, or does compiler pass by ref?
	if !hms.valid(lic^, handle) do return Layout_Item_Handle{}
	return hms.get(lic, handle).parent_handle
}

// delete item
delete_layout_item :: proc(lic: ^Layout_Item_Container, handle: Layout_Item_Handle) {
	if !hms.valid(lic^, handle) do return
	layout_item := hms.get(lic, handle)

	delete(layout_item.id)
	delete(layout_item.sub_nodes)
}
// delete item and potential children
delete_layout_item_and_children :: proc(lic: ^Layout_Item_Container, handle: Layout_Item_Handle) {

}

is_valid_tree :: proc(lic: ^Layout_Item_Container) -> bool {
	panic("Not implemented!")
}
