package spawn_entities

import cs "../../core/collision_scene/"
import hent "../../core/entity_handle"
import spat "../../core/spatial/"
import gent "../game_entities/"
import hm "core:container/handle_map"

spawn_empty_entity :: proc(ents: ^gent.Game_Entity_Handle_Map) -> hent.Entity_Handle {
	handle := hm.add(ents, gent.Entity{})

	return handle
}

add_static_mesh_trait :: proc(
	ents: ^gent.Game_Entity_Handle_Map,
	handle: hent.Entity_Handle,
	col_scene: ^cs.Collision_Scene,
	data: spat.Collision_Shape,
) {
	ent: ^gent.Entity = hm.get(ents, handle)

	assert(ent != nil)
	assert(.StaticMesh not_in ent.traits)

	ent.traits += {.StaticMesh}

	tris, transform := spat.shape_to_collision_triangles(data)

	ent.collision_scene_id = spat.add_to_level(
		&col_scene.collision_object_map,
		&col_scene.spatial_hash_grid,
		collision_object_data,
	)
}
