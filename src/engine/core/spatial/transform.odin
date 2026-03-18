package Spatial

Transform :: distinct struct {
	position: Vector,
	rotation: Quaternion,
	scale:    Vector,
}


transform_vector :: proc(t: Transform, v: Vector) -> Vector {
	v := v

	mat := matrix_from_transform(t)
	return mul(mat, &v)
}

transform_vector_tr :: proc(t: Transform, v: Vector) -> Vector {
	v := v

	mat := matrix_from_transform_tr(t)
	return mul_vector(mat, &v)
}
