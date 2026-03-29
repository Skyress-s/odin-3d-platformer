package serialize

import cc "../../engine/core/collision_channel/"
import cm "../../engine/core/collision_mesh/"
import cs "../../engine/core/collision_scene/"
import gent "../../game/game_entities/"
import sent "../../game/spawn_entities/"
import w "../../game/world/"
import serial_types "../serialization_types/"

import "base:runtime"
import hm "core:container/handle_map"
import "core:encoding/json"
import "core:fmt"
import "core:io"
import "core:log"
import "core:math/linalg"
import "core:os"
import fp "core:path/filepath"
import "core:strconv"
import "core:strings"
import "core:testing"

serialize_world :: proc(
	world: ^w.World,
	allocator: runtime.Allocator,
) -> serial_types.Serial_World {
	result: serial_types.Serial_World

	result.ents = make([dynamic]serial_types.Serial_Entity, allocator)

	result.author_best_speedrun_capture = world.author_best_speedrun_capture
	result.player_initial_state = world.player_initial_state

	it := hm.iterator_make(&world.entities)
	for ent, handle in hm.iterate(&it) {
		serial_ent := serial_types.Serial_Entity {
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

world_to_bytes :: proc(world: ^w.World, allocator: runtime.Allocator) -> []byte {
	bytes := serial_world_to_bytes(serialize_world(world, context.temp_allocator), allocator)
	return bytes
}

serial_world_to_bytes :: proc(
	world: serial_types.Serial_World,
	allocator: runtime.Allocator,
) -> []byte {
	init_user_serializers()
	data, marshal_err := json.marshal(world, {pretty = true})
	assert(marshal_err == nil, fmt.tprint(marshal_err))

	return data
}

save_world_to_file :: proc(world: serial_types.Serial_World, filepath: string) -> bool {
	data := serial_world_to_bytes(world, context.allocator)
	defer delete(data)

	return os.write_entire_file(filepath, data) == nil
}

world_from_serial_world :: proc(serial_world: serial_types.Serial_World, world: ^w.World) {
	w.world_init(world)
	world.name = strings.clone(serial_world.name, world.allocator)
	cm.init(&world.collision_scene.collision_meshes, world.allocator)
	cs.init_collision_scene(&world.collision_scene, world.allocator)

	world.author_best_speedrun_capture = serial_world.author_best_speedrun_capture
	world.player_initial_state = serial_world.player_initial_state

	ents := &world.entities
	cs := &world.collision_scene

	for serial_ent in serial_world.ents {
		new_ent_handle := hm.add(ents, gent.Entity{})
		new_ent: ^gent.Entity = hm.get(ents, new_ent_handle)
		assert(new_ent != nil)

		new_ent.traits = serial_ent.traits
		new_ent.transform_component = serial_ent.transform
		new_ent.collision_component = serial_ent.collision
		new_ent.handle = new_ent_handle
	}

	sent.reconstruct_spatial_hash_grid_from_entities(cs, ents, world.allocator)
}

bytes_to_world :: proc(bytes: []byte, world: ^w.World, allocator: runtime.Allocator) -> bool {
	init_user_serializers()
	serial_world: serial_types.Serial_World
	unmarshal_err := json.unmarshal(bytes, &serial_world, json.DEFAULT_SPECIFICATION, allocator)
	if unmarshal_err != nil {
		return false
	}

	world_from_serial_world(serial_world, world)

	return true
}

filename_to_bytes :: proc(filepath: string, allocator: runtime.Allocator) -> ([]byte, os.Error) {
	bytes, err := os.read_entire_file_from_path(filepath, allocator)
	if err != nil {
		return nil, err
	}

	return bytes, nil
}

load_serial_world_from_file :: proc(
	filepath: string,
	allocator := context.temp_allocator,
) -> (
	serial_types.Serial_World,
	bool,
) {
	data, err := os.read_entire_file_from_path(filepath, allocator)
	if err != nil {
		return {}, false
	}
	defer delete(data)

	serial_world: serial_types.Serial_World

	// serial_world.name = strings.clone(filepath[strings.last_index(filepath, "/"):], allocator)
	init_user_serializers()
	unmarshal_err := json.unmarshal(data, &serial_world, json.DEFAULT_SPECIFICATION, allocator)
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
