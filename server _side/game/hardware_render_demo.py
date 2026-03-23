import time
from pathlib import Path

from pynq import Overlay

BITSTREAM_PATH = Path(__file__).resolve().parent / "top_design.bit"
TARGET_FPS = 60
RUN_DURATION_SECONDS = 10.0
STEP_PIXELS = 4

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

WORLD_W = 20 * 64
WORLD_H = 15 * 64
SCREEN_W = 640
SCREEN_H = 480
MAX_CAM_X = WORLD_W - SCREEN_W
MAX_CAM_Y = WORLD_H - SCREEN_H


def set_camera(regs, x: int, y: int) -> None:
    regs.write(REG_CAM1_X, int(x))
    regs.write(REG_CAM1_Y, int(y))


def set_camera2(regs, x: int, y: int) -> None:
    regs.write(REG_CAM2_X, int(x))
    regs.write(REG_CAM2_Y, int(y))


def hide_cars(regs) -> None:
    regs.write(REG_CAR1_X, 0)
    regs.write(REG_CAR1_Y, 0)
    regs.write(REG_CAR2_X, 0)
    regs.write(REG_CAR2_Y, 0)
    regs.write(REG_CAR1_HEADING, 0)
    regs.write(REG_CAR2_HEADING, 0)


def horizontal_sweep_positions(step_pixels: int = STEP_PIXELS) -> list[int]:
    xs = list(range(0, MAX_CAM_X + 1, step_pixels))
    if xs[-1] != MAX_CAM_X:
        xs.append(MAX_CAM_X)
    return xs + xs[-2:0:-1]


def main() -> None:
    overlay = Overlay(str(BITSTREAM_PATH))
    regs = overlay.racing_renderer_0.mmio
    positions = horizontal_sweep_positions()
    delay = 1.0 / TARGET_FPS if TARGET_FPS > 0 else 0.0

    hide_cars(regs)
    set_camera(regs, 0, 0)
    set_camera2(regs, 0, 0)

    print(f"Bitstream loaded from {BITSTREAM_PATH}!", flush=True)
    print(f"Overlay IP blocks: {overlay.ip_dict.keys()}", flush=True)
    print(f"Camera range: (0,0) to ({MAX_CAM_X},{MAX_CAM_Y})", flush=True)
    print(
        f"[hardware-demo] starting duration={RUN_DURATION_SECONDS:.1f}s target_fps={TARGET_FPS}",
        flush=True,
    )

    start_time = time.perf_counter()
    window_start = start_time
    updates_in_window = 0
    total_updates = 0
    index = 0

    while True:
        x = positions[index]
        y = MAX_CAM_Y // 2
        set_camera(regs, x, y)
        set_camera2(regs, x, y)

        updates_in_window += 1
        total_updates += 1
        index = (index + 1) % len(positions)

        now = time.perf_counter()
        elapsed = now - start_time
        window_elapsed = now - window_start

        if window_elapsed >= 1.0:
            fps = updates_in_window / window_elapsed
            print(f"[hardware-demo] elapsed={elapsed:.1f}s fps={fps:.1f}", flush=True)
            window_start = now
            updates_in_window = 0

        if RUN_DURATION_SECONDS > 0 and elapsed >= RUN_DURATION_SECONDS:
            break

        if delay > 0:
            time.sleep(delay)

    average_fps = total_updates / (time.perf_counter() - start_time)
    print(f"[hardware-demo] average_fps={average_fps:.1f}", flush=True)


if __name__ == "__main__":
    main()
