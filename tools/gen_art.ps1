# Generates every PowerDecks sprite sheet (1x and 2x) from code.
# Run:  pwsh -File tools/gen_art.ps1 [-Preview <path-to-png>]
# Each sprite sits in its own cell, so any of them can be repainted by hand afterwards.
#
# Conventions followed (measured from the base game's sprites):
#   Cards    71x95 cell, 1px transparent padding, corner rows start at x = 4, 2, 2, 1.
#   Jokers   1px #BFC7D5 outline, #FDFDFD face, "JOKER" stacked vertically at (6,7) in #4F6367 with
#            7x8 letters, and the same text rotated 180 degrees in the bottom-right corner.
#            Jokers with a coloured panel keep a 3px white border inside the outline.
#   Legendary  full-bleed two-tone background, cream name plate on rows 78-86, and the character
#            on a separate floating layer (soul_pos).
#   Vouchers 59px wide ticket: stub on rows 1-19 holding the word VOUCHER, a pinched neck on row 20,
#            round notches top and bottom centre, a dashed white frame around the icon.
#            Upgraded tiers use a dark stub with a gold bar.
#   Decks    3px pure white border with no outline, pattern fills the rest.
param([string]$Preview = "")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;

public class Cv {
    public int W, H; public uint[] D;
    public Cv(int w, int h) { W = w; H = h; D = new uint[w * h]; }
    public void Set(int x, int y, uint c) { if (x >= 0 && y >= 0 && x < W && y < H) D[y * W + x] = c; }
    public uint Get(int x, int y) { return (x >= 0 && y >= 0 && x < W && y < H) ? D[y * W + x] : 0u; }
    public bool Solid(int x, int y) { return (Get(x, y) >> 24) != 0; }
    public void Fill(uint c) { for (int i = 0; i < D.Length; i++) D[i] = c; }
    public void Blit(Cv s, int ox, int oy) {
        for (int y = 0; y < s.H; y++) for (int x = 0; x < s.W; x++) {
            uint c = s.D[y * s.W + x];
            if ((c >> 24) != 0) Set(ox + x, oy + y, c);
        }
    }
    public Cv Scale(int k) {
        var r = new Cv(W * k, H * k);
        for (int y = 0; y < r.H; y++) for (int x = 0; x < r.W; x++) r.D[y * r.W + x] = D[(y / k) * W + (x / k)];
        return r;
    }
    public int[] Ints() { var r = new int[D.Length]; for (int i = 0; i < r.Length; i++) r[i] = unchecked((int)D[i]); return r; }
}

public static class Art {
    public const uint WHITE = 0xFFFFFFFFu;
    public static uint Hex(string s) { return 0xFF000000u | Convert.ToUInt32(s, 16); }
    public static uint Mix(uint a, uint b, double t) {
        uint r = 0xFF000000u;
        for (int sh = 0; sh <= 16; sh += 8) {
            double ca = (a >> sh) & 0xFF, cb = (b >> sh) & 0xFF;
            r |= ((uint)Math.Round(ca + (cb - ca) * t) & 0xFF) << sh;
        }
        return r;
    }
    public static uint Dark(uint c, double t) { return Mix(c, 0xFF000000u, t); }
    public static uint Light(uint c, double t) { return Mix(c, WHITE, t); }
    public static int Mod(int a, int n) { int r = a % n; return r < 0 ? r + n : r; }
    static double Sq(double v) { return v * v; }

    // ---- shapes -----------------------------------------------------------------------------
    static bool InRound(int x, int y, int x0, int y0, int x1, int y1, int r) {
        if (x < x0 || x > x1 || y < y0 || y > y1) return false;
        double dx = 0, dy = 0;
        if (x < x0 + r) dx = x0 + r - x - 0.5; else if (x > x1 - r) dx = x - (x1 - r) - 0.5;
        if (y < y0 + r) dy = y0 + r - y - 0.5; else if (y > y1 - r) dy = y - (y1 - r) - 0.5;
        return !(dx > 0 && dy > 0 && dx * dx + dy * dy > r * r);
    }
    public static bool[] RoundRect(int w, int h, int x0, int y0, int x1, int y1, int r) {
        var m = new bool[w * h];
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) m[y * w + x] = InRound(x, y, x0, y0, x1, y1, r);
        return m;
    }
    static bool[] CardMask() { return RoundRect(71, 95, 1, 1, 69, 93, 5); }
    // Distance (in pixels, 4-connected) from each masked pixel to the outside; edge pixels are 1.
    public static int[] Dist(bool[] m, int w, int h, int max) {
        var d = new int[w * h];
        for (int i = 0; i < d.Length; i++) d[i] = m[i] ? max + 1 : 0;
        for (int level = 1; level <= max; level++) {
            var hit = new List<int>();
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
                int i = y * w + x;
                if (d[i] != max + 1) continue;
                bool edge = x == 0 || y == 0 || x == w - 1 || y == h - 1
                    || d[i - 1] == level - 1 || d[i + 1] == level - 1 || d[i - w] == level - 1 || d[i + w] == level - 1;
                if (edge) hit.Add(i);
            }
            foreach (int i in hit) d[i] = level;
        }
        return d;
    }
    public static void Rect(Cv cv, int x0, int y0, int x1, int y1, uint c) {
        for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) cv.Set(x, y, c);
    }
    public static void Ellipse(Cv cv, double cx, double cy, double rx, double ry, uint c) {
        for (int y = (int)Math.Floor(cy - ry); y <= (int)Math.Ceiling(cy + ry); y++)
            for (int x = (int)Math.Floor(cx - rx); x <= (int)Math.Ceiling(cx + rx); x++)
                if (Sq((x - cx) / rx) + Sq((y - cy) / ry) <= 1) cv.Set(x, y, c);
    }
    public static void Circle(Cv cv, double cx, double cy, double r, uint c) { Ellipse(cv, cx, cy, r, r, c); }
    public static void Line(Cv cv, int x0, int y0, int x1, int y1, uint c) {
        int dx = Math.Abs(x1 - x0), dy = -Math.Abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, e = dx + dy;
        while (true) {
            cv.Set(x0, y0, c);
            if (x0 == x1 && y0 == y1) break;
            int e2 = 2 * e;
            if (e2 >= dy) { e += dy; x0 += sx; }
            if (e2 <= dx) { e += dx; y0 += sy; }
        }
    }
    // Copy of the canvas with a 1px outline drawn around everything on it
    static Cv Outlined(Cv s, uint c) {
        var r = new Cv(s.W, s.H);
        for (int y = 0; y < s.H; y++) for (int x = 0; x < s.W; x++) {
            if (s.Solid(x, y)) r.Set(x, y, s.Get(x, y));
            else if (s.Solid(x - 1, y) || s.Solid(x + 1, y) || s.Solid(x, y - 1) || s.Solid(x, y + 1)) r.Set(x, y, c);
        }
        return r;
    }
    public static void Stamp(Cv cv, string[] rows, int x0, int y0, int scale, Dictionary<char, uint> pal) {
        for (int y = 0; y < rows.Length; y++) for (int x = 0; x < rows[y].Length; x++) {
            uint c; if (!pal.TryGetValue(rows[y][x], out c)) continue;
            Rect(cv, x0 + x * scale, y0 + y * scale, x0 + x * scale + scale - 1, y0 + y * scale + scale - 1, c);
        }
    }
    static Dictionary<char, uint> Pal(params object[] kv) {
        var p = new Dictionary<char, uint>();
        for (int i = 0; i < kv.Length; i += 2) p[(char)kv[i]] = (uint)kv[i + 1];
        return p;
    }
    static void Medallion(Cv cv, double cx, double cy, double r, uint rim, uint fill) {
        Circle(cv, cx, cy, r, rim); Circle(cv, cx, cy, r - 1.5, WHITE); Circle(cv, cx, cy, r - 3.5, fill);
    }

    // ---- lettering (drawn for this mod, sized to the game's conventions) ---------------------
    static Dictionary<char, string[]> Font(params object[] kv) {
        var f = new Dictionary<char, string[]>();
        for (int i = 0; i < kv.Length; i += 2) f[(char)kv[i]] = (string[])kv[i + 1];
        return f;
    }
    static readonly Dictionary<char, string[]> BIG = Font(
        'J', new[] { "..#####", "....##.", "....##.", "....##.", "....##.", "##..##.", "##..##.", ".####.." },
        'O', new[] { ".#####.", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", ".#####." },
        'K', new[] { "##...##", "##..##.", "##.##..", "####...", "####...", "##.##..", "##..##.", "##...##" },
        'E', new[] { "#######", "##.....", "##.....", "#####..", "##.....", "##.....", "##.....", "#######" },
        'R', new[] { "######.", "##...##", "##...##", "######.", "##.##..", "##..##.", "##...##", "##...##" });
    static readonly Dictionary<char, string[]> MID = Font(
        'V', new[] { "##..##", "##..##", "##..##", "##..##", ".####.", ".####.", "..##.." },
        'O', new[] { ".####.", "##..##", "##..##", "##..##", "##..##", "##..##", ".####." },
        'U', new[] { "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####." },
        'C', new[] { ".#####", "##....", "##....", "##....", "##....", "##....", ".#####" },
        'H', new[] { "##..##", "##..##", "##..##", "######", "##..##", "##..##", "##..##" },
        'E', new[] { "######", "##....", "##....", "#####.", "##....", "##....", "######" },
        'R', new[] { "#####.", "##..##", "##..##", "#####.", "##.##.", "##..##", "##..##" });
    static readonly Dictionary<char, string[]> SMALL = Font(
        'A', new[] { ".##.", "#..#", "####", "#..#", "#..#" },
        'C', new[] { ".###", "#...", "#...", "#...", ".###" },
        'D', new[] { "###.", "#..#", "#..#", "#..#", "###." },
        'E', new[] { "####", "#...", "###.", "#...", "####" },
        'G', new[] { ".###", "#...", "#.##", "#..#", ".###" },
        'J', new[] { "..##", "...#", "...#", "#..#", ".##." },
        'K', new[] { "#..#", "#.#.", "##..", "#.#.", "#..#" },
        'N', new[] { "#..#", "##.#", "#.##", "#..#", "#..#" },
        'O', new[] { ".##.", "#..#", "#..#", "#..#", ".##." },
        'R', new[] { "###.", "#..#", "###.", "#.#.", "#..#" },
        'S', new[] { ".###", "#...", ".##.", "...#", "###." },
        'T', new[] { "###", ".#.", ".#.", ".#.", ".#." },
        'Y', new[] { "#.#", "#.#", ".#.", ".#.", ".#." },
        'Z', new[] { "####", "...#", ".##.", "#...", "####" });
    static int TextWidth(string s, Dictionary<char, string[]> f) {
        int w = 0; foreach (char ch in s) w += f[ch][0].Length + 1; return w - 1;
    }
    static void Text(Cv cv, string s, int x, int y, Dictionary<char, string[]> f, uint c) {
        foreach (char ch in s) {
            var g = f[ch];
            for (int r = 0; r < g.Length; r++) for (int q = 0; q < g[r].Length; q++) if (g[r][q] == '#') cv.Set(x + q, y + r, c);
            x += g[0].Length + 1;
        }
    }
    static void JokerText(Cv cv, uint c) {
        const string s = "JOKER";
        for (int i = 0; i < 5; i++) {
            var g = BIG[s[i]];
            for (int r = 0; r < 8; r++) for (int q = 0; q < 7; q++) if (g[r][q] == '#') {
                int px = 6 + q, py = 7 + i * 9 + r;
                cv.Set(px, py, c); cv.Set(70 - px, 94 - py, c);
            }
        }
    }

    // ---- palette ----------------------------------------------------------------------------
    static readonly uint OUTLINE = Hex("BFC7D5"), FACE = Hex("FDFDFD"), SLATE = Hex("4F6367"), INK = Hex("2B2D42"), PARCH = Hex("F3EFE0");
    static readonly uint TITAN = Hex("D9552B"), SIGNET = Hex("6C4AB6"), TYCOON = Hex("2F9E69"), JACK = Hex("37415A");
    static readonly uint NAVY = Hex("1B2038"), NAVY_L = Hex("2C3460");
    static readonly uint GOLD = Hex("F2C14E"), GOLD_D = Hex("A8741A");
    static readonly uint SEAL_RED = Hex("E8463D"), SEAL_BLUE = Hex("3F8EF0"), SEAL_PURPLE = Hex("9B5DE5"), SEAL_GOLD = Hex("F2B93B");
    static readonly uint SPEC = Hex("4584FA"), SPEC_L = Hex("9BC4FF"), SPEC_D = Hex("2B4C9B");

    // ---- emblems (centred on cx, cy) --------------------------------------------------------
    static void EmblemTitan(Cv cv, int cx, int cy) {
        Medallion(cv, cx, cy, 17, Dark(TITAN, 0.55), Hex("2E3440"));
        int w = 19, h = 22; var m = new bool[w * h];
        for (int y = 0; y < h; y++) {
            double hw = y <= 10 ? 9 : 9 * Math.Sqrt(Math.Max(0, 1 - Math.Pow((y - 10) / 11.5, 2)));
            for (int x = 0; x < w; x++) m[y * w + x] = Math.Abs(x - 9) <= hw;
        }
        var d = Dist(m, w, h, 3);
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            int dd = d[y * w + x]; if (dd == 0) continue;
            uint c = dd == 1 ? GOLD_D : (x < 9 ? GOLD : Dark(GOLD, 0.14));
            int v = y - Math.Abs(x - 9);
            if (dd >= 3 && ((v >= 2 && v <= 4) || (v >= 7 && v <= 9))) c = Hex("2E3440");
            cv.Set(cx - 9 + x, cy - 11 + y, c);
        }
    }
    static void Seal(Cv cv, double cx, double cy, uint c) {
        Circle(cv, cx, cy, 5.6, Dark(c, 0.5)); Circle(cv, cx, cy, 4.3, c); Circle(cv, cx, cy, 2.2, Light(c, 0.25));
        cv.Set((int)cx - 2, (int)cy - 3, WHITE); cv.Set((int)cx - 3, (int)cy - 2, WHITE);
    }
    static void EmblemSignet(Cv cv, int cx, int cy) {
        Medallion(cv, cx, cy, 17, Dark(SIGNET, 0.55), PARCH);
        Seal(cv, cx, cy - 7.5, SEAL_RED); Seal(cv, cx + 7.5, cy, SEAL_BLUE);
        Seal(cv, cx, cy + 7.5, SEAL_PURPLE); Seal(cv, cx - 7.5, cy, SEAL_GOLD);
    }
    static readonly string[] DOLLAR = { "..#..", ".####", "#.#..", "#.#..", ".###.", "..#.#", "..#.#", "####.", "..#.." };
    static void EmblemTycoon(Cv cv, int cx, int cy) {
        Medallion(cv, cx, cy, 17, Dark(TYCOON, 0.6), Dark(TYCOON, 0.45));
        Circle(cv, cx, cy, 11.6, GOLD_D); Circle(cv, cx, cy, 10.2, GOLD); Circle(cv, cx, cy, 8.0, Dark(GOLD, 0.1));
        Circle(cv, cx - 3, cy - 5, 1.5, Light(GOLD, 0.6));
        Stamp(cv, DOLLAR, cx - 2, cy - 4, 1, Pal('#', Dark(GOLD_D, 0.25)));
    }
    static readonly string[] LETTER_J = { "..#####", "....##.", "....##.", "....##.", "....##.", "....##.", "##..##.", "##..##.", "##..##.", ".####.." };
    static void EmblemJack(Cv cv, int cx, int cy) {
        Medallion(cv, cx, cy, 17, Dark(JACK, 0.5), PARCH);
        Stamp(cv, LETTER_J, cx - 4, cy - 9, 1, Pal('#', INK));
        Circle(cv, cx - 7, cy + 7, 2.3, TITAN); Circle(cv, cx, cy + 9, 2.3, SIGNET); Circle(cv, cx + 7, cy + 7, 2.3, TYCOON);
    }
    static readonly string[] STAR = { "....#....", "....#....", "...###...", "#########", ".#######.", "..#####..", "..#####..", ".###.###.", ".#.....#." };
    static readonly string[] CROWN = {
        "#.....#.....#", "##...###...##", "###.#####.###", "#############", "#############", ".###########.", ".#r#p#g#p#r#.", ".###########." };
    // All three deck colours under one crown
    static void EmblemMaster(Cv cv, int cx, int cy) {
        Circle(cv, cx, cy, 20, GOLD_D); Circle(cv, cx, cy, 18.8, GOLD); Circle(cv, cx, cy, 17, GOLD_D);
        for (int y = cy - 17; y <= cy + 17; y++) for (int x = cx - 17; x <= cx + 17; x++) {
            double dx = x - cx, dy = y - cy;
            if (dx * dx + dy * dy > 15.9 * 15.9) continue;
            double a = (Math.Atan2(dy, dx) * 180 / Math.PI + 450) % 360;   // 0 = straight up, clockwise
            cv.Set(x, y, a < 120 ? TITAN : a < 240 ? SIGNET : TYCOON);
        }
        Line(cv, cx, cy, cx, cy - 15, WHITE); Line(cv, cx, cy, cx + 13, cy + 8, WHITE); Line(cv, cx, cy, cx - 13, cy + 8, WHITE);
        Circle(cv, cx, cy, 9.6, GOLD_D); Circle(cv, cx, cy, 8.4, NAVY);
        Stamp(cv, STAR, cx - 4, cy - 5, 1, Pal('#', GOLD));
        var crown = new Cv(cv.W, cv.H);
        Stamp(crown, CROWN, cx - 6, cy - 30, 1, Pal('#', GOLD, 'r', SEAL_RED, 'p', SEAL_PURPLE, 'g', TYCOON));
        cv.Blit(Outlined(crown, GOLD_D), 0, 0);
    }

    // ---- panel patterns ---------------------------------------------------------------------
    static uint PanelTitan(int x, int y) { return Mod(y + Math.Abs(x - 35), 9) < 3 ? Light(TITAN, 0.18) : TITAN; }
    static uint PanelSignet(int x, int y) { return (Mod(x + y, 10) == 0 || Mod(x - y, 10) == 0) ? Light(SIGNET, 0.28) : SIGNET; }
    static uint PanelTycoon(int x, int y) { return Mod(x + y, 8) < 2 ? Light(TYCOON, 0.2) : TYCOON; }
    static uint PanelJack(int x, int y) {
        int b = Mod(x + y, 24);
        return b < 3 ? TITAN : b < 6 ? SIGNET : b < 9 ? TYCOON : JACK;
    }
    // Rays and diamond rings spreading from the centre
    static uint PanelMaster(int x, int y) {
        int ax = Math.Abs(x - 35), ay = Math.Abs(y - 47);
        if (ax == 0 || ay == 0 || ax == ay) return Dark(GOLD, 0.45);
        if (Mod(ax + ay, 8) == 0) return NAVY_L;
        if (Mod(ax + ay, 8) == 4 && Mod(ax, 4) == 0) return Dark(GOLD, 0.3);
        return NAVY;
    }

    // ---- deck backs -------------------------------------------------------------------------
    static Cv Back(uint main, Func<int, int, uint> panel, Action<Cv, int, int> emblem) {
        var cv = new Cv(71, 95);
        var d = Dist(CardMask(), 71, 95, 6);
        for (int y = 0; y < 95; y++) for (int x = 0; x < 71; x++) {
            int dd = d[y * 71 + x]; if (dd == 0) continue;
            cv.Set(x, y, dd <= 3 ? WHITE : dd <= 5 ? Dark(main, 0.3) : dd == 6 ? WHITE : panel(x, y));
        }
        emblem(cv, 35, 47);
        return cv;
    }
    static readonly string[] FLEURON = { "..#..", ".###.", "##.##", ".###.", "..#.." };
    static Cv BackMaster() {
        var cv = new Cv(71, 95);
        var d = Dist(CardMask(), 71, 95, 10);
        for (int y = 0; y < 95; y++) for (int x = 0; x < 71; x++) {
            int dd = d[y * 71 + x]; if (dd == 0) continue;
            uint c;
            if (dd <= 3) c = WHITE;
            else if (dd == 4 || dd == 6) c = GOLD_D;
            else if (dd == 5) c = GOLD;
            else if (dd <= 9) {
                // a row of gold studs running along every edge
                bool horizontal = Math.Min(y - 1, 93 - y) < Math.Min(x - 1, 69 - x);
                int t = horizontal ? Mod(x - 34, 8) : Mod(y - 46, 8);
                c = (dd == 8 ? t <= 2 : t == 1) ? GOLD : NAVY;
            }
            else if (dd == 10) c = GOLD;
            else c = PanelMaster(x, y);
            cv.Set(x, y, c);
        }
        foreach (int fx in new[] { 13, 53 }) foreach (int fy in new[] { 13, 77 }) Stamp(cv, FLEURON, fx, fy, 1, Pal('#', GOLD));
        EmblemMaster(cv, 35, 49);
        return cv;
    }

    // ---- sleeves (73 x 95, open pocket with a base) -----------------------------------------
    static Cv Sleeve(uint main, uint trim, Func<int, int, uint> panel, Action<Cv, int, int> emblem) {
        int W = 73, H = 95; var cv = new Cv(W, H);
        var mb = RoundRect(W, H, 2, 74, 70, 92, 4);
        var db = Dist(mb, W, H, 2);
        for (int i = 0; i < W * H; i++) if (db[i] > 0) cv.D[i] = db[i] == 1 ? Dark(main, 0.7) : Dark(main, 0.5);
        var mf = new bool[W * H];
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            int notch = Math.Max(0, Math.Min(Math.Min(x - 9, 63 - x), 13));
            mf[y * W + x] = y >= 12 + notch && InRound(x, y, 2, 0, 70, 86, 5);
        }
        var df = Dist(mf, W, H, 4);
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            int dd = df[y * W + x]; if (dd == 0) continue;
            cv.Set(x, y, dd == 1 ? Dark(main, 0.6) : dd <= 3 ? WHITE : dd == 4 ? trim : panel(x - 1, y - 8));
        }
        emblem(cv, 36, 55);
        return cv;
    }

    // ---- vouchers ---------------------------------------------------------------------------
    static readonly uint LAVENDER = Hex("B8BFE8"), STUB = Hex("F6F6FF"), STUB_INK = Hex("3D5365");
    static Cv Voucher(uint main, int tier, Action<Cv> icon) {
        var cv = new Cv(71, 95);
        var m = new bool[71 * 95];
        for (int y = 0; y < 95; y++) for (int x = 0; x < 71; x++) {
            bool inside = y <= 19 ? InRound(x, y, 6, 1, 64, 19, 2) : y == 20 ? (x >= 8 && x <= 62) : InRound(x, y, 6, 21, 64, 93, 2);
            if (Sq(x - 35) + Sq(y - 1.5) <= 5.6 * 5.6 || Sq(x - 35) + Sq(y - 93.5) <= 5.6 * 5.6) inside = false;
            m[y * 71 + x] = inside;
        }
        var d = Dist(m, 71, 95, 3);
        uint fill = tier == 1 ? STUB : tier == 2 ? Hex("46587A") : GOLD;
        uint ink = tier == 1 ? STUB_INK : tier == 2 ? STUB : Dark(GOLD_D, 0.35);
        for (int y = 0; y < 95; y++) for (int x = 0; x < 71; x++) {
            int dd = d[y * 71 + x]; if (dd == 0) continue;
            uint c;
            if (dd == 1) c = LAVENDER;
            else if (y == 20) c = ink;
            else if (y < 20) c = dd == 3 ? ink : fill;
            else if (dd == 2) c = Dark(main, 0.35);
            else if (dd == 3) c = STUB;
            else {
                // glossy diagonal sheen
                int g = Mod(x + y * 2, 60);
                c = g < 8 ? Light(main, 0.28) : g < 14 ? Light(main, 0.14) : y > 72 ? Dark(main, 0.12) : main;
            }
            cv.Set(x, y, c);
        }
        if (tier == 2) { Rect(cv, 11, 5, 26, 6, GOLD); Rect(cv, 44, 5, 59, 6, GOLD); }
        Text(cv, "VOUCHER", 35 - TextWidth("VOUCHER", MID) / 2, 12, MID, ink);
        // dashed frame around the icon
        var fd = Dist(RoundRect(71, 95, 14, 28, 56, 86, 4), 71, 95, 2);
        for (int y = 0; y < 95; y++) for (int x = 0; x < 71; x++)
            if (fd[y * 71 + x] >= 1 && fd[y * 71 + x] <= 2 && Mod(x + y, 6) < 4) cv.Set(x, y, STUB);
        icon(cv);
        return cv;
    }
    static readonly uint GLASS = Hex("1F7A8C"), STOCK = Hex("7B4B94");
    static void Pane(Cv cv, int x0, int y0, uint frame, bool back) {
        int w = 23, h = 34; var m = RoundRect(w, h, 0, 0, w - 1, h - 1, 2);
        var d = Dist(m, w, h, 2);
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            int dd = d[y * w + x]; if (dd == 0) continue;
            uint c = dd == 1 ? Dark(GLASS, 0.6) : dd == 2 ? frame
                : Mod(x - y, 13) < 3 ? WHITE : (back ? Hex("9BD8EA") : Hex("CDEFFA"));
            cv.Set(x0 + x, y0 + y, c);
        }
    }
    static void IconGlass(Cv cv, int tier) {
        if (tier >= 2) Pane(cv, 28, 37, WHITE, true);
        Pane(cv, tier >= 2 ? 21 : 24, tier >= 2 ? 43 : 40, tier == 3 ? GOLD : WHITE, false);
        if (tier == 3) Stamp(cv, STAR, 24, 52, 2, Pal('#', GOLD_D));
        if (tier == 3) Stamp(cv, STAR, 23, 51, 2, Pal('#', GOLD));
    }
    static readonly string[] CRATE = {
        "#################", "#ooooooooooooooo#", "#################", "#o#ttttttttttt#o#", "#o##ttttttttt##o#",
        "#ot##ttttttt##to#", "#ott##ttttt##tto#", "#ottt##ttt##ttto#", "#otttt##t##tttto#", "#ottttt###ttttto#",
        "#otttt##t##tttto#", "#ottt##ttt##ttto#", "#ott##ttttt##tto#", "#################", "#ooooooooooooooo#", "#################" };
    static readonly Dictionary<char, uint> CRATE_PAL = Pal('#', Hex("5A3210"), 'o', Hex("C98F45"), 't', Hex("EDC27F"));
    static void IconStock(Cv cv, int tier) {
        if (tier == 1) { Stamp(cv, CRATE, 18, 41, 2, CRATE_PAL); return; }
        Stamp(cv, CRATE, 27, 40, 1, CRATE_PAL); Stamp(cv, CRATE, 18, 56, 1, CRATE_PAL); Stamp(cv, CRATE, 36, 56, 1, CRATE_PAL);
    }
    // Scout line: a small Joker card in its rarity colour, then a lens (tier 1) or a gold reticle (tier 2) in the same spot
    static readonly uint SCOUT = Hex("B5772A"), UNCOMMON = Hex("4BC292"), RARE = Hex("FE5F55");
    static readonly string[] JESTER_MINI = {
        "o.........o", "#.........#", "##.......##", "###.....###", ".###...###.", ".#########.",
        "..ggggggg..", "...wwwww...", "...wkwkw...", "...wwwww...", "....wrw....", };
    static void MiniJoker(Cv cv, int x0, int y0, uint panel) {
        int w = 26, h = 36; var d = Dist(RoundRect(w, h, 0, 0, w - 1, h - 1, 2), w, h, 3);
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            int dd = d[y * w + x]; if (dd == 0) continue;
            uint c = dd == 1 ? Dark(SCOUT, 0.65) : dd <= 3 ? FACE : Mod(x + y, 7) < 2 ? Light(panel, 0.16) : panel;
            cv.Set(x0 + x, y0 + y, c);
        }
        Stamp(cv, JESTER_MINI, x0 + 8, y0 + 6, 1, Pal('#', WHITE, 'o', GOLD, 'g', GOLD, 'w', FACE, 'k', INK, 'r', RARE));
    }
    static void IconScout(Cv cv, int tier) {
        MiniJoker(cv, 17, 35, tier == 1 ? UNCOMMON : RARE);
        double cx = 42, cy = 67;
        uint dark = Hex("2B2D42");
        if (tier == 1) {
            // handle first, so the rim sits on top of it
            var hd = new Cv(71, 95);
            for (int t = 0; t <= 2; t++) Line(hd, 47 + t, 73, 51 + t, 81, Hex("7A4A22"));
            Line(hd, 47, 73, 51, 81, Hex("9C6332"));
            cv.Blit(Outlined(hd, dark), 0, 0);
            for (int y = 54; y <= 80; y++) for (int x = 29; x <= 55; x++) {
                double r = Math.Sqrt(Sq(x - cx) + Sq(y - cy));
                if (r > 9.6) continue;
                uint c = r > 8.6 ? dark : r > 6.8 ? (x + y < cx + cy - 4 ? WHITE : Hex("C4CCD8")) : Mix(cv.Get(x, y), Hex("CDEFFA"), 0.45);
                cv.Set(x, y, c);
            }
            cv.Set(38, 64, WHITE); cv.Set(39, 63, WHITE); cv.Set(38, 65, WHITE); cv.Set(40, 62, WHITE);
        } else {
            var g = new Cv(71, 95);
            for (int y = 52; y <= 82; y++) for (int x = 27; x <= 57; x++) {
                double r = Math.Sqrt(Sq(x - cx) + Sq(y - cy));
                if (r > 7.4 && r <= 8.8) g.Set(x, y, GOLD);
            }
            for (int k = 3; k <= 11; k++) { g.Set((int)cx, (int)cy - k, GOLD); g.Set((int)cx, (int)cy + k, GOLD); g.Set((int)cx - k, (int)cy, GOLD); g.Set((int)cx + k, (int)cy, GOLD); }
            g.Set((int)cx, (int)cy, GOLD);
            cv.Blit(Outlined(g, dark), 0, 0);
            var s = new Cv(71, 95);
            Stamp(s, STAR, 38, 31, 1, Pal('#', GOLD));
            cv.Blit(Outlined(s, GOLD_D), 0, 0);
        }
    }

    // ---- jokers -----------------------------------------------------------------------------
    static Cv JokerWhite() {
        var cv = new Cv(71, 95);
        var d = Dist(CardMask(), 71, 95, 1);
        for (int i = 0; i < 71 * 95; i++) if (d[i] > 0) cv.D[i] = d[i] == 1 ? OUTLINE : FACE;
        JokerText(cv, SLATE);
        return cv;
    }
    static Cv JokerPanel(Func<int, int, uint> fill, uint text) {
        var cv = new Cv(71, 95);
        var d = Dist(CardMask(), 71, 95, 4);
        for (int y = 0; y < 95; y++) for (int x = 0; x < 71; x++) {
            int dd = d[y * 71 + x]; if (dd == 0) continue;
            cv.Set(x, y, dd == 1 ? OUTLINE : dd <= 4 ? WHITE : fill(x, y));
        }
        JokerText(cv, text);
        return cv;
    }

    static readonly string[] PERCENT = { "##...#.", "##..#..", "...#...", "..#....", ".#..##.", "#...##." };
    static readonly string[] SCISSORS = {
        "..s.........s..", "..ss.......ss..", "...ss.....ss...", "...sss...sss...", "....sss.sss....", ".....sssss.....",
        "......sks......", ".....sssss.....", "....ss...ss....", "...oo.....oo...", "..oooo...oooo..", ".oo..oo.oo..oo.",
        ".o....o.o....o.", ".oo..oo.oo..oo.", "..oooo...oooo..", "...oo.....oo..." };
    static Cv JokerCouponClipper() {
        var cv = JokerWhite();
        uint red = Hex("FE5F55");
        int tw = 39, th = 24; var tm = RoundRect(tw, th, 0, 0, tw - 1, th - 1, 2);
        for (int y = 0; y < th; y++) for (int x = 0; x < tw; x++)
            if (Sq(x + 0.5) + Sq(y - 11.5) <= 12 || Sq(x - (tw - 0.5)) + Sq(y - 11.5) <= 12) tm[y * tw + x] = false;
        var td = Dist(tm, tw, th, 2);
        for (int y = 0; y < th; y++) for (int x = 0; x < tw; x++) {
            int dd = td[y * tw + x]; if (dd == 0) continue;
            cv.Set(16 + x, 11 + y, dd == 1 ? Dark(red, 0.4) : dd == 2 ? Light(red, 0.35) : red);
        }
        Stamp(cv, PERCENT, 29, 17, 2, Pal('#', WHITE));
        for (int x = 15; x <= 55; x++) if (Mod(x, 5) < 3) { cv.Set(x, 39, SLATE); cv.Set(x, 40, SLATE); }
        var s = new Cv(71, 95);
        Stamp(s, SCISSORS, 20, 45, 2, Pal('s', Hex("DDE3EC"), 'k', SLATE, 'o', Hex("FDA200")));
        cv.Blit(Outlined(s, SLATE), 0, 0);
        return cv;
    }

    static Cv JokerPiggyBank() {
        var cv = JokerWhite();
        uint pink = Hex("F7A8B8"), pinkD = Hex("E07C92"), pinkL = Hex("FFD3DC"), line = Hex("7A3B4F");
        var p = new Cv(71, 95);
        Rect(p, 23, 60, 27, 67, pinkD); Rect(p, 39, 60, 43, 67, pinkD);
        Ellipse(p, 33.5, 51, 16, 12, pink);
        for (int y = 0; y < 95; y++) for (int x = 0; x < 71; x++)
            if (p.Get(x, y) == pink && Sq((x - 33.5) / 16) + Sq((y - 48.0) / 12) > 1) p.Set(x, y, pinkD);
        Ellipse(p, 43.5, 39.5, 3.2, 4.2, pinkD);
        Ellipse(p, 50.5, 53, 4.6, 4.2, pinkL);
        p.Set(51, 52, line); p.Set(51, 55, line);
        Rect(p, 43, 47, 44, 48, line);
        Rect(p, 28, 40, 37, 41, line);
        foreach (var t in new[] { new[] { 17, 50 }, new[] { 16, 49 }, new[] { 15, 48 }, new[] { 15, 47 }, new[] { 16, 46 }, new[] { 17, 47 } }) p.Set(t[0], t[1], pinkD);
        Circle(p, 27, 46, 2.0, pinkL);
        cv.Blit(Outlined(p, line), 0, 0);
        var c = new Cv(71, 95);
        Circle(c, 32.5, 27, 5.4, GOLD); Circle(c, 32.5, 27, 3.2, Dark(GOLD, 0.12));
        c.Set(30, 24, WHITE); c.Set(31, 24, WHITE); c.Set(30, 25, WHITE);
        cv.Blit(Outlined(c, GOLD_D), 0, 0);
        cv.Set(26, 30, SLATE); cv.Set(25, 32, SLATE); cv.Set(39, 30, SLATE); cv.Set(40, 32, SLATE);
        return cv;
    }

    static void Bubble(Cv cv, double cx, double cy, double r) {
        Circle(cv, cx, cy, r + 1, SPEC_D); Circle(cv, cx, cy, r, SPEC_L); Circle(cv, cx, cy, r - 1, SPEC);
        cv.Set((int)Math.Round(cx - r / 2), (int)Math.Round(cy - r / 2), WHITE);
    }
    static Cv JokerToilAndTrouble() {
        var cv = JokerPanel((x, y) => Mod(x * 7 + y * 13, 61) == 0 ? Light(SLATE, 0.35) : SLATE, FACE);
        uint iron = INK, ironL = Hex("5C6184");
        for (int x = 24; x <= 46; x++) {
            int h = 2 + (int)Math.Round(4 * Math.Abs(Math.Sin(x * 1.3)));
            for (int k = 0; k < h; k++) cv.Set(x, 84 - k, k < h / 2 ? Hex("FDA200") : Hex("FE5F55"));
        }
        var p = new Cv(71, 95);
        Rect(p, 22, 72, 25, 78, iron); Rect(p, 45, 72, 48, 78, iron);
        for (int y = 50; y <= 75; y++) for (int x = 16; x <= 54; x++)
            if (Sq((x - 35) / 17.0) + Sq((y - 58) / 16.0) <= 1) p.Set(x, y, x < 28 && y < 68 && Sq((x - 35) / 17.0) + Sq((y - 58) / 16.0) > 0.6 ? ironL : iron);
        Ellipse(p, 35, 50, 18.5, 5, ironL);
        Ellipse(p, 35, 50, 15.5, 3.4, SPEC);
        for (int x = 22; x <= 48; x++) p.Set(x, 50 + (int)Math.Round(1.6 * Math.Sin(x * 0.7)), SPEC_L);
        p.Set(30, 49, WHITE); p.Set(40, 51, WHITE); p.Set(36, 48, WHITE);
        cv.Blit(Outlined(p, Hex("1B1C2B")), 0, 0);
        Bubble(cv, 29, 41, 2.6); Bubble(cv, 39, 34, 3.4); Bubble(cv, 32, 25, 2.2); Bubble(cv, 42, 20, 1.6);
        return cv;
    }

    // Plain coloured card like the game's Red Card: no border, small JOKER in the corner
    static Cv JokerPurpleCard() {
        var cv = new Cv(71, 95);
        uint purple = Hex("A782D1");
        var d = Dist(CardMask(), 71, 95, 2);
        for (int y = 0; y < 95; y++) for (int x = 0; x < 71; x++) {
            int dd = d[y * 71 + x]; if (dd == 0) continue;
            uint c = Mod(x * 3 + y * 5, 37) < 9 ? Light(purple, 0.09) : Mod(x * 7 - y * 3, 53) < 11 ? Dark(purple, 0.07) : purple;
            cv.Set(x, y, dd == 1 ? Dark(purple, 0.2) : c);
        }
        Text(cv, "JOKER", 65 - TextWidth("JOKER", SMALL), 85, SMALL, Dark(purple, 0.35));
        return cv;
    }

    // Legendary: background and name plate here, the jester itself on the floating layer
    static Cv LegendBase(uint deep, uint pale, string name) {
        var cv = new Cv(71, 95);
        var m = CardMask(); var d = Dist(m, 71, 95, 1);
        for (int y = 0; y < 95; y++) for (int x = 0; x < 71; x++) {
            if (d[y * 71 + x] == 0) continue;
            double w = Math.Sin((x + 11 * Math.Sin(y / 8.0)) / 5.5 + y / 15.0);
            uint c = w > 0.72 ? Light(pale, 0.55) : w > 0.05 ? pale : deep;
            if (d[y * 71 + x] == 1) {
                bool lowerRight = x + 1 > 69 || y + 1 > 93 || !m[y * 71 + x + 1] || !m[(y + 1) * 71 + x];
                c = lowerRight ? Dark(deep, 0.22) : Light(pale, 0.5);
            }
            cv.Set(x, y, c);
        }
        uint cream = Hex("F7F1E4");
        Rect(cv, 9, 87, 61, 87, Hex("B7A88A"));
        var pm = RoundRect(71, 95, 8, 78, 62, 86, 2);
        for (int i = 0; i < 71 * 95; i++) if (pm[i]) cv.D[i] = cream;
        cv.Set(11, 82, SLATE); cv.Set(59, 82, SLATE);
        Text(cv, name, 35 - TextWidth(name, SMALL) / 2, 80, SMALL, SLATE);
        return cv;
    }
    // Left half of the jester; the right half is mirrored with the two hat colours swapped
    static readonly string[] JESTER = {
        "...................kk", "..................kaa", "..................kaa", ".................kaaa", ".................kaaa",
        "................kaaaa", "................kaaaa", "...............kaaaaa", "......kkkkk....kaaaaa", "....kkaaaaakk.kaaaaaa",
        "...kaaaaaaaaakkaaaaaa", "..kaaaaaaaaaaakaaaaaa", ".kaaaaaaaaaaaaakaaaaa", ".kaaaakkkaaaaaakaaaaa", "kaaaak...kaaaaaakaaaa",
        "kaaak.....kaaaaakaaaa", "kaaak......kaaaaakaaa", ".kkk.......kkkkkkkkkk", "kgggk......kggggggggg", "kgggk......kggggggggg",
        ".kkk.......kkkkkkkkkk", "...........kwwwwwwwww", "...........kwwwwwwwww", "...........kwwwkkkwww", "...........kwwwkkkwww",
        "...........kwwwwwwwww", "...........kwwwwwwwww", "...........kwwwwwwwwk", "...........kwwpwwwwwk", "...........kwwpwwwwww",
        "............kwwrrrrrr", "............kwwwrrrrr", ".............kwwwwwww", "..............kwwwwww", "...............kkwwww",
        ".................kkkk", ".....kkkkk....kkkcccc", "...kkccccckkkkccccccc", "..kcccccccccccccdcccc", ".kcccccdccccccdcccccc",
        "kccccdccccccdcccccccc", "kcccccccccccccccccdcc", "kccccccccdccccccccccc", ".kcckkkcccckkkcccckkk", "..kk...kkkk...kkkk..." };
    static Cv LegendSoul(uint hatA, uint hatB) {
        var cv = new Cv(71, 95);
        var rows = new string[JESTER.Length];
        for (int i = 0; i < JESTER.Length; i++) {
            var h = JESTER[i]; var sb = new StringBuilder(h);
            for (int k = h.Length - 2; k >= 0; k--) sb.Append(h[k] == 'a' ? 'b' : h[k]);
            rows[i] = sb.ToString();
        }
        Stamp(cv, rows, 15, 23, 1, Pal('k', SLATE, 'a', hatA, 'b', hatB, 'g', GOLD, 'w', FACE, 'p', Hex("F7A8B8"),
            'r', Hex("FE5F55"), 'c', FACE, 'd', Hex("C4CCD8")));
        return cv;
    }

    // ---- mod icon ---------------------------------------------------------------------------
    static readonly string[] BOLT = { "....###", "...###.", "..###..", ".#####.", "...###.", "..###..", ".###...", ".##....", "#......" };
    static Cv Icon() {
        var cv = new Cv(34, 34);
        var m = RoundRect(34, 34, 6, 2, 27, 31, 4);
        var d = Dist(m, 34, 34, 3);
        for (int y = 0; y < 34; y++) for (int x = 0; x < 34; x++) {
            int dd = d[y * 34 + x]; if (dd == 0) continue;
            cv.Set(x, y, dd == 1 ? INK : dd <= 3 ? WHITE : TITAN);
        }
        Stamp(cv, BOLT, 11, 9, 2, Pal('#', Dark(TITAN, 0.5)));
        Stamp(cv, BOLT, 10, 8, 2, Pal('#', GOLD));
        return cv;
    }

    static Cv Sheet(int cw, int ch, params Cv[] cells) {
        var s = new Cv(cw * cells.Length, ch);
        for (int i = 0; i < cells.Length; i++) s.Blit(cells[i], i * cw, 0);
        return s;
    }

    // Cell order here must match the pos = { x = ... } values in items/*.lua
    public static Dictionary<string, Cv> Build() {
        var r = new Dictionary<string, Cv>();
        r["decks"] = Sheet(71, 95,
            Back(TITAN, PanelTitan, EmblemTitan), Back(SIGNET, PanelSignet, EmblemSignet),
            Back(TYCOON, PanelTycoon, EmblemTycoon), Back(JACK, PanelJack, EmblemJack), BackMaster());
        r["sleeves"] = Sheet(73, 95,
            Sleeve(TITAN, Dark(TITAN, 0.4), PanelTitan, EmblemTitan), Sleeve(SIGNET, Dark(SIGNET, 0.4), PanelSignet, EmblemSignet),
            Sleeve(TYCOON, Dark(TYCOON, 0.4), PanelTycoon, EmblemTycoon), Sleeve(JACK, Dark(JACK, 0.4), PanelJack, EmblemJack),
            Sleeve(NAVY, GOLD, PanelMaster, EmblemMaster));
        r["vouchers"] = Sheet(71, 95,
            Voucher(GLASS, 1, cv => IconGlass(cv, 1)), Voucher(GLASS, 2, cv => IconGlass(cv, 2)), Voucher(GLASS, 3, cv => IconGlass(cv, 3)),
            Voucher(STOCK, 1, cv => IconStock(cv, 1)), Voucher(STOCK, 2, cv => IconStock(cv, 2)),
            Voucher(SCOUT, 1, cv => IconScout(cv, 1)), Voucher(SCOUT, 2, cv => IconScout(cv, 2)));
        r["jokers"] = Sheet(71, 95,
            JokerCouponClipper(), JokerPiggyBank(), JokerToilAndTrouble(), JokerPurpleCard(),
            LegendBase(Hex("D9A3A0"), Hex("EFCFCB"), "STANCZYK"), LegendBase(Hex("A9CDB0"), Hex("D2E8D5"), "DAGONET"),
            LegendSoul(Hex("E5484D"), Hex("B8343A")), LegendSoul(Hex("3FA66B"), GOLD));
        r["icon"] = Icon();
        return r;
    }
}
'@

function Save-Canvas($cv, $path) {
    $bmp = New-Object System.Drawing.Bitmap $cv.W, $cv.H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $rect = New-Object System.Drawing.Rectangle 0, 0, $cv.W, $cv.H
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $bmp.PixelFormat)
    [System.Runtime.InteropServices.Marshal]::Copy($cv.Ints(), 0, $data.Scan0, $cv.W * $cv.H)
    $bmp.UnlockBits($data)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

$root = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Force "$root\assets\1x", "$root\assets\2x" | Out-Null

$sheets = [Art]::Build()
foreach ($name in $sheets.Keys) {
    Save-Canvas $sheets[$name] "$root\assets\1x\$name.png"
    Save-Canvas $sheets[$name].Scale(2) "$root\assets\2x\$name.png"
    "{0,-9} {1}x{2}" -f $name, $sheets[$name].W, $sheets[$name].H
}

if ($Preview) {
    # All sheets stacked on a dark background at 3x, for a quick look.
    # The Legendary floating layers are also composited onto their backgrounds, as the game shows them.
    $k = 3; $pad = 6
    $jokers = $sheets["jokers"]
    $legend = New-Object Cv 142, 95
    for ($i = 0; $i -lt 2; $i++) {
        $base = New-Object Cv 71, 95; $soul = New-Object Cv 71, 95
        $base.Blit($jokers, - (4 + $i) * 71, 0); $soul.Blit($jokers, - (6 + $i) * 71, 0)
        $legend.Blit($base, $i * 71, 0); $legend.Blit($soul, $i * 71, 0)
    }
    $rows = @($sheets["decks"], $sheets["sleeves"], $sheets["vouchers"], $jokers, $legend, $sheets["icon"])
    $w = (($rows | ForEach-Object { $_.W } | Measure-Object -Maximum).Maximum) + 2 * $pad
    $h = (($rows | ForEach-Object { $_.H + $pad } | Measure-Object -Sum).Sum) + $pad
    $all = New-Object Cv $w, $h
    $all.Fill([Art]::Hex("374244"))
    $y = $pad
    foreach ($row in $rows) { $all.Blit($row, $pad, $y); $y += $row.H + $pad }
    Save-Canvas $all.Scale($k) $Preview
}
