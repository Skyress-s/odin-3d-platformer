package world

import cm "../../core/collision_mesh/"
import cs "../../core/collision_scene/"
import hent "../../core/entity_handle/"
import spat "../../core/spatial/"
import gent "../../game/game_entities/"
import "core:fmt"

import mem "core:mem"
import vmem "core:mem/virtual"

Time_Trail_Float :: f64

// Global through entire program
Game :: struct {
	world: ^World,
	// Contains global data. Meshes, other stuff
}


Level :: struct {
	player_initial_state:         Player_Initial_State,
	author_best_speedrun_capture: Speedrun_Capture,
	entities:                     gent.Game_Entity_Handle_Map,
}

// Runtime
World :: struct {
	collision_scene:  ^cs.Collision_Scene,
	col_meshes:       ^cm.Collider_Mesh_Context, // One per file?
	level:            ^Level,
	speedrun_capture: Speedrun_Capture,

	// all world allocations are tied to this
	allocator:        mem.Allocator,
	arena:            vmem.Arena,
}

init :: proc(world: ^World) {
	arena_err := vmem.arena_init_growing(&world.arena)
	assert(arena_err == nil, fmt.tprint(arena_err))
	world.allocator = vmem.arena_allocator(&world.arena)
}

deinit :: proc(world: ^World) {
	vmem.arena_destroy(&world.arena)
}

Player_Initial_State :: struct {
	position, speed, look_direction: spat.Vector,
}

Speedrun_Capture :: struct {
	time: Time_Trail_Float,
}
