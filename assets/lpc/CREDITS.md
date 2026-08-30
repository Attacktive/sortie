# Art credits

All art in this directory comes from the **Liberated Pixel Cup (LPC)** ecosystem
on [OpenGameART](https://opengameart.org).

## Licensing — read this before redistributing

Both sources are dual-licensed **CC-BY-SA 3.0** and **GPL 3.0**.

- **CC-BY-SA 3.0** requires attribution *and* is **share-alike**: modified art must
  stay under a compatible licence.

- The tile atlas ships its own attribution manifest, reproduced verbatim as
  `ATTRIBUTION-tile-atlas.txt`. It lists every contributor whose work went into
  the atlas. Do not delete it.

- The project's **source code remains MIT**. The share-alike obligation attaches to
  the artwork and to derivatives of the artwork, not to the program that draws it.

The OpenGameART page for the tile atlas also lists OGA-BY, but the manifest
bundled *inside the download* names only CC-BY-SA 3.0 and GPL 3.0. Where the two
disagree, this project follows the stricter bundled manifest.

## Sources

| Source | Author | Licence |
|---|---|---|
| [LPC Medieval Fantasy Character Sprites](https://opengameart.org/content/lpc-medieval-fantasy-character-sprites) | Johannes Sjölund (wulax) and LPC contributors | CC-BY-SA 3.0 / GPL 3.0 |
| [LPC Tile Atlas](https://opengameart.org/content/lpc-tile-atlas) | assembled by adrix89 from LPC contributions — see `ATTRIBUTION-tile-atlas.txt` | CC-BY-SA 3.0 / GPL 3.0 |

## What was made from them

Characters are composited from the walkcycle sheets, south-facing idle frame
(row 2, frame 0), layered body → legs → feet → torso → arms → hands → head:

| File | Layers |
|---|---|
| `units/vanguard.png` | male body, full plate: pants, shoes, torso, shoulders, gloves, helmet |
| `units/mage.png` | male body, robe skirt, brown robe shirt, rope belt, robe hood |
| `units/skirmisher.png` | male body, greenish pants, brown shoes, leather torso/shoulders/bracers, leather belt and hat |
| `units/brute.png` | skeleton body, plate pants, chain torso — skull left bare so it reads as undead |
| `units/raider.png` | male body, greenish pants, brown shoes, leather torso, leather belt, chain hood |
| `units/scout.png` | bare skeleton body |

Terrain tiles are 32px atlas tiles composed into 64px cells, two by two:

| File | Atlas tiles (index = row × 32 + column) |
|---|---|
| `terrain/plain_a.png` | 800 ×4 — flat grass |
| `terrain/plain_b.png` | 800, 801, 800, 800 — one grass tuft |
| `terrain/plain_c.png` | 802, 800, 800, 801 — two tufts |
| `terrain/forest.png` | 704, 706 over 736, 738 — hedge with rounded top corners |
| `terrain/wall.png` | 350 ×4 — stone brick |

## Why 64px cells

LPC characters are 64×64 and LPC terrain is 32×32, both at 1:1 pixel density. A
64px cell holds one character exactly and a 2×2 block of terrain, so nothing is
ever scaled and every pixel stays the same size. Mixing scale factors is what
makes pixel art look wrong, and it is the mistake this replaced: the previous
16px art upscaled 3× put 3×3 pixel blocks next to 1×1 ones.
