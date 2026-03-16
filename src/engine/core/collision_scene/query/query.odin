package query

import logs "../../../../engine/core/logs/"
import gent "../../../../game/game_entities/"
import cc "../../collision_channel/"
import cm "../../collision_mesh/"
import cs "../../collision_scene/"
import hent "../../entity_handle/"
import spat "../../spatial/"


import hm "core:container/handle_map"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:testing"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// notify_object_transform_changed :: proc(
// 	level: ^l.Level,
// 	collision_object_id: hent.Entity_Handle,
// ) -> hent.Entity_Handle {
//
//
// 	collision_object_map := &level.entities
// 	collision_meshes := &level.collsion_scene.collision_meshes
// 	spatial_hash_grid := &level.collsion_scene.spatial_hash_grid
//
// 	found_object: ^gent.Entity = hm.get(collision_object_map, collision_object_id)
// 	assert(found_object != nil)
// 	if gent.Trait.Transform not_in found_object.traits do return {}
// 	if gent.Trait.Collision not_in found_object.traits do return {}
//
// 	collision_mesh := hm.get(&collision_meshes.mesh_map, found_object.collision_component.mesh_id)
// 	assert(collision_mesh != nil)
//
// 	bounds := spat.calculate_bounds_from_tris_transform(
// 		collision_mesh.tris,
// 		found_object.transform_component.transform,
// 	)
//
// 	test :: struct {
// 		id:  int,
// 		key: cs.Hash_Key,
// 	}
// 	cells_to_remove: [dynamic]cs.Hash_Key = {}
// 	object_to_remove: [dynamic]test = {}
// 	// Remove from spatial_hash_grid TODO: This is slow very inefficient
// 	for id, &cell in spatial_hash_grid {
// 		for &object_id, index in cell.objects_ids {
// 			if object_id == collision_object_id {
// 				append_elem(&object_to_remove, test{index, id})
// 			}
// 		}
//
// 	}
//
//
// 	for t in object_to_remove {
// 		object := &spatial_hash_grid[t.key]
// 		unordered_remove(&object.objects_ids, t.id) // wondering if this will work
//
// 		// hms.remove(collision_object_map, collision_object_id)
//
// 		if len(object.objects_ids) == 0 {
// 			append(&cells_to_remove, t.key)
//
// 		}
// 	}
//
//
// 	for &id in &cells_to_remove {
// 		delete_key(spatial_hash_grid, id)
// 	}
//
// 	// add_to_spatial_hash_grid(spatial_hash_grid, found_object.data, found_object.handle)
// 	// Insert again
// 	// id := create_and_add_collision_object_from_tris_transform(
// 	// 	collision_object_map,
// 	// 	spatial_hash_grid,
// 	// 	data.data.tris,
// 	// 	found_object.transform,
// 	// 	cc.is_blocking(data.data.collision_channels),
// 	// )
//
// 	return found_object.handle
// }

// add_shape_to_hash_map :: proc(
// 	collision_object_map: ^gent.Game_Entity_Handle_Map,
// 	spatial_hash_grid: ^map[cs.Hash_Key]cs.Hash_Cell,
// 	shape: spat.Collision_Shape,
// 	blocking_geo: bool = true,
// ) -> hent.Entity_Handle {
// 	bounds := spat.get_bounds(shape)
//
// 	collision_object_data := cs.shape_to_collision_object(shape)
//
// 	// id := add_to_object_map(collision_object_map, collision_object_data)
// 	add_to_spatial_hash_grid(spatial_hash_grid, collision_object_data, id)
//
// 	return id
// }

// create_and_add_collision_object_from_tris_transform :: proc(
// 	collision_scene: ^cs.Collision_Scene,
// 	collision_object_map: ^gent.Game_Entity_Handle_Map,
// 	spatial_hash_grid: ^Spatial_Hash_Grid,
// 	tris: [dynamic]spat.Collision_Triangle, // todo this is by ref right???
// 	transform: spat.Transform,
// 	blocking: cc.Responses = cc.BLOCK_ALL,
// ) -> hent.Entity_Handle {
//
// 	data := Collision_Object_Data {
// 		collision_channels = blocking,
// 		transform          = transform,
// 		tris               = tris,
// 	}
//
// 	collision_object_id := add_to_object_map(collision_object_map, data)
// 	runtime_data := Collision_Object_Data_Runtime {
// 		data   = data,
// 		handle = collision_object_id,
// 	}
//
// 	add_to_spatial_hash_grid(spatial_hash_grid, runtime_data, collision_object_id)
//
// 	return collision_object_id
// }


// remove_from_spatial_hash_grid :: proc(
// 	spatial_hash_grid: ^Spatial_Hash_Grid,
// 	collision_object_map: ^gent.Game_Entity_Handle_Map,
// 	id: hent.Entity_Handle,
// ) {
// 	object := hms.get(collision_object_map, id)
// 	assert(object != nil)
//
// 	{
// 		bounds := calculate_bounds_from_tris_transform(object.tris, object.transform) // todo defaults to  ref right hehe??
// 		potential_hash_keys := calculate_overlapping_cells2(bounds)
// 		defer delete(potential_hash_keys) // TODO: Use temp allocator?
//
// 		for hash_key in potential_hash_keys {
// 			cell := &spatial_hash_grid[hash_key]
// 			if cell != nil {
// 				spatial_hash_grid[hash_key] = cs.Hash_Cell{}
// 				cell = &spatial_hash_grid[hash_key]
// 				for obj_id, i in &cell.objects_ids {
// 					if obj_id == id {
// 						unordered_remove(&cell.objects_ids, i)
// 						break
// 					}
// 				}
// 			}
// 		}
// 	}
// }

entities_in_bound :: proc(
	ents: gent.Game_Entity_Handle_Map,
	col_scene: cs.Collision_Scene,
	bound: spat.Bound,
	allocator := context.allocator,
) -> [dynamic]hent.Entity_Handle {
	col_scene := col_scene

	ent_handles := make([dynamic]hent.Entity_Handle, allocator)

	ents := ents // copy right? So this is probably very slow
	cells := cs.calculate_overlapping_cells_by_bound(bound, context.temp_allocator)

	for hash in cells {
		cell, cell_ok := col_scene.spatial_hash_grid[hash]
		if !cell_ok do continue // no entries in cell

		for id in cell.objects_ids {
			ent: ^gent.Entity = hm.get(&ents, id)
			assert(ent != nil)

			if !gent.has_traits({.Collision}, ent^) do continue

			found_coll_mesh: ^cm.Mesh = hm.get(
				&col_scene.collision_meshes.mesh_map,
				ent.collision_component.mesh_id,
			)
			assert(found_coll_mesh != nil)

			for tri in found_coll_mesh.tris {
				// if spat.distance_to_tri(tri, )
				// TODO: Continue here. Need a AABB v TRiangle collision.

			}

			append(&ent_handles, id)
		}
	}

	return ent_handles
}

any_entity_in_bound_has :: proc(
	ents: gent.Game_Entity_Handle_Map,
	col_scene: cs.Collision_Scene,
	bound: spat.Bound,
	has_proc: proc(ent: gent.Entity, user_data: rawptr) -> bool,
	user_data: rawptr,
	allocator := context.allocator,
) -> hent.Entity_Handle {
	ents := ents
	ents_in_bound := entities_in_bound(ents, col_scene, bound, allocator)
	for ent_handle in ents_in_bound {
		ent := hm.get(&ents, ent_handle)
		assert(ent != nil)
		if has_proc(ent^, user_data) do return ent_handle
	}
	return {}
}

any_entity_in_bound_has_traits :: proc(
	ents: gent.Game_Entity_Handle_Map,
	col_scene: cs.Collision_Scene,
	bound: spat.Bound,
	traits: gent.Traits,
	allocator := context.allocator,
) -> hent.Entity_Handle {
	traits := traits

	has_proc :: proc(ent: gent.Entity, user_data: rawptr) -> bool {
		traits := cast(^gent.Traits)user_data
		return gent.has_traits(traits^, ent)
	}

	return any_entity_in_bound_has(ents, col_scene, bound, has_proc, &traits, allocator)
}

shg_valid_checked :: proc(ents: gent.Game_Entity_Handle_Map, shg: cs.Spatial_Hash_Grid) {
	ents := ents
	for key, cell in shg {
		for id in cell.objects_ids {
			gent.get_entity_checked(&ents, id)

		}

	}

}

// add_to_level :: proc(
// 	level: ^l.Level,
// 	// collision_object_map: ^gent.Game_Entity_Handle_Map,
// 	// spatial_hash_grid: ^map[cs.Hash_Key]cs.Hash_Cell,
// 	collision_object_data: cs.Collision_Object_Data,
// ) -> hent.Entity_Handle {
// 	id := add_to_object_map(collision_object_map, collision_object_data)
// 	add_to_spatial_hash_grid(spatial_hash_grid, collision_object_data, id)
//
// 	return id
// }
//
// remove_from_level :: proc(
// 	collision_object_map: ^gent.Game_Entity_Handle_Map,
// 	spatial_hash_grid: ^map[cs.Hash_Key]cs.Hash_Cell,
// 	id: hent.Entity_Handle,
// ) {
// 	remove_from_spatial_hash_grid(spatial_hash_grid, collision_object_map, id)
// 	remove_from_object_map(collision_object_map, id)
//
//
// }


// create_and_add_collision_object_from_tris :: proc(
// 	collision_object_map: ^gent.Game_Entity_Handle_Map,
// 	spatial_hash_grid: ^cs.Spatial_Hash_Grid,
// 	tris: [dynamic]spat.Collision_Triangle, // todo this is by ref right???
// 	blocking: cc.Responses = cc.BLOCK_ALL,
// ) {
// 	bounds := calculate_bounds_from_tris(tris) // todo defaults to  ref right hehe??
//
// 	potential_hash_keys := calculate_overlapping_cells2(bounds)
// 	// Adding to handle map
// 	collision_object_id := hms.add(
// 		collision_object_map,
// 		Collision_Object_Data_Runtime {
// 			collision_channels = blocking,
// 			tris = tris,
// 			transform = TRANSFORM_IDENTITY,
// 		},
// 	)
//
// 	for hash_key in potential_hash_keys {
// 		cell := &spatial_hash_grid[hash_key]
// 		if cell == nil {
// 			// fmt.println("Emty cell, creating new one...")
// 			spatial_hash_grid[hash_key] = {}
// 			cell = &spatial_hash_grid[hash_key]
// 		}
//
// 		append_elem(&cell.objects_ids, collision_object_id)
// 	}
// }

// sphere_trace_spatial_hash_grid :: proc(
// 	sphere_trace: ^spat.Sphere_Trace,
// 	shg: ^cs.Spatial_Hash_Grid,
// 	col_mesh_ctx: ^cm.Collider_Mesh_Context,
// 	com: ^gent.Game_Entity_Handle_Map,
// ) -> (
// 	hit: bool,
// 	id: hent.Entity_Handle,
// 	location: spat.Vector,
// ) {
// 	rays := cs.calculate_rays_by_sphere_trace(sphere_trace)
// 	defer delete(rays)
//
// 	hashes := cs.calculate_hashes_by_rays(&rays)
// 	defer delete(hashes)
//
// 	for hash_key in &hashes {
// 		ent_handles, ok := shg[hash_key]
// 		if ok {
// 			for object_id in &ent_handles.objects_ids {
// 				object: ^gent.Entity = hm.get(com, object_id)
// 				assert(object != nil)
// 				col_mesh := hm.get(&col_mesh_ctx.mesh_map, object.collision_component.mesh_id)
// 				assert(col_mesh != nil)
//
// 				for &tri in &col_mesh.tris {
//
//
// 				}
// 			}
// 		}
// 	}
//
// 	return
// }

ray_trace_object_single :: proc(
	ray: spat.Ray,
	col_mesh: cm.Mesh,
	transform: spat.Transform,
) -> (
	hit: bool,
	location: spat.Vector,
) {

	tris := col_mesh.tris
	spat.transform_triangles(&tris, transform)
	for &tri in tris {
		if hit, location = spat.ray_triangle_intersect(ray, tri); hit == true {
			return hit, location
		}
	}

	return hit, location
}

// TODO: Can make more efficient vairants, that preallocates the array.
ray_trace_object_multi :: proc(
	ray: spat.Ray,
	col_mesh: cm.Mesh,
	transform: spat.Transform,
) -> (
	hits: [dynamic]spat.Vector,
) {
	mat := spat.get_matrix_from_transform(transform)
	for tri in col_mesh.tris {
		tri := tri

		tri.points.x = (mat * rl.Vector4{tri.points.x.x, tri.points.x.y, tri.points.x.z, 1}).xyz
		tri.points.y = (mat * rl.Vector4{tri.points.y.x, tri.points.y.y, tri.points.y.z, 1}).xyz
		tri.points.z = (mat * rl.Vector4{tri.points.z.x, tri.points.z.y, tri.points.z.z, 1}).xyz
		// TODO: Transform the tri
		if ok, location := spat.ray_triangle_intersect(ray, tri); ok == true {
			// make sure collision is in front of ray.
			if linalg.dot((location - ray.origin), spat.ray_direction(ray)) > 0 {
				append_elem(&hits, location)
			}
		}
	}

	return hits
}

is_inside_entity :: proc(ent: gent.Entity, col_mesh: cm.Mesh, location: spat.Vector) -> bool {
	// If we shoot a ray straight up, that is longer than the longest size of the spat.Bounds. If we hit a odd number of tris, we are inside it.

	bounds: spat.Bound = spat.calculate_bounds_from_tris(col_mesh.tris)
	longest_size := linalg.length(bounds.max - bounds.min)
	ray: spat.Ray = spat.make_ray_with_origin_direction_distance(
		location,
		spat.Vector{0, 1, 0},
		longest_size,
	)

	hits := ray_trace_object_multi(ray, col_mesh, ent.transform_component.transform)
	defer delete(hits)

	return (len(hits) % 2) == 1
}
