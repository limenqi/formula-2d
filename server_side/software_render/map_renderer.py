from pathlib import Path

import pygame

from game.models import PlayerState


MAP_WIDTH_TILES = 20
MAP_HEIGHT_TILES = 15
SOURCE_TILE_SIZE = 64
TILE_SIZE = 32
WINDOW_WIDTH = MAP_WIDTH_TILES * TILE_SIZE
WINDOW_HEIGHT = MAP_HEIGHT_TILES * TILE_SIZE
BACKGROUND_COLOR = (12, 16, 24)
GRID_COLOR = (30, 36, 50)
PLAYER_COLORS = {
    1: (255, 80, 80),
    2: (80, 160, 255),
}

TILE_COLORS = {
    0x00: (34, 139, 34),
    0x07: (90, 90, 90),
    0x0E: (220, 220, 120),
    0x1C: (60, 60, 60),
    0x17: (160, 160, 160),
    0x1B: (120, 120, 120),
    0x1A: (180, 180, 180),
    0x1E: (200, 120, 80),
}
DEFAULT_TILE_COLOR = (70, 70, 70)
TILE_COUNT = 32


def init_map_renderer() -> tuple[pygame.Surface, pygame.font.Font]:
    pygame.init()
    screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
    pygame.display.set_caption("Racing Server Map")
    font = pygame.font.SysFont(None, 24)
    return screen, font


def poll_map_events() -> bool:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            return False
    return True


def load_tilemap(path: str = "renderer/tilemap.hex") -> list[list[int]]:
    tile_values = []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        text = line.strip()
        if text == "":
            continue
        tile_values.append(int(text, 16))

    expected_tiles = MAP_WIDTH_TILES * MAP_HEIGHT_TILES
    if len(tile_values) < expected_tiles:
        raise ValueError(
            f"tilemap has {len(tile_values)} tiles, expected at least {expected_tiles}"
        )

    grid = []
    for row in range(MAP_HEIGHT_TILES):
        start = row * MAP_WIDTH_TILES
        end = start + MAP_WIDTH_TILES
        grid.append(tile_values[start:end])
    return grid


def _decode_rgb565(value: int) -> tuple[int, int, int]:
    red = ((value >> 11) & 0x1F) * 255 // 31
    green = ((value >> 5) & 0x3F) * 255 // 63
    blue = (value & 0x1F) * 255 // 31
    return red, green, blue


def load_tileset(path: str = "renderer/tileset.hex") -> list[pygame.Surface]:
    pixel_values = []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        text = line.strip()
        if text == "":
            continue
        pixel_values.append(int(text, 16))

    pixels_per_tile = SOURCE_TILE_SIZE * SOURCE_TILE_SIZE
    expected_pixels = TILE_COUNT * pixels_per_tile
    if len(pixel_values) < expected_pixels:
        raise ValueError(
            f"tileset has {len(pixel_values)} pixels, expected at least {expected_pixels}"
        )

    tiles: list[pygame.Surface] = []
    for tile_index in range(TILE_COUNT):
        tile_surface = pygame.Surface((SOURCE_TILE_SIZE, SOURCE_TILE_SIZE))
        tile_start = tile_index * pixels_per_tile

        for py in range(SOURCE_TILE_SIZE):
            row_start = tile_start + py * SOURCE_TILE_SIZE
            for px in range(SOURCE_TILE_SIZE):
                color = _decode_rgb565(pixel_values[row_start + px])
                tile_surface.set_at((px, py), color)

        if TILE_SIZE != SOURCE_TILE_SIZE:
            tile_surface = pygame.transform.scale(tile_surface, (TILE_SIZE, TILE_SIZE))

        tiles.append(tile_surface)

    return tiles


def draw_map(
    screen: pygame.Surface,
    font: pygame.font.Font,
    tilemap: list[list[int]],
    tileset: list[pygame.Surface],
    players: dict[int, PlayerState],
) -> None:
    screen.fill(BACKGROUND_COLOR)

    for row_index, row in enumerate(tilemap):
        for col_index, tile_id in enumerate(row):
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

    pygame.display.flip()


def shutdown_map_renderer() -> None:
    pygame.quit()
