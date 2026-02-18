package serialization

import "core:encoding/json"
import "core:fmt"
import "core:math/linalg"
import "core:os"

import col_mesh "../core/collision_mesh"
import col_scene "../core/collision_scene"
import spat "../core/spatial"
import gent "../game/game_entities"
import l "../level"
import hm "core:container/handle_map"

Level_JSON :: struct {
	Name:                 string,
	Start_Position:       [3]f32,
	Start_Look_Direction: [3]f32,
	Start_Velocity:       [3]f32,
	Author_Time:          f64,
	Entities:             []Entity_JSON,
}

Entity_JSON :: struct {
	Position:         [3]f32,
	Rotation:         [4]f32,
	Scale:            [3]f32,
	Mesh_Type:        string,
	Trait_StaticMesh: bool,
	Trait_Collision:  bool,
	Trait_Finish:     bool,
	Trait_Kill:       bool,
	Trait_Grabable:   bool,
}

serialize_level :: proc(level: ^l.Level) -> (data: string, ok: bool) {
	entities := make([dynamic]Entity_JSON, 0)

	itr := hm.iterator_make(&level.entities)
	for ent in hm.iterate(&itr) {
		mesh_type := "Box"
		if ent.collision_component.mesh_id ==
		   level.collsion_scene.collision_meshes.primitive_ids[spat.Shape.Sphere] {
			mesh_type = "Sphere"
		} else if ent.collision_component.mesh_id ==
		   level.collsion_scene.collision_meshes.primitive_ids[spat.Shape.Cylinder] {
			mesh_type = "Cylinder"
		}

		entity_json := Entity_JSON {
			Position         = ent.transform_component.transform.position,
			Rotation         = {
				ent.transform_component.transform.rotation.x,
				ent.transform_component.transform.rotation.y,
				ent.transform_component.transform.rotation.z,
				ent.transform_component.transform.rotation.w,
			},
			Scale            = {
				ent.transform_component.transform.scale.x,
				ent.transform_component.transform.scale.y,
				ent.transform_component.transform.scale.z,
			},
			Mesh_Type        = mesh_type,
			Trait_StaticMesh = .StaticMesh in ent.traits,
			Trait_Collision  = .Collision in ent.traits,
			Trait_Finish     = .Finish in ent.traits,
			Trait_Kill       = .Kill in ent.traits,
			Trait_Grabable   = .Grabable in ent.traits,
		}
		append(&entities, entity_json)
	}

	level_json := Level_JSON {
		Name                 = level.name,
		Start_Position       = {
			level.start_position.x,
			level.start_position.y,
			level.start_position.z,
		},
		Start_Look_Direction = {
			level.start_look_direction.x,
			level.start_look_direction.y,
			level.start_look_direction.z,
		},
		Start_Velocity       = {
			level.start_velocity.x,
			level.start_velocity.y,
			level.start_velocity.z,
		},
		Author_Time          = level.author_time,
		Entities             = entities[:],
	}

	json_data, err := json.marshal(level_json)
	if err != nil {
		fmt.println("Failed to marshal level:", err)
		return "", false
	}

	return string(json_data), true
}

unserialize_level::proc(level_json: string, level: ^l.Level) {
        

}

save_to_file :: proc(level: ^l.Level, filepath: string) -> bool {
	data, ok := serialize_level(level)
	defer delete(data)
	if !ok do return false

	bytes := transmute([]u8)data
	written := os.write_entire_file(filepath, bytes)
	if !written {
		fmt.println("Failed to write file")
		return false
	}
	return true
}

load_from_file_level :: proc(filepath: string) -> l.Level {
        
	return l.Level{}
}
