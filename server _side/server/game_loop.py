import time
from socket import socket

from game.hw_interface import PhysicsHardwareInterface
from game.config import SERVER_TICK_HZ
from game.engine import GameEngine
from net.protocol import decode_client_packet, encode_snapshot
SCREEN_W = 640
SCREEN_H = 480
VP_HEIGHT = 240  # Each player gets half the screen vertically
WORLD_W = 20*64
WORLD_H = 15*64
players_results = []

PRE_RACE_DURATION = 10  # seconds of map fly-over before race starts

def centered_camera(player_x, player_y):
    cam_x = int(player_x - SCREEN_W // 2)
    cam_y = int(player_y - VP_HEIGHT // 2)
    cam_x = max(0, min(WORLD_W - SCREEN_W, cam_x))
    cam_y = max(0, min(WORLD_H - VP_HEIGHT, cam_y))
    return cam_x, cam_y

def centered_camera2(player_x, player_y):
    cam_x = int(player_x - SCREEN_W // 2)
    cam_y = int(player_y - VP_HEIGHT // 2)
    cam_x = max(0, min(WORLD_W - SCREEN_W, cam_x))
    cam_y = max(0, min(WORLD_H - VP_HEIGHT, cam_y ))
    return cam_x, cam_y

def _process_incoming_packets(
    sock: socket,
    engine: GameEngine,
    addrs: dict[int, tuple[str, int]],
) -> int:
    recv_count = 0
    
    while True:
        try:
            data, addr = sock.recvfrom(1024)
        except BlockingIOError:
            break

        try:
            player_id, seq, player = decode_client_packet(data.decode("utf-8"))

            accepted = engine.apply_client_update(
                player_id=player_id,
                seq=seq,
                x=player.x,
                y=player.y,
                vx=player.vx,
                vy=player.vy,
                heading=player.heading,
            )
            if not accepted:
                continue

            if player_id not in addrs:
                addrs[player_id] = addr

            recv_count += 1

            print(
                f"[RX] from={addr[0]}:{addr[1]} pid={player_id} "
                f"x={player.x:.2f} y={player.y:.2f} "
                f"vx={player.vx:.2f} vy={player.vy:.2f} h={player.heading:.2f}",
                flush=True,
            )
        except Exception:
            print(f"[RX-ERR] malformed from={addr}", flush=True)

    return recv_count

def check_cross(x, y):
    return 256 < x < 320 and 256 < y < 320

def player_dict_maker(player_id, race_time):
    player_time = {"player_id": player_id, "race_time": race_time}
    players_results.append(player_time)
    return players_results

def _run_pre_race_overview(
    sock: socket,
    engine: GameEngine,
    addrs: dict[int, tuple[str, int]],
    hw: PhysicsHardwareInterface,
) -> None:
    """
    Pan both cameras across the map over PRE_RACE_DURATION seconds so
    players get a tour of the track before the race begins.
    Both halves of the split-screen show the same view.
    Network packets are still processed so clients can connect.

    Pan path: top-left -> top-right -> bottom-right -> bottom-left -> centre
    Each segment gets an equal share of the total time.
    """
    print(f"[PRE-RACE] Map fly-over for {PRE_RACE_DURATION}s", flush=True)

    # Camera limits (max values before viewport goes out of bounds)
    max_cam_x = WORLD_W - SCREEN_W   # 1280 - 640 = 640
    max_cam_y = WORLD_H - VP_HEIGHT  # 960 - 240  = 720

    # Waypoints the camera will visit: (x, y)
    # Top-left -> top-right -> bottom-right -> bottom-left -> centre
    waypoints = [
        (0,         0),
        (max_cam_x, 0),
        (max_cam_x, max_cam_y),
        (0,         max_cam_y),
        (max_cam_x // 2, max_cam_y // 2),
    ]
    num_segments = len(waypoints) - 1
    segment_duration = PRE_RACE_DURATION / num_segments

    overview_start = time.time()
    tick_dt = 1.0 / SERVER_TICK_HZ
    next_tick = time.time()
    last_countdown = -1

    while True:
        _process_incoming_packets(sock, engine, addrs)

        now = time.time()
        elapsed = now - overview_start
        remaining = PRE_RACE_DURATION - elapsed

        if remaining <= 0:
            break

        if now >= next_tick:
            engine.tick(tick_dt)
            snapshot_text = encode_snapshot(engine.get_snapshot())
            snapshot = snapshot_text.encode("utf-8")
            for addr in addrs.values():
                sock.sendto(snapshot, addr)
            next_tick += tick_dt

        # Work out which segment we're in and how far through it
        seg_index = min(int(elapsed / segment_duration), num_segments - 1)
        seg_progress = (elapsed - seg_index * segment_duration) / segment_duration
        seg_progress = max(0.0, min(1.0, seg_progress))

        x0, y0 = waypoints[seg_index]
        x1, y1 = waypoints[seg_index + 1]
        cam_x = int(x0 + (x1 - x0) * seg_progress)
        cam_y = int(y0 + (y1 - y0) * seg_progress)

        hw.write_camera1(cam_x, cam_y)
        hw.write_camera2(cam_x, cam_y)

        secs_left = int(remaining) + 1
        if secs_left != last_countdown:
            last_countdown = secs_left
            print(f"[PRE-RACE] Race starts in {secs_left}s ...", flush=True)

        time.sleep(0.001)

    print("[PRE-RACE] GO!", flush=True)

def run_game_loop(
    sock: socket,
    engine: GameEngine,
    addrs: dict[int, tuple[str, int]],
) -> None:
    hw = PhysicsHardwareInterface(require_controller=False)
    hw.write_camera1(0, 0)
    hw.write_camera2(0, 0)

    # --- 10-second map overview before race begins ---
    _run_pre_race_overview(sock, engine, addrs, hw)

    cnt1 = 2
    cnt2 = 2
    tick_dt = 1.0 / SERVER_TICK_HZ
    next_tick = time.time()
    lasttime1 = time.time()
    lasttime2 = time.time()
    recv_count = 0
    send_count = 0
    next_stats = time.time() + 1.0

    print("[MENU] entering server game loop", flush=True)

    while cnt1>0 or cnt2>0:
        recv_count += _process_incoming_packets(sock, engine, addrs)

        now = time.time()
        if now >= next_tick:
            engine.tick(tick_dt)
            snapshot_text = encode_snapshot(engine.get_snapshot())
            snapshot = snapshot_text.encode("utf-8")

            for addr in addrs.values():
                sock.sendto(snapshot, addr)
                send_count += 1
                print(f"[TX] to={addr[0]}:{addr[1]} snapshot={snapshot_text}", flush=True)

            next_tick += tick_dt

        players = engine.get_snapshot()
        player1 = players.get(1)
        player2 = players.get(2)
        car1_heading = int(round(player1.heading * 1024 / 360.0)+256) & 0x3FF if player1 else 0
        car2_heading = int(round(player2.heading * 1024 / 360.0)+256) & 0x3FF if player2 else 0

        hw.write_players(
            car1_x=int(player1.x) if player1 else 0,
            car1_y=int(player1.y) if player1 else 0,
            car1_heading=car1_heading,
            car2_x=int(player2.x) if player2 else 0,
            car2_y=int(player2.y) if player2 else 0,
            car2_heading=car2_heading,
        )
        if player1:
            c1x, c1y = centered_camera(player1.x, player1.y)
            hw.write_camera1(c1x, c1y)
        if player2:
            c2x, c2y = centered_camera2(player2.x, player2.y)
            hw.write_camera2(c2x, c2y)
        if player1 and check_cross(player1.x, player1.y):
            if((time.time()-lasttime1)>15):
                cnt1-=1
                if(cnt1 <= 0):
                    endtime1 = time.time()
        if player2 and check_cross(player2.x, player2.y):
            if((time.time()-lasttime2)>15):
                cnt2-=1
                if(cnt2 <= 0):
                    endtime2 = time.time()
        if now >= next_stats:
            print(
                f"[STATS] recv/s={recv_count} send/s={send_count} "
                f"clients={len(addrs)} players={len(engine.players)}",
                flush=True,
            )
            recv_count = 0
            send_count = 0
            next_stats += 1.0
        time.sleep(0.001)
    

    player_dict_maker(player1,endtime1-lasttime1)
    player_dict_maker(player2,endtime2-lasttime2)

    return players_results