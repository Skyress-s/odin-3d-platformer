package raylib_bridge

import rl "vendor:raylib"
import spat "../Spatial"

// TODO: Might be kinda slow since we dont pass by ref
convert_ray :: proc(rl_ray: rl.Ray) -> spat.Ray{
	return spat.Ray{rl_ray.position, rl_ray.direction}
}
