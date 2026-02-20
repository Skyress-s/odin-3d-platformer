package players

import character "../Character"
import verlet "../engine/core/physics/verlet"
import spat "../engine/core/spatial/"
import editor_player "../editor_player"


Player_Mode :: enum {
	Game,
	Editor,
}

//fmt.printfln("{:6.3f} ", some_var) // [0.5, 3.0, 6.5]

Players :: struct {
	mode:   Player_Mode,
	game:   character.CharacternData,
	editor: editor_player.Editor_Player_Data,
}

init_players :: proc() -> Players {
	players := Players{}

	players.mode = Player_Mode.Game
	players.game = character.CharacternData {
		radius = 1,
		current_state = character.Airborne{},
		verlet_component = verlet.Velocity_Verlet_Component{position = spat.Vector{0, 0, 0}},
	}

	players.editor = editor_player.Editor_Player_Data {
		movement_speed = 30,
	}

	return players
}
