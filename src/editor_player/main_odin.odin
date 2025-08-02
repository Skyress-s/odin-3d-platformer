package editor_player

import "../Physics/verlet"
import spat "../Spatial"
import "../player_data"

Editor_Player_Data :: distinct struct {
	using look_data: player_data.Player_Look_Data,
	position:        spat.Vector,
}


update :: proc(Editor_Player_Data: ^Editor_Player_Data, dt: f32){
	

}
