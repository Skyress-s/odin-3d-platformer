package spawn_entities

import cc "../../engine/core/collision_channel/"
import cm "../../engine/core/collision_mesh/"
import cs "../../engine/core/collision_scene/"
import hent "../../engine/core/entity_handle"
import logs "../../engine/core/logs"
import spat "../../engine/core/spatial/"
import gent "../game_entities/"
import hm "core:container/handle_map"

spawn_empty_entity :: proc(ents: ^gent.Game_Entity_Handle_Map) -> hent.Entity_Handle {
	handle := hm.add(ents, gent.Entity{})

	return handle
}

// add_static_mesh_trait :: proc(
// 	ents: ^gent.Game_Entity_Handle_Map,
// 	handle: hent.Entity_Handle,
// 	col_scene: ^cs.Collision_Scene,
// 	data: spat.Collision_Shape,
// ) {
// 	ent: ^gent.Entity = hm.get(ents, handle)
//
// 	assert(ent != nil)
// 	assert(.StaticMesh not_in ent.traits)
//
// 	ent.traits += {.StaticMesh}
//
// 	tris, transform := spat.shape_to_collision_triangles(data)
//
// 	ent.collision_scene_id = spat.add_to_level(
// 		&col_scene.collision_object_map,
// 		&col_scene.spatial_hash_grid,
// 		collision_object_data,
// 	)
// }

add_trait_collision_shape :: proc(
	ents: ^gent.Game_Entity_Handle_Map,
	col_scene: ^cs.Collision_Scene,
	handle: hent.Entity_Handle,
	shape: spat.Shape,
) -> cm.Mesh_Handle {
	col_meshes: ^cm.Collider_Mesh_Context = &col_scene.collision_meshes

	ent: ^gent.Entity = hm.get(ents, handle)
	assert(ent != nil)

	assert(gent.has_traits({.Transform}, ent^)) // not sure I like this

	gent.add_traits_checked({.Collision}, ent)
	ent.collision_component.collision_response = cc.BLOCK_ALL
	assert(shape == .Box) // TODO: Currently only support boxes

	// Assign collision mesh
	box_id := col_meshes.primitive_ids[spat.Shape.Box]
	ent.collision_component.mesh_id = box_id

	// NOTE: This function does not add it to the spatial hash grid, you gotta remember to do that yourself (reconstruct_spatial_hash_grid_from_entities)


	return box_id
}


add_trait_transform :: proc(
	ents: ^gent.Game_Entity_Handle_Map,
	handle: hent.Entity_Handle,
	transform: spat.Transform,
) {
	ent: ^gent.Entity = hm.get(ents, handle)
	assert(ent != nil)

	gent.add_traits_checked({.Transform}, ent)

	ent.transform_component.transform = transform
}

spawn_box :: proc(
	transform: spat.Transform,
	col_scene: ^cs.Collision_Scene,
	ents: ^gent.Game_Entity_Handle_Map,
) -> ^gent.Entity {
	new_ent_handle := spawn_empty_entity(ents)
	new_ent: ^gent.Entity = hm.get(ents, new_ent_handle)

	add_trait_transform(ents, new_ent_handle, transform)
	add_trait_collision_shape(ents, col_scene, new_ent_handle, .Box)

	reconstruct_spatial_hash_grid_from_entities(col_scene, ents)

	return new_ent
}

reconstruct_spatial_hash_grid_from_entities :: proc(
	col_scene: ^cs.Collision_Scene,
	ents: ^gent.Game_Entity_Handle_Map,
) {

	logs.infof(.Editor, "Reconstruct Spatial Hash Grid")
	shg: ^cs.Spatial_Hash_Grid = &col_scene.spatial_hash_grid
	col_ctx: ^cm.Collider_Mesh_Context = &col_scene.collision_meshes
	cs.clear_spatial_hash_grid(shg)

	num_ents_in_shg: i64

	itr := hm.iterator_make(ents)
	for item in hm.iterate(&itr) {
		if !gent.has_traits({.Transform, .Collision}, item^) do return
		num_ents_in_shg += 1

		col_mesh := cm.get_mesh_checked(col_ctx, item.collision_component.mesh_id)
		bound := spat.calculate_bounds_from_tris_transform(
			col_mesh.tris,
			item.transform_component.transform,
		)

		cs.add_to_spatial_hash_grid(shg, item.handle, bound, context.allocator) // TODO: Okay?
	}


	// Validation
	{
		objects_ids: map[hent.Entity_Handle]bool = make(
			map[hent.Entity_Handle]bool,
			context.temp_allocator,
		)
		for key, cell in shg {
			for ent_handle in cell.objects_ids {
				objects_ids[ent_handle] = true
			}
		}

		assert(i64(len(objects_ids)) == num_ents_in_shg)
	}
}
