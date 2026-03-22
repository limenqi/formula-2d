from pathlib import Path

import pygame

from software_render.map_renderer import (
    MAP_HEIGHT_TILES,
    MAP_WIDTH_TILES,
    TILE_SIZE,
    draw_map,
    init_map_renderer,
    load_tilemap,
    load_tileset,
    poll_map_events,
    shutdown_map_renderer,
)


TRACK_META_PATH = Path(
    "InfoProcTopLevel_upgrade/InfoProcTopLevel.ip_user_files/mem_init_files/track_meta.mem"
)

OVERLAY_COLORS = {
    "00": (0, 0, 0, 0),
    "01": (0, 180, 0, 90),
    "02": (180, 0, 0, 110),
    "04": (0, 120, 255, 110),
}


def load_track_meta(path: Path = TRACK_META_PATH) -> list[list[str]]:
    values: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        values.extend(part.strip().upper() for part in line.split() if part.strip())

    expected = MAP_WIDTH_TILES * MAP_HEIGHT_TILES
    if len(values) != expected:
        raise ValueError(f"track_meta has {len(values)} cells, expected {expected}")

    rows: list[list[str]] = []
    for row in range(MAP_HEIGHT_TILES):
        start = row * MAP_WIDTH_TILES
        rows.append(values[start : start + MAP_WIDTH_TILES])
    return rows


def draw_overlay(screen: pygame.Surface, font: pygame.font.Font, track_meta: list[list[str]]) -> None:
    for row in range(MAP_HEIGHT_TILES):
        for col in range(MAP_WIDTH_TILES):
            x = col * TILE_SIZE
            y = row * TILE_SIZE
            cell = track_meta[row][col]

            color = OVERLAY_COLORS.get(cell)
            if color is not None and color[3] > 0:
                overlay = pygame.Surface((TILE_SIZE, TILE_SIZE), pygame.SRCALPHA)
                overlay.fill(color)
                screen.blit(overlay, (x, y))

            label = font.render(cell, True, (0, 0, 0))
            screen.blit(label, (x + 3, y + 3))

    index_font = pygame.font.SysFont(None, 18)
    for col in range(MAP_WIDTH_TILES):
        label = index_font.render(str(col), True, (255, 255, 0))
        screen.blit(label, (col * TILE_SIZE + TILE_SIZE // 2 - 5, 2))
    for row in range(MAP_HEIGHT_TILES):
        label = index_font.render(str(row), True, (255, 255, 0))
        screen.blit(label, (2, row * TILE_SIZE + TILE_SIZE // 2 - 5))


def main() -> None:
    screen, font = init_map_renderer()
    tilemap = load_tilemap()
    tileset = load_tileset()
    track_meta = load_track_meta()

    try:
        running = True
        while running:
            running = poll_map_events()
            draw_map(screen, font, tilemap, tileset, {})
            draw_overlay(screen, font, track_meta)
            pygame.display.flip()
    finally:
        shutdown_map_renderer()


if __name__ == "__main__":
    main()
