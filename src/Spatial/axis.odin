package Spatial

Axis :: distinct enum{
	X, Y, Z, None
}

axis_to_unit_vector :: proc(axis: Axis) -> Vector{
	switch axis {
	case .X:
		return {1,0,0}
	case .Y:
		return {0,1,0}
	case .Z:
		return {0,0,1}
	case .None:
		return ZERO_VEC3
	}

	unreachable()
}
