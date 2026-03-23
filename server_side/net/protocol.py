"""Packet encoding and decoding helpers for the UDP demo."""

from game.models import PlayerState

# called by client when sending packet to server
def encode_client_packet(player: PlayerState, seq: int) -> str:
    return (
        f"{player.player_id},{seq},{player.x:.3f},{player.y:.3f},"
        f"{player.vx:.3f},{player.vy:.3f},{player.heading:.3f}"
    )

# called by server to decode when receiving packet from client
def decode_client_packet(text: str) -> tuple[int, int, PlayerState]:
    p, seq, x, y, vx, vy, heading = text.strip().split(",")
    player_id = int(p)
    return (
        player_id,
        int(seq),
        PlayerState(
            player_id=player_id,
            x=float(x),
            y=float(y),
            vx=float(vx),
            vy=float(vy),
            heading=float(heading),
        ),
    )

# called by server to prepare to send game state to client
def encode_snapshot(states: dict[int, PlayerState]) -> str:
    parts = []
    for pid, state in states.items():
        parts.append(
            f"{pid}:{state.x:.2f}:{state.y:.2f}:{state.vx:.2f}:{state.vy:.2f}:{state.heading:.2f}"
        )
    return ";".join(parts)

# called by client to receive game state from server
def decode_snapshot(text: str) -> dict[int, PlayerState]:
    players = {}
    if text.strip() == "":
        return players
        # empty dictionary if no players in snapshot.
    # each player is an entry split by ;
    for entry in text.split(";"):
        pid, x, y, vx, vy, heading = entry.split(":")
        player_id = int(pid)
        players[player_id] = PlayerState(
            player_id=player_id,
            x=float(x),
            y=float(y),
            vx=float(vx),
            vy=float(vy),
            heading=float(heading),
        )
    return players
