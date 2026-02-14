package level
import cc "../core/collision_channel"
import cs "../core/collision_scene/"
import spat "../core/spatial"
import gent "../game/game_entities/"
import "core:math/linalg"
import rl "vendor:raylib"

// add_debug_level_objects :: proc(
// 	level: ^Level,
// 	collision_objects: ^gent.Game_Entity_Handle_Map,
// 	spaital_hash_grid: ^map[cs.Hash_Key]cs.Hash_Cell,
// ) {
//
// 	q := linalg.QUATERNIONF32_IDENTITY
//
//
// 	cs.add_shape_to_hash_map(
// 		collision_objects,
// 		spaital_hash_grid,
// 		spat.Collision_Shape{{{16, 16, 16}, q, {1, 1, 1}}, spat.Box{{10.0, 10.0, 9.0}}},
// 	)
//
// 	spat.add_shape_to_hash_map(
// 		collision_objects,
// 		spaital_hash_grid,
// 		spat.Collision_Shape {
// 			{{9, 17, 9}, spat.QUATERNION_IDENTITY, {1, 1, 1}},
// 			spat.Box{{1.0, 1.0, 1.0}},
// 		},
// 	)
//
// 	spat.add_shape_to_hash_map(
// 		collision_objects,
// 		spaital_hash_grid,
// 		spat.Collision_Shape {
// 			{{0, -20, 0}, spat.QUATERNION_IDENTITY, {1, 1, 1}},
// 			spat.Box{{150.0, 10.0, 150}},
// 		},
// 	)
//
// 	// spat.add_shape_to_hash_map(
// 	// 	collision_objects,
// 	// 	spaital_hash_grid,
// 	// 	&spat.Collision_Shape{{{17, 6, 9}, {}, {1, 1, 1}}, spat.Sphere{5.0}},
// 	// )
// 	//
// 	// spat.add_shape_to_hash_map(
// 	// 	collision_objects,
// 	// 	spaital_hash_grid,
// 	// 	&spat.Collision_Shape{{{-32, 0, 0}, q, {1, 1, 1}}, spat.Cylinder{9.0, 3.0}},
// 	// )
//
// 	q2 := linalg.quaternion_from_forward_and_up_f32({1, 1, 1}, {1, -1, 1})
// 	//box3 := Collision_Shape{i, {{-32, 0, 0}, q, {2, 2, 2}}, Box{{9.0, 9.0, 9.0}}}
// 	spat.add_shape_to_hash_map(
// 		collision_objects,
// 		spaital_hash_grid,
// 		spat.Collision_Shape{{{-32, 0, 0}, q2, {2, 2, 2}}, spat.Box{{9.0, 9.0, 9.0}}},
// 	)
//
// 	for box_num in 0 ..= 5 {
// 		id := spat.add_shape_to_hash_map(
// 			collision_objects,
// 			spaital_hash_grid,
// 			spat.Collision_Shape {
// 				{{cast(f32)(box_num * 90 + 100), 0, 0}, spat.QUATERNION_IDENTITY, {1, 1, 1}},
// 				spat.Box{{3, 3, 40}},
// 			},
// 		)
//
// 		level.collsion_scene.grappable[id] = true
//
// 	}
//
// 	tris: [dynamic]spat.Collision_Triangle
//
// 	append_quad :: proc(
// 		tris: ^[dynamic]spat.Collision_Triangle,
// 		a, b, c, d: rl.Vector3,
// 		offs: rl.Vector3 = {},
// 	) {
// 		points := []spat.Collision_Triangle {
// 			spat.Collision_Triangle{{b + offs, a + offs, c + offs}},
// 			spat.Collision_Triangle{{b + offs, c + offs, d + offs}},
// 		}
// 		append(tris, ..points)
// 	}
//
// 	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {0, -2, 0})
// 	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {0, -2, 10})
// 	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {10, 0, 10})
// 	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 10, 10}, {10, 10, 10}, {10, 0, 20})
// 	append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {10, 10, 30})
//
// 	spat.create_and_add_collision_object_from_tris(collision_objects, spaital_hash_grid, tris)
//
// 	// Add finish volume
// 	finish_object_shape := spat.Collision_Shape {
// 		spat.Transform{spat.Vector{0, -10, 0}, spat.QUATERNION_IDENTITY, spat.ONE_VEC3},
// 		spat.Box{{4, 4, 4}},
// 	}
// 	bounds := spat.get_bounds(finish_object_shape)
// 	collision_object_data := spat.shape_to_collision_object(finish_object_shape)
// 	collision_object_data.collision_channels.player = cc.BLOCK
//
// 	id := spat.add_to_object_map(collision_objects, collision_object_data)
// 	spat.add_to_spatial_hash_grid(spaital_hash_grid, collision_object_data, id)
// 	spat.add_to_finish_volumes(&level.collsion_scene.finish_volumes, id)
// }
