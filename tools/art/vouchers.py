"""Voucher sheet: 7 tickets in the order items/vouchers.lua expects.

    0 Tempered Glass   1 Laminated Glass   2 Bulletproof Glass   (teal, tiers 1-3)
    3 Supplier         4 Wholesaler                              (plum, tiers 1-2)
    5 Talent Scout     6 Headhunter                              (ochre, tiers 1-2)

Light comes from the top-left everywhere: bodies carry a diagonal sheen and a bevel, every icon
material has a three-tone ramp plus highlights, outlines use a dark tone of the object's own colour,
and each icon drops a hard 1px shadow down-right onto the ticket.
"""
import math

from common import (CLEAR, FACE, GOLD, GOLD_D, INK, LAVENDER, MID, RARE, STUB, STUB_INK, UNCOMMON, WHITE,
                    dark, dist, in_round, light, mix, new, outlined, paste, rgb, round_mask, sheet, text,
                    text_width)

GLASS = rgb('1F7A8C')
STOCK = rgb('7B4B94')
SCOUT = rgb('B5772A')
TIER2_STUB = rgb('46587A')

# The dashed frame is x 14..56, y 28..86 and 2px thick, so icons keep to roughly x 17..53, y 31..83.


# ---- small helpers ------------------------------------------------------------------------------
def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def get(img, x, y):
    if 0 <= x < img.width and 0 <= y < img.height:
        return img.getpixel((x, y))
    return CLEAR


def blend(under, over, t):
    """over painted on top of under at opacity t (under may be transparent)."""
    if under[3] == 0:
        return over
    return mix(under, over, t)


def drop_shadow(cell, icon, colour, dx=1, dy=1):
    """Paints a hard shadow of the icon's silhouette onto the ticket body, then the icon itself."""
    shadow = new()
    for y in range(icon.height):
        for x in range(icon.width):
            if icon.getpixel((x, y))[3] and get(cell, x + dx, y + dy)[3]:
                put(shadow, x + dx, y + dy, colour)
    paste(cell, shadow)
    paste(cell, icon)


def bevel_tone(x, y, x0, y0, x1, y1, band, hi, mid, lo):
    """Top/left strip lit, bottom/right strip shaded; the two off-corners stay mid."""
    tl = y - y0 < band or x - x0 < band
    br = y1 - y < band or x1 - x < band
    if tl and br:
        return mid
    return hi if tl else lo if br else mid


def star_pixels(cx, cy, R, r, rot=-90):
    """Pixels covered (>= 50%) by a five-point star; supersampled 4x4."""
    pts = []
    for k in range(10):
        rad = R if k % 2 == 0 else r
        a = math.radians(rot + 36 * k)
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))

    def inside(px, py):
        hit = False
        j = len(pts) - 1
        for i in range(len(pts)):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                hit = not hit
            j = i
        return hit

    out = []
    for y in range(int(cy - R) - 1, int(cy + R) + 2):
        for x in range(int(cx - R) - 1, int(cx + R) + 2):
            n = sum(inside(x + (i + 0.5) / 4, y + (j + 0.5) / 4) for i in range(4) for j in range(4))
            if n >= 8:
                out.append((x, y))
    return out


def draw_star(img, cx, cy, R, r, outline=None):
    """Gold star lit from the top-left, outlined in dark gold."""
    lay = new()
    hi, mid, lo = light(GOLD, 0.55), GOLD, rgb('D99A2B')
    for x, y in star_pixels(cx, cy, R, r):
        dx, dy = x + 0.5 - cx, y + 0.5 - cy
        s = dx + dy * 0.8
        c = hi if s < -R * 0.25 else lo if s > R * 0.3 else mid
        put(lay, x, y, c)
    paste(img, outlined(lay, outline or dark(GOLD_D, 0.3)))


# ---- the ticket ---------------------------------------------------------------------------------
def ticket(main, tier):
    cell = new()
    w, h = cell.size
    m = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if y <= 19:
                inside = in_round(x, y, 6, 1, 64, 19, 2)
            elif y == 20:
                inside = 8 <= x <= 62
            else:
                inside = in_round(x, y, 6, 21, 64, 93, 2)
            if (x - 35) ** 2 + (y - 1.5) ** 2 <= 5.6 ** 2 or (x - 35) ** 2 + (y - 93.5) ** 2 <= 5.6 ** 2:
                inside = False
            m[y][x] = inside
    d = dist(m, 5)

    # stub colours by tier: light / dark with a gold bar / gold
    if tier == 1:
        fill, fill_hi, fill_lo, ink = STUB, WHITE, mix(STUB, LAVENDER, 0.35), STUB_INK
    elif tier == 2:
        fill, fill_hi, fill_lo, ink = TIER2_STUB, light(TIER2_STUB, 0.16), dark(TIER2_STUB, 0.12), STUB
    else:
        fill, fill_hi, fill_lo, ink = GOLD, light(GOLD, 0.4), rgb('E3A93C'), dark(GOLD_D, 0.35)

    # body ramp
    L3, L2, L1 = light(main, 0.48), light(main, 0.30), light(main, 0.15)
    D1, D2 = dark(main, 0.14), dark(main, 0.26)

    px = cell.load()
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd == 0:
                continue
            if dd == 1:
                c = LAVENDER
            elif y == 20:
                c = ink
            elif y < 20:
                if dd == 3:
                    c = ink
                elif dd == 2:
                    c = fill_hi if y <= 3 else fill_lo if y >= 17 else fill
                else:
                    c = fill_hi if y <= 4 else fill_lo if y >= 16 else fill
            elif dd == 2:
                c = dark(main, 0.35)
            elif dd == 3:
                c = STUB
            elif dd == 4:
                c = bevel_tone(x, y, 9, 24, 61, 90, 6, L2, main, D2)
            else:
                c = body(x, y, main, L3, L2, L1, D1, D2)
            px[x, y] = c

    # stub glints: tier 3 gets a diagonal gleam across the gold
    if tier == 2:
        for x0, x1 in ((11, 26), (44, 59)):
            for x in range(x0, x1 + 1):
                px[x, 5] = light(GOLD, 0.35)
                px[x, 6] = GOLD
            px[x0, 6] = px[x1, 6] = GOLD_D
    if tier == 3:
        for y in range(4, 19):
            for x in range(8, 63):
                if d[y][x] >= 4 and 0 <= (x + y) - 22 < 3:
                    px[x, y] = light(GOLD, 0.7)
                elif d[y][x] >= 4 and (x + y) - 22 == 4:
                    px[x, y] = light(GOLD, 0.4)

    text(cell, "VOUCHER", 35 - text_width("VOUCHER", MID) // 2, 12, MID, ink)

    # dashed frame around the icon, with a 1px shadow so it sits on the body
    fd = dist(round_mask(w, h, 14, 28, 56, 86, 4), 2)
    dash = [(x, y) for y in range(h) for x in range(w) if 1 <= fd[y][x] <= 2 and (x + y) % 6 < 4]
    dashset = set(dash)
    for x, y in dash:
        if (x + 1, y + 1) not in dashset and d[y + 1][x + 1] >= 4:
            px[x + 1, y + 1] = dark(main, 0.3)
    for x, y in dash:
        px[x, y] = STUB
    return cell


def body(x, y, main, L3, L2, L1, D1, D2):
    """Glossy body: broad diagonal sheen across the upper half, a thin echo stripe, a faint
    second sheen low down, and a darker lower third (dithered at the boundaries)."""
    u = x + 2 * y
    chk = (x + y) % 2
    # main sheen band
    if 88 <= u < 118:
        if 94 <= u < 112:
            return L3 if 98 <= u < 108 else L2
        return L1 if not (u in (88, 117) and chk) else main
    if 121 <= u < 124:
        return L2
    if 176 <= u < 188:
        return L1 if 179 <= u < 185 or chk else main
    # vertical value
    if y < 30:
        return L1 if y < 28 or chk else main
    if y > 82:
        return D2 if y > 85 or chk else D1
    if y > 70:
        return D1 if y > 72 or chk else main
    return main


# ---- glass line ---------------------------------------------------------------------------------
GLASS_HI, GLASS_MID, GLASS_LO = rgb('E4F8FF'), rgb('A9E1F2'), rgb('6EBFD8')
GLASS_LINE = dark(GLASS, 0.55)
SILVER = (WHITE, rgb('CFDCE6'), rgb('8FA5B5'))
GOLDS = (light(GOLD, 0.5), GOLD, rgb('C98A22'))


def pane(cell, x0, y0, w, h, frame, alpha=0.82):
    """A framed glass pane on the cell. Glass is slightly see-through so whatever is behind it
    (the ticket, or another pane) shows faintly."""
    x1, y1 = x0 + w - 1, y0 + h - 1
    m = round_mask(w, h, 0, 0, w - 1, h - 1, 2)
    d = dist(m, 4)
    lay = new()
    for j in range(h):
        for i in range(w):
            dd = d[j][i]
            if dd == 0:
                continue
            x, y = x0 + i, y0 + j
            if dd == 1:
                c = GLASS_LINE
            elif dd <= 3:
                c = bevel_tone(x, y, x0 + 1, y0 + 1, x1 - 1, y1 - 1, 2, *frame)
                # inner lip of the frame catches a darker edge on the bottom/right
                if dd == 3 and (j >= h - 4 or i >= w - 4) and not (j < 3 or i < 3):
                    c = frame[2]
            else:
                # glass: light at the top-left fading to the deeper tint bottom-right
                t = (i / w + j / h) / 2
                g = GLASS_HI if t < 0.30 else GLASS_MID if t < 0.62 else GLASS_LO
                # inner shadow line under the top/left frame lip
                if dd == 4 and (j == 3 or i == 3):
                    g = GLASS_LO
                # glints: a broad and a thin streak running "/" through the upper-left
                s = i + j
                k = int((w + h) * 0.30)
                if k <= s < k + 3 or s == k + 5:
                    g = WHITE
                k2 = int((w + h) * 0.68)
                if k2 <= s < k2 + 2:
                    g = GLASS_HI
                c = blend(get(cell, x, y), g, alpha)
            put(lay, x, y, c)
    paste(cell, lay)
    return lay


def sparkle(img, x, y, size=2, colour=WHITE):
    put(img, x, y, colour)
    for k in range(1, size + 1):
        c = colour if k < size else mix(colour, GLASS_HI, 0.5)
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            put(img, x + dx, y + dy, c)


def icon_glass(main, tier):
    cell = ticket(main, tier)
    icon = new()
    if tier == 1:
        pane(icon, 21, 35, 29, 44, SILVER, alpha=1.0)
        sparkle(icon, 47, 37, 2)
    elif tier == 2:
        pane(icon, 27, 33, 25, 38, SILVER, alpha=1.0)
        pane(icon, 19, 42, 25, 38, SILVER)
        sparkle(icon, 48, 35, 2)
    else:
        pane(icon, 30, 32, 22, 34, SILVER, alpha=1.0)
        pane(icon, 25, 37, 22, 34, SILVER)
        pane(icon, 19, 44, 24, 36, GOLDS)
        draw_star(icon, 31.0, 62.5, 8.6, 3.7)
        sparkle(icon, 49, 34, 2)
    drop_shadow(cell, icon, dark(main, 0.45))
    return cell


# ---- stock line ---------------------------------------------------------------------------------
WOOD_HI, WOOD_L, WOOD_M, WOOD_D = rgb('F3CF8E'), rgb('E0A85E'), rgb('C0823F'), rgb('8C5627')
WOOD_LINE = rgb('4E2A10')


def crate(img, x, y, w, h, dep):
    """Wooden crate in oblique view: front face (w x h) at (x, y + dep), top face and right side
    receding up-right by dep pixels. Lit from the top-left: top lightest, side darkest."""
    lay = new()
    fy = y + dep  # front face top row
    fx1, fy1 = x + w - 1, fy + h - 1
    rim = 3 if w >= 20 else 2
    # front face
    for j in range(h):
        for i in range(w):
            X, Y = x + i, fy + j
            on_frame = i < rim or j < rim or i >= w - rim or j >= h - rim
            if on_frame:
                c = WOOD_L
                if i == rim - 1 and rim <= j < h - rim or j == rim - 1 and rim <= i < w - rim:
                    c = WOOD_D  # inner edge of the frame boards, shaded toward the inset panel
                elif j == h - 1 or i == w - 1:
                    c = WOOD_M
                elif j == 0 or i == 0:
                    c = WOOD_HI
            else:
                # inset planks with seams
                ii, jj = i - rim, j - rim
                ih = h - 2 * rim
                c = WOOD_M
                seams = max(1, ih // 5)
                if jj > 0 and jj % (ih // (seams + 1) + 1) == 0:
                    c = WOOD_D
                if jj == 0:
                    c = WOOD_D
                # diagonal brace from bottom-left to top-right
                iw = w - 2 * rim
                bd = jj - (ih - 1 - round(ii * (ih - 1) / max(1, iw - 1)))
                if -1 <= bd <= 1:
                    c = WOOD_HI if bd == -1 else WOOD_L
                elif bd == 2:
                    c = WOOD_D
            put(lay, X, Y, c)
    # top face
    for k in range(1, dep + 1):
        Y = fy - k
        for i in range(w):
            X = x + i + k
            c = WOOD_HI if (i + k) % 6 else WOOD_L
            if k == dep:
                c = WOOD_L
            put(lay, X, Y, c)
    # right side
    for k in range(1, dep + 1):
        X = fx1 + k
        for j in range(h):
            Y = fy + j - k
            c = WOOD_D if j < h - 1 else dark(WOOD_D, 0.2)
            if j < rim - 1 or j >= h - rim:
                c = WOOD_M
            put(lay, X, Y, c)
    # crisp edges between faces
    for k in range(0, dep + 1):
        put(lay, fx1 + k, fy - k, WOOD_LINE)
    for i in range(w):
        put(lay, x + i, fy, WOOD_LINE)
    for j in range(h):
        put(lay, fx1, fy + j, WOOD_LINE)
    # restore the lit top rim row of the front frame (one below the edge line)
    for i in range(1, w - 1):
        put(lay, x + i, fy + 1, WOOD_HI)
    # nails at the frame corners
    for nx, ny in ((x + 1, fy + 2), (fx1 - 2, fy + 2), (x + 1, fy1 - 1), (fx1 - 2, fy1 - 1)):
        put(lay, nx, ny, WOOD_LINE)
    paste(img, outlined(lay, WOOD_LINE))


def icon_stock(main, tier):
    cell = ticket(main, tier)
    icon = new()
    if tier == 1:
        crate(icon, 19, 40, 27, 27, 7)
    else:
        crate(icon, 18, 61, 16, 15, 4)   # bottom-left
        crate(icon, 34, 61, 16, 15, 4)   # bottom-right
        crate(icon, 26, 43, 16, 15, 4)   # top
    drop_shadow(cell, icon, dark(main, 0.45))
    return cell


# ---- scout line ---------------------------------------------------------------------------------
JESTER = [
    "b...........b",
    "Hh.........hd",
    ".Hh...b...hd.",
    ".HHh.Hhd.hdd.",
    "..HHhHhdhddd.",
    "..HHhhhhhddd.",
    "..ggGgggGgg..",
    "..fffffffff..",
    "..fkkfffkkf..",
    "..ffffffffs..",
    "..fpfffffps..",
    "..ffkfffkfs..",
    "...ffkkkfs...",
    "....fffss....",
    "..rwrwrwrwr..",
    "...rwrwrwr...",
]


def mini_joker(img, x0, y0, panel):
    w, h = 27, 39
    lay = new()
    d = dist(round_mask(w, h, 0, 0, w - 1, h - 1, 2), 4)
    phi, pmid, plo = light(panel, 0.28), panel, dark(panel, 0.22)
    edge = dark(panel, 0.6)
    for j in range(h):
        for i in range(w):
            dd = d[j][i]
            if dd == 0:
                continue
            if dd == 1:
                c = edge
            elif dd <= 3:
                # white card border, shaded on the bottom/right
                c = FACE
                if dd == 2:
                    c = rgb('D9DEE8') if (j >= h - 3 or i >= w - 3) and not (j < 3 or i < 3) else WHITE
            else:
                t = (i / w + j / h) / 2
                c = phi if t < 0.22 else pmid if t < 0.66 else plo
                if dd == 4 and (j == 3 or i == 3):
                    c = plo  # inset shadow under the border
                s = i + j
                if 27 <= s < 30:
                    c = mix(c, WHITE, 0.25)
            put(lay, x0 + i, y0 + j, c)
    pal = {'b': GOLD, 'H': dark(panel, 0.2), 'h': dark(panel, 0.38), 'd': dark(panel, 0.55), 'g': GOLD, 'G': light(GOLD, 0.5),
           'f': FACE, 's': rgb('D9DEE8'), 'k': INK, 'p': rgb('F49AA0'), 'r': GOLD, 'w': WHITE}
    jx, jy = x0 + (w - len(JESTER[0])) // 2, y0 + 8
    jest = new()
    for j, row in enumerate(JESTER):
        for i, ch in enumerate(row):
            if ch in pal:
                put(jest, jx + i, jy + j, pal[ch])
    paste(lay, outlined(jest, dark(panel, 0.5)))
    paste(img, lay)


def lens(img, cx, cy):
    """Magnifying glass: brass rim, see-through lens that enlarges what is under it, wooden handle."""
    dark_brass = rgb('5C3A10')
    # handle down-right at 45 degrees
    hl = new()
    for t in range(0, 9):
        for o in (-1, 0, 1):
            x = round(cx + 6.5 + t * 0.707 + o * 0.707)
            y = round(cy + 6.5 + t * 0.707 - o * 0.707)
            c = WOOD_L if o == -1 else WOOD_M if o == 0 else WOOD_D
            put(hl, x, y, c)
    for t in range(0, 9):
        x = round(cx + 6.5 + t * 0.707)
        y = round(cy + 6.5 + t * 0.707)
        if get(hl, x - 1, y)[3] == 0:
            put(hl, x - 1, y, WOOD_L)
    paste(img, outlined(hl, WOOD_LINE))
    # lens + rim
    src = img.copy()
    rim = new()
    R = 8.6
    for y in range(int(cy - R) - 1, int(cy + R) + 2):
        for x in range(int(cx - R) - 1, int(cx + R) + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r > R:
                continue
            if r > R - 2.2:
                a = dx + dy
                c = GOLDS[0] if a < -3 else GOLDS[2] if a > 3 else GOLDS[1]
            else:
                # magnified view of what lies beneath, tinted like glass
                sx, sy = cx + dx / 1.7, cy + dy / 1.7
                under = src.getpixel((int(sx), int(sy)))
                base = under if under[3] else get(img, x, y)
                c = mix(base, GLASS_HI, 0.3) if base[3] else GLASS_MID
                if r > R - 3.2 and dx + dy > 2:
                    c = mix(c, GLASS_LO, 0.5)  # inner shade under the rim
            put(rim, x, y, c)
    # highlight arc on the upper-left of the glass
    for a in range(200, 260, 8):
        rr = R - 3.6
        put(rim, round(cx - 0.5 + rr * math.cos(math.radians(a))), round(cy - 0.5 + rr * math.sin(math.radians(a))), WHITE)
    put(rim, int(cx) - 2, int(cy) - 2, WHITE)
    paste(img, outlined(rim, dark_brass))


def reticle(img, cx, cy):
    """Gold crosshair: a ring crossed by four 1px ticks, with a pip in the middle.
    cx, cy should sit on a pixel centre (x.5) so the ticks centre exactly."""
    g = new()
    R = 7.6
    for y in range(int(cy - 12), int(cy + 13)):
        for x in range(int(cx - 12), int(cx + 13)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if R - 1.7 < r <= R:
                a = dx + dy
                put(g, x, y, GOLDS[0] if a < -3 else GOLDS[2] if a > 3 else GOLDS[1])
    ix, iy = int(cx), int(cy)
    for k in range(3, 12):
        put(g, ix, iy - k, GOLDS[0])
        put(g, ix - k, iy, GOLDS[0])
        put(g, ix, iy + k, GOLDS[2])
        put(g, ix + k, iy, GOLDS[2])
    put(g, ix, iy, light(GOLD, 0.6))
    paste(img, outlined(g, rgb('5C3A10')))


def icon_scout(main, tier):
    cell = ticket(main, tier)
    icon = new()
    mini_joker(icon, 18, 32, UNCOMMON if tier == 1 else RARE)
    if tier == 1:
        lens(icon, 40.0, 66.0)
    else:
        reticle(icon, 39.5, 66.5)
        draw_star(icon, 48.6, 38.0, 5.7, 2.5)
    drop_shadow(cell, icon, dark(main, 0.45))
    return cell


def build():
    cells = [
        icon_glass(GLASS, 1), icon_glass(GLASS, 2), icon_glass(GLASS, 3),
        icon_stock(STOCK, 1), icon_stock(STOCK, 2),
        icon_scout(SCOUT, 1), icon_scout(SCOUT, 2),
    ]
    return {'vouchers': sheet(cells)}
