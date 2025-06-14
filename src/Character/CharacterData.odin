package Character

import MotionComponent "../Physics/MotionComponent"

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
    using Motion: MotionComponent.MotionComponent,
    CurrentState : State

}