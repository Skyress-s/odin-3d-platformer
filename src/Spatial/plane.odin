package Spatial

Plane :: distinct struct {
	point_on_plane, normal: Vector,
}

Plane_Bounded :: distinct struct {
	// using plane: Plane,
	center, normal, forward: Vector,
	lenghts:     Vector2,
}
