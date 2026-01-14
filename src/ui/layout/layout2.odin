package layout
//
//
// import vmem "core:mem/virtual"
//
// import hms "../../handle_map/handle_map_static/"
// import clay "../clay-odin/"
//
// Context :: struct {
// 	arena: vmem.Arena,
// 	items: Layout_Item_Container,
// }
//
// Layout_Item :: struct {
// 	handle:        hms.Handle, // Must be present for Handle Map.
// 	parent_handle: hms.Handle,
// 	child_nodes:   [dynamic]hms.Handle,
//
// 	// Clay stuff
// 	id:            string,
// 	layout_dir:    clay.LayoutDirection,
//
// 	// Layout
// 	size_percent:  [2]f32,
// 	layout_proc:   proc(parent_node: ^Tiling_Node, active_elems: ^Active_Elements),
// 	userdata:      rawptr,
// }
//
// Layout_Item_Handle :: hms.Handle
//
// Layout_Item_Container :: hms.Handle_Map(Layout_Item, hms.Handle, 1 >> 8)
//
// get_parent :: proc(
// 	lic: ^Layout_Item_Container,
// 	handle: Layout_Item_Handle,
// ) -> Layout_Item_Handle { 	// TODO: Does this slow it down, or does compiler pass by ref?
// 	if !hms.valid(lic^, handle) do return Layout_Item_Handle{}
// 	return hms.get(lic, handle).parent_handle
// }
//
// // deletes item.
// delete_layout_item :: proc(lic: ^Layout_Item_Container, handle: Layout_Item_Handle) {
// 	if !hms.valid(lic^, handle) do return
// 	layout_item := hms.get(lic, handle)
//
// 	delete(layout_item.id)
// 	delete(layout_item.child_nodes)
// }
//
// cut_layout_item :: proc(lic: ^Layout_Item_Container, handle: Layout_Item_Handle) {
// 	if hms.valid(lic^, handle) do return
//
// 	layout_item_to_delete := hms.get(lic, handle)
//
// 	parent_handle := layout_item_to_delete.parent_handle
// 	assert(hms.valid(lic^, parent_handle), "are you trying to delete the root?")
//
// 	parent_layout_item := hms.get(lic, parent_handle)
//
//
// }
//
// // delete item and potential children
// delete_layout_item_and_children :: proc(lic: ^Layout_Item_Container, handle: Layout_Item_Handle) {
// 	if !hms.valid(lic^, handle) do return
//
// 	layout_item := hms.get(lic, handle)
// 	for child_handle in layout_item.child_nodes {
// 		delete_layout_item(lic, child_handle)
// 	}
//
// 	delete_layout_item(lic, handle)
// }
//
//
// add_layout_node :: proc(
// 	lic: ^Layout_Item_Container,
// 	parent_handle: Layout_Item_Handle,
// 	index: u8,
// 	layout_item_to_add: Layout_Item,
// ) {
// 	if !hms.valid(lic^, parent_handle) do return
//
// 	parent_layout_item := hms.get(lic, parent_handle)
// 	new_handle, add_ok := hms.add(lic, layout_item_to_add)
// 	assert(add_ok)
// 	new_layout_item := hms.get(lic, new_handle)
// 	inject_at(&parent_layout_item.child_nodes, index, new_handle)
//
// 	// setup state
// 	new_layout_item.parent_handle = parent_handle
// }
//
//
// is_valid_tree :: proc(lic: ^Layout_Item_Container) -> bool {
// 	panic("Not implemented!")
// }
