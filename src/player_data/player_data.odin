package player_data

import spat "../Spatial"
import "core:math/linalg"
import "core:math"

import "core:os"
Player_Look_Data :: distinct struct{
	using look_radians: spat.Vector2
} 

calculate_look_to_stuff :: proc(
	rot: spat.Quaternion
	) -> (){

}
// todo terrible name
calculate_stuff_from_look :: proc(
	look_data: ^Player_Look_Data,
) -> (
	rot: linalg.Quaternionf32,
	forward, right: linalg.Vector3f32,
) {
	rot =
		linalg.quaternion_from_euler_angle_y_f32(look_data.look_radians.y) *
		linalg.quaternion_from_euler_angle_x_f32(look_data.look_radians.x)

	forward = linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{0, 0, 1})
	right = linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{1, 0, 0})

	// TODO: Remove
	xz_forward := forward
	xz_forward.y = 0
	xz_forward = linalg.normalize(xz_forward)

	return rot, forward, right
}

update_player_look_data :: proc(look_data: ^Player_Look_Data, delta_look: spat.Vector2, dt: f32){
	look_data.look_radians.y -= delta_look.x * 0.0015 // left and right
	look_data.look_radians.x += delta_look.y * 0.0015 // up and down
	look_data.look_radians.x = linalg.clamp(
		look_data.look_radians.x,
		-math.PI * 0.499,
		math.PI * 0.499,
	)
}
