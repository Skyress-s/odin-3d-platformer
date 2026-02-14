package collision_mesh

import spat "../spatial/"
import "core:reflect"

import hm "core:container/handle_map"

Mesh :: struct {
	handle: Mesh_Handle,
	tris:   [dynamic]spat.Collision_Triangle,
}

Mesh_Handle :: hm.Handle32

Map :: distinct hm.Static_Handle_Map(1024, Mesh, Mesh_Handle)

Collider_Mesh_Context :: struct {
	mesh_map:      Map,
	primitive_ids: [len(spat.Shape)]Mesh_Handle,
}


init :: proc(mesh_map: ^Map) {

	for shape_type in spat.Shape {

		tris := spat.get_box_tris()


	}


}
