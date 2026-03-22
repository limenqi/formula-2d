from server.aws_functions import upload_race_result
from server.aws_functions import fetch_leaderboard

def generating_leaderboard(players_results):

    players_results.sort(key = lambda player: player["race_time"])
    for i in range(len(players_results)):
        players_results[i]["position"] = i+1
    
    for player in players_results:
        upload_race_result(
            player["player_id"],
            player["position"],
            player["race_time"]
        )

    leaderboard = fetch_leaderboard()
    print(leaderboard)




