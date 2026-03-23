from server.game_loop import run_game_loop
from server.menu_loop import run_menu_loop
from server.game_ending import generating_leaderboard


def main() -> None:
    sock, engine, addrs = run_menu_loop()
    racetime_results = run_game_loop(sock=sock, engine=engine, addrs=addrs)
    generating_leaderboard(racetime_results)

    
    

if __name__ == "__main__":
    main()
