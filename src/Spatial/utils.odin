package Spatial

import "core:math/linalg"
mult :: proc(mat: ^linalg.Matrix4f32, vec: Vector) -> Vector{
	return (mat^*Vector4{vec.x, vec.y, vec.z, 1}).xyz
}
