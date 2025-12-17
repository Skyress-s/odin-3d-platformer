package layout

import clay "../clay-odin"


// todo deciding layout can be chosen later. For now just place it where its convenient
register_node :: proc(root_node: ^Tiling_Node, name: string) -> (ok: bool, node: ^Tiling_Node) {
	new_node := generate_default_leaf()
	add_ok, inserted_node := add_node2(root_node, new_node, 0)
	assert(add_ok)
	return true, inserted_node
}

unregister_node :: proc(root_node: ^Tiling_Node, name: string) -> (ok: bool) {
	node := find_node(root_node, name)
	assert(node != nil)

	return delete_node2(root_node, node)
}

// get_node :: proc(root_node: ^Tiling_Node, name: string) -> (ok: bool, node: Tiling_Node) {
//
// }
