package layout

import clay "../clay-odin"


// todo deciding layout can be chosen later. For now just place it where its convenient
register_node :: proc(
	root_node: ^Tiling_Node,
	new_node: Tiling_Node,
) -> (
	ok: bool,
	node: ^Tiling_Node,
) {
	add_ok, inserted_node := add_node2(root_node, new_node, 0)
	assert(add_ok)
	return true, inserted_node
}

unregister_node :: proc(root_node: ^Tiling_Node, name: string) -> (ok: bool) {
	node := find_node(root_node, name)
	assert(node != nil)

	return delete_node2(root_node, node)
}

get_node :: proc(root_node: ^Tiling_Node, name: string) -> (^Tiling_Node, bool) {
	if root_node.clay_id == name do return root_node, true

	for &node in root_node.sub_nodes {
		found_node, ok := get_node_in_children(root_node, name)
		if ok do return found_node, true
	}


	return nil, false
}

get_node_in_children :: proc(node: ^Tiling_Node, name: string) -> (^Tiling_Node, bool) {
	for &child in node.sub_nodes {
		if child.clay_id == name do return &child,true 
		found_node, ok := get_node_in_children(&child, name)
		if ok do return found_node,true 

	}

	return nil, false
}
