package world_utils
import cm "../../engine/core/collision_mesh/"
import csq "../../engine/core/collision_scene/query/"
import spat "../../engine/core/spatial/"
import gent "../game_entities/"
import sent "../spawn_entities/"

import w "../world/"


make_basic_world :: proc(world: ^w.World) {
	w.world_init(world)
	cm.init(&world.collision_scene.collision_meshes, world.world_allocator)
	ents := &world.entities

	ent1 := sent.spawn_box(
		{
			position = spat.ONE_VEC3 * 5,
			rotation = spat.QUATERNION_IDENTITY,
			scale = spat.ONE_VEC3 * 4,
		},
		&world.collision_scene,
		&world.entities,
		world.world_allocator,
	)
	gent.add_traits_checked({.Grabable}, ent1)

	sent.spawn_box(
		{
			position = -spat.UP_VEC3 * 8,
			rotation = spat.QUATERNION_IDENTITY,
			scale = spat.ONE_VEC3 + spat.Vector{1, 0, 1} * 8,
		},
		&world.collision_scene,
		&world.entities,
		world.world_allocator,
	)

	sent.reconstruct_spatial_hash_grid_from_entities(
		&world.collision_scene,
		&world.entities,
		world.world_allocator,
	)

	csq.shg_valid_checked(world.entities, world.collision_scene.spatial_hash_grid)
}
