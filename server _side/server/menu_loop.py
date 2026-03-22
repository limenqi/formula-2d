import time
from socket import socket

from game.config import SERVER_MENU_POLL_HZ, SERVER_PORT, SERVER_REQUIRED_PLAYERS
from game.engine import GameEngine
from net.udp import create_udp_server_socket
from server.game_loop import _process_incoming_packets
from server.aws_functions import reset_leaderboard

# from software_render.menu_ui import (
#     draw_menu,
#     init_menu_ui,
#     poll_menu_events,
#     shutdown_menu_ui,
# )


def run_menu_loop() -> tuple[socket, GameEngine, dict[int, tuple[str, int]]]:
    sock = create_udp_server_socket(SERVER_PORT)
    engine = GameEngine()
    addrs: dict[int, tuple[str, int]] = {}
    menu_dt = 1.0 / SERVER_MENU_POLL_HZ
#     screen, title_font, body_font = init_menu_ui()
    reset_leaderboard() # jsut simply an aws cloud database reset

    print(f"server listening on 0.0.0.0:{SERVER_PORT}", flush=True)
    print("[MENU] waiting for players", flush=True)

    while True:
#         if not poll_menu_events():
#             shutdown_menu_ui()
#             raise SystemExit

        _process_incoming_packets(sock, engine, addrs)
#         draw_menu(
#             screen=screen,
#             title_font=title_font,
#             body_font=body_font,
#             connected_players=len(engine.players),
#             required_players=SERVER_REQUIRED_PLAYERS,
#             player_ids=sorted(engine.players.keys()),
#         )

        if len(engine.players) >= SERVER_REQUIRED_PLAYERS:
            print("[MENU] enough players connected, entering game", flush=True)
#             shutdown_menu_ui()
            return sock, engine, addrs

        time.sleep(menu_dt)
