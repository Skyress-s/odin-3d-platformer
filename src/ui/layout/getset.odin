package layout

import clay "../clay-odin"


// todo deciding layout can be chosen later. For now just place it where its convenient
register_node :: proc(root_node: ^Tiling_Node, name: string) -> (ok: bool, node: ^Tiling_Node) {
	new_node := generate_default_leaf()
	add_ok, inserted_node := add_node2(root_node, new_node, 0)
	assert(add_ok)
	return true, inserted_node
}

// unregister_node :: proc(root_node: ^Tiling_Node, name: string) -> (ok: bool) {
// 	hovered_parent_node, index_in_parent := find_node_parent(root_node, node)
// 	if index_in_parent != -1 {
// 		fmt.printfln(
// 			"hovered_node {}, parent {}, {}",
// 			hovered_node.clay_id,
// 			hovered_parent_node.clay_id,
// 			index_in_parent,
// 		)
// 		delete_node(root_node, hovered_parent_node, index_in_parent)
// 	}
// }

// get_node :: proc(root_node: ^Tiling_Node, name: string) -> (ok: bool, node: Tiling_Node) {
//
// }
