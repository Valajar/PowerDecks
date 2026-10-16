"""Shared helpers for the PowerDecks sprite scripts.

Base-game conventions (measured from vanilla sprites):
  Cards     71x95 cell, 1px transparent padding; card spans x 1..69, y 1..93 and its corner rows
            start at x = 4, 2, 2, 1 (card_mask() reproduces this exactly).
  Jokers    1px OUTLINE edge, FACE fill, "JOKER" stacked vertically at (6, 7) in SLATE with 7x8 letters and a
            1px gap, plus the same text rotated 180 degrees in the bottom-right (joker_text()). Jokers with a
            coloured panel keep a 3px white border inside the outline. Plain-colour jokers (Red Card style)
            have no border and a small "JOKER" in the bottom-right.
  Legendary full-bleed two-tone background, cream name plate on rows 78-86 (shadow on row 87), and the
            character on a separate floating layer cell (soul_pos) with a transparent background.
  Vouchers  59px ticket (x 6..64): stub on rows 1-19 with VOUCHER text on rows 12-18, pinched neck on row 20
            (x 8..62), round notches top and bottom centre, dashed white frame around the icon. Tier 1 has a
            light stub, tier 2 a dark stub with a gold bar.
  Decks     3px pure white border with no outline; pattern fills the rest.
  Sleeves   73x95 cells (Card Sleeves mod), open pocket shape with a darker base.
All art must be original; follow the layout, never copy vanilla pixels.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CARD = (71, 95)
SLEEVE = (73, 95)
CLEAR = (0, 0, 0, 0)


def rgb(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (a[3] if len(a) > 3 else 255,)


def dark(c, t): return mix(c, (0, 0, 0, 255), t)
def light(c, t): return mix(c, (255, 255, 255, 255), t)


# Palette shared across sheets; the deck colours double as the identity of each deck everywhere
WHITE = (255, 255, 255, 255)
OUTLINE = rgb('BFC7D5'); FACE = rgb('FDFDFD'); SLATE = rgb('4F6367'); INK = rgb('2B2D42'); PARCH = rgb('F3EFE0')
TITAN = rgb('D9552B'); SIGNET = rgb('6C4AB6'); TYCOON = rgb('2F9E69'); JACK = rgb('37415A')
NAVY = rgb('1B2038'); NAVY_L = rgb('2C3460')
GOLD = rgb('F2C14E'); GOLD_D = rgb('A8741A')
SEAL_RED = rgb('E8463D'); SEAL_BLUE = rgb('3F8EF0'); SEAL_PURPLE = rgb('9B5DE5'); SEAL_GOLD = rgb('F2B93B')
SPEC = rgb('4584FA'); SPEC_L = rgb('9BC4FF'); SPEC_D = rgb('2B4C9B')
UNCOMMON = rgb('4BC292'); RARE = rgb('FE5F55'); TAROT = rgb('A782D1')
LAVENDER = rgb('B8BFE8'); STUB = rgb('F6F6FF'); STUB_INK = rgb('3D5365')


def new(size=CARD):
    return Image.new('RGBA', size, CLEAR)


def in_round(x, y, x0, y0, x1, y1, r):
    if x < x0 or x > x1 or y < y0 or y > y1:
        return False
    dx = dy = 0.0
    if x < x0 + r: dx = x0 + r - x - 0.5
    elif x > x1 - r: dx = x - (x1 - r) - 0.5
    if y < y0 + r: dy = y0 + r - y - 0.5
    elif y > y1 - r: dy = y - (y1 - r) - 0.5
    return not (dx > 0 and dy > 0 and dx * dx + dy * dy > r * r)


def round_mask(w, h, x0, y0, x1, y1, r):
    """mask[y][x] -> bool for a rounded rectangle."""
    return [[in_round(x, y, x0, y0, x1, y1, r) for x in range(w)] for y in range(h)]


def card_mask(size=CARD):
    return round_mask(size[0], size[1], 1, 1, size[0] - 2, size[1] - 2, 5)


def dist(mask, maxd=8):
    """Distance (4-connected) from each masked pixel to the outside: edge pixels are 1, outside is 0."""
    h, w = len(mask), len(mask[0])
    big = maxd + 1
    d = [[big if mask[y][x] else 0 for x in range(w)] for y in range(h)]
    for level in range(1, maxd + 1):
        hits = []
        for y in range(h):
            for x in range(w):
                if d[y][x] != big:
                    continue
                if x in (0, w - 1) or y in (0, h - 1) or level - 1 in (d[y][x - 1], d[y][x + 1], d[y - 1][x], d[y + 1][x]):
                    hits.append((x, y))
        for x, y in hits:
            d[y][x] = level
    return d


def solid(img, x, y):
    return 0 <= x < img.width and 0 <= y < img.height and img.getpixel((x, y))[3] > 0


def outlined(img, colour):
    """Copy with a 1px outline around everything opaque."""
    out = img.copy()
    px = out.load()
    for y in range(img.height):
        for x in range(img.width):
            if not solid(img, x, y) and any(solid(img, x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = colour
    return out


def stamp(img, rows, x0, y0, palette, scale=1):
    """Draws an ASCII pixel map; characters missing from the palette are transparent."""
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            c = palette.get(ch)
            if c is None:
                continue
            for sy in range(scale):
                for sx in range(scale):
                    X, Y = x0 + x * scale + sx, y0 + y * scale + sy
                    if 0 <= X < img.width and 0 <= Y < img.height:
                        px[X, Y] = c


def paste(dst, src, x=0, y=0):
    dst.alpha_composite(src, (x, y))


# ---- lettering (drawn for this mod, sized to the base game's conventions) ----------------------
BIG = {  # 7x8, the vertical JOKER corner text
    'J': ["..#####", "....##.", "....##.", "....##.", "....##.", "##..##.", "##..##.", ".####.."],
    'O': [".#####.", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", ".#####."],
    'K': ["##...##", "##..##.", "##.##..", "####...", "####...", "##.##..", "##..##.", "##...##"],
    'E': ["#######", "##.....", "##.....", "#####..", "##.....", "##.....", "##.....", "#######"],
    'R': ["######.", "##...##", "##...##", "######.", "##.##..", "##..##.", "##...##", "##...##"],
}
MID = {  # 6x7, the VOUCHER stub text
    'V': ["##..##", "##..##", "##..##", "##..##", ".####.", ".####.", "..##.."],
    'O': [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    'U': ["##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    'C': [".#####", "##....", "##....", "##....", "##....", "##....", ".#####"],
    'H': ["##..##", "##..##", "##..##", "######", "##..##", "##..##", "##..##"],
    'E': ["######", "##....", "##....", "#####.", "##....", "##....", "######"],
    'R': ["#####.", "##..##", "##..##", "#####.", "##.##.", "##..##", "##..##"],
}
SMALL = {  # 5 tall, name plates and small corner text
    'A': [".##.", "#..#", "####", "#..#", "#..#"], 'C': [".###", "#...", "#...", "#...", ".###"],
    'D': ["###.", "#..#", "#..#", "#..#", "###."], 'E': ["####", "#...", "###.", "#...", "####"],
    'G': [".###", "#...", "#.##", "#..#", ".###"], 'J': ["..##", "...#", "...#", "#..#", ".##."],
    'K': ["#..#", "#.#.", "##..", "#.#.", "#..#"], 'N': ["#..#", "##.#", "#.##", "#..#", "#..#"],
    'O': [".##.", "#..#", "#..#", "#..#", ".##."], 'R': ["###.", "#..#", "###.", "#.#.", "#..#"],
    'S': [".###", "#...", ".##.", "...#", "###."], 'T': ["###", ".#.", ".#.", ".#.", ".#."],
    'Y': ["#.#", "#.#", ".#.", ".#.", ".#."], 'Z': ["####", "...#", ".##.", "#...", "####"],
}


def text_width(s, font):
    return sum(len(font[ch][0]) + 1 for ch in s) - 1


def text(img, s, x, y, font, colour):
    for ch in s:
        stamp(img, font[ch], x, y, {'#': colour})
        x += len(font[ch][0]) + 1


def joker_text(img, colour):
    """The vertical JOKER in the top-left and its 180-degree copy in the bottom-right."""
    px = img.load()
    for i, ch in enumerate("JOKER"):
        for r, row in enumerate(BIG[ch]):
            for q, c in enumerate(row):
                if c == '#':
                    x, y = 6 + q, 7 + i * 9 + r
                    px[x, y] = colour
                    px[70 - x, 94 - y] = colour


# ---- output -----------------------------------------------------------------------------------
def sheet(cells, size=CARD):
    out = new((size[0] * len(cells), size[1]))
    for i, cell in enumerate(cells):
        assert cell.size == size, f"cell {i} is {cell.size}, expected {size}"
        paste(out, cell, i * size[0], 0)
    return out


def save_sheet(name, img):
    """Writes assets/1x/<name>.png and the nearest-neighbour 2x copy."""
    (ROOT / 'assets' / '1x').mkdir(parents=True, exist_ok=True)
    (ROOT / 'assets' / '2x').mkdir(parents=True, exist_ok=True)
    img.save(ROOT / 'assets' / '1x' / f'{name}.png')
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(ROOT / 'assets' / '2x' / f'{name}.png')
