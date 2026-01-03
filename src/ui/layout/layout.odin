package layout
import clay "../clay-odin"
import c "core:c"
import "core:fmt"
import "core:log"
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
	layout_proc:  proc(parent_node: ^Tiling_Node, active_elems: ^Active_Elements),
	userdata:     rawptr,
}

generate_root_node :: proc() -> Tiling_Node {

	return make_new_node("root")
}

make_new_node :: proc {
	make_new_node_with_draw_proc,
	make_new_node_with_name,
}

make_new_node_with_draw_proc :: proc(
	name: string,
	layout_proc: proc(parent_node: ^Tiling_Node, 
	active_elems: ^Active_Elements
		),

	userdata: rawptr,
) -> Tiling_Node {
	new_node := make_new_node_with_name(name)
	new_node.userdata = userdata
	new_node.layout_proc = layout_proc
	return new_node
}

make_new_node_with_name :: proc(name: string) -> Tiling_Node {
	return Tiling_Node{layout_dir = .TopToBottom, clay_id = name, size_percent = {0.5, 0.5}}
}

make_new_id :: proc(allocator := context.allocator) -> string {
	@(static) id_counter: i32 = -1
	id_counter += 1

	return fmt.aprintf("gen_{}", id_counter)
}

generate_default_leaf :: proc(allocator := context.allocator) -> Tiling_Node {

	return make_new_node(make_new_id())
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

layout_nodes :: proc(
	node: ^Tiling_Node,
	active_elems: ^Active_Elements,
) -> (
	hoovered_node: ^Tiling_Node,
) {
	// if node.has_content do return hoovered_node

	// if clay.UI(clay.ID(node.clay_id))(
	// config = clay.ElementDeclaration{
	// 	// layout = {
	// 	// 	layoutDirection = node.layout_dir,
	// 	// 	sizing = clay.Sizing {
	// 	// 		clay.SizingPercent(0.1),
	// 	// 		clay.SizingPercent(0.1),
	// 	// 	},
	// 	// 	padding = clay.PaddingAll(8),
	// 	// 	childGap = 8,
	// 	// },
	// 	backgroundColor = {0,0,0,0}, // node_leaf_distance(node^) == 0 ? auto_hightlight_color() : leaf_dist_to_color(node_leaf_distance(node^)),
	// 	floating = clay.FloatingElementConfig{offset = {0,0}, expand = clay.Dimensions{100,100}}
	//
	// },
	// ) {
	// 	for &n in node.sub_nodes {
	// 		new_hovered_node := draw_nodes(&n)
	// 		if new_hovered_node != nil do hoovered_node = new_hovered_node
	// 	}
	// 	if node_leaf_distance(node^) == 0 {
	// 		leaf_distance := node_leaf_distance(node^)
	//
	// 		// node.draw_content(node)
	// 		clay.TextDynamic(
	// 			node.clay_id,
	// 			clay.TextConfig(
	// 				{fontSize = 32, fontId = FONT_ID_BODY_16, textColor = COLOR_LIGHT},
	// 			),
	// 		)
	// 		if clay.Hovered() do hoovered_node = node
	// 	}
	// }

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
		backgroundColor = {0, 0, 0, 0}, // node_leaf_distance(node^) == 0 ? auto_hightlight_color() : leaf_dist_to_color(node_leaf_distance(node^)),
	},
	) {
		if node.layout_proc != nil {
			node.layout_proc(node, active_elems)
			// return hoovered_node
		}
		for &n in node.sub_nodes {
			new_hovered_node := layout_nodes(&n, active_elems)
			if new_hovered_node != nil do hoovered_node = new_hovered_node
		}
		if node_leaf_distance(node^) == 0 {
			leaf_distance := node_leaf_distance(node^)

			// node.draw_content(node)
			if clay.UI(clay.ID(fmt.tprintf("{}_debug_name", node.clay_id)))(
				config = clay.ElementDeclaration {
					floating = clay.FloatingElementConfig{attachTo = .Parent},
				},
			) {
				clay.TextDynamic(
					node.clay_id,
					clay.TextConfig(
						{fontSize = 16, fontId = FONT_ID_BODY_16, textColor = COLOR_LIGHT},
					),
				)
			}
			if clay.Hovered() do hoovered_node = node
		}
	}
	return hoovered_node
}

find_node :: proc {
	find_node_by_name,
}

find_node_by_name :: proc(root: ^Tiling_Node, name: string) -> ^Tiling_Node {

	for &node in root.sub_nodes {
		if node.clay_id == name do return &node
		if found_node := find_node_by_name(&node, name); found_node != nil do return found_node
	}

	return nil
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
		delete_node_memory(&n)
	}

	// delete(node.sub_nodes)
	if free do delete(node.sub_nodes)
	clear(&node.sub_nodes)

}

delete_node_memory :: proc(node: ^Tiling_Node) {
	delete(node.sub_nodes)
	delete(node.clay_id)
}

delete_node2 :: proc(root, node_to_delete: ^Tiling_Node) -> (deleted: bool) {
	delete_all_child_nodes(node_to_delete, true)

	parent_node, node_index_parent := find_node_parent(root, node_to_delete)
	unordered_remove(&parent_node.sub_nodes, node_index_parent)

	// delete_node_memory(node_to_delete) todo crashes when opening and closing editor panel

	if len(parent_node.sub_nodes) == 1 {
		if parent_node.clay_id == root.clay_id {
			// fmt.println("hit root")
			return
		}

		grandparent_node, grandparent_index := find_node_parent(root, parent_node)
		assert(grandparent_index != -1)
		if grandparent_index == -1 do return
		grandparent_node.sub_nodes[grandparent_index] = parent_node.sub_nodes[0]

		// delete(parent_node.clay_id)
		// delete(parent_node.sub_nodes)

	}

	return true
}

delete_node :: proc(root, parent_node: ^Tiling_Node, index: i32) {
	delete_all_child_nodes(&parent_node.sub_nodes[index], true)
	delete_node_memory(&parent_node.sub_nodes[index])

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
		// delete_node_memory(parent_node)
	}

}

add_node :: proc(node: ^Tiling_Node, index: i32, new_node: Tiling_Node) {
	inject_at(&node.sub_nodes, index, new_node)
	// append_elem(&node.sub_nodes, new_node)
}

add_node2 :: proc(
	node: ^Tiling_Node,
	node_to_insert: Tiling_Node,
	index: u32,
) -> (
	ok: bool,
	new_node: ^Tiling_Node,
) {
	inject_ok, inject_err := inject_at(&node.sub_nodes, index, node_to_insert)
	assert(inject_ok)

	return inject_ok, &node.sub_nodes[index]
}

// @(test)
// test_delete_node :: proc(t: ^testing.T) {
// 	root_node := create_tiling_nodes_2X()
//
//
// 	// delete_node(&root_node)
// 	free_all(context.temp_allocator)
// }
