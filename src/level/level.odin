package level


import spat "../Spatial"

Level :: distinct struct {
	collision_object_map: spat.Collision_Object_Handle_Map,
	spatial_hash_grid:    spat.Spatial_Hash_Grid,
}
