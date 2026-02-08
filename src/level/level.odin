package level

import spat "../Spatial"

Level :: distinct struct {
	name:                                                 string,
	collsion_scene:                                       spat.Collision_Scene,


	// Player Start
	start_position, start_look_direction, start_velocity: spat.Vector,

	// Stats
	author_time:                                          f64,
}

delete_level :: proc(l: ^Level) {
	delete(l.name)

	spat.delete_collision_scene(&l.collsion_scene)

}
