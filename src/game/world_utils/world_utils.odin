package world_utils
import cm "../../engine/core/collision_mesh/"
import cs "../../engine/core/collision_scene"
import csq "../../engine/core/collision_scene/query/"
import spat "../../engine/core/spatial/"
import gent "../game_entities/"
import sent "../spawn_entities/"
import "core:strings"

import w "../world/"

reload_world :: proc(world_session: ^w.World_Session) {
	w.world_deinit(world_session.world)


}

make_basic_world :: proc(world: ^w.World) {
	w.world_init(world)
	cm.init(&world.collision_scene.collision_meshes, world.allocator)
	cs.init_collision_scene(&world.collision_scene, world.allocator)
	ents := &world.entities

	world.name = strings.clone("basic world", world.allocator)

	ent1 := sent.spawn_box(
		{
			position = spat.ONE_VEC3 * 5,
			rotation = spat.QUATERNION_IDENTITY,
			scale = spat.ONE_VEC3 * 4,
		},
		&world.collision_scene,
		&world.entities,
		world.allocator,
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
		world.allocator,
	)

	sent.reconstruct_spatial_hash_grid_from_entities(
		&world.collision_scene,
		&world.entities,
		world.allocator,
	)

	csq.shg_valid_checked(world.entities, world.collision_scene.spatial_hash_grid)
}
