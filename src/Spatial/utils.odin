package Spatial

import "core:math/linalg"
// mult :: proc(mat: ^linalg.Matrix4f32, vec: Vector) -> Vector{
// 	return (mat^*Vector4{vec.x, vec.y, vec.z, 1}).xyz
// }

mult :: proc(mat: linalg.Matrix4f32, vec: ^Vector){
	vec^ = (mat*Vector4{vec.x, vec.y, vec.z, 1}).xyz
}

mul :: proc(mat: linalg.Matrix4f32, vec: ^Vector) -> Vector{
	return (mat*Vector4{vec.x, vec.y, vec.z, 1}).xyz
}


mul_vector :: proc(mat: linalg.Matrix4f32, vec: ^Vector) -> Vector{
	return (mat*Vector4{vec.x, vec.y, vec.z, 0}).xyz
}

mul_point :: proc(mat: linalg.Matrix4f32, vec: ^Vector) -> Vector{
	return (mat*Vector4{vec.x, vec.y, vec.z, 1}).xyz
}
