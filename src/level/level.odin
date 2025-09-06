package level

import spat "../Spatial"

Level :: distinct struct {
	name:                 string,
	collision_object_map: spat.Collision_Object_Handle_Map,
	spatial_hash_grid:    spat.Spatial_Hash_Grid,
	finish_volumes: 	  map[spat.Collision_Object_Id]bool, // TODO: I give up, there should be a set type somewhere MPH-00001
	kill_volumes: 		  map[spat.Collision_Object_Id]bool,
	
	
	// Player Start
	start_position:       spat.Vector,
	start_look_direction: spat.Vector,
	
}
