import math
import os
import struct
from pathlib import Path
from time import perf_counter, sleep
 
from pynq import Overlay
 
from game.models import PlayerState
 
 
BIT_PATH = Path("/home/xilinx/jupyter_notebooks/infoProcFinal_Server/game/top_design.bit")
PHYSICS_IP_NAME = "physics_axi_ip_0"
RENDERER_IP_NAME = "racing_renderer_0"
 
# --- Controller input ---
EVENT_PATH_P1 = "/dev/input/event0"
EVENT_PATH_P2 = "/dev/input/event1"
EVENT_SIZE = 16
 
EV_KEY = 0x01
EV_ABS = 0x03
 
ABS_X = 0
ABS_Y = 1
ABS_R2 = 4
 
BTN_R2 = 311
BTN_SQUARE = 304
BTN_CROSS = 305
BTN_CIRCLE = 306
BTN_TRIANGLE = 307
 
# --- Physics IP registers ---
REG_CONTROL = 0x00
REG_CUR_X = 0x04
REG_CUR_Y = 0x08
REG_CUR_HEADING = 0x0C
REG_CUR_SPEED = 0x10
REG_TARGET_HEADING = 0x14
REG_INPUT_FLAGS = 0x18
REG_NEXT_X = 0x1C
REG_NEXT_Y = 0x20
REG_NEXT_HEADING = 0x24
REG_NEXT_SPEED = 0x28
REG_STATUS_FLAGS = 0x2C
 
# --- Renderer IP registers (split-screen dual camera) ---
REG_CAM1_X = 0x00
REG_CAM1_Y = 0x04
REG_CAR1_X = 0x08
REG_CAR1_Y = 0x0C
REG_CAR2_X = 0x10
REG_CAR2_Y = 0x14
REG_CAR1_HEADING = 0x18
REG_CAR2_HEADING = 0x1C
REG_CAM2_X = 0x20
REG_CAM2_Y = 0x24
 
CTRL_START = 0x1
CTRL_DONE = 0x2
FLAG_THROTTLE = 0x1
 
Q8 = 1 << 8
 
# Split-screen viewport: each player gets 640x240 (top/bottom halves of 640x480)
VP_WIDTH = 640
VP_HEIGHT = 240
WORLD_WIDTH = 1280
WORLD_HEIGHT = 960
 
 
def to_q16_8(value: float) -> int:
    return int(round(value * Q8)) & 0xFFFFFF
 
 
def from_q16_8(value: int) -> float:
    return value / Q8
 
 
def normalize_stick(raw_value: int) -> float:
    return max(-1.0, min(1.0, (raw_value - 128) / 127.0))
 
 
def stick_to_heading(x_axis: float, y_axis: float, deadzone: float = 0.20) -> int | None:
    if abs(x_axis) < deadzone and abs(y_axis) < deadzone:
        return None
    angle = math.atan2(y_axis, x_axis)
    if angle < 0:
        angle += 2 * math.pi
    return int(round(angle * 1024 / (2 * math.pi))) & 0x3FF
 
 
class ControllerState:
    """Tracks raw input state for one controller."""
 
    def __init__(self, event_path: str) -> None:
        self.event_path = event_path
        self.fd = None
        self.stick_x_raw = 128
        self.stick_y_raw = 128
        self.r2_raw = 0
        self.buttons = {
            "R2": 0,
            "SQUARE": 0,
            "CROSS": 0,
            "CIRCLE": 0,
            "TRIANGLE": 0,
        }
 
    def open(self) -> bool:
        if os.path.exists(self.event_path):
            self.fd = os.open(self.event_path, os.O_RDONLY | os.O_NONBLOCK)
            return True
        return False
 
    def poll(self) -> dict[str, float | bool | str]:
        if self.fd is None:
            return {
                "stick_x": 0.0,
                "stick_y": 0.0,
                "r2_raw": 0,
                "throttle": False,
                "pressed": "None",
            }
 
        while True:
            try:
                data = os.read(self.fd, EVENT_SIZE)
            except BlockingIOError:
                break
            if len(data) < EVENT_SIZE:
                break
 
            _, _, ev_type, code, value = struct.unpack("llHHI", data)
 
            if ev_type == EV_ABS:
                if code == ABS_X:
                    self.stick_x_raw = value
                elif code == ABS_Y:
                    self.stick_y_raw = value
                elif code == ABS_R2:
                    self.r2_raw = value
            elif ev_type == EV_KEY:
                if code == BTN_R2:
                    self.buttons["R2"] = value
                elif code == BTN_SQUARE:
                    self.buttons["SQUARE"] = value
                elif code == BTN_CROSS:
                    self.buttons["CROSS"] = value
                elif code == BTN_CIRCLE:
                    self.buttons["CIRCLE"] = value
                elif code == BTN_TRIANGLE:
                    self.buttons["TRIANGLE"] = value
 
        stick_x = normalize_stick(self.stick_x_raw)
        stick_y = normalize_stick(self.stick_y_raw)
        throttle = (self.r2_raw > 0) or bool(self.buttons["R2"])
        pressed = [name for name, val in self.buttons.items() if val]
 
        return {
            "stick_x": stick_x,
            "stick_y": stick_y,
            "r2_raw": self.r2_raw,
            "throttle": throttle,
            "pressed": ", ".join(pressed) if pressed else "None",
        }
 
 
class PhysicsHardwareInterface:
    def __init__(self, require_controller: bool = True) -> None:
        if not BIT_PATH.exists():
            raise RuntimeError(f"Bitstream not found: {BIT_PATH}")
 
        overlay = Overlay(str(BIT_PATH))
        physics_ip = getattr(overlay, PHYSICS_IP_NAME)
        renderer_ip = getattr(overlay, RENDERER_IP_NAME)
 
        self._overlay = overlay
        self.mmio = physics_ip.mmio
        self.render_mmio = renderer_ip.mmio
 
        # Two controllers for split-screen
        self.controller_p1 = ControllerState(EVENT_PATH_P1)
        self.controller_p2 = ControllerState(EVENT_PATH_P2)
 
        if require_controller:
            if not self.controller_p1.open():
                raise RuntimeError(f"P1 controller not found: {EVENT_PATH_P1}")
            if not self.controller_p2.open():
                print(f"WARNING: P2 controller not found: {EVENT_PATH_P2}")
 
        # Track per-player speed (physics IP is shared, stepped sequentially)
        self.cur_speed_p1 = 0
        self.cur_speed_p2 = 0
 
    # --- Renderer writes ---
 
    def write_camera1(self, cam_x: int, cam_y: int) -> None:
        self.render_mmio.write(REG_CAM1_X, cam_x)
        self.render_mmio.write(REG_CAM1_Y, cam_y)
 
    def write_camera2(self, cam_x: int, cam_y: int) -> None:
        self.render_mmio.write(REG_CAM2_X, cam_x)
        self.render_mmio.write(REG_CAM2_Y, cam_y)
 
    def write_players(
        self,
        car1_x: int,
        car1_y: int,
        car1_heading: int,
        car2_x: int,
        car2_y: int,
        car2_heading: int,
    ) -> None:
        self.render_mmio.write(REG_CAR1_X, car1_x)
        self.render_mmio.write(REG_CAR1_Y, car1_y)
        self.render_mmio.write(REG_CAR1_HEADING, car1_heading)
        self.render_mmio.write(REG_CAR2_X, car2_x)
        self.render_mmio.write(REG_CAR2_Y, car2_y)
        self.render_mmio.write(REG_CAR2_HEADING, car2_heading)
 
    @staticmethod
    def center_camera(
        car_x: float,
        car_y: float,
        vp_w: int = VP_WIDTH,
        vp_h: int = VP_HEIGHT,
        world_w: int = WORLD_WIDTH,
        world_h: int = WORLD_HEIGHT,
    ) -> tuple[int, int]:
        cam_x = max(0, min(int(car_x) - vp_w // 2, world_w - vp_w))
        cam_y = max(0, min(int(car_y) - vp_h // 2, world_h - vp_h))
        return cam_x, cam_y
 
    def update_renderer(
        self, state_p1: PlayerState, state_p2: PlayerState
    ) -> None:
        """Push both car positions + both cameras to the renderer in one shot."""
        # Car world positions (integer pixels for renderer)
        self.write_players(
            car1_x=int(state_p1.x),
            car1_y=int(state_p1.y),
            car1_heading=int(round(state_p1.heading * 1024 / 360.0)) & 0x3FF,
            car2_x=int(state_p2.x),
            car2_y=int(state_p2.y),
            car2_heading=int(round(state_p2.heading * 1024 / 360.0)) & 0x3FF,
        )
        # Cameras track each player
        c1x, c1y = self.center_camera(state_p1.x, state_p1.y)
        c2x, c2y = self.center_camera(state_p2.x, state_p2.y)
        self.write_camera1(c1x, c1y)
        self.write_camera2(c2x, c2y)
 
    # --- Physics IP (shared, time-multiplexed per player) ---
 
    def write_state(
        self,
        cur_x: int,
        cur_y: int,
        cur_heading: int,
        cur_speed: int,
        target_heading: int,
        throttle: bool,
    ) -> None:
        self.mmio.write(REG_CUR_X, cur_x)
        self.mmio.write(REG_CUR_Y, cur_y)
        self.mmio.write(REG_CUR_HEADING, cur_heading)
        self.mmio.write(REG_CUR_SPEED, cur_speed)
        self.mmio.write(REG_TARGET_HEADING, target_heading)
        self.mmio.write(REG_INPUT_FLAGS, FLAG_THROTTLE if throttle else 0)
 
    def read_results(self) -> dict[str, int]:
        return {
            "control": self.mmio.read(REG_CONTROL),
            "next_x": self.mmio.read(REG_NEXT_X) & 0xFFFFFF,
            "next_y": self.mmio.read(REG_NEXT_Y) & 0xFFFFFF,
            "next_heading": self.mmio.read(REG_NEXT_HEADING) & 0x3FF,
            "next_speed": self.mmio.read(REG_NEXT_SPEED) & 0xFFFF,
            "status_flags": self.mmio.read(REG_STATUS_FLAGS) & 0xFF,
        }
 
    def run_tick(self, timeout_s: float = 0.05) -> dict[str, int]:
        self.mmio.write(REG_CONTROL, CTRL_START)
        deadline = perf_counter() + timeout_s
        while perf_counter() < deadline:
            control = self.mmio.read(REG_CONTROL)
            if control & CTRL_DONE:
                return self.read_results()
            sleep(0.0005)
        raise TimeoutError("Physics IP did not assert done before timeout")
 
    def _step_one_player(
        self,
        current_state: PlayerState,
        controller: ControllerState,
        cur_speed: int,
    ) -> tuple[PlayerState, dict, int]:
        """Run one physics tick for a single player."""
        ctrl = controller.poll()
        target_heading = stick_to_heading(ctrl["stick_x"], ctrl["stick_y"])
        if target_heading is None:
            target_heading = int(round(current_state.heading * 1024 / 360.0)) & 0x3FF
 
        self.write_state(
            cur_x=to_q16_8(current_state.x),
            cur_y=to_q16_8(current_state.y),
            cur_heading=int(round(current_state.heading * 1024 / 360.0)) & 0x3FF,
            cur_speed=cur_speed,
            target_heading=target_heading,
            throttle=bool(ctrl["throttle"]),
        )
        result = self.run_tick()
        new_speed = result["next_speed"]
 
        heading_degrees = (result["next_heading"] * 360.0) / 1024.0
        heading_radians = math.radians(heading_degrees)
        speed = from_q16_8(result["next_speed"])
        vx = speed * math.cos(heading_radians)
        vy = speed * math.sin(heading_radians)
 
        next_state = PlayerState(
            player_id=current_state.player_id,
            x=from_q16_8(result["next_x"]),
            y=from_q16_8(result["next_y"]),
            vx=vx,
            vy=vy,
            heading=heading_degrees,
        )
        debug = dict(ctrl)
        debug["status_flags"] = result["status_flags"]
        debug["speed"] = speed
        return next_state, debug, new_speed
 
    def step_both_players(
        self,
        state_p1: PlayerState,
        state_p2: PlayerState,
    ) -> tuple[PlayerState, PlayerState, dict, dict]:
        """
        Step both players through the single physics IP sequentially,
        then update the renderer with both positions.
        """
        # Player 1 physics tick
        next_p1, debug_p1, self.cur_speed_p1 = self._step_one_player(
            state_p1, self.controller_p1, self.cur_speed_p1
        )
        # Player 2 physics tick
        next_p2, debug_p2, self.cur_speed_p2 = self._step_one_player(
            state_p2, self.controller_p2, self.cur_speed_p2
        )
        # Push both to renderer (cars + cameras)
        self.update_renderer(next_p1, next_p2)
 
        return next_p1, next_p2, debug_p1, debug_p2
 
    # --- Backwards-compatible single-player step ---
 
    def step(
        self, current_state: PlayerState
    ) -> tuple[PlayerState, dict[str, float | bool | str | int]]:
        """Single-player step (legacy). Uses P1 controller."""
        next_state, debug, self.cur_speed_p1 = self._step_one_player(
            current_state, self.controller_p1, self.cur_speed_p1
        )
        return next_state, debug
    