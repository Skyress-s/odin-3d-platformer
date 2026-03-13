package serialization
import cc "../engine/core/collision_channel/"
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
	idx:       u32,
	traits:    gent.Traits,
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
			idx       = u32(handle.idx),
			traits    = ent.traits,
			transform = ent.transform_component,
			collision = ent.collision_component,
		}
		append(&result.ents, serial_ent)
	}

	// result.collision_scene = world.collision_scene

	return result
}

save_world_to_file :: proc(world: Serial_World, filepath: string) -> bool {
	init_user_serializers()
	data, marshal_err := json.marshal(world, {pretty = true})
	assert(marshal_err == nil, fmt.tprint(marshal_err))
	defer delete(data)

	return os.write_entire_file(filepath, data) == nil
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

		new_ent.traits = serial_ent.traits
		new_ent.transform_component = serial_ent.transform
		new_ent.collision_component = serial_ent.collision
		new_ent.handle = new_ent_handle
	}

	sent.reconstruct_spatial_hash_grid_from_entities(col_scene, ents, world.world_allocator)
}

load_serial_world_from_file :: proc(filepath: string) -> (Serial_World, bool) {
	init_user_serializers()
	data, err := os.read_entire_file_from_path(filepath, context.allocator)
	if err != nil {
		return {}, false
	}
	defer delete(data)

	serial_world: Serial_World
	unmarshal_err := json.unmarshal(
		data,
		&serial_world,
		json.DEFAULT_SPECIFICATION,
		context.temp_allocator,
	)
	if unmarshal_err != nil {
		return {}, false
	}

	return serial_world, true
}


@(private)
user_un_marshalers_initialized: bool
user_marshalers: map[typeid]json.User_Marshaler
user_unmarshalers: map[typeid]json.User_Unmarshaler

marshal_cc_responses :: proc(
	w: io.Writer,
	v: any,
	opt: ^json.Marshal_Options,
) -> json.Marshal_Error {

	ti := runtime.type_info_base(type_info_of(v.id))
	a := any{v.data, ti.id}
	responses := v.(cc.Responses)

	io.write_i64(w, i64(responses))

	return {}
}

unmarshal_cc_responses :: proc(p: ^json.Parser, v: any) -> json.Unmarshal_Error {
	responses := cast(^cc.Responses)v.data

	token, token_err := json.advance_token(p)
	i, ok := strconv.parse_i64(token.text)
	if !ok do return json.Unsupported_Type_Error{}

	// value = Integer(i)
	responses^ = cc.Responses(i)

	return {}
}

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
quat128_marshal :: proc(w: io.Writer, v: any, opt: ^json.Marshal_Options) -> json.Marshal_Error {
	ti := runtime.type_info_base(type_info_of(v.id))
	a := any{v.data, ti.id}
	q := v.(quaternion128)

	json.opt_write_start(w, opt, '[') or_return
	json.opt_write_iteration(w, opt, true) or_return
	io.write_f32(w, real(q))
	json.opt_write_iteration(w, opt, false) or_return
	io.write_f32(w, imag(q))
	json.opt_write_iteration(w, opt, false) or_return
	io.write_f32(w, jmag(q))
	json.opt_write_iteration(w, opt, false) or_return
	io.write_f32(w, kmag(q))
	json.opt_write_end(w, opt, ']') or_return

	return nil
}
quat256_marshal :: proc(w: io.Writer, v: any, opt: ^json.Marshal_Options) -> json.Marshal_Error {
	ti := runtime.type_info_base(type_info_of(v.id))
	a := any{v.data, ti.id}
	q := v.(quaternion256)

	json.opt_write_start(w, opt, '[') or_return
	json.opt_write_iteration(w, opt, true) or_return
	io.write_f64(w, real(q))
	json.opt_write_iteration(w, opt, false) or_return
	io.write_f64(w, imag(q))
	json.opt_write_iteration(w, opt, false) or_return
	io.write_f64(w, jmag(q))
	json.opt_write_iteration(w, opt, false) or_return
	io.write_f64(w, kmag(q))
	json.opt_write_end(w, opt, ']') or_return

	return nil
}

quat64_unmarshal :: proc(p: ^json.Parser, v: any) -> json.Unmarshal_Error {
	q := cast(^quaternion64)v.data
	json.expect_token(p, .Open_Bracket)

	token, token_err := json.advance_token(p)
	r, _ := strconv.parse_f32(token.text)

	json.expect_token(p, .Comma)

	token, token_err = json.advance_token(p)
	i, _ := strconv.parse_f32(token.text)

	json.expect_token(p, .Comma)

	token, token_err = json.advance_token(p)
	j, _ := strconv.parse_f32(token.text)

	json.expect_token(p, .Comma)

	token, token_err = json.advance_token(p)
	k, _ := strconv.parse_f32(token.text)

	json.expect_token(p, .Close_Bracket)
	q^ = quaternion(real = r, imag = i, jmag = j, kmag = k)

	return {}
}
quat128_unmarshal :: proc(p: ^json.Parser, v: any) -> json.Unmarshal_Error {
	// q := v.(quaternion64)
	q := cast(^quaternion128)v.data
	json.expect_token(p, .Open_Bracket)

	token, token_err := json.advance_token(p)
	r, _ := strconv.parse_f32(token.text)

	json.expect_token(p, .Comma)

	token, token_err = json.advance_token(p)
	i, _ := strconv.parse_f32(token.text)

	json.expect_token(p, .Comma)

	token, token_err = json.advance_token(p)
	j, _ := strconv.parse_f32(token.text)

	json.expect_token(p, .Comma)

	token, token_err = json.advance_token(p)
	k, _ := strconv.parse_f32(token.text)

	json.expect_token(p, .Close_Bracket)
	q^ = quaternion(real = r, imag = i, jmag = j, kmag = k)

	return {}
}
quat256_unmarshal :: proc(p: ^json.Parser, v: any) -> json.Unmarshal_Error {
	// q := v.(quaternion64)
	q := cast(^quaternion256)v.data
	json.expect_token(p, .Open_Bracket)

	token, token_err := json.advance_token(p)
	r, _ := strconv.parse_f64(token.text)

	json.expect_token(p, .Comma)

	token, token_err = json.advance_token(p)
	i, _ := strconv.parse_f64(token.text)

	json.expect_token(p, .Comma)

	token, token_err = json.advance_token(p)
	j, _ := strconv.parse_f64(token.text)

	json.expect_token(p, .Comma)

	token, token_err = json.advance_token(p)
	k, _ := strconv.parse_f64(token.text)

	json.expect_token(p, .Close_Bracket)
	q^ = quaternion(real = r, imag = i, jmag = j, kmag = k)

	return {}
}


init_user_serializers :: proc() {
	if user_un_marshalers_initialized do return
	user_un_marshalers_initialized = true

	if json._user_marshalers == nil {
		user_marshalers[typeid_of(quaternion64)] = quat64_marshal
		user_marshalers[typeid_of(quaternion128)] = quat128_marshal
		user_marshalers[typeid_of(quaternion256)] = quat256_marshal
		user_marshalers[typeid_of(cc.Responses)] = marshal_cc_responses
		json.set_user_marshalers(&user_marshalers)

	}
	if json._user_unmarshalers == nil {
		user_unmarshalers[typeid_of(quaternion64)] = quat64_unmarshal
		user_unmarshalers[typeid_of(quaternion128)] = quat128_unmarshal
		user_unmarshalers[typeid_of(quaternion256)] = quat256_unmarshal
		user_unmarshalers[typeid_of(cc.Responses)] = unmarshal_cc_responses
		json.set_user_unmarshalers(&user_unmarshalers)
	}
}

denit_user_serializers :: proc() {
	delete(user_marshalers)
	delete(user_unmarshalers)
	json._user_marshalers = nil
	json._user_unmarshalers = nil
}

// @(deferred_none = denit_user_serializers)
// scoped_user_serializers :: proc() {
// 	init_user_serializers()
// }


@(test)
test_user_serializers :: proc(t: ^testing.T) {
	init_user_serializers()

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
	init_user_serializers()

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
			"Serial World Mismatch: Entity count: got %d, want %d",
			len(loaded_serial_world.ents),
			len(serial_world.ents),
		),
	)

	loaded_world := new(w.World)
	defer free(loaded_world)
	world_from_serial_world(loaded_serial_world, loaded_world)


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
