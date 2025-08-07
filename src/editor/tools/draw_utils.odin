package tools

import spat "../../Spatial/"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

draw_position_tooltip :: proc(location: spat.Vector) {
	PLANE_SIZE :: 100

	rlgl.PushMatrix()
	rlgl.Translatef(location.x, location.y, location.z)
	rl.DrawPlane(spat.ZERO_VEC3, spat.Vector2{PLANE_SIZE, PLANE_SIZE}, rl.ColorLerp(rl.RED, rl.GREEN, 0.5))
	rlgl.PopMatrix()

	rl.DrawPlane(location, spat.Vector2{PLANE_SIZE, PLANE_SIZE}, rl.ColorLerp(rl.RED, rl.GREEN, 0.5))

}
