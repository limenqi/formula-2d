from socket import socket

from game.config import (
    CLIENT_PLAYER_ID,
    CLIENT_SERVER_IP,
    CLIENT_SPAWN_HEADING,
    CLIENT_SPAWN_X,
    CLIENT_SPAWN_Y,
    SERVER_PORT,
)
from game.models import PlayerState
from net.protocol import encode_client_packet
from net.udp import create_udp_client_socket


def run_menu_loop() -> tuple[socket, int, str]:
    sock = create_udp_client_socket()
    player_id = CLIENT_PLAYER_ID
    server_ip = CLIENT_SERVER_IP
    server = (server_ip, SERVER_PORT)

    print("[MENU] press Enter to start", flush=True)
    input()

    initial_state = PlayerState(
        player_id=player_id,
        x=CLIENT_SPAWN_X,
        y=CLIENT_SPAWN_Y,
        vx=0.0,
        vy=0.0,
        heading=CLIENT_SPAWN_HEADING,
    )
    packet_text = encode_client_packet(initial_state, seq=0)
    sock.sendto(packet_text.encode("utf-8"), server)

    print("[MENU] registration packet sent, entering game loop", flush=True)
    return sock, player_id, server_ip
