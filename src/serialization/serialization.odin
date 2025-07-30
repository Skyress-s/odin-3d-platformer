#+feature dynamic-literals
package serialization

import spat "../Spatial"
import l "../level"

import "core:encoding/json"
import "core:fmt"
import os "core:os"

// Can be null, since we dont have the #no_nil tag
Result :: distinct struct {
	reason: string,
}


Result_Union :: union {
	Result,
}

@(private)
Level_Serialization_Data :: struct {
	name:    string,
	//objects: [dynamic]spat.Collision_Object_Data,
	objects: [dynamic]int,
}

// filepath is relative to root of project (where main.odin is)
save_to_file_level :: proc(level: ^l.Level, filepath: string) {
	level_serialization_data := Level_Serialization_Data {
		level.name,
		{1, 6, 3, 43534, 7, 3, 4, 454, 0},
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

	json.unmarshal(data, &loaded_level)

	return loaded_level
}

save_to_file :: proc {
	save_to_file_level,
}
