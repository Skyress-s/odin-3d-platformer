package serialization_types

import gent "../../game/game_entities/"
import gmisc "../../game/misc/"

Serial_Entity :: struct {
	idx:       u32,
	traits:    gent.Traits,
	transform: gent.Transform_Component,
	collision: gent.Collision_Component,
}

Serial_World :: struct {
	ents:                         [dynamic]Serial_Entity,
	name:                         string,
	author_best_speedrun_capture: gmisc.Speedrun_Capture,
	player_initial_state:         gmisc.Player_Initial_State,
	// collision_scene:              cs.Collision_Scene,
}

serial_world_deinit :: proc(serial_world: ^Serial_World) {
	delete(serial_world.name)
	delete(serial_world.ents)
}
