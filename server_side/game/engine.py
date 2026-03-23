from game.models import PlayerState


class GameEngine:
    def __init__(self) -> None:
        self.players: dict[int, PlayerState] = {}
        self.last_seq: dict[int, int] = {}
        self.elapsed_time = 0.0

    def apply_client_update(
        self,
        player_id: int,
        seq: int,
        x: float,
        y: float,
        vx: float,
        vy: float,
        heading: float,
    ) -> bool:
        last_seq = self.last_seq.get(player_id, -1)
        # return -1 if player not found
        if seq <= last_seq:
            return False

        self.last_seq[player_id] = seq
        self.players[player_id] = PlayerState(
            player_id=player_id,
            x=x,
            y=y,
            vx=vx,
            vy=vy,
            heading=heading,
        )
        return True

    def tick(self, dt: float) -> None:
        self.elapsed_time += dt;

    def get_snapshot(self) -> dict[int, PlayerState]:
        return dict(self.players)
