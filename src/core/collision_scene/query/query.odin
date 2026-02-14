package query

import col_scene "../"
import gent "../../../game/game_entities/"
import l "../../../level/"
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

notify_object_transform_changed :: proc(
	level: ^l.Level,
	collision_object_map: ^gent.Game_Entity_Handle_Map,
	collision_meshes: ^cm.Map,
	spatial_hash_grid: ^map[col_scene.Hash_Key]col_scene.Hash_Cell,
	collision_object_id: hent.Entity_Handle,
) -> hent.Entity_Handle {


	collision_object_map := &level.entities
	collision_meshes := &level.collsion_scene.collision_meshes
	spatial_hash_grid := &level.collsion_scene.spatial_hash_grid

	found_object: ^gent.Entity = hm.get(collision_object_map, collision_object_id)
	if gent.Trait.Transform not_in found_object.traits do return {}
	if gent.Trait.Collision not_in found_object.traits do return {}

	collision_mesh := hm.get(collision_meshes, found_object.collision_component.mesh_id)
	assert(collision_mesh != nil)

	bounds := spat.calculate_bounds_from_tris_transform(
		collision_mesh.tris,
		found_object.transform_component.transform,
	)

	test :: struct {
		id:  int,
		key: col_scene.Hash_Key,
	}
	cells_to_remove: [dynamic]col_scene.Hash_Key = {}
	object_to_remove: [dynamic]test = {}
	// Remove from spatial_hash_grid TODO: This is slow very inefficient
	for id, &cell in spatial_hash_grid {
		for &object_id, index in cell.objects_ids {
			if object_id == collision_object_id {
				append_elem(&object_to_remove, test{index, id})
			}
		}

	}


	for t in object_to_remove {
		object := &spatial_hash_grid[t.key]
		unordered_remove(&object.objects_ids, t.id) // wondering if this will work

		// hms.remove(collision_object_map, collision_object_id)

		if len(object.objects_ids) == 0 {
			append(&cells_to_remove, t.key)

		}
	}


	for &id in &cells_to_remove {
		delete_key(spatial_hash_grid, id)
	}

	add_to_spatial_hash_grid(spatial_hash_grid, found_object.data, found_object.handle)
	// Insert again
	// id := create_and_add_collision_object_from_tris_transform(
	// 	collision_object_map,
	// 	spatial_hash_grid,
	// 	data.data.tris,
	// 	found_object.transform,
	// 	cc.is_blocking(data.data.collision_channels),
	// )

	return found_object.handle
}

add_shape_to_hash_map :: proc(
	collision_object_map: ^gent.Game_Entity_Handle_Map,
	spatial_hash_grid: ^map[col_scene.Hash_Key]col_scene.Hash_Cell,
	shape: spat.Collision_Shape,
	blocking_geo: bool = true,
) -> hent.Entity_Handle {
	bounds := spat.get_bounds(shape)

	collision_object_data := col_scene.shape_to_collision_object(shape)

	// id := add_to_object_map(collision_object_map, collision_object_data)
	add_to_spatial_hash_grid(spatial_hash_grid, collision_object_data, id)

	return id
}

// create_and_add_collision_object_from_tris_transform :: proc(
// 	collision_scene: ^col_scene.Collision_Scene,
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

add_to_spatial_hash_grid :: proc(
	spatial_hash_grid: ^Spatial_Hash_Grid,
	data: Collision_Object_Data,
	id: hent.Entity_Handle,
) {

	bounds := calculate_bounds_from_tris_transform(data.tris, data.transform) // todo defaults to  ref right hehe??
	potential_hash_keys := calculate_overlapping_cells2(bounds)
	defer delete(potential_hash_keys)
	for hash_key in potential_hash_keys {
		cell := &spatial_hash_grid[hash_key]
		if cell == nil {
			// log.warnf("Emty cell, creating new one...")
			spatial_hash_grid[hash_key] = col_scene.Hash_Cell{}
			cell = &spatial_hash_grid[hash_key]
		}

		append_elem(&cell.objects_ids, id)
	}
}

remove_from_spatial_hash_grid :: proc(
	spatial_hash_grid: ^Spatial_Hash_Grid,
	collision_object_map: ^gent.Game_Entity_Handle_Map,
	id: hent.Entity_Handle,
) {
	object := hms.get(collision_object_map, id)
	assert(object != nil)

	{
		bounds := calculate_bounds_from_tris_transform(object.tris, object.transform) // todo defaults to  ref right hehe??
		potential_hash_keys := calculate_overlapping_cells2(bounds)
		defer delete(potential_hash_keys) // TODO: Use temp allocator?

		for hash_key in potential_hash_keys {
			cell := &spatial_hash_grid[hash_key]
			if cell != nil {
				spatial_hash_grid[hash_key] = col_scene.Hash_Cell{}
				cell = &spatial_hash_grid[hash_key]
				for obj_id, i in &cell.objects_ids {
					if obj_id == id {
						unordered_remove(&cell.objects_ids, i)
						break
					}
				}
			}
		}
	}
}

// TODO: maybe only iteratie thorugh volumes in the active cells
does_location_overlap_finish_volume :: proc(
	finish_volumes: ^map[hent.Entity_Handle]bool,
	collision_object_map: ^gent.Game_Entity_Handle_Map,
	location: ^spat.Vector,
) -> hent.Entity_Handle {
	for finish_volume_object_id in finish_volumes {
		found_object := hms.get(collision_object_map, finish_volume_object_id)
		assert(
			found_object != nil,
			fmt.tprintf("Could not find object with id: {}", finish_volume_object_id),
		)

		if is_inside_object(found_object, location) {
			return finish_volume_object_id
		}
	}

	return INVALID_OBJECT_ID
}

add_to_level :: proc(
	collision_object_map: ^gent.Game_Entity_Handle_Map,
	spatial_hash_grid: ^map[col_scene.Hash_Key]col_scene.Hash_Cell,
	collision_object_data: col_scene.Collision_Object_Data,
) -> hent.Entity_Handle {
	id := add_to_object_map(collision_object_map, collision_object_data)
	add_to_spatial_hash_grid(spatial_hash_grid, collision_object_data, id)

	return id
}

remove_from_level :: proc(
	collision_object_map: ^gent.Game_Entity_Handle_Map,
	spatial_hash_grid: ^map[col_scene.Hash_Key]col_scene.Hash_Cell,
	id: hent.Entity_Handle,
) {
	remove_from_spatial_hash_grid(spatial_hash_grid, collision_object_map, id)
	remove_from_object_map(collision_object_map, id)


}


create_and_add_collision_object_from_tris :: proc(
	collision_object_map: ^gent.Game_Entity_Handle_Map,
	spatial_hash_grid: ^col_scene.Spatial_Hash_Grid,
	tris: [dynamic]spat.Collision_Triangle, // todo this is by ref right???
	blocking: cc.Responses = cc.BLOCK_ALL,
) {
	bounds := calculate_bounds_from_tris(tris) // todo defaults to  ref right hehe??

	potential_hash_keys := calculate_overlapping_cells2(bounds)
	// Adding to handle map
	collision_object_id := hms.add(
		collision_object_map,
		Collision_Object_Data_Runtime {
			collision_channels = blocking,
			tris = tris,
			transform = TRANSFORM_IDENTITY,
		},
	)

	for hash_key in potential_hash_keys {
		cell := &spatial_hash_grid[hash_key]
		if cell == nil {
			// fmt.println("Emty cell, creating new one...")
			spatial_hash_grid[hash_key] = {}
			cell = &spatial_hash_grid[hash_key]
		}

		append_elem(&cell.objects_ids, collision_object_id)
	}
}
sphere_trace_spatial_hash_grid :: proc(
	sphere_trace: ^spat.Sphere_Trace,
	shg: ^col_scene.Spatial_Hash_Grid,
	com: ^gent.Game_Entity_Handle_Map,
) -> (
	hit: bool,
	id: hent.Entity_Handle,
	location: spat.Vector,
) {
	rays := calculate_rays_by_sphere_trace(sphere_trace)
	defer delete(rays)

	hashes := calculate_hashes_by_rays(&rays)
	defer delete(hashes)

	for hash_key in &hashes {
		object_ids, ok := shg[hash_key]
		if ok {
			for object_id in &object_ids.objects_ids {
				object := hms.get(com, object_id)
				for &tri in &object.tris {


				}
			}
		}
	}

	return
}
ray_trace_object_single :: proc(
	ray: ^spat.Ray,
	collision_object: ^gent.Entity,
) -> (
	hit: bool,
	location: spat.Vector,
) {

	for &tri in collision_object.transform_component.tris {
		if hit, location = ray_triangle_intersect(ray, &tri); hit == true {
			return hit, location
		}
	}

	return hit, location
}

// TODO: Can make more efficient vairants, that preallocates the array.
ray_trace_object_multi :: proc(
	ray: ^spat.Ray,
	collision_object: ^Collision_Object_Data_Runtime,
) -> (
	hits: [dynamic]spat.Vector,
) {
	mat := get_matrix_from_transform(collision_object.transform)
	for tri in collision_object.tris {
		tri := tri

		tri.points.x = (mat * rl.Vector4{tri.points.x.x, tri.points.x.y, tri.points.x.z, 1}).xyz
		tri.points.y = (mat * rl.Vector4{tri.points.y.x, tri.points.y.y, tri.points.y.z, 1}).xyz
		tri.points.z = (mat * rl.Vector4{tri.points.z.x, tri.points.z.y, tri.points.z.z, 1}).xyz
		// TODO: Transform the tri
		if ok, location := ray_triangle_intersect(ray, &tri); ok == true {
			// make sure collision is in front of ray.
			if linalg.dot((location - ray.origin), ray_direction(ray^)) > 0 {
				append_elem(&hits, location)
			}
		}
	}

	return hits
}
is_inside_object :: proc(
	collision_object: ^Collision_Object_Data_Runtime,
	location: ^spat.Vector,
) -> bool {
	// If we shoot a ray straight up, that is longer than the longest size of the spat.Bounds. If we hit a odd number of tris, we are inside it.

	bounds: spat.Bound = spat.calculate_bounds_from_tris(collision_object.tris)
	longest_size := linalg.length(bounds.max - bounds.min)
	ray: Ray = make_ray_with_origin_direction_distance(
		location^,
		spat.Vector{0, 1, 0},
		longest_size,
	)
	hits := ray_trace_object_multi(&ray, collision_object)
	defer delete(hits)

	// fmt.printfln("num tris {}", len(collision_object.tris))
	// fmt.printfln("nun hits {}, length of ray {}, bounds {}", len(hits), longest_size, bounds)
	return (len(hits) % 2) == 1
}
