#+feature dynamic-literals
package serialization

import cc "../Physics/collision_channel"
import spat "../Spatial"
import l "../level"
import "core:math"
import "core:math/linalg"

import "core:encoding/json"
import "core:fmt"
import os "core:os"

import hms "../handle_map/handle_map_static"

// Can be null, since we dont have the #no_nil tag
Result :: distinct struct {
	reason: string,
}


Result_Union :: union {
	Result,
}

Serializable_Transform :: struct {
	position, scale: spat.Vector,
	rotation:        [4]f32,
}

Serializable_Collision_Object_Data :: distinct struct {
	collision_channels: u16,
	transform:          Serializable_Transform,
	tris:               [dynamic]spat.Collision_Triangle, // TODO into its own blob?
}

@(private)
Level_Serialization_Data :: struct {
	name:                 string,
	objects:              [dynamic]Serializable_Collision_Object_Data,
	start_position:       spat.Vector,
	start_look_direction: spat.Vector,
	finish_volumes_ids:[dynamic]spat.Collision_Object_Id


	//objects: [dynamic]int,
}

// filepath is relative to root of project (where main.odin is)
save_to_file_level :: proc(level: ^l.Level, filepath: string) {
	level_serialization_data := Level_Serialization_Data {
		name                 = level.name,
		//object {1, 6, 3, 43534, 7, 3, 4, 454, 0},
		start_position       = level.start_position,
		start_look_direction = level.start_look_direction,
	}

	for id in level.finish_volumes{
		append_elem(&level_serialization_data.finish_volumes_ids, id)
	}
	/*
	collision_channels: u16,
	tris:               [dynamic]Collision_Triangle,
	*/
	// Could not get the iter to work, a but perhaps?
	for &i in level.collision_object_map.items {
		if hms.skip(i) do continue

		rot := i.transform.rotation

		serializable_transform := Serializable_Transform {
			position = i.transform.position,
			// rotation = transmute([4]f32)i.transform.rotation,
			rotation = {real(rot), imag(rot), jmag(rot), kmag(rot)},
			scale    = i.transform.scale,
		}
		fmt.println("rot to save: ", serializable_transform.rotation)

		append_elem(
			&level_serialization_data.objects,
			Serializable_Collision_Object_Data {
				collision_channels = i.collision_channels,
				transform = serializable_transform,
				tris = i.tris,
			},
		)
	}


	data, err := json.marshal(level_serialization_data, {pretty = true})
	assert(err == nil, fmt.aprint("Json save_to_file_level() error: ", err))

	// data_as_string := "ops"
	// data_as_bytes := transmute([]byte)(data_as_string) // 'transmute' casts our string to a byte array
	os.write_entire_file(filepath, data)
}

load_from_file_level :: proc(filepath: string) -> (loaded_level: l.Level) {
	data, success := os.read_entire_file(filepath)
	assert(
		success == true,
		fmt.aprint(
			"load_from_file_level() failed, filepath does not point to existing file?: ",
			filepath,
		),
	)
	loaded_serialized_level_data: Level_Serialization_Data

	err := json.unmarshal(data, &loaded_serialized_level_data)
	assert(err == nil, fmt.aprint(err))


	loaded_level.name = loaded_serialized_level_data.name
	loaded_level.start_position = loaded_serialized_level_data.start_position
	loaded_level.start_look_direction = loaded_serialized_level_data.start_look_direction

	for &id in loaded_serialized_level_data.finish_volumes_ids{
		loaded_level.finish_volumes[id] = true
	}

	for &obj in loaded_serialized_level_data.objects {
		fmt.println("loading new object")
		// new_loaded_rotation :spat.Quaternion= spat.Quaternion{x = obj.transform.rotation.x, y = obj.transform.rotation.y, z = obj.transform.rotation.z, w = obj.transform.rotation.w}
		loaded_rot:=obj.transform.rotation
		new_loaded_rotation: spat.Quaternion = quaternion(real = loaded_rot.x, imag = loaded_rot.y, jmag = loaded_rot.z, kmag = loaded_rot.w)
		new_loaded_transform := spat.Transform {
			position = obj.transform.position,
			rotation = new_loaded_rotation,
			scale    = obj.transform.scale,
		}
		new_loaded_object := spat.Collision_Object_Data {
			collision_channels = obj.collision_channels,
			transform          = new_loaded_transform,
			tris               = obj.tris,
		}


		fmt.println("adding to new level")
		spat.add_to_level(
			&loaded_level.collision_object_map,
			&loaded_level.spatial_hash_grid,
			new_loaded_object,
		)


		// spat.create_and_add_collision_object_from_tris(
		// 	&loaded_level.collision_object_map,
		// 	&loaded_level.spatial_hash_grid,
		// 	obj.tris,
		// 	cc.is_blocking(obj.collision_channels),
		// )
	}

	fmt.println("success loading level at path: ", filepath)

	return loaded_level
}

save_to_file :: proc {
	save_to_file_level,
}
