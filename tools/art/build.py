"""Builds every PowerDecks sprite sheet (1x and 2x).

    python tools/art/build.py                    # all sheets
    python tools/art/build.py jokers             # only the sheets from jokers.py
    python tools/art/build.py --preview out.png  # also writes a 3x preview of everything built

Each module (decks.py, vouchers.py, jokers.py) exposes build() -> {sheet_name: Image}.
Cell order inside each sheet must match the pos = { x = ... } values in items/*.lua.
"""
import importlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from common import new, paste, rgb, save_sheet, CARD  # noqa: E402

MODULES = ['decks', 'vouchers', 'jokers']


def legend_composite(jokers):
    """The Legendary cards as the game shows them: base cells 4-5 with soul cells 6-7 on top."""
    out = new((CARD[0] * 2, CARD[1]))
    for i in range(2):
        for cell in (4 + i, 6 + i):
            paste(out, jokers.crop((cell * CARD[0], 0, (cell + 1) * CARD[0], CARD[1])), i * CARD[0], 0)
    return out


def main(argv):
    preview = None
    if '--preview' in argv:
        preview = argv[argv.index('--preview') + 1]
        argv = [a for a in argv if a not in ('--preview', preview)]
    sheets = {}
    for name in argv or MODULES:
        built = importlib.import_module(name).build()
        for sheet_name, img in built.items():
            save_sheet(sheet_name, img)
            sheets[sheet_name] = img
            print(f"{sheet_name:9} {img.width}x{img.height}")
    if preview:
        rows = [sheets[k] for k in ('decks', 'sleeves', 'vouchers', 'jokers', 'icon') if k in sheets]
        if 'jokers' in sheets and sheets['jokers'].width >= CARD[0] * 8:
            rows.insert(rows.index(sheets['jokers']) + 1, legend_composite(sheets['jokers']))
        pad = 6
        canvas = new((max(r.width for r in rows) + pad * 2, sum(r.height + pad for r in rows) + pad))
        canvas.paste(rgb('374244'), (0, 0, canvas.width, canvas.height))
        y = pad
        for r in rows:
            paste(canvas, r, pad, y)
            y += r.height + pad
        canvas.resize((canvas.width * 3, canvas.height * 3), 0).save(preview)
        print("preview", preview)


if __name__ == '__main__':
    main(sys.argv[1:])
