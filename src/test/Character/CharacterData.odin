package Character

import "core:math/linalg"
import MotionComponent "../MotionComponent"

Grounded :: struct {
    Slowed: bool
}

Airborne :: struct {
    Speed: f16
}



State :: union {
    Grounded,
    Airborne
}

CharacternData :: struct {
    Motion: MotionComponent.MotionComponent

}