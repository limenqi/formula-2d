# Formula 2D

Formula 2D is an FPGA-accelerated multiplayer 2D racing game built on a Zynq/PYNQ platform.

The system combines:
- hardware-accelerated game physics (custom AXI IP),
- hardware-accelerated graphics rendering (custom AXI renderer, HDMI output),
- UDP-based multiplayer synchronisation, and
- AWS-backed leaderboard services.

---

## Repository Structure

```text
.
├── client_side/
│   ├── client/                 # Client entrypoints and loops
│   ├── game/                   # Client config/models/physics abstraction
│   └── net/                    # UDP + protocol encode/decode
│
├── server_side/
│   ├── server/                 # Server entrypoints, game loop, AWS calls
│   ├── game/                   # Server engine, hardware interface, config
│   ├── net/                    # UDP + protocol encode/decode
│   └── software_render/        # Optional software render/debug utilities
│
└── vivado/
    ├── top_design.bit          # FPGA bitstream
    ├── top_design.hwh          # Hardware handoff
    ├── ip_repo/physics_axi_ip/ # Physics IP source
    └── racing_axi/...          # Renderer IP source/assets
```

---

## Prerequisites

### Software
- Python 3.10+ recommended.

Install Python dependencies:
```bash
pip install requests
pip install pygame # for debugging
```

### Hardware/runtime
For the hardware-accelerated server path:
- PYNQ environment with `pynq` package available.
- Bitstream and IP names must match `server_side/game/hw_interface.py`.

---

## Configuration

Before running, set network/runtime constants in:
- `server_side/game/config.py`
- `client_side/game/config.py`

Ensure consistency for:
- `SERVER_PORT`
- `SERVER_TICK_HZ` and `CLIENT_SEND_HZ`
- `SERVER_REQUIRED_PLAYERS`
- `CLIENT_SERVER_IP` (must point to server host)

Multiplayer IDs:
- Set unique `CLIENT_PLAYER_ID` per client instance (e.g. `1`, `2`).

---

## How to Run on PYNQ
### 1) Folder layout on each board
```bash
/home/xilinx/jupyter_notebooks/formula2d/
├── server_side/
├── client_side/
└── vivado/
    ├── top_design.bit
    └── top_design.hwh
```
- On the server board, ensure `server_side/` exists and bitstream files are available.
- On each client board, ensure `client_side/` exists.
- Use a fresh new terminal for each separate game run so previous processes, environment state, or loaded overlays do not interfere with the next run.


### 2) Start Server (authoritative node)

From workspace root:
```bash
cd server_side
python -m server.main
```

Expected output includes:
- server bind (`server listening on 0.0.0.0:<port>`)
- menu wait status
- runtime `RX`/`TX`/`STATS` logs after clients join

### 3) Start Client(s)

From workspace root, for each client:
```bash
cd client_side
python -m client.main
```

Client flow:
- prompts for start input
- sends registration packet
- enters fixed-rate update loop
- sends player packets and receives snapshots

---

## Runtime Overview

1. Client sends UDP updates:  
   `player_id, seq, x, y, vx, vy, heading`
2. Server validates sequence freshness and updates authoritative state.
3. Server broadcasts consolidated snapshots to clients.
4. Server writes official camera/car/heading state via MMIO.
5. FPGA renderer produces split-screen HDMI output.
6. End-of-race results are pushed to AWS leaderboard API.

---

## Optional Render Comparison

From the project root on PYNQ:

```bash
python -m software_render.hdmi_map_demo
python -m game.hardware_render_demo
```

Use these only if you want a quick software vs hardware rendering comparison.

