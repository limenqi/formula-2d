import pygame


WINDOW_WIDTH = 800
WINDOW_HEIGHT = 600
BACKGROUND_COLOR = (18, 24, 38)
TEXT_COLOR = (235, 240, 255)
ACCENT_COLOR = (90, 200, 160)


def init_menu_ui() -> tuple[pygame.Surface, pygame.font.Font, pygame.font.Font]:
    pygame.init()
    screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
    pygame.display.set_caption("Racing Server Menu")
    title_font = pygame.font.SysFont(None, 56)
    body_font = pygame.font.SysFont(None, 32)
    return screen, title_font, body_font


def poll_menu_events() -> bool:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            return False
    return True


def draw_menu(
    screen: pygame.Surface,
    title_font: pygame.font.Font,
    body_font: pygame.font.Font,
    connected_players: int,
    required_players: int,
    player_ids: list[int],
) -> None:
    screen.fill(BACKGROUND_COLOR)

    title = title_font.render("Racing Game Server", True, TEXT_COLOR)
    status = body_font.render("Waiting for players...", True, ACCENT_COLOR)
    count = body_font.render(
        f"Connected: {connected_players} / {required_players}",
        True,
        TEXT_COLOR,
    )
    players = body_font.render(
        f"Players: {', '.join(str(pid) for pid in player_ids) or 'None'}",
        True,
        TEXT_COLOR,
    )

    screen.blit(title, (60, 80))
    screen.blit(status, (60, 180))
    screen.blit(count, (60, 240))
    screen.blit(players, (60, 290))

    pygame.display.flip()


def shutdown_menu_ui() -> None:
    pygame.quit()
