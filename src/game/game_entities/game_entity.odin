package game_entities

import hm "core:container/handle_map"
import ilist "core:container/intrusive/list"

// This hole system is very much inspired by Wookash's great interview of Anton Mikhailov: https://www.youtube.com/watch?v=ShSGHb65f3M

Entity :: struct {
	traits: Traits,
	handle: Entity_Handle,
}

Traits :: bit_set[Trait]
Trait :: enum {
	// Game specific
	Star,
	Finish,
	Player,
	Physics,

	// General
	StaticMesh,
	Collider,
}

Player_Data :: struct {}


Entity_Handle :: hm.Handle32
Game_Entity_Handle_Map :: hm.Static_Handle_Map(1024, Entity, Entity_Handle)
