package verlet

import spat "../../Spatial"


Velocity_Verlet_Component :: struct {
	position, velocity, acceleration: spat.Vector,
}

// Do the first half of the timestep of leapfrog
velocity_verlet_leap :: proc(component: ^Velocity_Verlet_Component, dt: f32) {
	// using leapfrog verlet intergration
	// todo translate
	// beregn ny posisjon et halvt tick fram i tid:
	component.position += component.velocity * dt / 2
}

// Do the second half of the timestep of leapfrog
velocity_verlet_frog :: proc(component: ^Velocity_Verlet_Component, dt: f32) {

	// beregn a(x) utifra kollisjoner og krefter ved nye posisjonen, 
	// og bruk den til å beregne ny hastighet
	component.velocity += component.acceleration * dt

	// beregn den faktiske nye posisjonen et halvt tick til fram i tid
	component.position += component.velocity * dt / 2
	component.acceleration = {}
}

velocity_verlet_homegenus_gravity :: proc(
	component: ^Velocity_Verlet_Component,
	gravity: spat.Vector,
	dt: f32,
) {
	// using leapfrog verlet intergration
	// todo translate
	// beregn ny posisjon et halvt tick fram i tid:
	component.position += component.velocity * dt / 2

	// beregn a(x) utifra kollisjoner og krefter ved nye posisjonen, 
	// og bruk den til å beregne ny hastighet
	component.velocity += gravity * dt // todo this is dogshit 

	// beregn den faktiske nye posisjonen et halvt tick til fram i tid
	component.position += component.velocity * dt / 2
}


// In case we need to perform velocity verlet when we dont have the component or non uniform gravitational fields.
velocity_verlet :: proc {
	velocity_verlet_homegenus_gravity,
}
