#+feature dynamic-literals
package serialization

import cc "../core/collision_channel/"
import cm "../core/collision_mesh/"
import cs "../core/collision_scene/"
import hent "../core/entity_handle/"
import spat "../core/spatial"
import gent "../game/game_entities/"
import l "../level"
import "../logs"

import "core:encoding/json"
import "core:fmt"
import os "core:os"


Serializable_Collision_Scene :: struct {
	meshes_ctx: cm.Collider_Mesh_Context,
	shg:        cs.Spatial_Hash_Grid,
}

Serializable_Entities :: struct {
	ent: gent.Entity,
}

Serializable_Level :: struct {
	scene: Serializable_Collision_Scene,
}

@(private)
Level_Serialization_Data :: struct {
	name:                 string,
	// objects:              [dynamic]Serializable_Collision_Object_Data,
	start_position:       spat.Vector,
	start_look_direction: spat.Vector,
	finish_volumes_ids:   [dynamic]hent.Entity_Handle,
	kill_volume_ids:      [dynamic]hent.Entity_Handle,
	grapple_volume_ids:   [dynamic]hent.Entity_Handle,
	author_time:          f64,

	//objects: [dynamic]int,
}

Serializable_Quaternion :: struct {
	components: [4]f32,
}


Serializable_Transform :: distinct struct {
	position: spat.Vector,
	rotation: Serializable_Quaternion,
	scale:    spat.Vector,
}

create_serializable_quaternion :: proc(q: spat.Quaternion) -> Serializable_Quaternion {
	return Serializable_Quaternion{{real(q), imag(q), jmag(q), kmag(q)}}
}

create_serializable_transform :: proc(
	transform: spat.Transform,
) -> (
	s_transform: Serializable_Transform,
) {
	s_transform.position = transform.position
	s_transform.rotation = create_serializable_quaternion(transform.rotation)
	s_transform.scale = transform.scale

	return s_transform
}


serialize_level :: proc(level: l.Level) -> Serializable_Level {

	return {}
}

delete_level_serialization_data :: proc(lsd: ^Level_Serialization_Data) {
	// delete(lsd.name)
	// delete(lsd.objects)

	// Memory in scod is transferred to level
	// for &scod in lsd.objects {
	// 	delete_serializable_collision_object_data(&scod)
	// }
	// delete(lsd.objects)

	// lsd.objects

	delete(lsd.finish_volumes_ids)
	delete(lsd.kill_volume_ids)
	delete(lsd.grapple_volume_ids)
}


// filepath is relative to root of project (where main.odin is)
// save_to_file_level :: proc(level: Serialized_Level, filepath: string) {
// col_scene := &level.collsion_scene
//
// level_serialization_data := Level_Serialization_Data {
// 	name                 = level.name,
// 	//object {1, 6, 3, 43534, 7, 3, 4, 454, 0},
// 	start_position       = level.start_position,
// 	start_look_direction = level.start_look_direction,
// 	author_time          = level.author_time,
// }
// defer delete_level_serialization_data(&level_serialization_data)
//
/*
	collision_channels: u16,
	tris:               [dynamic]Collision_Triangle,
	*/
// Could not get the iter to work, a but perhaps?
// for &i in col_scene.collision_object_map.items {
// 	if hms.skip(i) do continue
//
// 	rot := i.transform.rotation
//
// 	serializable_transform := Serializable_Transform {
// 		position = i.transform.position,
// 		// rotation = transmute([4]f32)i.transform.rotation,
// 		rotation = {real(rot), imag(rot), jmag(rot), kmag(rot)},
// 		scale    = i.transform.scale,
// 	}
//
// 	append_elem(
// 		&level_serialization_data.objects,
// 		Serializable_Collision_Object_Data {
// 			collision_channels = transmute(cc.Response_Size)i.collision_channels,
// 			transform = serializable_transform,
// 			tris = i.tris,
// 			id = i.handle,
// 		},
// 	)
// }


// data, err := json.marshal(level_serialization_data, {pretty = true})
// defer delete(data)
// assert(err == nil, fmt.tprint("Json save_to_file_level() error: ", err))
//
// // data_as_string := "ops"
// // data_as_bytes := transmute([]byte)(data_as_string) // 'transmute' casts our string to a byte array
// os.write_entire_file(filepath, data)
// }

load_from_file_level :: proc(filepath: string) -> (loaded_level: l.Level) {
	// data, success := os.read_entire_file(filepath)
	// defer delete(data)
	//
	// assert(
	// 	success == true,
	// 	fmt.aprint(
	// 		"load_from_file_level() failed, filepath does not point to existing file?: ",
	// 		filepath,
	// 	),
	// )
	// loaded_serialized_level_data: Level_Serialization_Data
	// defer delete_level_serialization_data(&loaded_serialized_level_data)
	//
	// err := json.unmarshal(data, &loaded_serialized_level_data)
	// assert(err == nil, fmt.aprint(err))
	//
	//
	// loaded_level.name = loaded_serialized_level_data.name
	// loaded_level.start_position = loaded_serialized_level_data.start_position
	// loaded_level.start_look_direction = loaded_serialized_level_data.start_look_direction
	//
	// // In case somebody loads an old level (author_time will be laoded as 0)
	//
	// for &obj in loaded_serialized_level_data.objects {
	// 	// new_loaded_rotation :spat.Quaternion= spat.Quaternion{x = obj.transform.rotation.x, y = obj.transform.rotation.y, z = obj.transform.rotation.z, w = obj.transform.rotation.w}
	// 	loaded_rot := obj.transform.rotation
	// 	new_loaded_rotation: spat.Quaternion = quaternion(
	// 		real = loaded_rot.x,
	// 		imag = loaded_rot.y,
	// 		jmag = loaded_rot.z,
	// 		kmag = loaded_rot.w,
	// 	)
	// 	new_loaded_transform := spat.Transform {
	// 		position = obj.transform.position,
	// 		rotation = new_loaded_rotation,
	// 		scale    = obj.transform.scale,
	// 	}
	// 	new_loaded_object := spat.Collision_Object_Data {
	// 		collision_channels = transmute(cc.Responses)obj.collision_channels,
	// 		transform          = new_loaded_transform,
	// 		tris               = obj.tris,
	// 	}
	//
	//
	// 	new_id := spat.add_to_level(
	// 		&loaded_level.collsion_scene.collision_object_map,
	// 		&loaded_level.collsion_scene.spatial_hash_grid,
	// 		new_loaded_object,
	// 	)
	//
	//
	// 	add_to_identifier_array_if_exists :: proc(
	// 		old_arr: ^[dynamic]spat.hent.Entity_Handle,
	// 		target_map: ^map[spat.hent.Entity_Handle]bool,
	// 		old_id, new_id: spat.hent.Entity_Handle,
	// 	) {
	// 		for id in old_arr^ {
	// 			if id == old_id {
	// 				target_map[new_id] = true
	// 				break
	// 			}
	// 		}
	// 	}
	// 	collision_scene := &loaded_level.collsion_scene
	// 	add_to_identifier_array_if_exists(
	// 		&loaded_serialized_level_data.finish_volumes_ids,
	// 		&collision_scene.finish_volumes,
	// 		obj.id,
	// 		new_id,
	// 	)
	// 	add_to_identifier_array_if_exists(
	// 		&loaded_serialized_level_data.kill_volume_ids,
	// 		&collision_scene.kill_volumes,
	// 		obj.id,
	// 		new_id,
	// 	)
	// 	add_to_identifier_array_if_exists(
	// 		&loaded_serialized_level_data.grapple_volume_ids,
	// 		&collision_scene.grappable,
	// 		obj.id,
	// 		new_id,
	// 	)
	//
	//
	// 	// spat.create_and_add_collision_object_from_tris(
	// 	// 	&loaded_level.collision_object_map,
	// 	// 	&loaded_level.spatial_hash_grid,
	// 	// 	obj.tris,
	// 	// 	cc.is_blocking(obj.collision_channels),
	// 	// )
	// }
	//
	// logs.infof(.Serialization, "success loading level at path: {}", filepath)
	//
	return loaded_level

}

// save_to_file :: proc {
// 	save_to_file_level,
// }
