package level

import cm "../engine/core/collision_mesh/"
import cs "../engine/core/collision_scene/"
import spat "../engine/core/spatial"
import gent "../game/game_entities/"

Level :: distinct struct {
	name:                 string,
	collsion_scene:       cs.Collision_Scene,
	entities:             gent.Game_Entity_Handle_Map,


	// Player Start
	start_position:       spat.Vector,
	start_look_direction: spat.Vector,
	start_velocity:       spat.Vector,

	// Stats
	author_time:          f64,
}

delete_level :: proc(l: ^Level) {
	delete(l.name)
	cs.deinit_collision_scene(&l.collsion_scene)
	cm.deinit(&l.collsion_scene.collision_meshes)
	// cm.deinit(l.)

	// col_scene.delete_collision_scene(&l.collsion_scene)
}
