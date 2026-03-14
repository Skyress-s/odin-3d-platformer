package test_serialize

import hm "core:container/handle_map"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:testing"

import p "../"
import cc "../../../engine/core/collision_channel/"
import gent "../../../game/game_entities/"
import w "../../../game/world/"
import wutils "../../../game/world_utils/"

@(test)
test_user_serializers :: proc(t: ^testing.T) {
	p.init_user_serializers()
	test_quat :: proc($T: typeid, t: ^testing.T) {
		q: T = quaternion(real = 1.123, imag = 2.234, jmag = 3.345, kmag = .456)
		data, marshal_err := json.marshal(q)
		testing.expect(t, marshal_err == nil, fmt.tprintf("Error: {}", marshal_err))

		q2: T
		unmarshal_err := json.unmarshal(data, &q2)
		testing.expect(t, unmarshal_err == nil, fmt.tprintf("Error: {}", unmarshal_err))

		testing.expect(t, q == q2, fmt.tprintf("{} != {}", q, q2))

	}

	test_cc_responses :: proc(t: ^testing.T) {
		respones1 := cc.Responses{}
		respones1.player = cc.BLOCK

		data, marshal_err := json.marshal(respones1)
		testing.expect(t, marshal_err == nil, fmt.tprint(marshal_err))

		respones2: cc.Responses
		unmarshal_err := json.unmarshal(data, &respones2)
		testing.expect(t, unmarshal_err == nil, fmt.tprint(unmarshal_err))

		testing.expect(t, respones1 == respones2, fmt.tprintf("{} != {}", respones1, respones2))
	}

	test_quat(quaternion64, t)
	test_quat(quaternion128, t)
	test_quat(quaternion256, t)
	test_cc_responses(t)


	free_all(context.temp_allocator)


	// log.infof("---------------- ")
	// log.infof("{}", string(data))
	// log.infof("---------------- {} | {}", q64, q64_2)
}

@(test)
test_world_serial_flow :: proc(t: ^testing.T) {
	p.init_user_serializers()

	world := new(w.World)
	defer free(world)

	log.warnf("{}", context.logger.data)
	wutils.make_basic_world(world)


	serial_world := p.serialize_world(world, context.allocator)

	test_filepath :: "test_world_output.json"

	ok := p.save_world_to_file(serial_world, test_filepath)
	testing.expect(t, ok, "Failed to save world to file")

	loaded_serial_world, load_ok := p.load_serial_world_from_file(test_filepath)
	testing.expect(t, load_ok, "Failed to load world from file")

	testing.expect(
		t,
		len(serial_world.ents) == len(loaded_serial_world.ents),
		fmt.aprintf(
			"Serial World Mismatch: Entity count: got %d, want %d",
			len(loaded_serial_world.ents),
			len(serial_world.ents),
		),
	)

	loaded_world := new(w.World)
	defer free(loaded_world)
	p.world_from_serial_world(loaded_serial_world, loaded_world)


	testing.expect(
		t,
		world.player_initial_state == loaded_world.player_initial_state,
		fmt.aprintf(
			"Player Initial State Mismatch got {}, want {}",
			world.player_initial_state,
			loaded_world.player_initial_state,
		),
	)

	test_propety :: proc(t: ^testing.T, T1, T2: $T) {
		testing.expect(t, T1 == T2, fmt.tprintf("{} != {}", T1, T2))

	}

	itr := hm.iterator_make(&world.entities)
	for entity_ptr, i in hm.iterate(&itr) {
		entity: gent.Entity = entity_ptr^
		loaded_entity := loaded_world.entities.items[i.idx]

		test_propety(t, entity.traits, loaded_entity.traits)
		test_propety(t, entity.collision_component, loaded_entity.collision_component)
		test_propety(t, entity.transform_component, loaded_entity.transform_component)
	}
}
