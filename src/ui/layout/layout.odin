package layout
import clay "../clay-odin"
import c "core:c"
import "core:fmt"
import "core:math"
import "core:testing"
import rl "vendor:raylib"


auto_hightlight_color :: proc() -> clay.Color {
	return clay.Hovered() ? COLOR_TOP_BORDER_3 : COLOR_BLUE_DARK
}

Node_Leaf :: distinct struct{}

Node_Branch :: distinct struct{}


Tiling_Node :: distinct struct {
	sub_nodes:    [dynamic]Tiling_Node,
	clay_id:      string,
	layout_dir:   clay.LayoutDirection,
	size_percent: [2]f32,
	has_content : bool,
	draw_content: proc(parent_node: ^Tiling_Node),
}

generate_default_leaf :: proc() -> Tiling_Node {
	@(static) id_counter: i32 = -1
	id_counter += 1

	return Tiling_Node {
		layout_dir = .TopToBottom,
		clay_id = fmt.aprintf("gen_{}", id_counter),
		size_percent = {0.5, 0.5},
		draw_content = draw_node_name,
	}
}

draw_node_name :: proc(parent_node: ^Tiling_Node) {
	clay.TextDynamic(
		fmt.tprintfln("clay_id: {}", parent_node.clay_id),
		clay.TextConfig({fontSize = 16, fontId = FONT_ID_BODY_16, textColor = COLOR_LIGHT}),
	)
}


node_leaf_distance :: proc(node: Tiling_Node, current_dist: u32 = 0) -> u32 {
	if len(node.sub_nodes) == 0 do return current_dist
	current_dist := current_dist

	current_dist += 1
	max_dist: u32 = 0
	for &n in node.sub_nodes {
		found_dist := node_leaf_distance(n, current_dist)
		if found_dist > max_dist do max_dist = found_dist
	}

	return max_dist
}

draw_nodes :: proc(node: ^Tiling_Node) -> (hoovered_node: ^Tiling_Node) {
	if node.has_content do return hoovered_node

	if clay.UI(clay.ID(node.clay_id))(
	{
		// layout = {layoutDirection = node.layout_dir, sizing = {clay.SizingGrow(), clay.SizingGrow()}, padding = clay.PaddingAll(node_leaf_distance(node) == 1 ? 8/2 : 0), childGap = node_leaf_distance(node) == 1 ? 8 : 0},
		layout = {
			layoutDirection = node.layout_dir,
			sizing = clay.Sizing {
				clay.SizingPercent(node.size_percent.x),
				clay.SizingPercent(node.size_percent.y),
			},
			padding = clay.PaddingAll(8),
			childGap = 8,
		},
		backgroundColor = node_leaf_distance(node^) == 0 ? auto_hightlight_color() : leaf_dist_to_color(node_leaf_distance(node^)),
	},
	) {
		for &n in node.sub_nodes {
			new_hovered_node := draw_nodes(&n)
			if new_hovered_node != nil do hoovered_node = new_hovered_node
		}
		if node_leaf_distance(node^) == 0 {
			leaf_distance := node_leaf_distance(node^)

			node.draw_content(node)
			// clay.TextDynamic(node.clay_id,
			// 	clay.TextConfig(
			// 		{fontSize = 16, fontId = FONT_ID_BODY_16, textColor = COLOR_LIGHT},
			// 	),
			// )
			if clay.Hovered() do hoovered_node = node
		}
	}
	return hoovered_node
}

// todo this is not very efficient atm, it searches the entire tree. Can probably use a better structure later
find_node_parent :: proc(root, node: ^Tiling_Node) -> (^Tiling_Node, i32) {
	for &n, index in root.sub_nodes {

		// if strings.compare(n.clay_id, node.clay_id) == 0 do return &n, i32(index)
		if n.clay_id == node.clay_id {
			return root, i32(index)
		}
		found_node, found_index := find_node_parent(&n, node)
		if found_index != -1 do return found_node, found_index
	}
	return nil, -1
}

direction_is_horizontal :: proc(direction: DirectionStraight) -> bool {return(
		direction == .Left ||
		direction == .Right \
	)}
direction_is_vertical :: proc(direction: DirectionStraight) -> bool {return(
		!direction_is_horizontal(direction) \
	)}


DirectionStraight :: enum {
	Up,
	Down,
	Left,
	Right,
}


DirectionDiagonal :: enum {
	UpperLeft,
	UpperRight,
	LowerLeft,
	LowerRight,
}

direction_is_left :: proc(direction: DirectionDiagonal) -> bool {
	return direction == .UpperLeft || direction == .LowerLeft
}

direction_is_up :: proc(direction: DirectionDiagonal) -> bool {
	return direction == .UpperLeft || direction == .UpperRight
}


get_edge_clicked :: proc(
	element_bounds: clay.BoundingBox,
	mouse_pos: rl.Vector2,
) -> DirectionStraight {
	tile_center: [2]c.float = {
		element_bounds.x + element_bounds.width / 2,
		element_bounds.y + element_bounds.height / 2,
	}

	dir := tile_center - [2]c.float{mouse_pos.x, mouse_pos.y}

	dir.x *= element_bounds.height
	dir.y *= element_bounds.width
	if math.abs(dir.x) > math.abs(dir.y) {
		if dir.x > 0 do return .Left
		return .Right
	} else {
		if dir.y > 0 do return .Up
		return .Down
	}

	return nil
}

get_corner_clicked :: proc(bounds: clay.BoundingBox, mouse_pos: [2]c.float) -> DirectionDiagonal {
	tile_center := [2]c.float{bounds.x + bounds.width / 2, bounds.y + bounds.height / 2}

	dir := mouse_pos - tile_center

	if dir.x > 0 { 	// Right
		if dir.y > 0 { 	// Lower
			return .LowerRight
		} else { 	// Upper
			return .UpperRight
		}
	} else { 	// Left
		if dir.y > 0 { 	// Lower
			return .LowerLeft
		} else { 	// Upper
			return .UpperLeft
		}
	}
}

// todo name
// // Note, return nodes can be 'node' and be the same node.
find_parent_x_y_scalers :: proc(
	root, node: ^Tiling_Node,
	corner: DirectionDiagonal,
) -> (
	horizontal, vertical: ^Tiling_Node,
) {
	// todo name
	search_for_parent_with_layout_direction :: proc(
		root, parent, node: ^Tiling_Node,
		layout_direction: clay.LayoutDirection,
		clicked_corner: DirectionDiagonal,
	) -> ^Tiling_Node {
		if parent.layout_dir == layout_direction {
			if layout_direction == .LeftToRight {
				if direction_is_left(clicked_corner) {
					if parent.sub_nodes[0].clay_id != node.clay_id {
						return node
					}
				} else { 	// Right
					if parent.sub_nodes[len(parent.sub_nodes) - 1].clay_id != node.clay_id {
						return node
					}
				}
			} else { 	// TopToBottom
				if direction_is_up(clicked_corner) {
					if parent.sub_nodes[0].clay_id != node.clay_id {
						return node
					}
				} else { 	// Right
					if parent.sub_nodes[len(parent.sub_nodes) - 1].clay_id != node.clay_id {
						return node
					}
				}

			}
		}
		grand_parent, _ := find_node_parent(root, parent)
		if grand_parent == nil do return nil
		return search_for_parent_with_layout_direction(
			root,
			grand_parent,
			parent,
			layout_direction,
			clicked_corner,
		)
	}

	parent, _ := find_node_parent(root, node)

	horizontal = search_for_parent_with_layout_direction(root, parent, node, .LeftToRight, corner)
	vertical = search_for_parent_with_layout_direction(root, parent, node, .TopToBottom, corner)

	if horizontal == nil do horizontal = root
	if vertical == nil do vertical = root

	return
}

distance_to_percent_of_bounding_box :: proc(
	bounds, parent_bounds: clay.BoundingBox,
	mouse_movement: [2]c.float,
) -> (
	scale_diff: [2]c.float,
) {
	current_percent: [2]c.float = {
		bounds.width / parent_bounds.width,
		bounds.height / parent_bounds.height,
	}

	percent_after: [2]c.float = {
		(bounds.width + mouse_movement.x) / parent_bounds.width,
		(bounds.height + mouse_movement.y) / parent_bounds.height,
	}

	scale_diff = percent_after - current_percent

	return
}

normalize_entire_tile_tree :: proc(root: ^Tiling_Node) {
	// root.size_percent = {0.75, 0.75}
	root.size_percent = {1, 1}
	normalize_child_nodes(root)

}

normalize_child_nodes :: proc(node: ^Tiling_Node) {
	total: [2]f32
	for &n in node.sub_nodes {
		MIN_SIZE_PERCENT: f32 : 0.1
		if n.size_percent.x < MIN_SIZE_PERCENT do n.size_percent.x = MIN_SIZE_PERCENT
		if n.size_percent.y < MIN_SIZE_PERCENT do n.size_percent.y = MIN_SIZE_PERCENT

		total += n.size_percent
	}

	for &n in node.sub_nodes {
		if node.layout_dir == .LeftToRight {
			n.size_percent.x = n.size_percent.x / total.x
			n.size_percent.y = 1.0
		} else {
			n.size_percent.x = 1.0
			n.size_percent.y = n.size_percent.y / total.y
		}
	}

	for &n in node.sub_nodes {
		normalize_child_nodes(&n)
	}
}

normalize_tile_nodes_sizes :: proc(root, node: ^Tiling_Node) {
	if node.clay_id == root.clay_id {
		root.size_percent = {0.5, 0.5}
		return
	}
	total: [2]f32
	for &child_node in node.sub_nodes {
		total += node.size_percent
	}

	for &child_node in node.sub_nodes {
		if node.layout_dir == .LeftToRight {
			child_node.size_percent.x = child_node.size_percent.x / total.x
			child_node.size_percent.y = 1
		} else {
			child_node.size_percent.x = 1
			child_node.size_percent.y = child_node.size_percent.y / total.y
		}
		node.size_percent /= total
	}
}

delete_all_child_nodes :: proc(node: ^Tiling_Node, free: bool = false) {
	for &n in node.sub_nodes {
		// todo only preform this is its not empty?
		delete_all_child_nodes(&n, true)
		delete(n.clay_id)
		delete(n.sub_nodes)
	}

	// delete(node.sub_nodes)
	if free do delete(node.sub_nodes)
	clear(&node.sub_nodes)

}

delete_node :: proc(root, parent_node: ^Tiling_Node, index: i32) {
	delete_all_child_nodes(&parent_node.sub_nodes[index], true)

	unordered_remove(&parent_node.sub_nodes, index)

	if len(parent_node.sub_nodes) == 1 {
		if parent_node.clay_id == root.clay_id {
			// clear(&root.sub_nodes)
			fmt.println("hit root")
			return
		}

		grandparent_node, grandparent_index := find_node_parent(root, parent_node)
		assert(grandparent_index != -1)
		if grandparent_index == -1 do return
		grandparent_node.sub_nodes[grandparent_index] = parent_node.sub_nodes[0]
	}
}

add_node :: proc(node: ^Tiling_Node, index: i32, new_node: Tiling_Node) {
	inject_at(&node.sub_nodes, index, new_node)
	// append_elem(&node.sub_nodes, new_node)
}

@(test)
test_delete_node :: proc(t: ^testing.T) {
	root_node := create_tiling_nodes_2X()


	// delete_node(&root_node)
	free_all(context.temp_allocator)
}
