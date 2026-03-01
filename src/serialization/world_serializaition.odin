package serialization
import cs "../engine/core/collision_scene/"
import gent "../game/game_entities/"
import w "../game/world/"

import "core:encoding/json"

Serial_Entity :: struct {
	handle:    u16,
	traits:    gent.Traits,
	transform: gent.Transform_Component,
	collision: gent.Collision_Component,
}

Serial_World :: struct {
	ents:                         [dynamic]Serial_Entity,
	collision_scene:              cs.Collision_Scene, // Reset between speedruns
	author_best_speedrun_capture: w.Speedrun_Capture,
	player_initial_state:         w.Player_Initial_State,
}

serialize_world :: proc(world: w.World) -> Serial_World {
	return {}
}
