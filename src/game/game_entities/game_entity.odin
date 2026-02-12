package game_entities

import spat "../../Spatial/"
import hm "core:container/handle_map"
import ilist "core:container/intrusive/list"

// This hole system is very much inspired by Wookash's great interview of Anton Mikhailov: https://www.youtube.com/watch?v=ShSGHb65f3M

Entity :: struct {
	handle:             Entity_Handle,
	traits:             Traits,
	collision_scene_id: spat.Collision_Object_Id,
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
