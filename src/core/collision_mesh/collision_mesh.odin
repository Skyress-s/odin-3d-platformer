package collision_mesh

import spat "../spatial/"

import hm "core:container/handle_map"

Mesh :: struct {
	handle: Mesh_Handle,
	tris:   [dynamic]spat.Collision_Triangle,
}

Mesh_Handle :: hm.Handle32

Map :: distinct hm.Static_Handle_Map(1024, Mesh, Mesh_Handle)
