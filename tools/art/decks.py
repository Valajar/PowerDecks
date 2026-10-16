"""Deck backs, Card Sleeves and the mod icon.

    decks    5 cells of 71x95: Titan, Signet, Tycoon, Jack of All Trades, Master of All Trades
    sleeves  5 cells of 73x95 in the same order
    icon     one 34x34 mod icon

Light comes from the top-left everywhere: top/left edges take the light tone, bottom/right edges the shadow tone,
and every outline is a dark tone of the object's own colour. Patterns are mirrored about the card centre so the
backs read as symmetric, like the vanilla ones. Each sleeve reuses its deck's colour, pattern and emblem.
"""
import math

from common import (CARD, SLEEVE, WHITE, PARCH, TITAN, SIGNET, TYCOON, JACK, NAVY, NAVY_L, GOLD, GOLD_D,
                    SEAL_RED, SEAL_BLUE, SEAL_PURPLE, SEAL_GOLD, new, card_mask, round_mask, dist, mix, dark, light,
                    sheet)

CX, CY = 35, 47          # card centre (the card spans x 1..69, y 1..93)


# ---- colour ramps -------------------------------------------------------------------------------
def ramp(c, hi=0.24, lo=0.26, ol=0.58):
    """light / mid / shadow / outline for one material."""
    return {'hi': light(c, hi), 'mid': c, 'lo': dark(c, lo), 'ol': dark(c, ol)}


GOLD_R = {'hi': light(GOLD, 0.5), 'mid': GOLD, 'lo': mix(GOLD, GOLD_D, 0.6), 'ol': dark(GOLD_D, 0.35)}
NAVY_RAY = mix(NAVY, NAVY_L, 0.5)


# ---- small drawing helpers ----------------------------------------------------------------------
def put(img, x, y, c):
    if c is not None and 0 <= x < img.width and 0 <= y < img.height:
        img.load()[x, y] = c


def disc(cx, cy, r):
    """Pixels of a filled circle (with the r^2 + 0.8r rule, so the flat tops have no single-pixel nubs)."""
    out = set()
    lim = r * r + r * 0.8
    for y in range(int(cy - r) - 2, int(cy + r) + 3):
        for x in range(int(cx - r) - 2, int(cx + r) + 3):
            if (x - cx) ** 2 + (y - cy) ** 2 <= lim:
                out.add((x, y))
    return out


def ring(cx, cy, r0, r1):
    return disc(cx, cy, r1) - disc(cx, cy, r0)


N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def border_of(pts):
    """4-connected outside neighbours of a pixel set."""
    return {(x + dx, y + dy) for x, y in pts for dx, dy in N4} - pts


def outline(img, pts, c, skip=()):
    for p in border_of(pts):
        if p not in skip:
            put(img, *p, c)


def bevel(img, pts, r, inner=None):
    """1px bevel: top/left edge light, bottom/right edge shadow, the rest mid."""
    for x, y in pts:
        top = (x, y - 1) not in pts or (x - 1, y) not in pts
        bot = (x, y + 1) not in pts or (x + 1, y) not in pts
        put(img, x, y, r['hi'] if top and not bot else r['lo'] if bot and not top else (inner or r['mid']))


def dome(img, pts, cx, cy, rad, r, hi_at=0.42, lo_at=-0.30):
    """Sphere-like shading on a round shape, lit from the top-left."""
    for x, y in pts:
        t = (-(x - cx) - (y - cy)) / (rad * 1.414)
        put(img, x, y, r['hi'] if t > hi_at else r['lo'] if t < lo_at else r['mid'])


def drop_shadow(img, pts, c):
    """1px shadow below-right of a shape (light comes from the top-left)."""
    for x, y in pts:
        if (x + 1, y + 1) not in pts:
            put(img, x + 1, y + 1, c)


def lit_side(x, y, cx, cy):
    """+ on the top-left half of a round shape, - on the bottom-right half."""
    return -(x - cx) - (y - cy)


def mirror4(pts, cx=CX, cy=CY):
    return {(X, Y) for x, y in pts for X in (x, 2 * cx - x) for Y in (y, 2 * cy - y)}


def glyph(rows, x0, y0, ch='#'):
    return {(x0 + x, y0 + y) for y, row in enumerate(rows) for x, c in enumerate(row) if c == ch}


# ---- emblems (all centred on cx, cy) ------------------------------------------------------------
def medallion(img, cx, cy, rad, main, fill):
    """A round plate: outline in the deck's dark tone, a bevelled white ring and a recessed centre."""
    r = ramp(main)
    plate = disc(cx, cy, rad)
    outline(img, plate, r['ol'])
    white_lo = mix(WHITE, main, 0.2)
    for x, y in plate:
        put(img, x, y, WHITE if lit_side(x, y, cx, cy) >= -3 else white_lo)
    inner = disc(cx, cy, rad - 2.3)
    for x, y in inner:
        put(img, x, y, fill)
    # the recess: its top-left wall is in shadow, its bottom-right wall catches the light
    for x, y in inner - disc(cx, cy, rad - 3.3):
        t = lit_side(x, y, cx, cy)
        put(img, x, y, r['ol'] if t > 4 else dark(fill, 0.12) if t > -4 else fill)
    return inner


SHIELD = [
    "#################",
    "#################",
    "#################",
    "#################",
    "#################",
    "#################",
    "#################",
    "#################",
    "#################",
    ".###############.",
    ".###############.",
    "..#############..",
    "..#############..",
    "...###########...",
    "....#########....",
    ".....#######.....",
    "......#####......",
    ".......###.......",
    "........#........",
]


def emblem_titan(img, cx, cy, rad=17):
    tr = ramp(TITAN)
    medallion(img, cx, cy, rad, TITAN, dark(TITAN, 0.6))
    pts = glyph(SHIELD, cx - 8, cy - 10)
    outline(img, pts, GOLD_R['ol'])
    # shield face: the classic split light, lit left half and shaded right half, plus a bevelled rim
    for x, y in pts:
        put(img, x, y, light(GOLD, 0.12) if x < cx else GOLD if x == cx else GOLD_R['lo'])
    rim = {p for p in pts if any((p[0] + dx, p[1] + dy) not in pts for dx, dy in N4)}
    for x, y in rim:
        put(img, x, y, GOLD_R['hi'] if (x < cx and y < cy + 6) or y == cy - 10 else GOLD_D)
    # three rank chevrons in the deck's own red, following the shield's point, kept inside the rim
    inside = pts - rim
    for low in (-3, 1, 5):
        for x in range(cx - 7, cx + 8):
            v = cy + low - (abs(x - cx) * 2) // 3
            for y, c in ((v, light(TITAN, 0.25) if x <= cx else TITAN), (v + 1, dark(TITAN, 0.2)), (v + 2, tr['ol'])):
                if (x, y) in inside:
                    put(img, x, y, c)
    # sheen on the upper-left of the shield
    for i in range(3):
        put(img, cx - 6 + i, cy - 8, light(GOLD, 0.7))
    put(img, cx - 6, cy - 7, light(GOLD, 0.7))


def seal(img, cx, cy, base):
    r = ramp(base, 0.38, 0.3, 0.55)
    pts = disc(cx, cy, 3.7)
    outline(img, pts, r['ol'])
    dome(img, pts, cx, cy, 4, r, 0.4, -0.25)
    # a stamped centre: recessed ring (shadow top-left, light bottom-right)
    for x, y in ring(cx, cy, 0.6, 1.8):
        t = lit_side(x, y, cx, cy)
        put(img, x, y, r['lo'] if t > 0 else r['hi'] if t < 0 else r['mid'])
    put(img, cx, cy, r['mid'])
    put(img, cx - 2, cy - 2, WHITE)


def emblem_signet(img, cx, cy, rad=17):
    medallion(img, cx, cy, rad, SIGNET, PARCH)
    # a small purple lozenge holds the four seals together
    loz = {(cx + dx, cy + dy) for dx in range(-3, 4) for dy in range(-3, 4) if abs(dx) + abs(dy) <= 3}
    bevel(img, loz, ramp(SIGNET, 0.3))
    put(img, cx, cy, light(SIGNET, 0.6))
    for (dx, dy), c in (((0, -7), SEAL_RED), ((7, 0), SEAL_BLUE), ((0, 7), SEAL_PURPLE), ((-7, 0), SEAL_GOLD)):
        seal(img, cx + dx, cy + dy, c)


DOLLAR = [
    "..#..",
    ".####",
    "##.#.",
    "##.#.",
    ".###.",
    "..###",
    "..#.#",
    "####.",
    "..#..",
]


def emblem_tycoon(img, cx, cy, rad=17):
    medallion(img, cx, cy, rad, TYCOON, dark(TYCOON, 0.42))
    fx, fy = cx - 1, cy - 1                  # the coin face, its edge shows below-right
    face = disc(fx, fy, 10)
    edge = disc(fx + 1, fy + 2, 10) | disc(fx + 1, fy + 1, 10)
    outline(img, face | edge, GOLD_R['ol'])
    for x, y in edge - face:
        put(img, x, y, GOLD_D if (x + y) % 2 else mix(GOLD_D, GOLD, 0.35))     # reeded edge
    for x, y in face:
        d2 = math.hypot(x - fx, y - fy)
        t = lit_side(x, y, fx, fy)
        if d2 > 8.4:
            c = GOLD_R['hi'] if t > 3 else GOLD_R['lo'] if t < -5 else GOLD           # raised rim
        elif d2 > 7.3:
            c = GOLD_R['lo'] if t > -1 else GOLD_R['hi']                               # step down into the field
        else:
            c = light(GOLD, 0.28) if t > 7 else GOLD
        put(img, x, y, c)
    gl = glyph(DOLLAR, fx - 2, fy - 4)
    for x, y in gl:                       # engraved: the bottom-right wall of each groove is lit
        if (x + 1, y + 1) not in gl:
            put(img, x + 1, y + 1, light(GOLD, 0.45))
    for x, y in gl:
        put(img, x, y, dark(GOLD_D, 0.1))
    for p in ((fx - 6, fy - 5), (fx - 5, fy - 6), (fx - 4, fy - 7)):
        put(img, *p, WHITE)


LETTER_J = [
    ".#######.",
    ".#######.",
    "....###..",
    "....###..",
    "....###..",
    "....###..",
    "....###..",
    "....###..",
    "##..###..",
    "###.###..",
    ".#####...",
    "..###....",
]


def gem(img, cx, cy, base, rad=2.4):
    g = disc(cx, cy, rad)
    r = ramp(base, 0.4, 0.25, 0.55)
    outline(img, g, r['ol'])
    dome(img, g, cx, cy, rad, r, 0.3, -0.3)
    put(img, cx - 1, cy - 1, WHITE)


def emblem_jack(img, cx, cy, rad=17):
    medallion(img, cx, cy, rad, JACK, PARCH)
    # the white ring turns into three arcs in the three deck colours: half of each deck
    for x, y in disc(cx, cy, rad) - disc(cx, cy, rad - 1.3):
        a = (math.degrees(math.atan2(y - cy, x - cx)) + 90) % 360
        base = TITAN if a < 120 else TYCOON if a < 240 else SIGNET
        put(img, x, y, light(base, 0.15) if lit_side(x, y, cx, cy) > 0 else base)
        if a % 120 < 5 or a % 120 > 115:
            put(img, x, y, WHITE)
    j = glyph(LETTER_J, cx - 5, cy - 10)
    jr = {'hi': light(JACK, 0.35), 'mid': JACK, 'lo': dark(JACK, 0.4)}
    for x, y in j:
        put(img, x + 1, y + 1, mix(PARCH, JACK, 0.28))      # drop shadow on the parchment
    bevel(img, j, jr)
    for dx, c in ((-7, TITAN), (0, SIGNET), (7, TYCOON)):
        gem(img, cx + dx, cy + (7 if dx else 9), c)


STAR8 = [
    "....#....",
    "....#....",
    "..#.#.#..",
    "...###...",
    "#########",
    "...###...",
    "..#.#.#..",
    "....#....",
    "....#....",
]
CROWN = [
    "#.....#.....#",
    "#....###....#",
    "##...###...##",
    "##.#######.##",
    "#############",
    "#############",
    ".###########.",
    ".###########.",
]
TINY = {  # gold marks set into each third of the Master ring: a chevron, a seal and a coin
    TITAN: ["#...#", ".#.#.", "..#.."],
    SIGNET: [".#.", "#.#", ".#."],
    TYCOON: [".#.", "###", ".#."],
}


def emblem_master(img, cx, cy, rad=19, crown=True):
    outer = disc(cx, cy, rad)
    outline(img, outer, GOLD_R['ol'])
    for x, y in outer:
        t = lit_side(x, y, cx, cy)
        put(img, x, y, GOLD_R['hi'] if t > rad * 0.45 else GOLD_R['lo'] if t < -rad * 0.45 else GOLD)
    # a beaded channel just inside the rim
    for x, y in ring(cx, cy, rad - 3.2, rad - 1.6):
        put(img, x, y, GOLD_D)
    beads = max(16, int(rad * 1.3))
    for k in range(beads):
        a = k * math.tau / beads
        bx, by = round(cx + math.cos(a) * (rad - 2.4)), round(cy + math.sin(a) * (rad - 2.4))
        put(img, bx, by, GOLD_R['hi'] if lit_side(bx, by, cx, cy) > -4 else GOLD)
    # three-colour ring, one third per deck, each a raised band lit from the top-left
    rin = rad * 0.5
    band = disc(cx, cy, rad - 3.2) - disc(cx, cy, rin)
    for x, y in band:
        a = (math.degrees(math.atan2(y - cy, x - cx)) + 90) % 360
        rr = ramp(TITAN if a < 120 else TYCOON if a < 240 else SIGNET, 0.3, 0.3)
        dd = math.hypot(x - cx, y - cy)
        t = lit_side(x, y, cx, cy)
        if dd > rad - 4.3:
            c = rr['lo'] if t > 0 else rr['mid']             # the outer wall faces away from the light up top
        elif dd < rin + 1.2:
            c = rr['hi'] if t < 0 else rr['lo']
        else:
            c = rr['hi'] if t > rad * 0.35 else rr['mid']
        put(img, x, y, c)
    # gold spokes between the thirds and a gold mark in the middle of each third
    for ang in (-90, 30, 150):
        a = math.radians(ang)
        for s in range(int(rin), rad - 2):
            put(img, round(cx + math.cos(a) * s), round(cy + math.sin(a) * s), GOLD_R['hi'] if ang == -90 else GOLD)
    mid_r = (rad - 3.2 + rin) / 2
    for ang, base in ((-30, TITAN), (90, TYCOON), (210, SIGNET)) if rad >= 17 else ():
        a = math.radians(ang)
        mx, my = round(cx + math.cos(a) * mid_r), round(cy + math.sin(a) * mid_r)
        rows = TINY[base]
        g = glyph(rows, mx - len(rows[0]) // 2, my - 1)
        for x, y in g:
            put(img, x + 1, y + 1, dark(base, 0.45))
        for x, y in g:
            put(img, x, y, GOLD_R['hi'])
    # navy centre behind a gold lip, and the star
    for x, y in disc(cx, cy, rin) - disc(cx, cy, rin - 1.4):
        put(img, x, y, GOLD_R['lo'] if lit_side(x, y, cx, cy) > 0 else GOLD_R['hi'])
    for x, y in disc(cx, cy, rin - 1.4):
        put(img, x, y, NAVY)
    st = glyph(STAR8, cx - 4, cy - 4)
    for x, y in st:
        put(img, x + 1, y + 1, dark(NAVY, 0.45))
    for x, y in st:
        t = lit_side(x, y, cx, cy)
        put(img, x, y, GOLD_R['hi'] if t > 0 else GOLD if t == 0 else GOLD_R['lo'])
    put(img, cx, cy, WHITE)
    if not crown:
        return
    cw = len(CROWN[0])
    cr = glyph(CROWN, cx - cw // 2, cy - rad - 6)
    outline(img, cr, GOLD_R['ol'], skip=outer)
    bevel(img, cr, GOLD_R)
    by = cy - rad - 2
    for dx, c in ((-4, TITAN), (0, SIGNET), (4, TYCOON)):
        put(img, cx + dx, by, c)
        put(img, cx + dx - 1, by, light(c, 0.35))
        put(img, cx + dx, by + 1, dark(c, 0.3))
    for dx in (-6, 0, 6):
        put(img, cx + dx, cy - rad - 6, WHITE)


# ---- panel patterns (x, y in card coordinates, symmetric about CX, CY) -----------------------------
def pat_titan(x, y):
    """Rows of rank chevrons with a dotted seam between them and a spine down the middle."""
    ax = abs(x - CX)
    v = (y - CY + ax) % 10
    if v in (0, 1):
        return light(TITAN, 0.18)
    if v == 2:
        return dark(TITAN, 0.12)
    if v == 6 and (x - CX) % 2 == 0:
        return dark(TITAN, 0.16)
    if ax == 0:
        return dark(TITAN, 0.08)
    return TITAN


def pat_signet(x, y):
    """A fine diamond trellis with studs at the crossings and a pip in every diamond."""
    u, v = (x - CX) + (y - CY), (x - CX) - (y - CY)
    lu, lv = u % 10 == 0, v % 10 == 0
    if lu and lv:
        return light(SIGNET, 0.55)
    if lu or lv:
        return light(SIGNET, 0.22)
    if u % 10 == 5 and v % 10 == 5:
        return dark(SIGNET, 0.25)
    if (u % 10 == 5 and v % 10 in (4, 6)) or (v % 10 == 5 and u % 10 in (4, 6)):
        return dark(SIGNET, 0.1)
    return SIGNET


def pat_tycoon(x, y):
    """Banknote guilloche: two crossing waves woven into a rope of lenses, with a dot in each lens."""
    dx, dy = x - CX, y - CY
    s = 2.0 * math.sin(dx * math.tau / 12)
    a = round(dy - s) % 8 == 0
    b = round(dy + s) % 8 == 0
    if a and b:
        return light(TYCOON, 0.5)
    if a or b:
        return light(TYCOON, 0.26)
    if dy % 8 == 0 and dx % 6 == 3:
        return dark(TYCOON, 0.22)
    if dy % 8 == 4 and dx % 12 in (0, 6):
        return dark(TYCOON, 0.12)
    return TYCOON


JACK_DOTS = (TITAN, SIGNET, TYCOON)


def pat_jack(x, y):
    """Harlequin diamonds (12 x 16) in two slate tones, with a tri-colour stud on every vertex."""
    dx, dy = x - CX, y - CY + 8
    a, b = 8 * dx + 6 * dy, 8 * dx - 6 * dy
    ia, ib = a // 96, b // 96
    for ox, oy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):      # a small cross-shaped stud on each vertex
        vx, vy = dx + ox, dy + oy
        if vx % 12 == 0 and vy % 16 == 0 or vx % 12 == 6 and vy % 16 == 8:
            c = JACK_DOTS[(vx // 6 + vy // 8) % 3]
            return light(c, 0.3) if (ox, oy) == (0, 0) else c if (ox, oy) in ((1, 0), (0, 1)) else dark(c, 0.15)
    if a % 96 < 7 or b % 96 < 7:
        return dark(JACK, 0.3)
    if (ia + ib) % 2 == 0:
        # light diamonds get a lit top-left inner edge
        return light(JACK, 0.2) if (a % 96 < 14 or b % 96 > 82) else light(JACK, 0.1)
    return dark(JACK, 0.08)


def pat_master(x, y):
    """Fine rays from the centre with a scatter of tiny gold stars, mirrored in four."""
    dx, dy = x - CX, y - CY
    ray = int(math.floor((math.atan2(dy, dx) + math.pi) / math.tau * 32)) % 2
    p = (abs(dx), abs(dy))
    if p in STARS:
        return GOLD
    if p in STAR_TIPS:
        return GOLD_D
    return NAVY if ray else NAVY_RAY


STARS = {(17, 30), (8, 37), (24, 21), (24, 37), (27, 3), (5, 28), (14, 24)}
STAR_TIPS = {(sx + ox, sy + oy) for sx, sy in STARS for ox, oy in N4}


# ---- frames ------------------------------------------------------------------------------------------
def simple_frame(main, dd, lit):
    """Colour of frame ring dd (1 = outermost) for the plain decks; None means pattern."""
    r = ramp(main)
    if dd <= 3:
        return WHITE
    if dd == 4:
        return r['ol']
    if dd == 5:
        return main
    if dd == 6:
        return light(main, 0.45) if lit else r['lo']
    if dd == 7:
        return r['lo']
    return None


CORNER_STUD = [".#.", "###", ".#."]


def back_simple(main, pattern, emblem):
    img = new(CARD)
    d = dist(card_mask(), 8)
    for y in range(CARD[1]):
        for x in range(CARD[0]):
            if d[y][x]:
                horiz = min(y - 1, 93 - y) < min(x - 1, 69 - x)
                lit = (y < CY) if horiz else (x < CX)
                put(img, x, y, simple_frame(main, d[y][x], lit) or pattern(x, y))
    for fx, fy in ((9, 9), (59, 9), (9, 83), (59, 83)):
        pts = glyph(CORNER_STUD, fx, fy)
        outline(img, pts, ramp(main)['ol'])
        bevel(img, pts, {'hi': light(main, 0.6), 'mid': light(main, 0.45), 'lo': light(main, 0.2)})
    emblem(img, CX, CY)
    return img


# Master: gold triple frame, a running meander, rosette corners, corner fans, rays and a crowned medallion
MEANDER = [  # 5 rows, period 8: a running key drawn as one continuous gold line
    "#######.",
    "......#.",
    "####..#.",
    "#..#..#.",
    "#..####.",
]
ROSETTE = [
    "..#..",
    ".###.",
    "##.##",
    ".###.",
    "..#..",
]


def master_band(dd, t, lit):
    """Frame rings for the Master deck: gold, gold, dark gold, a 5px meander band, dark gold, gold, outline."""
    if dd <= 3:
        return WHITE
    if dd == 4:
        return GOLD_R['ol']
    if dd == 5:
        return GOLD_R['hi'] if lit else GOLD
    if dd == 6:
        return GOLD_D
    if 7 <= dd <= 11:
        if t is None:
            return NAVY
        return (GOLD if lit else GOLD_R['lo']) if MEANDER[dd - 7][t % 8] == '#' else NAVY
    if dd == 12:
        return GOLD_D
    if dd == 13:
        return GOLD_R['hi'] if lit else GOLD
    if dd == 14:
        return GOLD_R['ol']
    return None


def rosette(img, bx, by, jewel):
    for yy in range(by, by + 5):
        for xx in range(bx, bx + 5):
            put(img, xx, yy, NAVY)
    pts = glyph(ROSETTE, bx, by)
    for x, y in pts:
        put(img, x, y, GOLD_R['hi'] if x - bx + y - by < 4 else GOLD)
    put(img, bx + 2, by + 2, jewel)


CORNER = [  # top-left inner corner: a bracket echoing the frame, a scroll and a stud
    "######.",
    "#......",
    "#.###..",
    "#.#....",
    "#.#..#.",
    "#.....#",
    "....#..",
]


def corner_ornaments(img, x0, y0):
    pts = mirror4(glyph(CORNER, x0, y0))
    drop_shadow(img, pts, dark(NAVY, 0.45))
    for x, y in pts:
        put(img, x, y, GOLD_R['hi'] if (x < CX and y < CY) else GOLD if (x < CX or y < CY) else GOLD_R['lo'])


def back_master():
    img = new(CARD)
    d = dist(card_mask(), 15)
    for y in range(CARD[1]):
        for x in range(CARD[0]):
            dd = d[y][x]
            if dd == 0:
                continue
            horiz = min(y - 1, 93 - y) < min(x - 1, 69 - x)
            lit = (y < CY) if horiz else (x < CX)
            # the meander runs clockwise around the card
            t = (x - 12 if y < CY else 58 - x) if horiz else (y - 12 if x > CX else 82 - y)
            put(img, x, y, master_band(dd, t, lit) or pat_master(x, y))
    for (bx, by), jewel in (((7, 7), SEAL_RED), ((59, 7), SEAL_BLUE), ((7, 83), SEAL_GOLD), ((59, 83), SEAL_PURPLE)):
        rosette(img, bx, by, jewel)
    corner_ornaments(img, 16, 16)
    # small gold lozenges in the middle of the top and bottom of the field
    fleur = glyph(["...#...", "..#.#..", ".#.#.#.", "..#.#..", "...#..."], CX - 3, 16)
    for x, y in mirror4(fleur):
        put(img, x, y, GOLD if y < CY else GOLD_R['lo'])
    emblem_master(img, CX, CY + 3)
    return img


# ---- sleeves (73 x 95): an open pocket over the deck with a darker base -------------------------------
SW, SH = SLEEVE
SCX, SCY = 36, 53       # centre of the sleeve's front panel (its emblem sits here)
EAR = 17                # the back wall's highest row; everything above stays clear so the deck shows
FACE_BOTTOM = 82


def scoop(x):
    """0 at the ears, rising smoothly to 1 across the middle of the pocket opening."""
    u = abs(x - SCX) / 35
    t = min(1.0, max(0.0, (u - 0.4) / 0.5))
    return 0.5 + 0.5 * math.cos(math.pi * t)


def back_top(x): return EAR + round(4 * scoop(x))
def face_top(x): return EAR + 3 + round(9 * scoop(x))


def sleeve_body(img, main):
    """Back wall (the inside of the pocket, seen over the front lip) and the base tray."""
    back = {(x, y) for x in range(1, 72) for y in range(back_top(x), 88)}
    back -= {(1, EAR), (71, EAR), (2, EAR), (70, EAR), (1, EAR + 1), (71, EAR + 1)}
    for x, y in back:
        edge = (x, y - 1) not in back
        side = (x - 1, y) not in back or (x + 1, y) not in back
        put(img, x, y, dark(main, 0.72) if edge or side else dark(main, 0.5))
    for x, y in back:            # the cut edge of the back wall catches the light
        if (x, y - 1) not in back and (x, y + 1) in back and (x - 1, y) in back and (x + 1, y) in back:
            put(img, x, y + 1, dark(main, 0.28))
    base = round_mask(SW, SH, 1, FACE_BOTTOM - 8, 71, 93, 3)
    bd = dist(base, 2)
    for y in range(SH):
        for x in range(SW):
            if not bd[y][x]:
                continue
            if bd[y][x] == 1:
                c = dark(main, 0.74)
            elif y <= FACE_BOTTOM + 2:
                c = dark(main, 0.3)          # lit top of the base, just under the front panel
            elif y >= 90:
                c = dark(main, 0.62)
            else:
                c = dark(main, 0.45)
            put(img, x, y, c)
    for i in range(6):                       # chamfered corners of the tray
        put(img, 2 + i, FACE_BOTTOM + 3 + i, dark(main, 0.62))
        put(img, 70 - i, FACE_BOTTOM + 3 + i, dark(main, 0.62))
    for x in range(8, 65):
        put(img, x, FACE_BOTTOM + 8, dark(main, 0.6))


def face_mask():
    fm = round_mask(SW, SH, 2, 0, 70, FACE_BOTTOM, 4)
    for y in range(SH):
        for x in range(SW):
            if y < face_top(x):
                fm[y][x] = False
    return fm


def face_run(x, y):
    """Which edge of the front panel a pixel is closest to: 'top', 'left', 'right' or 'bottom'."""
    ds = {'top': y - face_top(x), 'left': x - 2, 'right': 70 - x, 'bottom': FACE_BOTTOM - y}
    return min(ds, key=ds.get)


def sleeve(main, pattern, emblem):
    img = new(SLEEVE)
    sleeve_body(img, main)
    fd = dist(face_mask(), 8)
    r = ramp(main)
    for y in range(SH):
        for x in range(SW):
            dd = fd[y][x]
            if not dd:
                continue
            run = face_run(x, y)
            lit = run in ('top', 'left')
            if dd == 1:
                c = r['ol']
            elif dd <= 3:
                c = WHITE if lit or dd == 2 else mix(WHITE, main, 0.15)
            else:
                c = simple_frame(main, dd, lit) or pattern(x - 1, y - (SCY - CY))
            put(img, x, y, c)
    emblem(img, SCX, SCY)
    return img


def sleeve_master():
    img = new(SLEEVE)
    sleeve_body(img, NAVY_L)
    fd = dist(face_mask(), 15)
    for y in range(SH):
        for x in range(SW):
            dd = fd[y][x]
            if not dd:
                continue
            run = face_run(x, y)
            lit = run in ('top', 'left')
            if dd == 1:
                c = dark(NAVY, 0.5)
            elif dd <= 3:
                c = WHITE if lit or dd == 2 else mix(WHITE, NAVY_L, 0.15)
            elif run == 'top' and 7 <= dd <= 11:
                # along the curved lip the meander gives way to a beaded chain
                c = NAVY if dd != 9 else GOLD_R['hi'] if x % 3 == 0 else GOLD_D
            else:
                t = {'left': 74 - y, 'right': y - 20, 'bottom': 64 - x}.get(run, 0)
                c = master_band(dd, t, lit)
            put(img, x, y, c or pat_master(x - 1, y - (SCY - CY)))
    rosette(img, 8, FACE_BOTTOM - 10, SEAL_GOLD)
    rosette(img, 60, FACE_BOTTOM - 10, SEAL_PURPLE)
    emblem_master(img, SCX, SCY + 1, 15)
    return img


# ---- mod icon (34 x 34): a fanned stack of the deck colours with a gold bolt -------------------------
BOLT = [
    "......######",
    ".....######.",
    "....######..",
    "...######...",
    "..######....",
    ".##########.",
    "..########..",
    "......####..",
    ".....####...",
    "....####....",
    "....###.....",
    "...###......",
    "...##.......",
    "..##........",
    "..#.........",
]


def mini_card(img, x0, y0, w, h, main, fill):
    d = dist(round_mask(34, 34, x0, y0, x0 + w - 1, y0 + h - 1, 2), 3)
    for y in range(34):
        for x in range(34):
            if d[y][x]:
                put(img, x, y, dark(main, 0.6) if d[y][x] == 1 else WHITE if d[y][x] == 2 else fill(x, y))


def icon():
    img = new((34, 34))
    mini_card(img, 14, 1, 18, 24, TYCOON, lambda x, y: light(TYCOON, 0.2) if (x + y) % 4 == 0 else TYCOON)
    mini_card(img, 10, 3, 18, 24, SIGNET, lambda x, y: light(SIGNET, 0.2) if (x - y) % 4 == 0 else SIGNET)
    mini_card(img, 6, 5, 18, 24, TITAN, lambda x, y: light(TITAN, 0.18) if (y + abs(x - 14)) % 5 == 0 else TITAN)
    mini_card(img, 2, 8, 18, 24, NAVY, lambda x, y: NAVY_RAY if (x - y) % 4 == 0 else NAVY)
    b = glyph(BOLT, 5, 12)
    for x, y in b:
        put(img, x + 1, y + 1, dark(NAVY, 0.5))
    outline(img, b, GOLD_R['ol'])
    bevel(img, b, GOLD_R)
    return img


def build():
    decks = [
        back_simple(TITAN, pat_titan, emblem_titan),
        back_simple(SIGNET, pat_signet, emblem_signet),
        back_simple(TYCOON, pat_tycoon, emblem_tycoon),
        back_simple(JACK, pat_jack, emblem_jack),
        back_master(),
    ]
    sleeves = [
        sleeve(TITAN, pat_titan, emblem_titan),
        sleeve(SIGNET, pat_signet, emblem_signet),
        sleeve(TYCOON, pat_tycoon, emblem_tycoon),
        sleeve(JACK, pat_jack, emblem_jack),
        sleeve_master(),
    ]
    return {'decks': sheet(decks, CARD), 'sleeves': sheet(sleeves, SLEEVE), 'icon': icon()}
