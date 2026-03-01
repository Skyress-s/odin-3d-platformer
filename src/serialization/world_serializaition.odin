package serialization
import cs "../engine/core/collision_scene/"
import hent "../engine/core/entity_handle/"
import spat "../engine/core/spatial/"
import gent "../game/game_entities/"
import w "../game/world/"
import wutils "../game/world_utils/"

import hm "core:container/handle_map"
import "core:encoding/json"
import "core:os"
import "core:testing"

Serial_Entity :: struct {
	handle:    u32,
	traits:    gent.Traits,
	transform: gent.Transform_Component,
	collision: gent.Collision_Component,
}

Serial_World :: struct {
	ents:                         [dynamic]Serial_Entity,
	collision_scene:              cs.Collision_Scene,
	author_best_speedrun_capture: w.Speedrun_Capture,
	player_initial_state:         w.Player_Initial_State,
}

serialize_world :: proc(world: ^w.World) -> Serial_World {
	result: Serial_World

	result.collision_scene = world.collision_scene
	result.author_best_speedrun_capture = world.author_best_speedrun_capture
	result.player_initial_state = world.player_initial_state

	it := hm.iterator_make(&world.entities)
	for ent, handle in hm.iterate(&it) {
		serial_ent := Serial_Entity {
			handle    = u32(handle.idx),
			traits    = ent.traits,
			transform = ent.transform_component,
			collision = ent.collision_component,
		}
		append(&result.ents, serial_ent)
	}

	return result
}

save_world_to_file :: proc(world: Serial_World, filepath: string) -> bool {
	data, marshal_err := json.marshal(world, {pretty = true})
	if marshal_err != nil {
		return false
	}
	defer delete(data)

	return os.write_entire_file(filepath, data)
}

world_from_serial_world :: proc(serial_world: Serial_World, world: ^w.World) {

}

load_serial_world_from_file :: proc(filepath: string) -> Serial_World {

}


@(test)
test_world_serial_from :: proc(t: ^testing.T) {
	world := w.World{}
	wutils.make_basic_world(&world)
	defer w.world_deinit(&world)

	// Serialize
	// Save to file

	// Load from file (Serial_World)
	// Build world based on Serial_Entity

	// Assert that data is equal from before and after the load.
	// NOTE: All data won't be equal, the generation is expected to change.
}
