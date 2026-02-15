package collision_mesh

import spat "../spatial/"

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

get_mesh_checked :: proc(ctx: ^Collider_Mesh_Context, handle: Mesh_Handle) -> ^Mesh {
	found_mesh := hm.get(&ctx.mesh_map, handle)
	assert(found_mesh != nil)
	return found_mesh
}


init :: proc(ctx: ^Collider_Mesh_Context) {

	box_tris := spat.get_box_tris()
	box_mesh: Mesh = {
		tris = box_tris,
	}

	ctx.primitive_ids[spat.Shape.Box] = hm.add(&ctx.mesh_map, box_mesh)
}
