package spawn_entities

import cc "../../core/collision_channel/"
import cm "../../core/collision_mesh/"
import cs "../../core/collision_scene/"
import hent "../../core/entity_handle"
import spat "../../core/spatial/"
import l "../../level/"
import logs "../../logs"
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
	level: ^l.Level,
	handle: hent.Entity_Handle,
	shape: spat.Shape,
) -> cm.Mesh_Handle {
	ents: ^gent.Game_Entity_Handle_Map = &level.entities
	col_scene: ^cs.Collision_Scene = &level.collsion_scene
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


	// Add to collision structure

	col_mesh: ^cm.Mesh = hm.get(&col_meshes.mesh_map, ent.collision_component.mesh_id)
	assert(col_mesh != nil)

	bounds := spat.calculate_bounds_from_tris_transform(
		col_mesh.tris,
		ent.transform_component.transform,
	)
	cs.add_to_spatial_hash_grid(&level.collsion_scene.spatial_hash_grid, handle, bounds)

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
