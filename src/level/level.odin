package level

import spat "../Spatial"
import gent "../game/game_entities/"

Level :: distinct struct {
	name:                 string,
	collsion_scene:       spat.Collision_Scene,
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

	spat.delete_collision_scene(&l.collsion_scene)

}
