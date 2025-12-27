package layout

import clay "../clay-odin"
import "core:c"
import fmt "core:fmt"
import "core:log"
import raylib "vendor:raylib"

tiling_window_test :: proc(root_node: ^Tiling_Node) {
	mouse_position := [2]c.float{raylib.GetMousePosition().x, raylib.GetMousePosition().y}
	root_node := root_node
	// root := create_tiling_nodes_2X()

	normalize_entire_tile_tree(root_node)
	hovered_node := draw_nodes(root_node)

	@(static) scaling_node: ^Tiling_Node
	@(static) start_pos: [2]c.float
	@(static) corner_clicked: DirectionDiagonal
	@(static) horizontal_node: ^Tiling_Node
	@(static) vertical_node: ^Tiling_Node
	if hovered_node != nil {
		if raylib.IsMouseButtonPressed(raylib.MouseButton.LEFT) {

			hovered_parent_node, index_in_parent := find_node_parent(root_node, hovered_node)
			if index_in_parent != -1 {
				fmt.printfln(
					"hovered_node {}, parent {}, {}",
					hovered_node.clay_id,
					hovered_parent_node.clay_id,
					index_in_parent,
				)
				delete_node(root_node, hovered_parent_node, index_in_parent)
			}
			// normalize_tile_nodes_sizes(root_node, hovered_parent_node)
			// Remove a random element
		}
		if raylib.IsMouseButtonPressed(raylib.MouseButton.RIGHT) {
			tile_bounds := clay.GetElementData(clay.ID(hovered_node.clay_id)).boundingBox
			x := tile_bounds.x
			y := tile_bounds.y

			direction_clicked := get_edge_clicked(tile_bounds, raylib.GetMousePosition())

			hovered_parent_node, index_in_parent := find_node_parent(root_node, hovered_node)
			if index_in_parent == -1 { 	// Root node, spawn a single one that covers entire screen
				root_node.layout_dir = .LeftToRight
				append_elem(&hovered_node.sub_nodes, generate_default_leaf())

			} else {
				if hovered_parent_node.layout_dir == .LeftToRight {
					if direction_is_horizontal(direction_clicked) {

						add_node(
							hovered_parent_node,
							index_in_parent + i32(direction_clicked == .Right),
							generate_default_leaf(),
						)
					} else {
						hovered_node.layout_dir = .TopToBottom

						new_node := generate_default_leaf()
						new_node.clay_id = hovered_node.clay_id
						hovered_node.clay_id = make_new_id()

						if direction_clicked == .Down {
							add_node(hovered_node, 0, generate_default_leaf())
							add_node(hovered_node, 0, new_node)
						} else {
							add_node(hovered_node, 0, new_node)
							add_node(hovered_node, 0, generate_default_leaf())
						}
					}
				} else {
					if direction_is_vertical(direction_clicked) {
						add_node(
							hovered_parent_node,
							index_in_parent + i32(direction_clicked == .Down),
							generate_default_leaf(),
						)
					} else {
						hovered_node.layout_dir = .LeftToRight
						new_node := generate_default_leaf()
						new_node.clay_id = hovered_node.clay_id
						hovered_node.clay_id = make_new_id()

						if direction_clicked == .Left {
							add_node(hovered_node, 0, new_node)
							add_node(hovered_node, 0, generate_default_leaf())
						} else {
							add_node(hovered_node, 0, generate_default_leaf())
							add_node(hovered_node, 0, new_node)
						}
					}
				}

			}

			// Add a random element
		}
		{
			if raylib.IsMouseButtonPressed(raylib.MouseButton.MIDDLE) {
				scaling_node = hovered_node
				start_pos = raylib.GetMousePosition()
				log.info("hej before")
				fmt.println("hej!!!")

				corner_clicked = get_corner_clicked(
					clay.GetElementData(clay.ID(hovered_node.clay_id)).boundingBox,
					mouse_position,
				)
				log.info("hej after")

				horizontal_node, vertical_node = find_parent_x_y_scalers(
					root_node,
					hovered_node,
					corner_clicked,
				)
			}
		}


		// TODO clean tree? Pop elements that only have a single child!
	}
	if raylib.IsMouseButtonDown(raylib.MouseButton.MIDDLE) {

		// log.infof("middle down: hovered_node == nil -> {}", hovered_node == nil)
		// log.infof("horizontal_node {}", horizontal_node == nil)
		// log.infof("vertical_node   {}", vertical_node == nil)

		if (vertical_node == nil || horizontal_node == nil) do return

		mouse_diff := raylib.GetMousePosition() - start_pos

		diff: [2]c.float
		horizontal_parent_node, _ := find_node_parent(root_node, horizontal_node)
		vertical_parent_node, _ := find_node_parent(root_node, vertical_node)
		if horizontal_parent_node == nil {
			diff.x = mouse_diff.x
		} else {
			diff.x =
				distance_to_percent_of_bounding_box(clay.GetElementData(clay.ID(horizontal_node.clay_id)).boundingBox, clay.GetElementData(clay.ID(horizontal_parent_node.clay_id)).boundingBox, mouse_diff).x
		}
		if vertical_parent_node == nil {
			diff.y = mouse_diff.y
		} else {
			diff.y =
				distance_to_percent_of_bounding_box(clay.GetElementData(clay.ID(vertical_node.clay_id)).boundingBox, clay.GetElementData(clay.ID(vertical_parent_node.clay_id)).boundingBox, mouse_diff).y
		}

		// scaling_node.size_percent += diff / 100
		left := direction_is_left(corner_clicked)
		up := direction_is_up(corner_clicked)
		if left do diff.x = -diff.x
		if up do diff.y = -diff.y

		try_scale_next_child :: proc(
			root, node: ^Tiling_Node,
			forward, horizontal: bool,
			diff: f32,
		) {

			parent, child_index := find_node_parent(root, node)
			if parent == nil do return

			index: i32 = child_index - (i32(forward) * 2 - 1)
			if index < 0 || index >= i32(len(parent.sub_nodes)) do return

			if horizontal {
				parent.sub_nodes[index].size_percent.x -= diff
				// parent.sub_nodes[index].size_percent.x -= distance_to_percent_of_bounding_box(clay.GetElementData(clay.ID(parent.sub_nodes[index].clay_id)).boundingBox, diff).x
			} else {
				parent.sub_nodes[index].size_percent.y -= diff
				// parent.sub_nodes[index].size_percent.y -= distance_to_percent_of_bounding_box(clay.GetElementData(clay.ID(parent.sub_nodes[index].clay_id)).boundingBox, diff).y
			}
		}


		horizontal_node.size_percent.x += diff.x
		try_scale_next_child(root_node, horizontal_node, left, true, diff.x)
		vertical_node.size_percent.y += diff.y
		try_scale_next_child(root_node, vertical_node, up, false, diff.y)

		start_pos = raylib.GetMousePosition()

	}
	if raylib.IsMouseButtonReleased(raylib.MouseButton.MIDDLE) {
		scaling_node = nil
	}

}

// create_root_node :: proc() -> Tiling_Node {
//
// }

// Does not do anything specific atm. Placeholder
create_root_node :: proc() -> (root_node: Tiling_Node) {
	return generate_default_leaf()
}

create_tiling_nodes_2X :: proc() -> (root_node: Tiling_Node) {
	root_node = generate_default_leaf()
	for i in 0 ..< 2 {
		append_elem(&root_node.sub_nodes, generate_default_leaf())
		// for j in 0 ..< (2 + i) {
		// 	append_elem(
		// 		&root_node.sub_nodes[i].sub_nodes,
		// 		Tiling_Node{layout_dir = .LeftToRight, clay_id = fmt.aprintf("{}{}", i, j)},
		// 	)
		// 	for k in 0 ..< (2 + j) {
		// 		append_elem(
		// 			&root_node.sub_nodes[i].sub_nodes[j].sub_nodes,
		// 			Tiling_Node {
		// 				layout_dir = .TopToBottom,
		// 				clay_id = fmt.aprintf("{}{}{}", i, j, k),
		// 			},
		// 		)
		// 	}
		// }
	}
	root_node.clay_id = fmt.aprintf("root")
	root_node.size_percent = {0.5, 0.5}


	// todo memory
	return root_node
}
