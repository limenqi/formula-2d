import time
from socket import socket

from game.config import (
    CLIENT_SEND_HZ,
    CLIENT_SPAWN_HEADING,
    CLIENT_SPAWN_X,
    CLIENT_SPAWN_Y,
    SERVER_PORT,
)
from game.models import PlayerState
from game.physics import get_fixed_input, physics_step
from net.protocol import decode_snapshot, encode_client_packet


def run_game_loop(sock: socket, player_id: int, server_ip: str) -> None:
    server = (server_ip, SERVER_PORT)

    send_dt = 1.0 / CLIENT_SEND_HZ
    next_send = time.time()
    start = time.time()

    tx_count = 0
    rx_count = 0
    next_stats = time.time() + 1.0

    seq = 1
    players: dict[int, PlayerState] = {}
    current_player_state = PlayerState(
        player_id=player_id,
        x=CLIENT_SPAWN_X,
        y=CLIENT_SPAWN_Y,
        vx=0.0,
        vy=0.0,
        heading=CLIENT_SPAWN_HEADING,
    )

    print(f"client {player_id} -> {server_ip}:{SERVER_PORT}", flush=True)

    while True:
        now = time.time()

        if now >= next_send:
            player_input = get_fixed_input(player_id)
            current_player_state = physics_step(
                current_state=current_player_state,
                player_input=player_input,
                elapsed_time=now - start,
            )

            packet_text = encode_client_packet(current_player_state, seq)
            sock.sendto(packet_text.encode("utf-8"), server)
            tx_count += 1
            print(f"[TX] to={server[0]}:{server[1]} data={packet_text}", flush=True)

            seq += 1
            next_send += send_dt

        try:
            data, addr = sock.recvfrom(4096)
            players = decode_snapshot(data.decode("utf-8"))
            rx_count += 1
            print(f"[RX] from={addr[0]}:{addr[1]} players={players}", flush=True)
        except BlockingIOError:
            pass

        if now >= next_stats:
            print(f"[STATS] tx/s={tx_count} rx/s={rx_count}", flush=True)
            tx_count = 0
            rx_count = 0
            next_stats += 1.0

        time.sleep(0.001)
