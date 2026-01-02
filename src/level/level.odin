package level

import spat "../Spatial"
import hms "../handle_map/handle_map_static/"

Level :: distinct struct {
	name:                 string,
	collision_object_map: spat.Collision_Object_Handle_Map,
	spatial_hash_grid:    spat.Spatial_Hash_Grid,

	// TODO: These ids could all just be stored in the collision channel... 
	finish_volumes:       map[spat.Collision_Object_Id]bool, // TODO: I give up, there should be a set type somewhere MPH-00001
	kill_volumes:         map[spat.Collision_Object_Id]bool,
	grappable:            map[spat.Collision_Object_Id]bool,



	// Player Start
	start_position,
	start_look_direction,
	start_velocity: spat.Vector,

	// Stats
	author_time: f64
}

delete_level :: proc(l: ^Level){
	delete(l.name)

	spat.delete_spatial_hash_grid(&l.spatial_hash_grid)

	for item in l.collision_object_map.items{
		if hms.skip(item) do continue
		delete(item.tris)
	}
	
	delete(l.finish_volumes)
	delete(l.kill_volumes)
	delete(l.grappable)
}
