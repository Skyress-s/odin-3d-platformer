package render_game

import render "../"
import col "../../color"
import ddu "../../debug_draw_utils"
import e_tools "../../editor/tools"
import cm "../../engine/core/collision_mesh/"
import cs "../../engine/core/collision_scene/"
import hent "../../engine/core/entity_handle/"
import spat "../../engine/core/spatial/"
import g "../../game/game/"
import gent "../../game/game_entities/"
import w "../../game/world/"
import gs "../../game_state"
import lightray "../../lightray"
import "../../player_data/"
import plrs "../../players/"

import "core:c"
import hm "core:container/handle_map"
import "core:math/linalg"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"


render :: proc(game: ^g.Game, debug_draw_data: ^render.Debug_Draw_Data, game_rect: rl.Rectangle) {
	dt := rl.GetFrameTime()
	// rl.BeginDrawing()
	rl.BeginTextureMode(game.textures.render_targets.game)
	rl.ClearBackground({40, 30, 50, 255})

	rl.BeginMode3D(cam)


	@(static) shader_editor_tool_depth: rl.Shader
	if shader_editor_tool_depth.id == 0 do shader_editor_tool_depth = rl.LoadShader("content/shaders/editor_tool_depth/depth.vert", "content/shaders/editor_tool_depth/depth.frag")

	assert(shader_editor_tool_depth.id != 0)
	view_loc := rl.GetShaderLocation(lightray.lighting.shader, "viewPos")

	cam_position := cam.position
	rl.SetShaderValue(
		lightray.lighting.shader,
		view_loc,
		&cam_position,
		rlgl.ShaderUniformDataType.VEC3,
	)

	lightray.begin_lighting()
	lightray.set_ambient_light(rl.Color{255, 255, 255, 255}, 0.3)

	rl.DrawSphere(spat.Vector{0, 100, 0}, 1, col.YELLOW)

	tool := &game.players.editor.transform_tool

	// Draw debug tooltips
	if game.game_state.cheat_state.draw_debug_draw_utilities_instructions {
		ddu.draw_all_instructions_and_reset()
		ddu.update_lifetime_and_clean(dt)
	} else {
		ddu.clear_all_instructions()
	}

	players := game.players

	switch players.mode {
	case plrs.Player_Mode.Game:
		if players.game.is_hooked {
			rl.DrawSphere(players.game.hooked_position, 3, rl.RAYWHITE)
			points: [2]spat.Vector2
		}

	case plrs.Player_Mode.Editor:
		_, forward, _ := player_data.calculate_direction_from_look(players.game.look_angles)
		player_verlet := &players.game.verlet_component

		rl.DrawCylinder(
			player_verlet.position - spat.Vector{0, players.game.radius, 0},
			players.game.radius,
			players.game.radius,
			players.game.radius * 2,
			8,
			rl.GREEN,
		)
		rl.DrawLine3D(player_verlet.position, player_verlet.position + forward * 8, rl.RED)

	}

	// rl.DrawCube(tool.transform.position, 50, 50, 50, rl.MAGENTA)

	player_verlet := &players.game.verlet_component
	player_root_pos_for_drawing := player_verlet.position - spat.Vector{0, 0.1, 0}
	rl.DrawLine3D(
		player_root_pos_for_drawing,
		player_verlet.position + player_verlet.velocity * 0.4,
		rl.ORANGE,
	)

	// Draw rope
	if players.game.is_hooked {
		rl.DrawLine3D(player_root_pos_for_drawing, players.game.hooked_position, rl.VIOLET)
	}


	draw_collision_tri :: proc(
		transform: ^spat.Transform,
		t: ^spat.Collision_Triangle,
		face_color, edge_color: rl.Color,
	) {
		rlgl.PushMatrix()
		// rlgl.Scalef(transform.scale.x,transform.scale.y, transform.scale.z)
		// euler_x, euler_y, euler_z:= linalg.euler_angles_from_quaternion_f32(transform.rotation, linalg.Euler_Angle_Order.XYZ)
		// rlgl.Rotatef(euler_x, 1, 0, 0)
		// rlgl.Rotatef(euler_y, 0, 1, 0)
		// rlgl.Rotatef(euler_z, 0, 0, 1)

		mat := spat.get_matrix_from_transform(transform^)

		transformed_tri := t^

		for &p in transformed_tri.points {
			p4 := mat * spat.Vector4{p.x, p.y, p.z, 1}
			p = p4.xyz
		}


		draw_triangle(
			transformed_tri.points.x,
			transformed_tri.points.y,
			transformed_tri.points.z,
			face_color,
		)

		rl.DrawLine3D(transformed_tri.points.x, transformed_tri.points.y, edge_color)
		rl.DrawLine3D(transformed_tri.points.x, transformed_tri.points.z, edge_color)
		rl.DrawLine3D(transformed_tri.points.y, transformed_tri.points.z, edge_color)
		rlgl.PopMatrix()
	}


	draw_collision_object :: proc(
		id: hent.Entity_Handle,
		level: ^w.World,
		face_color, edge_color: rl.Color,
	) {
		entity: ^gent.Entity = hm.static_get(&level.entities, id)
		assert(entity != nil)

		collision_mesh: ^cm.Mesh = hm.static_get(
			&level.collision_scene.collision_meshes.mesh_map,
			entity.collision_component.mesh_id,
		)
		assert(collision_mesh != nil)

		assert(gent.Trait.Transform in entity.traits)
		assert(gent.Trait.Collision in entity.traits)

		for &t in collision_mesh.tris {
			draw_collision_tri(&entity.transform_component.transform, &t, face_color, edge_color)
		}
	}

	drawn_collision_objects_ids: map[hent.Entity_Handle]bool
	defer delete(drawn_collision_objects_ids)

	itr := hm.iterator_make(&game.entities)
	for entity in hm.iterate(&itr) {
		if !gent.has_traits({.Transform, .Collision}, entity^) do continue

		col := rl.WHITE
		if gent.has_traits({.Finish}, entity^) do col = rl.YELLOW
		else if gent.has_traits({.Grabable}, entity^) do col = rl.SKYBLUE
		else if gent.has_traits({.Kill}, entity^) do col = rl.RED

		draw_collision_object(entity.handle, game.world, col, rl.WHITE)
	}

	// for star_id, picked_up in level.collsion_scene.stars {
	// 	drawn_collision_objects_ids[star_id] = true
	// 	if !picked_up {
	// 		volume_obj := hms.get(&level.collsion_scene.collision_object_map, star_id)
	// 		assert(volume_obj != nil)
	// 		draw_collision_object(volume_obj, rl.YELLOW, rl.RED)
	// 	}
	//
	// }
	//
	// for kill_id in level.collsion_scene.kill_volumes {
	// 	drawn_collision_objects_ids[kill_id] = true
	//
	// 	volume_obj := hms.get(&level.collsion_scene.collision_object_map, kill_id)
	// 	assert(volume_obj != nil)
	// 	draw_collision_object(volume_obj, rl.RED, rl.GRAY)
	//
	// }
	//
	// for grappable_obj_id in level.collsion_scene.grappable {
	// 	drawn_collision_objects_ids[grappable_obj_id] = true
	//
	// 	volume_obj := hms.get(&level.collsion_scene.collision_object_map, grappable_obj_id)
	// 	assert(volume_obj != nil)
	// 	draw_collision_object(volume_obj, rl.SKYBLUE, rl.GRAY)
	//
	// }
	//
	// for volume_id in level.collsion_scene.finish_volumes {
	// 	drawn_collision_objects_ids[volume_id] = true
	//
	// 	volume_obj := hms.get(&level.collsion_scene.collision_object_map, volume_id)
	// 	assert(volume_obj != nil)
	// 	draw_collision_object(volume_obj, rl.GREEN, rl.GRAY)
	// }


	// if game_state.cheat_state.change_color_when_player_in_cell {
	// 	for cell_key in debug_draw_data.active_cell {
	// 		for &collision_object_id in level.collsion_scene.spatial_hash_grid[cell_key].objects_ids {
	// 			has_been_drawn := collision_object_id in drawn_collision_objects_ids
	// 			if (!has_been_drawn) {
	// 				obj: ^spat.Collision_Object_Data = hms.get(
	// 					&level.collsion_scene.collision_object_map,
	// 					collision_object_id,
	// 				)
	// 				draw_collision_object(obj, rl.GREEN, rl.GRAY)
	// 				drawn_collision_objects_ids[collision_object_id] = true
	// 			}
	// 		}
	// 	}
	// }
	//
	// // Draw all other geometry
	// for hash_key in level.collsion_scene.spatial_hash_grid {
	// 	if hash_key == debug_draw_data.active_cell_hash do continue
	//
	// 	cell := &level.collsion_scene.spatial_hash_grid[hash_key]
	// 	for &collision_object_id in cell.objects_ids {
	// 		has_been_drawn := collision_object_id in drawn_collision_objects_ids
	// 		if (!has_been_drawn) {
	// 			draw_collision_object(
	// 				hms.get(&level.collsion_scene.collision_object_map, collision_object_id),
	// 				rl.LIGHTGRAY,
	// 				rl.GRAY,
	// 			)
	// 			drawn_collision_objects_ids[collision_object_id] = true
	// 		}
	// 	}
	// }


	// Draw coorinate axis
	// rl.DrawCube({0, 0, 0}, 0.1, 0.1, 0.1, rl.WHITE)
	// rl.DrawCube({1, 0, 0}, 1, 0.1, 0.1, rl.RED)
	// rl.DrawCube({0, 1, 0}, 0.1, 1, 0.1, rl.GREEN)
	// rl.DrawCube({0, 0, 1}, 0.1, 0.1, 1, rl.BLUE)


	if game.game_state.cheat_state.draw_bounds {
		hash_key := cs.Hash_Location(player_verlet.position)
		cs.Draw_Hash_Cell_Bounds(hash_key)
		cs.draw_hash_grid_bounds_populated_cells(game.spatial_hash_grid, &hash_key)}


	/*
		active_cell_items := spatial_hash_map[hash_key].items

		for shape in objects {
			color := rl.RED
			for active_cell_item in active_cell_items {
				if active_cell_item.id == shape.id {
					color = rl.GREEN
					break
				}
			}

			// draw_collision_shape(shape, &color)
		}

		*/
	lightray.end_lighting()
	rl.BeginShaderMode(shader_editor_tool_depth)

	if players.mode == plrs.Player_Mode.Editor {
		e_tools.draw_tooltip(&level.entities, tool, players.editor.position)
	}

	rl.EndShaderMode()

	rl.EndMode3D()

	// Draw UI babiiiiiii


	// rl.EndDrawing()
	rl.EndTextureMode()


}

draw_triangle :: proc(a, b, c: spat.Vector, color: rl.Color) {
	rlgl.PushMatrix()
	defer rlgl.PopMatrix()

	normal := linalg.normalize(linalg.cross(b - a, c - a))

	rlgl.Begin(rlgl.TRIANGLES)
	defer rlgl.End()

	rlgl.Color4ub(color.r, color.g, color.b, color.a)

	rlgl.Normal3f(normal.x, normal.y, normal.z)

	rlgl.Vertex3f(a.x, a.y, a.z)
	rlgl.Vertex3f(b.x, b.y, b.z)
	rlgl.Vertex3f(c.x, c.y, c.z)
}
