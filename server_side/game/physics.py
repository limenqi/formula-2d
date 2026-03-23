import math

from game.models import PlayerState

try:
    from game_physics.hw_interface import PhysicsHardwareInterface
except Exception:
    PhysicsHardwareInterface = None


_physics_hw = None


def init_physics_backend(use_hardware: bool = False):
    global _physics_hw
    if use_hardware and PhysicsHardwareInterface is not None:
        _physics_hw = PhysicsHardwareInterface()
    else:
        _physics_hw = None
    return _physics_hw


def get_fixed_input(player_id: int) -> dict[str, float]:
    return {
        "radius": 10.0,
        "angular_velocity": 0.6 + 0.1 * player_id,
    }


def physics_step(
    current_state: PlayerState,
    player_input: dict[str, float],
    elapsed_time: float,
) -> PlayerState:
    if _physics_hw is not None:
        next_state, _ = _physics_hw.step(current_state)
        return next_state

    radius = player_input["radius"]
    angular_velocity = player_input["angular_velocity"]
    angle = angular_velocity * elapsed_time
    center_x = 320.0
    center_y = 240.0
    # place holder
    return PlayerState(
        player_id=current_state.player_id,
        x=center_x + radius * math.cos(angle),
        y=center_y + radius * math.sin(angle),
        vx=-radius * angular_velocity * math.sin(angle),
        vy=radius * angular_velocity * math.cos(angle),
        heading=math.degrees(angle) % 360.0,
    )


def get_hardware_debug_state():
    if _physics_hw is None:
        return None
    controller_state = _physics_hw.poll_controller_state()
    return controller_state
