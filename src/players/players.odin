package players

import character "../Character"
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
