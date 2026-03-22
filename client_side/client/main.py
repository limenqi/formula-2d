from client.game_loop import run_game_loop
from client.menu_loop import run_menu_loop
from game.physics import init_physics_backend

def main() -> None:
    init_physics_backend(use_hardware=True)
    sock, player_id, server_ip = run_menu_loop()
    run_game_loop(sock=sock, player_id=player_id, server_ip=server_ip)


if __name__ == "__main__":
    main()
