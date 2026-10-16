"""PowerDecks Joker sheet: 8 cells of 71x95, in the order items/jokers.lua references them.

    0 Coupon Clipper   1 Piggy Bank   2 Toil & Trouble   3 Purple Card
    4 Stanczyk base    5 Dagonet base 6 Stanczyk soul    7 Dagonet soul

Every object is built from shape masks (sets of (x, y) pixels) and drawn with draw(): a 3-tone ramp lit
from the top-left plus a 1px outline in a dark tone of the object's own colour. Parts are drawn back to
front, so each part's outline separates it from whatever is behind it.
"""
import math

from common import (CARD, FACE, GOLD, GOLD_D, INK, NAVY, NAVY_L, OUTLINE, RARE, SEAL_BLUE, SLATE, SMALL, SPEC,
                    SPEC_D, SPEC_L, TAROT, WHITE, card_mask, dark, dist, joker_text, light, mix, new, rgb, sheet,
                    stamp, text, text_width)

W, H = CARD
COOL = (40, 28, 78, 255)     # shadows lean blue-violet
WARM = (255, 248, 222, 255)  # lights lean warm


# ---- shapes -----------------------------------------------------------------------------------
def ellipse(cx, cy, rx, ry):
    m = {(x, y) for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1)
         for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1)
         if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0}
    return denub(m) if rx > 3 and ry > 3 else m


def denub(m):
    """Drops lone pixels sticking out of a curve, which would otherwise grow a bump in the outline."""
    return {(x, y) for x, y in m
            if sum((x + dx, y + dy) in m for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) >= 2}


def rect(x0, y0, x1, y1):
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def poly(pts):
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    out = set()
    for y in range(math.floor(min(ys)), math.ceil(max(ys)) + 1):
        for x in range(math.floor(min(xs)), math.ceil(max(xs)) + 1):
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                (xi, yi), (xj, yj) = pts[i], pts[j]
                if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                    inside = not inside
                j = i
            if inside:
                out.add((x, y))
    return out


def bezier(p0, p1, p2, n=60):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / n for i in range(n + 1))]


def tube(path, r0, r1):
    """Union of discs along a path, radius easing from r0 to r1: horns, blades, handles."""
    out = set()
    n = len(path) - 1
    for i, (px, py) in enumerate(path):
        r = r0 + (r1 - r0) * (i / n)
        for y in range(math.floor(py - r), math.ceil(py + r) + 1):
            for x in range(math.floor(px - r), math.ceil(px + r) + 1):
                if (x - px) ** 2 + (y - py) ** 2 <= r * r:
                    out.add((x, y))
    return out


# ---- colour -----------------------------------------------------------------------------------
def ramp(base, o=0.58, s=0.22, l=0.3, h=0.7):
    """outline / shadow / base / light / highlight, hue-shifted cool in shadow and warm in light."""
    return {'o': mix(base, COOL, o), 's': mix(base, COOL, s), 'b': base, 'l': mix(base, WARM, l),
            'h': mix(base, WARM, h)}


def put(img, pts, c):
    px = img.load()
    for x, y in pts:
        if 0 <= x < img.width and 0 <= y < img.height:
            px[x, y] = c


def draw(img, mask, r, sh=2, lit=1, outline=True, flat=False, cast=()):
    """Fills mask with the ramp lit from the top-left, then outlines it in r['o']."""
    px = img.load()
    for x, y in mask:
        if not (0 <= x < img.width and 0 <= y < img.height):
            continue
        if flat:
            c = r['b']
        elif (x + 1, y) not in mask or (x, y + 1) not in mask or (x + 1, y + 1) not in mask:
            c = r['s']
        elif any((x - k, y) not in mask or (x, y - k) not in mask for k in range(1, lit + 1)):
            c = r['l']
        elif any((x + k, y) not in mask or (x, y + k) not in mask or (x + k, y + k) not in mask
                 for k in range(2, sh + 1)):
            c = r['s']
        else:
            c = r['b']
        if (x, y) in cast:
            c = r['s']
        px[x, y] = c
    if outline:
        put(img, rim(mask), r['o'])


def rim(mask):
    return {(x + dx, y + dy) for x, y in mask for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))} - mask


def line(p0, p1, n=40):
    return [(p0[0] + (p1[0] - p0[0]) * t / n, p0[1] + (p1[1] - p0[1]) * t / n) for t in range(n + 1)]


def shift(mask, dx, dy):
    return {(x + dx, y + dy) for x, y in mask}


# ---- card bases -------------------------------------------------------------------------------
def white_joker():
    img = new()
    m = card_mask()
    d = dist(m, 1)
    px = img.load()
    for y in range(H):
        for x in range(W):
            if d[y][x]:
                px[x, y] = OUTLINE if d[y][x] == 1 else FACE
    joker_text(img, SLATE)
    return img


def panel_joker(fill, text_colour):
    img = new()
    m = card_mask()
    d = dist(m, 4)
    px = img.load()
    for y in range(H):
        for x in range(W):
            dd = d[y][x]
            if dd:
                px[x, y] = OUTLINE if dd == 1 else WHITE if dd <= 4 else fill(x, y)
    joker_text(img, text_colour)
    return img


# ---- 0: Coupon Clipper ------------------------------------------------------------------------
PERCENT = ["##....##", "##...##.", "....##..", "...##...", "..##....", ".##...##", "##....##"]
STEEL = ramp(rgb('D3DAE6'), o=0.62, s=0.25, l=0.6)
COIN = {'o': GOLD_D, 's': rgb('D99A2B'), 'b': GOLD, 'l': rgb('FBE29A'), 'h': WHITE}


def coupon_clipper():
    img = white_joker()
    red = ramp(RARE, o=0.55)
    # dashed cut line around the coupon
    x0, y0, x1, y1 = 17, 8, 62, 39
    for x in range(x0, x1 + 1):
        if (x - x0) % 4 < 2:
            put(img, [(x, y0), (x, y1)], rgb('A9B3C4'))
    for y in range(y0, y1 + 1):
        if (y - y0) % 4 < 2:
            put(img, [(x0, y), (x1, y)], rgb('A9B3C4'))
    # the coupon: ticket with round bites on both sides
    c = rect(20, 11, 59, 36) - ellipse(19.5, 23.5, 3.2, 3.2) - ellipse(59.5, 23.5, 3.2, 3.2)
    c -= {(20, 11), (59, 11), (20, 36), (59, 36)}
    put(img, shift(c, 1, 1), rgb('D9DEE8'))  # soft drop shadow on the card
    draw(img, c, red)
    inner = rect(23, 14, 56, 33) - ellipse(19.5, 23.5, 5.2, 5.2) - ellipse(59.5, 23.5, 5.2, 5.2)
    for p in rim(inner) & c:
        if (p[0] + p[1]) % 3:
            put(img, [p], red['l'])
    # perforation between the main part and the stub
    for y in range(13, 35, 2):
        put(img, [(48, y)], red['s'])
    # bold percent sign with a dark drop shadow
    stamp(img, PERCENT, 27, 18, {'#': red['o']}, 2)
    stamp(img, PERCENT, 26, 17, {'#': WHITE}, 2)
    # stub: star and barcode
    put(img, [(53, 17), (52, 18), (53, 18), (54, 18), (51, 19), (52, 19), (53, 19), (54, 19), (55, 19),
              (52, 20), (53, 20), (54, 20), (52, 21), (54, 21)], GOLD)
    for i, x in enumerate(range(51, 57)):
        if i != 2:
            put(img, [(x, y) for y in range(25, 32 - (i % 2))], red['o'])

    # scissors, opened, jaws reaching up toward the coupon
    pivot = (32, 62)
    tip_a, tip_b = (45, 40), (55, 53)
    handle_a, handle_b = (24, 76), (15, 67)
    blue = ramp(SEAL_BLUE, o=0.6)
    hole_a, hole_b = ellipse(*handle_a, 3.4, 2.6), ellipse(*handle_b, 3.4, 2.6)
    blade_a, blade_b = tube(line(pivot, tip_a), 2.8, 0.6), tube(line(pivot, tip_b), 2.8, 0.6)
    grip_a = (ellipse(*handle_a, 6.6, 5.6) | tube(line(pivot, handle_a), 2.2, 2.4)) - hole_a - ellipse(*pivot, 3, 3)
    grip_b = (ellipse(*handle_b, 6.6, 5.6) | tube(line(pivot, handle_b), 2.2, 2.4)) - hole_b - ellipse(*pivot, 3, 3)
    whole = blade_a | blade_b | grip_a | grip_b
    put(img, shift(whole, 2, 2) - whole - hole_a - hole_b, rgb('E3E7EE'))  # shadow on the card
    # each half is one piece: blade a runs into grip b, blade b into grip a
    draw(img, blade_a, STEEL)
    draw(img, grip_b, blue)
    draw(img, blade_b, STEEL)
    draw(img, grip_a, blue)
    for (hx, hy) in (handle_a, handle_b):
        put(img, [(hx - 5, hy - 1), (hx - 4, hy - 3), (hx - 3, hy - 4), (hx - 2, hy - 4)], blue['h'])
        put(img, [(hx + 2, hy + 3), (hx + 3, hy + 3)], blue['s'])
    for tip in (tip_a, tip_b):  # glints along the blades
        for t in (0.3, 0.45, 0.6):
            put(img, [(round(pivot[0] + (tip[0] - pivot[0]) * t) - 1, round(pivot[1] + (tip[1] - pivot[1]) * t) - 1)],
                WHITE)
    draw(img, ellipse(*pivot, 1.6, 1.6), COIN)
    put(img, [(pivot[0] - 1, pivot[1] - 1)], WHITE)
    return img


# ---- 1: Piggy Bank ----------------------------------------------------------------------------
PINK = ramp(rgb('F7A8B8'), o=0.55, s=0.2, l=0.4)


def coin(img, cx, cy, rx, ry, mark=True):
    c = ellipse(cx, cy, rx, ry)
    draw(img, c, COIN)
    inner = ellipse(cx, cy, rx - 2, ry - 2) if rx > 3 else set()
    put(img, rim(inner) & c, COIN['s'])
    if mark and rx >= 5:
        stamp(img, [".#.", "###", "#..", "###", "..#", "###", ".#."], round(cx) - 1, round(cy) - 3,
              {'#': GOLD_D})
    put(img, [(round(cx - rx + 2), round(cy - ry + 2)), (round(cx - rx + 3), round(cy - ry + 1))], WHITE)


def piggy_bank():
    img = white_joker()
    # ground shadow
    put(img, ellipse(35, 80, 20, 2.4), rgb('E4E8EF'))
    # coins: one spinning in the air, one dropping into the slot
    coin(img, 50, 16, 3.2, 6.4, mark=False)
    put(img, [(46, 9), (45, 10), (55, 21), (56, 22), (55, 9), (56, 8)], rgb('C7CEDA'))
    coin(img, 33, 33, 6.4, 6.4)
    for x, y0 in ((25, 24), (41, 24), (27, 20), (39, 20)):
        put(img, [(x, y0), (x, y0 + 1), (x, y0 + 2)], rgb('C7CEDA'))
    # legs behind, tail, body, near legs, head details
    def leg(x0, y1):
        return rect(x0, 66, x0 + 5, y1) - {(x0, y1), (x0 + 5, y1)}
    far_legs = leg(25, 77) | leg(43, 76)
    near_legs = leg(18, 78) | leg(36, 78)
    back = ramp(rgb('E58FA3'), o=0.5)
    draw(img, far_legs, back)
    put(img, {(x, y) for x, y in far_legs if y >= 76}, rgb('B85A72'))
    tail = tube(bezier((17, 58), (10, 60), (12, 54)) + bezier((12, 54), (14, 50), (16, 54)), 1.1, 1.0)
    draw(img, tail, PINK, flat=True)
    body = ellipse(34, 60, 18, 13)
    ear_back = poly([(40, 49), (45, 42), (48, 51)])
    draw(img, ear_back, back)
    draw(img, body, PINK, sh=3)
    # soft belly shading: lower third of the body in shadow tone
    put(img, {(x, y) for x, y in body if ((x - 34) / 18) ** 2 + ((y - 56) / 13) ** 2 > 1 and (x, y + 1) in body
              and (x + 1, y) in body}, PINK['s'])
    put(img, ellipse(26, 53, 4, 2.4) & body, PINK['l'])
    put(img, [(23, 52), (24, 51), (25, 51)], PINK['h'])
    draw(img, near_legs, PINK)
    hoof = rgb('C86C84')
    for lx in (18, 36):
        put(img, rect(lx + 1, 77, lx + 4, 78) | {(lx, 77), (lx + 5, 77)}, hoof)
        put(img, [(lx + 2, 78), (lx + 3, 77)], PINK['o'])
    ear = poly([(42, 50), (46, 41), (51, 51)])
    draw(img, ear, PINK)
    put(img, poly([(45, 48), (46, 44), (48, 49)]), PINK['s'])
    snout = ellipse(51.5, 62, 4.2, 4.6)
    draw(img, snout, ramp(rgb('FBC1CD'), o=0.55))
    put(img, [(51, 60), (51, 61), (53, 60), (53, 61)], PINK['o'])
    # eye with a glint, cheek blush
    put(img, rect(44, 55, 45, 57), INK)
    put(img, [(44, 55)], WHITE)
    put(img, [(42, 61), (43, 61), (44, 61), (43, 62)], rgb('F27A93'))
    # coin slot on top of the back
    put(img, rect(28, 47, 38, 48), PINK['o'])
    put(img, rect(29, 47, 37, 47), INK)
    put(img, rect(28, 49, 38, 49), PINK['l'])
    # the dropping coin's lower edge slips into the slot
    return img


# ---- 2: Toil & Trouble ------------------------------------------------------------------------
IRON = {'o': rgb('121325'), 's': rgb('25273C'), 'b': rgb('3A3E5C'), 'l': rgb('585E86'), 'h': rgb('8D95C2')}
SPECR = {'o': SPEC_D, 's': rgb('3866D0'), 'b': SPEC, 'l': SPEC_L, 'h': WHITE}
FIRE = [rgb('C93A3A'), rgb('FE5F55'), rgb('FDA200'), rgb('FDE07A')]


def toil_bg(x, y):
    base = mix(NAVY, NAVY_L, min(1, max(0, (y - 6) / 70)))
    if y > 66:  # warm glow from the fire
        base = mix(base, rgb('6B3A4A'), min(0.55, (y - 66) / 40))
    if (x * 7 + y * 13) % 89 == 0 or (x * 11 + y * 5) % 151 == 0:
        base = light(base, 0.35)
    return base


def bubble(img, cx, cy, r):
    b = ellipse(cx, cy, r, r)
    draw(img, b, SPECR, outline=True)
    put(img, [(round(cx - r * 0.45), round(cy - r * 0.45))], WHITE)


def toil_and_trouble():
    img = panel_joker(toil_bg, FACE)
    # flames and logs under the pot
    for bx, h, w, sway in ((20, 9, 3.5, -2), (26, 13, 4, -1), (35, 15, 4.5, 1), (43, 12, 4, 2), (50, 8, 3.5, 2)):
        for k, scale in enumerate((1.0, 0.72, 0.42)):
            hh, ww = h * scale, w * scale
            put(img, poly([(bx - ww, 87), (bx - ww * 0.8, 87 - hh * 0.45), (bx + sway * scale, 87 - hh),
                           (bx + ww * 0.8, 87 - hh * 0.45), (bx + ww, 87)]), FIRE[k + 1] if k else FIRE[0])
    wood = ramp(rgb('8A5A3C'), o=0.6)
    for a, b in (((22, 82), (50, 88)), ((48, 82), (20, 88))):
        log = tube(line(a, b), 1.9, 1.9)
        draw(img, log, wood)
        put(img, [(round(b[0]) + (1 if b[0] > a[0] else -1), round(b[1]))], rgb('D9A877'))
    # cauldron: legs, body, rim
    draw(img, rect(21, 72, 24, 79), IRON)
    draw(img, rect(46, 72, 49, 79), IRON)
    body = ellipse(35, 61, 18, 14)
    draw(img, body, IRON, sh=3, lit=2)
    put(img, ellipse(26, 57, 2.4, 5) & body, IRON['l'])
    put(img, [(24, 55), (24, 56), (25, 54)], IRON['h'])
    # glow on the iron from the fire
    put(img, {(x, y) for x, y in body if y >= 72 and (x, y + 1) not in body}, rgb('8E4A3A'))
    rim_m = ellipse(35, 48, 20, 5)
    draw(img, rim_m, IRON, lit=1, sh=1)
    put(img, {(x, 44) for x in range(28, 43)}, IRON['h'])
    liquid = ellipse(35, 48, 16.5, 3.2)
    draw(img, liquid, SPECR, outline=False, flat=True)
    for x in range(20, 51):
        y = 48 + round(1.4 * math.sin(x * 0.55))
        if (x, y) in liquid:
            put(img, [(x, y)], SPEC_L)
    put(img, [(25, 47), (26, 47), (44, 48)], WHITE)
    # froth spilling over the lip and dripping down the side
    for cx, cy, r in ((24, 45, 2.4), (30, 44, 3.2), (37, 43, 3.6), (44, 44, 2.8), (48, 46, 2)):
        bubble(img, cx, cy, r)
    for x0, length in ((19, 7), (41, 10), (47, 5)):
        drip = rect(x0, 50, x0 + 1, 50 + length) | ellipse(x0 + 0.5, 50 + length, 1.4, 1.4)
        draw(img, drip, SPECR)
    # rising bubbles
    for cx, cy, r in ((31, 36, 2.2), (40, 31, 3.2), (33, 24, 2.0), (45, 19, 2.6), (38, 12, 1.6), (51, 10, 1.4),
                      (25, 28, 1.3), (50, 29, 1.2)):
        bubble(img, cx, cy, r)
    # sparkles among the bubbles
    for sx, sy in ((28, 17), (55, 22), (46, 36)):
        put(img, [(sx, sy), (sx - 1, sy), (sx + 1, sy), (sx, sy - 1), (sx, sy + 1)], SPEC_L)
        put(img, [(sx, sy)], WHITE)
    return img


# ---- 3: Purple Card ---------------------------------------------------------------------------
def purple_card():
    img = new()
    m = card_mask()
    d = dist(m, 3)
    px = img.load()
    p = TAROT
    for y in range(H):
        for x in range(W):
            dd = d[y][x]
            if not dd:
                continue
            # gentle diagonal sheen across the card
            band = (x + y * 0.6) % 46
            c = light(p, 0.07) if 6 <= band < 14 else light(p, 0.04) if 14 <= band < 17 else p
            if (x + y) < 40:
                c = mix(c, light(p, 0.08), 0.6)
            if dd == 1:
                c = dark(p, 0.32)
            elif dd == 2:
                edge_lr = not m[y][x + 1] or not m[y + 1][x] or (d[y][x + 1] == 1) or (d[y + 1][x] == 1)
                c = dark(p, 0.12) if edge_lr else light(p, 0.25)
            px[x, y] = c
    # faint embossed crescent and star, tone on tone
    moon = ellipse(35, 44, 13, 13) - ellipse(41, 40, 11, 11)
    star = poly([(44, 46), (46, 51), (51, 52), (47, 55), (48, 60), (44, 57), (40, 60), (41, 55), (37, 52), (42, 51)])
    for shape in (moon, star):
        put(img, {(x, y) for x, y in shape}, light(p, 0.06))
        put(img, {(x, y) for x, y in shape if (x - 1, y) not in shape or (x, y - 1) not in shape}, light(p, 0.2))
        put(img, {(x, y) for x, y in shape if (x + 1, y) not in shape or (x, y + 1) not in shape}, dark(p, 0.1))
    text(img, "JOKER", 65 - text_width("JOKER", SMALL), 85, SMALL, dark(p, 0.38))
    return img


# ---- 4/5: Legendary backgrounds ---------------------------------------------------------------
def legend_base(deep, pale, name):
    img = new()
    m = card_mask()
    d = dist(m, 1)
    px = img.load()
    for y in range(H):
        for x in range(W):
            if not d[y][x]:
                continue
            # harlequin lattice of diamonds, alternating two tones
            u, v = (x - 35) / 9 + (y - 40) / 13, (x - 35) / 9 - (y - 40) / 13
            cu, cv = math.floor(u), math.floor(v)
            c = deep if (cu + cv) % 2 else pale
            fu, fv = u - cu, v - cv
            if min(fu, 1 - fu) < 0.06 or min(fv, 1 - fv) < 0.06:
                c = mix(deep, pale, 0.5)
            if d[y][x] == 1:
                lower_right = x + 1 > 69 or y + 1 > 93 or not m[y][x + 1] or not m[y + 1][x]
                c = dark(deep, 0.25) if lower_right else light(pale, 0.5)
            px[x, y] = c
    cream = rgb('F7F1E4')
    put(img, rect(9, 87, 61, 87), rgb('B7A88A'))
    plate = {(x, y) for x, y in rect(8, 78, 62, 86)} - {(8, 78), (62, 78), (8, 86), (62, 86)}
    put(img, plate, cream)
    put(img, [(11, 82), (59, 82)], SLATE)
    text(img, name, 35 - text_width(name, SMALL) // 2, 80, SMALL, SLATE)
    return img


# ---- 6/7: Legendary jesters -------------------------------------------------------------------
def bell(img, cx, cy, r, col):
    b = ellipse(cx, cy, r, r)
    draw(img, b, col)
    put(img, [(round(cx) - 1, round(cy + r) - 1), (round(cx), round(cy + r) - 1), (round(cx) + 1, round(cy + r) - 1)],
        col['o'])
    put(img, [(round(cx - r * 0.4), round(cy - r * 0.4))], col['h'])


GOLDR = {'o': GOLD_D, 's': rgb('D99A2B'), 'b': GOLD, 'l': rgb('FBE29A'), 'h': WHITE}
SILVER = ramp(rgb('DCE2EC'), o=0.62, s=0.22, l=0.7)


def halves(img, mask, left, right, split=35, **kw):
    draw(img, {p for p in mask if p[0] <= split}, left, **kw)
    draw(img, {p for p in mask if p[0] > split}, right, **kw)


def ruff(img, cx, cy, rx, ry, n, col):
    """Pleated ruff: a ring of tubular folds around the neck, drawn back to front."""
    folds = []
    for k in range(n):
        t = 2 * math.pi * k / n
        folds.append((math.sin(t), ellipse(cx + rx * math.cos(t), cy + ry * math.sin(t), 2.6, 3.8)))
    edge = dict(col, o=mix(col['o'], col['s'], 0.25))
    for _, m in sorted(folds, key=lambda f: f[0]):
        draw(img, m, edge)


STAN_FACE = [  # x 27..43, y 40..46: brows raised in the middle, heavy lids, eyes cast down
    ".....bb...bb.....",
    "...bbb.....bbb...",
    "..bb.........bb..",
    ".................",
    "..kkkk.....kkkk..",
    "..wppw.....wppw..",
    "...ss.......ss...",
]


def stanczyk():
    img = new()
    red = ramp(rgb('E5484D'), o=0.6)
    wine = ramp(rgb('9C2B3E'), o=0.55)
    skin = ramp(rgb('F3D6C1'), o=0.62, s=0.2, l=0.4)
    hair = ramp(rgb('6E4A3B'), o=0.5, l=0.22)
    linen = ramp(rgb('F6F1E7'), o=0.55, s=0.26, l=0.5)

    hood = ellipse(35, 48, 15, 15.5)
    halves(img, hood, red, wine)
    ruff(img, 35, 64.5, 16.5, 3.6, 18, linen)
    face = ellipse(35, 47, 10.5, 13)
    draw(img, face, skin)
    put(img, {(x, y) for x, y in face if y <= 39}, skin['s'])  # shade under the hat brim
    stamp(img, STAN_FACE, 27, 40, {'b': hair['o'], 'k': skin['o'], 'w': WHITE, 'p': INK, 's': skin['s']})
    put(img, [(35, y) for y in range(44, 50)], skin['l'])
    put(img, [(36, y) for y in range(45, 50)], skin['s'])
    put(img, [(34, 50), (35, 51), (36, 51), (37, 50)], skin['o'])
    put(img, [(26, 47), (26, 48), (44, 47), (44, 48)], skin['s'])
    beard = poly([(27.5, 52), (42.5, 52), (40, 59), (35.5, 67.5), (34.5, 67.5), (30, 59)])
    draw(img, beard, hair)
    put(img, [(33, 60), (34, 62), (34, 63), (32, 57)], hair['l'])
    put(img, [(37, 58), (36, 61), (38, 56)], hair['s'])
    put(img, [(33, 55), (34, 55), (35, 55), (36, 55), (37, 55), (32, 56), (38, 56)], rgb('5E1E28'))
    moust = poly([(28, 54.5), (32, 51), (35, 52), (38, 51), (42, 54.5), (38, 53.4), (35, 54), (32, 53.4)])
    draw(img, moust, hair)
    put(img, [(31, 52), (32, 52)], hair['l'])

    # three-pointed hat: side points droop beside the face, the middle one flops over to the right
    horn_l = tube(bezier((27, 31), (13, 17), (13, 37)), 5.2, 1.6)
    horn_r = tube(bezier((43, 31), (57, 17), (57, 37)), 5.2, 1.6)
    horn_m = tube(bezier((35, 30), (32, 7), (46, 14)), 5.6, 1.6)
    draw(img, horn_m, wine)
    draw(img, horn_l, red)
    draw(img, horn_r, red)
    crown = ellipse(35, 34, 13.5, 7) - rect(0, 36, 70, 94)
    halves(img, crown, wine, red)
    band = rect(21, 34, 49, 38) - {(21, 34), (49, 34), (21, 38), (49, 38)}
    draw(img, band, GOLDR, sh=1)
    for x in range(23, 49, 4):
        put(img, [(x, 36), (x + 1, 35), (x + 1, 37), (x + 2, 36), (x + 1, 36)], wine['b'])
    put(img, [(17, 23), (18, 22), (19, 21), (16, 25)], red['h'])
    put(img, [(31, 17), (31, 16), (32, 14)], wine['l'])
    put(img, [(47, 22), (48, 21)], red['h'])
    put(img, [(29, 29), (30, 28), (31, 28)], wine['l'])
    bell(img, 13, 40, 2.8, GOLDR)
    bell(img, 57, 40, 2.8, GOLDR)
    bell(img, 48, 16, 2.8, GOLDR)
    return img


DAG_FACE = [  # x 26..44, y 42..45: arched brows, eyes squeezed shut with laughter
    "...bbb.......bbb...",
    "..b...b.....b...b..",
    "...kkk.......kkk...",
    "..kk.kk.....kk.kk..",
]


def dagonet():
    img = new()
    green = ramp(rgb('3FA66B'), o=0.6)
    gold = dict(GOLDR)
    paint = ramp(rgb('F7F3EC'), o=0.55, s=0.12, l=0.6)
    paint['s'] = rgb('E0D8DC')
    ink = rgb('3B2B3A')

    # pointed collar: five petals hang from the neck, alternating green and gold, a bell on every tip
    petals = []
    for i, deg in enumerate((-66, -33, 0, 33, 66)):
        a = math.radians(deg)
        tip = (35 + 22 * math.sin(a), 58 + 12 * math.cos(a))
        bl = (35 + 10 * math.sin(a - 0.5), 56 + 6 * math.cos(a - 0.5))
        br = (35 + 10 * math.sin(a + 0.5), 56 + 6 * math.cos(a + 0.5))
        petals.append((abs(deg), poly([bl, tip, br, (35, 53)]), tip, i))
    petals.sort(key=lambda p: -p[0])
    for _, m, tip, i in petals:
        draw(img, m, green if i % 2 == 0 else gold)
    for _, m, tip, i in petals:
        bell(img, tip[0], tip[1] + 1.5, 2.2, SILVER)

    hair = ramp(rgb('E5853B'), o=0.55, l=0.35)
    for sx in (1, -1):
        curls = set()
        for cx, cy, r in ((23, 42, 3.2), (22, 47, 2.8), (24, 51, 2.3)):
            curls |= ellipse(35 + sx * (cx - 35), cy, r, r)
        draw(img, curls, hair)
    face = ellipse(35, 48, 11.5, 11.5)
    draw(img, face, paint)
    stamp(img, DAG_FACE, 26, 42, {'b': hair['o'], 'k': ink})
    # green diamond under the left eye, blush on the right cheek
    put(img, [(29, 47), (28, 48), (29, 48), (30, 48), (29, 49), (29, 50)], green['b'])
    put(img, [(28, 48), (29, 47)], green['l'])
    put(img, ellipse(41.5, 49, 2.2, 1.3), rgb('F59BA3'))
    put(img, [(40, 49)], rgb('FBC6C9'))
    nose = ellipse(35, 48, 2, 1.8)
    draw(img, nose, ramp(rgb('EF5A5F'), o=0.5), outline=False)
    put(img, [(34, 47)], WHITE)
    mouth = poly([(28.5, 51.5), (41.5, 51.5), (39, 56), (35, 57.4), (31, 56)])
    put(img, mouth, rgb('7A1F2B'))
    put(img, {(x, 52) for x in range(30, 41)}, WHITE)
    put(img, {(x, y) for x, y in mouth if y >= 55}, rgb('E46473'))
    put(img, rim(mouth) & face, rgb('5A1520'))
    put(img, [(28, 51), (42, 51), (27, 50), (43, 50)], rgb('5A1520'))

    # two-pointed hat sweeping up and out, curling at the tips
    horn_l = tube(bezier((29, 33), (19, 30), (17, 19)) + bezier((17, 19), (16, 9), (12, 12)), 5.6, 1.6)
    horn_r = tube(bezier((41, 33), (51, 30), (53, 19)) + bezier((53, 19), (54, 9), (58, 12)), 5.6, 1.6)
    draw(img, horn_l, green)
    draw(img, horn_r, gold)
    crown = ellipse(35, 36, 13, 8) - rect(0, 38, 70, 94)
    halves(img, crown, gold, green)
    band = rect(22, 36, 48, 39) - {(22, 36), (48, 36), (22, 39), (48, 39)}
    draw(img, band, green, sh=1)
    for x in range(24, 48, 4):
        put(img, [(x, 37), (x + 1, 37), (x, 38), (x + 1, 38)], gold['b'])
        put(img, [(x, 37)], gold['l'])
    put(img, [(15, 23), (15, 22), (16, 20), (14, 25)], green['h'])
    put(img, [(51, 23), (51, 22), (52, 20)], gold['h'])
    put(img, [(28, 31), (29, 30), (30, 30)], gold['h'])
    bell(img, 11, 15, 2.8, SILVER)
    bell(img, 59, 15, 2.8, SILVER)
    return img


# ---- sheet ------------------------------------------------------------------------------------
def build():
    cells = [coupon_clipper(), piggy_bank(), toil_and_trouble(), purple_card(),
             legend_base(rgb('D9A3A0'), rgb('EFCFCB'), "STANCZYK"),
             legend_base(rgb('A9CDB0'), rgb('D2E8D5'), "DAGONET"),
             stanczyk(), dagonet()]
    return {'jokers': sheet(cells)}
