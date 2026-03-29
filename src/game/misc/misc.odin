package misc

import spat "../../engine/core/spatial/"

import "core:time"

Player_Initial_State :: struct {
	position, speed, look_direction: spat.Vector,
}

Speedrun_Capture :: struct {
	time: time.Stopwatch,
}
