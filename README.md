# PowerDecks

A [Steamodded](https://github.com/Steamodded/smods) mod for Balatro that adds strong but simple decks and vouchers, a handful of Jokers, and matching [Card Sleeves](https://github.com/larswijn/CardSleeves) for every deck.

![All PowerDecks sprites](docs/preview.png)

## Requirements

- [Steamodded](https://github.com/Steamodded/smods) 1.0.0 beta or newer
- [Talisman](https://github.com/SpectralPack/Talisman) or [Amulet](https://github.com/frostice482/amulet) (needed for the Legendary Jokers' ^Mult and ^Chips)
- Optional: [Card Sleeves](https://github.com/larswijn/CardSleeves), for the matching sleeves

Drop the `PowerDecks` folder into your `Mods` folder.

## Decks

| Deck | Effect |
|---|---|
| Titan | +1 Joker slot, +2 hand size |
| Signet | +2 consumable slots, start with Deja Vu, Trance, Medium and Talisman |
| Tycoon | +$14 at start, +2 shop card slots, +1 Booster Pack in the shop |
| Jack of All Trades | Half of every bonus above, rounded down: +1 hand size, +1 consumable slot, +1 shop slot, +$7, 2 random Signet Spectrals |
| Master of All Trades | Every effect of Titan, Signet and Tycoon at once |

## Sleeves (with Card Sleeves)

Each sleeve gives its deck's effect. On its own deck it gives a smaller bonus instead:

| Sleeve | On its own deck |
|---|---|
| Titan | +1 Joker slot |
| Signet | +2 consumable slots |
| Tycoon | +$14, +1 Booster Pack in the shop |
| Jack of All Trades | +1 Joker slot, +1 Booster Pack in the shop |
| Master of All Trades | Adds the Jack of All Trades effect |

## Vouchers

| Voucher | Effect | Cost |
|---|---|---|
| Tempered Glass | Glass Cards are 2X less likely to break | $10 |
| Laminated Glass | Glass Cards are 4X less likely to break | $10 |
| Bulletproof Glass | Glass Cards never break when scored | $15 |
| Supplier | Vouchers also restock after the Big Blind | $10 |
| Wholesaler | Vouchers restock after every Blind | $10 |
| Talent Scout | Uncommon Jokers appear 2X more often | $10 |
| Headhunter | Rare Jokers appear 2X more often | $10 |

Each line is a chain: a later voucher only appears once the one before it is redeemed.

## Jokers

| Joker | Rarity | Effect |
|---|---|---|
| Coupon Clipper | Uncommon | X0.75 Mult for each Voucher redeemed this run |
| Piggy Bank | Uncommon | Earn $3 at end of round, plus $2 for each Voucher redeemed this run |
| Toil & Trouble | Uncommon | Create a Spectral card when a Boss Blind is defeated (must have room) |
| Purple Card | Common | Create a Tarot card when any Booster Pack is skipped (must have room) |
| Stanczyk | Legendary | Gains ^0.01 Mult each time another Joker gives X Mult |
| Dagonet | Legendary | Gains ^0.01 Chips each time another Joker gives Chips |

## Development

- `tools/art/` generates every sprite sheet (1x and 2x) from code with Python and Pillow: `python tools/art/build.py --preview preview.png`. `common.py` holds the shared palette and the base game's layout conventions; `decks.py`, `vouchers.py` and `jokers.py` each draw their own sheets, and `python tools/art/build.py jokers` rebuilds just one of them.
- `tools/run_game.ps1 -SelfTest` launches Balatro through Steam and runs `dev/selftest.lua` inside the game. It starts throwaway runs on every deck and sleeve, checks each item against the live game state, prints `[PWRTEST]` lines to the Lovely log and quits. Saving is blocked while it runs.
