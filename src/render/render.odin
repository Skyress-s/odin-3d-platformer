package render_types
import cs "../engine/core/collision_scene/"
import "core:c"
import rl "vendor:raylib"

Debug_Draw_Data :: distinct struct {
	active_cell:      map[cs.Hash_Key]bool,
	active_cell_hash: cs.Hash_Key,
}

Render_Targets :: struct {
	game: rl.RenderTexture2D,
}

Textures :: struct {
	render_targets: Render_Targets,
	cursor_texture: rl.Texture2D,
}

textures_init :: proc(game_dims: [2]c.int) -> Textures {
	textures: Textures
	textures.render_targets.game = rl.LoadRenderTexture(game_dims[0], game_dims[1])
	textures.cursor_texture = rl.LoadTexture("content/resources/cursor_1.png")
	return textures
}
textures_deinit :: proc(textures: Textures) {
	rl.UnloadRenderTexture(textures.render_targets.game)
}
