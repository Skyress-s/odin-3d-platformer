package Character
import col "../color"
import ddu "../debug_draw_utils"
import cc "../engine/core/collision_channel"
import cm "../engine/core/collision_mesh/"
import cs "../engine/core/collision_scene/"
import csq "../engine/core/collision_scene/query/"
import logs "../engine/core/logs"
import verlet "../engine/core/physics/verlet"
import spat "../engine/core/spatial"
import vmouse "../engine/core/virtual_mouse/"
import gent "../game/game_entities/"
import "../game_state"
import "../input"
import "../player_data"
import hm "core:container/handle_map"
import "core:math/linalg"
import "core:time"
import rl "vendor:raylib"


Grounded :: struct {
	allow_gain_max_speed, acceleration: f32,
}

Airborne :: struct {
	allow_gain_max_speed, acceleration: f32,
}

State :: union #no_nil {
	Grounded,
	Airborne,
}

Speedrun_Stopwatches_Type :: time.Stopwatch

CharacternData :: struct {
	// using motion:           MotionComponent.MotionComponent,
	current_state:          State,
	hooked_position:        spat.Vector,
	is_hooked:              bool,
	start_distance_to_hook: f32,
	verlet_component:       verlet.Velocity_Verlet_Component,
	using look_angles:      player_data.Player_Look_Data,
	// look_angles:            rl.Vector2,
	radius:                 f32,

	// Cheats
	air_jumping_cheat:      bool,
	speedrun_stop_watch:    time.Stopwatch,
	best_time:              f64,
}

start_speedrun :: proc(game_player: ^CharacternData) {
	time.stopwatch_start(&game_player.speedrun_stop_watch)
}


pause_speedrun :: proc(game_player: ^CharacternData) {
	time.stopwatch_stop(&game_player.speedrun_stop_watch)
}

reset_speedrun :: proc(game_player: ^CharacternData) {
	time.stopwatch_reset(&game_player.speedrun_stop_watch)
}

get_current_speedrun_time :: proc(game_player: ^CharacternData) -> f64 {
	return time.duration_seconds(time.stopwatch_duration(game_player.speedrun_stop_watch))
}


reset_run :: proc(character_data: ^CharacternData, start_location, start_velocity: ^spat.Vector) {
	reset_speedrun(character_data)
	start_speedrun(character_data)

	character_data.verlet_component.position = start_location^
	character_data.verlet_component.velocity = start_velocity^
	character_data.look_angles = player_data.calculate_look_angles_from_direction(start_velocity^)
	character_data.is_hooked = false
	character_data.hooked_position = spat.ZERO_VEC3
}

notify_level_loaded :: proc(character_data: ^CharacternData) {
	character_data.speedrun_stop_watch = time.Stopwatch{}
	character_data.best_time = 0
}
