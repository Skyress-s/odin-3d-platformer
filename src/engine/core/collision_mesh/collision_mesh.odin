package collision_mesh

import logs "../logs/"
import spat "../spatial/"
import "base:runtime"

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


init :: proc(ctx: ^Collider_Mesh_Context, allocator: runtime.Allocator) {
	box_tris := spat.get_box_tris(allocator)
	// defer delete(box_tris)
	box_mesh: Mesh = {
		tris = box_tris,
	}

	ctx.primitive_ids[spat.Shape.Box] = hm.add(&ctx.mesh_map, box_mesh)
}

deinit :: proc(ctx: ^Collider_Mesh_Context) {
	logs.debugf(.Physics, "Deinitializing Collider Mesh Context.")
	itr := hm.iterator_make(&ctx.mesh_map)
	for item, _ in hm.iterate(&itr) {
		delete(item.tris)
	}
}
