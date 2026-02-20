package editor_player

import spat "../engine/core/spatial"
import e_tools "../editor/tools"
import "../input"
import player_data "../player_data/"
import vmouse "../engine/core/virtual_mouse/"
import "core:math/linalg"
import rl "vendor:raylib"

Editor_Player_Data :: distinct struct {
	using look_data: player_data.Player_Look_Data,
	position:        spat.Vector,
	movement_speed:  f32,
	transform_tool:  e_tools.Transform_Tool_Data,
}


update :: proc(editor_player: ^Editor_Player_Data, vmouse_ctx: ^vmouse.Context, dt: f32) {
	input_snapshot := input.make_input_snapshot()
	// Update the position and look_data

	_, is_looking := input_snapshot.seconday_click.(input.Down)
	if is_looking {
		player_data.update_player_look_data(&editor_player.look_data, rl.GetMouseDelta(), dt)

		// if (!vmouse.is_cursor_hidden(vmouse_ctx^)) {
		vmouse.hide_cursor(vmouse_ctx)
		vmouse.restrict_mouse(vmouse_ctx, vmouse.get_mouse_pos(vmouse_ctx^))
		// }
	} else { 	// not looking with camera
		// if (vmouse.is_cursor_hidden(vmouse_ctx^)) {
		vmouse.show_cursor(vmouse_ctx)
		vmouse.free_mouse(vmouse_ctx)
		// }
	}

	_, forward, right := player_data.calculate_direction_from_look(editor_player)

	_, up := input_snapshot.jump.(input.Down)
	_, down := input_snapshot.crouch.(input.Down)

	editor_player.movement_speed = linalg.max(
		editor_player.movement_speed + rl.GetMouseWheelMove() * 15,
		0,
	)

	editor_player.position +=
		((forward * input_snapshot.movement.y) +
			(right * input_snapshot.movement.x) +
			(linalg.cross(forward, right) * ((up ? 1 : 0) + (down ? -1 : 0)))) *
		dt *
		editor_player.movement_speed


}
