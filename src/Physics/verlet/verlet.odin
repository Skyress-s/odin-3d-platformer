package verlet

import spat "../../Spatial"


Velocity_Verlet_Component :: struct {
	position, velocity: spat.Vector,
}

velocity_verlet_no_component :: proc(
	position, velocity: ^spat.Vector,
	acceleration: spat.Vector,
	dt: f32,
) {
	position^ += velocity^ * dt + 0.5 * acceleration * dt * dt
	velocity^ += acceleration * dt
}
velocity_verlet_with_component :: proc(
	velocity_verlet_component: ^Velocity_Verlet_Component,
	acceleration: spat.Vector,
	dt: f32,
) {
	velocity_verlet_no_component(
		&velocity_verlet_component.position,
		&velocity_verlet_component.velocity,
		acceleration,
		dt,
	)
}


velocity_verlet :: proc {
	velocity_verlet_with_component,
	velocity_verlet_no_component,
}
