package serialization
import cm "../engine/core/collision_mesh/"
import cs "../engine/core/collision_scene/"
import logs "../engine/core/logs"
import gent "../game/game_entities/"
import sent "../game/spawn_entities/"
import w "../game/world/"
import wutils "../game/world_utils/"
import "core:io"
import "core:log"
import "core:math/linalg"

import "base:runtime"
import hm "core:container/handle_map"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:testing"

Serial_Entity :: struct {
	handle:    u32,
	// traits:    gent.Traits,
	transform: gent.Transform_Component,
	collision: gent.Collision_Component,
}

Serial_World :: struct {
	ents:                         [dynamic]Serial_Entity,
	author_best_speedrun_capture: w.Speedrun_Capture,
	player_initial_state:         w.Player_Initial_State,
	// collision_scene:              cs.Collision_Scene,
}

serialize_world :: proc(world: ^w.World) -> Serial_World {
	result: Serial_World

	result.author_best_speedrun_capture = world.author_best_speedrun_capture
	result.player_initial_state = world.player_initial_state

	it := hm.iterator_make(&world.entities)
	for ent, handle in hm.iterate(&it) {
		serial_ent := Serial_Entity {
			handle    = u32(handle.idx),
			// traits    = ent.traits,
			transform = ent.transform_component,
			collision = ent.collision_component,
		}
		append(&result.ents, serial_ent)
	}

	// result.collision_scene = world.collision_scene

	return result
}

save_world_to_file :: proc(world: Serial_World, filepath: string) -> bool {
	data, marshal_err := json.marshal(world, {pretty = true})
	assert(marshal_err == nil, fmt.tprint(marshal_err))
	defer delete(data)

	return os.write_entire_file(filepath, data)
}

world_from_serial_world :: proc(serial_world: Serial_World, world: ^w.World) {
	w.world_init(world)
	cm.init(&world.collision_scene.collision_meshes, world.world_allocator)
	cs.init_collision_scene(&world.collision_scene, world.world_allocator)

	world.author_best_speedrun_capture = serial_world.author_best_speedrun_capture
	world.player_initial_state = serial_world.player_initial_state

	ents := &world.entities
	col_scene := &world.collision_scene

	for serial_ent in serial_world.ents {
		new_ent_handle := hm.add(ents, gent.Entity{})
		new_ent: ^gent.Entity = hm.get(ents, new_ent_handle)
		assert(new_ent != nil)

		// new_ent.traits = serial_ent.traits
		new_ent.transform_component = serial_ent.transform
		new_ent.collision_component = serial_ent.collision
		new_ent.handle = new_ent_handle
	}

	sent.reconstruct_spatial_hash_grid_from_entities(col_scene, ents, world.world_allocator)
}

load_serial_world_from_file :: proc(filepath: string) -> (Serial_World, bool) {
	data, ok := os.read_entire_file(filepath)
	if !ok {
		return {}, false
	}
	defer delete(data)

	serial_world: Serial_World
	unmarshal_err := json.unmarshal(data, &serial_world)
	if unmarshal_err != nil {
		return {}, false
	}

	return serial_world, true
}


@(test)
test_world_serial_flow :: proc(t: ^testing.T) {
	// context.logger = logs.init()
	// defer log.destroy_console_logger(context.logger)

	world := new(w.World)
	defer free(world)

	log.warnf("{}", context.logger.data)
	wutils.make_basic_world(world)


	serial_world := serialize_world(world)

	test_filepath :: "test_world_output.json"

	ok := save_world_to_file(serial_world, test_filepath)
	testing.expect(t, ok, "Failed to save world to file")

	loaded_serial_world, load_ok := load_serial_world_from_file(test_filepath)
	testing.expect(t, load_ok, "Failed to load world from file")

	testing.expect(
		t,
		len(serial_world.ents) == len(loaded_serial_world.ents),
		fmt.aprintf(
			"Entity count mismatch: got %d, want %d",
			len(loaded_serial_world.ents),
			len(serial_world.ents),
		),
	)
}
user_serializers: map[typeid]json.User_Marshaler

quat64_marshal :: proc(w: io.Writer, v: any, opt: ^json.Marshal_Options) -> json.Marshal_Error {
	ti := runtime.type_info_base(type_info_of(v.id))
	a := any{v.data, ti.id}
	q := v.(quaternion64)

	json.opt_write_start(w, opt, '[') or_return
	json.opt_write_iteration(w, opt, true) or_return
	io.write_f16(w, real(q))
	json.opt_write_iteration(w, opt, false) or_return
	io.write_f16(w, imag(q))
	json.opt_write_iteration(w, opt, false) or_return
	io.write_f16(w, jmag(q))
	json.opt_write_iteration(w, opt, false) or_return
	io.write_f16(w, kmag(q))
	json.opt_write_end(w, opt, ']') or_return

	return nil
}

setup_user_serializers :: proc() {
	user_serializers[typeid_of(quaternion64)] = quat64_marshal
	json.set_user_marshalers(&user_serializers)
}

@(test)
test_user_serializers :: proc(t: ^testing.T) {
	q64: quaternion64 = linalg.QUATERNIONF16_IDENTITY
	data, err := json.marshal(q64)
	testing.expect(t, err == nil, fmt.tprintf("Error: {}", err))

}
