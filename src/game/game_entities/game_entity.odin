package game_entities

import cc "../../core/collision_channel/"
import col_mesh "../../core/collision_mesh/"
import hent "../../core/entity_handle/"
import spat "../../core/spatial/"
import hm "core:container/handle_map"
// import ilist "core:container/intrusive/list"

// This hole system is very much inspired by Wookash's great interview of Anton Mikhailov: https://www.youtube.com/watch?v=ShSGHb65f3M

Entity :: struct {
	handle:              hent.Entity_Handle,
	traits:              Traits,
	transform_component: Transform_Component,
	collision_component: Collision_Component,
}

Transform_Component :: struct {
	transform: spat.Transform,
}

Collision_Component :: struct {
	mesh_id:            col_mesh.Mesh_Handle,
	collision_response: cc.Responses,
}

Traits :: bit_set[Trait]
Trait :: enum {
	// Game specific
	Transform,
	Star,
	Finish,
	Kill,
	Player,
	Physics,
	Grabable,

	// General
	StaticMesh,
	Collision,
}

Player_Data :: struct {}


Game_Entity_Handle_Map :: hm.Static_Handle_Map(1024, Entity, hent.Entity_Handle)

has_traits :: proc {
	has_traits_entity_handle,
	has_traits_entity,
	has_traits_traits,
}

has_traits_entity_handle :: proc(
	wanted_traits: Traits,
	ents: Game_Entity_Handle_Map,
	id: hent.Entity_Handle,
) -> bool {
	ents := ents
	ent := hm.get(&ents, id)
	if ent == nil do return false

	return has_traits_entity(wanted_traits, ent^)
}

has_traits_entity :: proc(wanted_traits: Traits, ent: Entity) -> bool {
	return has_traits_traits(wanted_traits, ent.traits)
}
has_traits_traits :: proc(wanted_traits: Traits, actual_traits: Traits) -> bool {
	return wanted_traits & actual_traits == wanted_traits
}

add_traits_checked :: proc(new_traits: Traits, ent: ^Entity) {
	assert(!has_traits(new_traits, ent.traits))

	ent.traits += new_traits
}
