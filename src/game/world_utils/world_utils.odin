package world_utils
import "core:strings"

import cm "../../engine/core/collision_mesh/"
import cs "../../engine/core/collision_scene"
import csq "../../engine/core/collision_scene/query/"
import logs "../../engine/core/logs/"
import spat "../../engine/core/spatial/"
import serial "../../serialization/serialize/"
import gent "../game_entities/"
import sent "../spawn_entities/"
import w "../world/"

reload_world :: proc(world_session: ^w.World_Session) {
	logs.infof(.Gamelogic, "Realoading World")

	if (world_session.world != nil) {
		w.world_deinit(world_session.world)
		free(world_session.world)
		world_session.world = nil
	}

	new_world := new(w.World)
	// w.world_init(new_world)

	serial.bytes_to_world(world_session.last_loaded_world, new_world, context.temp_allocator)

	world_session.world = new_world
}

// External memory?
world_goto_next_level :: proc(world_session: ^w.World_Session, world: ^w.World) {
	w.world_deinit(world_session.world)

	free(world_session.world)

	world_session.world = world
	// load level
	// assign it
	// remove unused colmeshes
	// recalc shg
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
