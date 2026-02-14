package debug_draw_utils

import spat "../core/spatial"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

draw_circle :: proc(ins: ^Circle_Ins) {
	rl.DrawCircle3D(ins.location, ins.radius, ins.up, 0, ins.color)
}

draw_cyllinder :: proc(ins: ^Wire_Cyllinder_Ins) {

	ray_direction := spat.ray_direction(ins.ray)
	rotate_axis := linalg.normalize(linalg.cross(spat.UP_VEC3, ray_direction))
	rotate_angles := math.to_degrees(linalg.vector_angle_between(spat.UP_VEC3, ray_direction))
	ray_origin := ins.ray.origin

	rlgl.Translatef(ray_origin.x, ray_origin.y, ray_origin.z)
	rlgl.Rotatef(rotate_angles, rotate_axis.x, rotate_axis.y, rotate_axis.z)

	ray_length := spat.ray_length(&ins.ray)
	rl.DrawCylinderWires(spat.ZERO_VEC3, ins.radius, ins.radius, ray_length, 16, ins.color)
}

draw_capsule_wires :: proc(ins: ^Wire_Capsule_Ins) {
	rl.DrawCapsuleWires(
		ins.sphere_trace.origin,
		ins.sphere_trace.end,
		ins.radius,
		16,
		2,
		ins.color,
	)
}
