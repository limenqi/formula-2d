import time

import numpy as np
import pygame
from pynq.lib.video import VideoMode
from pynq.overlays.base import BaseOverlay

from game.models import PlayerState
from software_render.map_renderer import (
    BACKGROUND_COLOR,
    DEFAULT_TILE_COLOR,
    GRID_COLOR,
    MAP_HEIGHT_TILES,
    MAP_WIDTH_TILES,
    PLAYER_COLORS,
    TILE_COLORS,
    TILE_SIZE,
    WINDOW_HEIGHT,
    WINDOW_WIDTH,
    load_tilemap,
    load_tileset,
)

TARGET_FPS = 60
RUN_DURATION_SECONDS = 0.0


def draw_map_to_surface(
    screen: pygame.Surface,
    font: pygame.font.Font,
    tilemap: list[list[int]],
    tileset: list[pygame.Surface],
    players: dict[int, PlayerState],
) -> None:
    screen.fill(BACKGROUND_COLOR)

    for row_index in range(MAP_HEIGHT_TILES):
        row = tilemap[row_index]
        for col_index in range(MAP_WIDTH_TILES):
            tile_id = row[col_index]
            rect = pygame.Rect(
                col_index * TILE_SIZE,
                row_index * TILE_SIZE,
                TILE_SIZE,
                TILE_SIZE,
            )
            if 0 <= tile_id < len(tileset):
                screen.blit(tileset[tile_id], rect.topleft)
            else:
                color = TILE_COLORS.get(tile_id, DEFAULT_TILE_COLOR)
                pygame.draw.rect(screen, color, rect)
            pygame.draw.rect(screen, GRID_COLOR, rect, width=1)

    for player_id, player in players.items():
        color = PLAYER_COLORS.get(player_id, (255, 255, 255))
        px = int(player.x)
        py = int(player.y)
        pygame.draw.circle(screen, color, (px, py), 8)
        label = font.render(str(player_id), True, (0, 0, 0))
        screen.blit(label, (px - 5, py - 8))


def surface_to_bgr_frame(screen: pygame.Surface, frame: np.ndarray) -> None:
    rgb = pygame.surfarray.array3d(screen)
    frame[:, :, :] = np.transpose(rgb, (1, 0, 2))[:, :, ::-1]


def main() -> None:
    pygame.font.init()
    overlay = BaseOverlay("base.bit")
    hdmi_out = overlay.video.hdmi_out
    mode = VideoMode(WINDOW_WIDTH, WINDOW_HEIGHT, 24, fps=60)

    screen = pygame.Surface((WINDOW_WIDTH, WINDOW_HEIGHT))
    font = pygame.font.SysFont(None, 24)
    tilemap = load_tilemap()
    tileset = load_tileset()
    players: dict[int, PlayerState] = {}
    clock = pygame.time.Clock()
    start_time = time.perf_counter()
    stats_window_start = start_time
    frames_in_window = 0

    print(
        "[hdmi-demo] loading PYNQ base overlay; this replaces the current PL design with base.bit",
        flush=True,
    )

    hdmi_out.configure(mode)
    hdmi_out.start()

    try:
        running = True
        while running:
            draw_map_to_surface(screen, font, tilemap, tileset, players)
            frame = hdmi_out.newframe()
            surface_to_bgr_frame(screen, frame)
            hdmi_out.writeframe(frame)
            frames_in_window += 1

            now = time.perf_counter()
            elapsed = now - start_time
            stats_elapsed = now - stats_window_start
            if stats_elapsed >= 1.0:
                fps = frames_in_window / stats_elapsed
                print(
                    f"[hdmi-demo] elapsed={elapsed:.1f}s fps={fps:.1f}",
                    flush=True,
                )
                stats_window_start = now
                frames_in_window = 0

            if RUN_DURATION_SECONDS > 0 and elapsed >= RUN_DURATION_SECONDS:
                running = False

            if TARGET_FPS > 0:
                clock.tick(TARGET_FPS)
    finally:
        hdmi_out.stop()
        pygame.quit()


if __name__ == "__main__":
    main()
