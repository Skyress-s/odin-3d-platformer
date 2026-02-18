package world

import cm "../../core/collision_mesh/"
import cs "../../core/collision_scene/"
import hent "../../core/entity_handle/"
import spat "../../core/spatial/"
import gent "../../game/game_entities/"

Time_Trail_Float :: f64

// Global through entire program
Game :: struct {
	col_meshes: cm.Collider_Mesh_Context, // One per file?

	// Contains global data. Meshes, other stuff
}

Level :: struct {
	player_initial_state: Player_Initial_State,
	author_time:          Time_Trail_Float,
}

// Runtime
World :: struct {
	entities:        gent.Game_Entity_Handle_Map,
	collision_scene: cs.Collision_Scene,
	best_time:       Time_Trail_Float,
}

Player_Initial_State :: struct {
	position, speed, look_direction: spat.Vector,
}
