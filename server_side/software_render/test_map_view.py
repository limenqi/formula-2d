from game.models import PlayerState
from software_render.map_renderer import (
    draw_map,
    init_map_renderer,
    load_tilemap,
    load_tileset,
    poll_map_events,
    shutdown_map_renderer,
)


def main() -> None:
    screen, font = init_map_renderer()
    tilemap = load_tilemap()
    tileset = load_tileset()
    players: dict[int, PlayerState] = {}

    try:
        running = True
        while running:
            running = poll_map_events()
            draw_map(screen, font, tilemap, tileset, players)
    finally:
        shutdown_map_renderer()


if __name__ == "__main__":
    main()
