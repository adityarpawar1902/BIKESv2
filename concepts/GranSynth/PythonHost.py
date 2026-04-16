import pygame
import sys
from pythonosc import udp_client

# --- OSC ---
osc_client = udp_client.SimpleUDPClient("127.0.0.1", 57120)

# --- Music ---
NOTES = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
SCALES = {
    "Major":      [0,2,4,5,7,9,11],
    "Minor":      [0,2,3,5,7,8,10],
    "Dorian":     [0,2,3,5,7,9,10],
    "Mixolydian": [0,2,4,5,7,9,10],
}
QUALITIES = {
    "Major":      ["maj","min","min","maj","maj","min","dim"],
    "Minor":      ["min","dim","maj","min","min","maj","maj"],
    "Dorian":     ["min","min","maj","maj","min","dim","maj"],
    "Mixolydian": ["maj","min","dim","maj","min","min","maj"],
}
CHORD_SEMIS = {"maj":[0,4,7], "min":[0,3,7], "dim":[0,3,6]}
ROMAN       = ["I","II","III","IV","V","VI"]

def pad_label(root, scale, degree):
    semi = SCALES[scale][degree]
    qual = QUALITIES[scale][degree]
    note = NOTES[(root + semi) % 12]
    suffix = "" if qual == "maj" else ("m" if qual == "min" else "°")
    roman  = ROMAN[degree] if qual == "maj" else ROMAN[degree].lower()
    return roman, f"{note}{suffix}", qual

# ---------------------------------------------------------------------------
# PALETTE  (shared with receiver)
# ---------------------------------------------------------------------------
C_BG        = (247, 245, 240)   # warm off-white page
C_SURFACE   = (255, 255, 255)   # card / pad face
C_BORDER    = (200, 196, 190)   # idle border
C_INK       = ( 26,  25,  22)   # near-black text / active pad bg
C_PRESS    = (1, 24, 87)
C_MUTED     = (136, 135, 128)   # secondary labels
C_ACCENT    = (252, 226, 28)   # teal — active roman numeral
C_ACT_SUB   = (100, 160, 130)   # active quality label (muted teal)
C_DROP_BG   = (255, 255, 255)
C_DROP_HL   = (236, 234, 228)   # dropdown item hover

# ---------------------------------------------------------------------------
pygame.init()
W, H = 900, 640
screen = pygame.display.set_mode((W, H))
pygame.display.set_caption("Chord Grid — Host")
pygame.mouse.set_visible(False)
clock    = pygame.time.Clock()

font_roman   = pygame.font.SysFont("Arial", 18, bold=True)
font_note    = pygame.font.SysFont("Arial", 48, bold=True)
font_qual    = pygame.font.SysFont("Arial", 15)
font_drop    = pygame.font.SysFont("Arial", 16, bold=True)
font_hint    = pygame.font.SysFont("Arial", 13)

# State
root        = 0
scale       = "Major"
active      = -1
root_open   = False
scale_open  = False

HEADER = 68
MARGIN = 16
GAP    = 8

def pad_rects():
    gw = W - 2*MARGIN
    gh = H - HEADER - MARGIN
    pw = (gw - 2*GAP) // 3
    ph = (gh -   GAP) // 2
    rects = []
    for i in range(6):
        c, r = i % 3, i // 3
        rects.append(pygame.Rect(MARGIN + c*(pw+GAP), HEADER + r*(ph+GAP), pw, ph))
    return rects

def draw_rounded_rect(surf, color, rect, radius, border=0, border_color=None):
    pygame.draw.rect(surf, color, rect, border_radius=radius)
    if border and border_color:
        pygame.draw.rect(surf, border_color, rect, border, border_radius=radius)

def draw_dropdown(surf, x, y, w, label, options, is_open):
    box = pygame.Rect(x, y, w, 36)
    draw_rounded_rect(surf, C_DROP_BG, box, 6, 2, C_BORDER)
    lbl = font_drop.render(label + "  ▾", True, C_INK)
    surf.blit(lbl, (x + 10, y + 8))
    if is_open:
        oh = len(options) * 34
        panel = pygame.Rect(x, y + 38, w, oh)
        draw_rounded_rect(surf, C_DROP_BG, panel, 6, 1, C_BORDER)
        mx, my = pygame.mouse.get_pos()
        for i, opt in enumerate(options):
            r = pygame.Rect(x + 2, y + 40 + i*34, w - 4, 32)
            if r.collidepoint(mx, my):
                draw_rounded_rect(surf, C_DROP_HL, r, 4)
            surf.blit(font_drop.render(opt, True, C_INK), (r.x + 8, r.y + 7))

def select_pad(i):
    global active
    if active == i:
        active = -1
        osc_client.send_message("/chord", [NOTES[root], scale, 0])
    else:
        active = i
        osc_client.send_message("/chord", [NOTES[root], scale, i + 1])

running = True
while running:
    screen.fill(C_BG)
    mx, my = pygame.mouse.get_pos()
    rects  = pad_rects()

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
            running = False

        elif event.type == pygame.MOUSEBUTTONDOWN:
            clicked = False

            # Root dropdown
            root_box = pygame.Rect(MARGIN, 16, 80, 36)
            if root_box.collidepoint(mx, my):
                root_open = not root_open; scale_open = False; clicked = True
            elif root_open:
                for i, n in enumerate(NOTES):
                    if pygame.Rect(MARGIN, 56 + i*34, 80, 32).collidepoint(mx, my):
                        root = i; root_open = False; clicked = True
                if not clicked:
                    root_open = False; clicked = True

            # Scale dropdown
            scale_box = pygame.Rect(MARGIN + 90, 16, 160, 36)
            if not clicked and scale_box.collidepoint(mx, my):
                scale_open = not scale_open; root_open = False; clicked = True
            elif not clicked and scale_open:
                for i, s in enumerate(SCALES):
                    if pygame.Rect(MARGIN + 90, 56 + i*34, 160, 32).collidepoint(mx, my):
                        scale = s; scale_open = False; clicked = True
                if not clicked:
                    scale_open = False; clicked = True

            if not clicked and not root_open and not scale_open:
                for i, rect in enumerate(rects):
                    if rect.collidepoint(mx, my):
                        select_pad(i); clicked = True; break

        elif event.type == pygame.KEYDOWN:
            for idx, key in enumerate([pygame.K_1,pygame.K_2,pygame.K_3,
                                        pygame.K_4,pygame.K_5,pygame.K_6]):
                if event.key == key:
                    select_pad(idx)

    # --- Draw pads ---
    for i, rect in enumerate(rects):
        is_active = (active == i)
        is_hover  = rect.collidepoint(mx, my) and not is_active
        roman, note_str, qual = pad_label(root, scale, i)

        bg  = C_PRESS    if is_active else (C_DROP_HL if is_hover else C_SURFACE)
        bdr = C_PRESS    if is_active else (C_MUTED   if is_hover else C_BORDER)

        draw_rounded_rect(screen, bg, rect, 10, 2, bdr)

        # Roman numeral (top-left)
        r_col = C_ACCENT if is_active else C_MUTED
        r_txt = font_roman.render(roman, True, r_col)
        screen.blit(r_txt, (rect.x + 14, rect.y + 12))

        # Key number hint (top-right)
        h_txt = font_hint.render(str(i+1), True, C_MUTED if not is_active else (80, 100, 90))
        screen.blit(h_txt, (rect.right - 20, rect.y + 12))

        # Note name (centre)
        n_col = (255, 255, 255) if is_active else C_INK
        n_txt = font_note.render(note_str, True, n_col)
        screen.blit(n_txt, (rect.centerx - n_txt.get_width()//2,
                             rect.centery - n_txt.get_height()//2 + 4))

        # Quality label (bottom-centre)
        q_col = C_ACT_SUB if is_active else C_MUTED
        q_txt = font_qual.render(qual, True, q_col)
        screen.blit(q_txt, (rect.centerx - q_txt.get_width()//2, rect.bottom - 22))

    # --- Draw dropdowns on top ---
    draw_dropdown(screen, MARGIN,      16,  80, NOTES[root],  NOTES,             root_open)
    draw_dropdown(screen, MARGIN + 90, 16, 160, scale,        list(SCALES.keys()), scale_open)

    pygame.display.flip()
    clock.tick(60)

pygame.quit()
