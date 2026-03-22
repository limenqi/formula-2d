from dataclasses import dataclass


@dataclass
class PlayerState:
    player_id: int
    x: float
    y: float
    vx: float
    vy: float
    heading: float
