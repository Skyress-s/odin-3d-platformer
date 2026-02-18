package game_entities

import cc "../../core/collision_channel/"
import col_mesh "../../core/collision_mesh/"
import hent "../../core/entity_handle/"
import spat "../../core/spatial/"
import hm "core:container/handle_map"


Serialized_Entity :: struct {
	handle:              hent.Entity_Handle,
	traits:              Traits,
	transform_component: Transform_Component,
	collision_component: Collision_Component,
}
