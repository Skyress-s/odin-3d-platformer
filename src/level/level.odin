package level


import spat "../Spatial"

Level :: distinct struct {
	name:                 string,
	collision_object_map: spat.Collision_Object_Handle_Map,
	spatial_hash_grid:    spat.Spatial_Hash_Grid,
	start_position:       spat.Vector,
	start_look_direction: spat.Vector,
}
