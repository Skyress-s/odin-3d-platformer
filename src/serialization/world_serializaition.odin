package serialization
import gent "../game/game_entities/"
import w "../game/world/"

import "core:encoding/json"

Serial_World :: struct {
	ents: [dynamic]gent.Entity,
}

Asset_Path :: struct {}

world_to_serializable :: proc(world: w.World) {


}
