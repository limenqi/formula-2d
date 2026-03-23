import requests
import json

API_URL = "https://qoquxmgosl.execute-api.us-east-1.amazonaws.com/scores"

def upload_race_result(player_id, position, race_time):
    """Sends the final race data to the AWS DynamoDB database."""
    payload = {
        "player_id": str(player_id),
        "position": int(position),
        "race_time": float(race_time)
    }
    
    try:
        print(f"[CLOUD] Uploading score for {player_id}...")
        # 5sec timeuot so bad internet connection doesnt freeze server
        response = requests.post(API_URL, json=payload, timeout=5)
        
        if response.status_code == 200:
            print("[CLOUD] Success! Score stored.")
        else:
            print(f"[CLOUD] AWS Error {response.status_code}: {response.text}")
            
    except requests.exceptions.RequestException as e:
        print(f"[CLOUD] Network connection failed. Error: {e}")

def fetch_leaderboard():

    try:
        print("[CLOUD] Fetching latest leaderboard...")
        response = requests.get(API_URL, timeout=5)
        
        if response.status_code == 200:
            leaderboard = response.json()
            
            print("\n" + "="*30)
            print("🏆 GLOBAL LEADERBOARD 🏆")
            print("="*30)
            for item in leaderboard:
                print(f"Pos: {int(item['position'])} | Player: {item['player_id']} | Time: {item['race_time']:.2f}s")
            print("="*30 + "\n")
            
            return leaderboard
        else:
            print(f"[CLOUD] AWS Error fetching leaderboard: {response.text}")
            return []
            
    except requests.exceptions.RequestException as e:
        print(f"[CLOUD] Network connection failed: {e}")
        return []
    
def reset_leaderboard():
    try:
        print("[CLOUD] Resetting the leaderboard...")
        response = requests.delete(API_URL, timeout=5)
        
        if response.status_code == 200:
            print("[CLOUD] " + response.json().get('message', 'Reset successful!'))
        else:
            print(f"[CLOUD] AWS Error resetting leaderboard: {response.text}")
            
    except requests.exceptions.RequestException as e:
        print(f"[CLOUD] Network connection failed: {e}")