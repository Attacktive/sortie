# Audio credits

All sound in this directory comes from **[Kenney RPG Audio](https://kenney.nl/assets/rpg-audio)**
by Kenney Vleugels.

## Licensing

**CC0 1.0** — public domain. No attribution is required and there is no
share-alike obligation. Kenney asks only that credit "would be nice", which is
what this file is. The full text ships as `LICENSE-kenney.txt`.

This was chosen deliberately. The artwork in `assets/lpc/` is CC-BY-SA 3.0, and
adding a second share-alike source for the sake of three sound effects would
have compounded an obligation for no gain.

## What maps to what

Files are renamed for what they mean in the game rather than what they were
called in the pack. The originals are listed so the mapping stays traceable.

| File | Original | Why this clip |
|---|---|---|
| `hit.ogg` | `chop.ogg` | Silence, a sharp spike, then a fast decay — a single impact. At 0.24s it ends exactly as the 0.43s swing does. |
| `miss.ogg` | `knifeSlice.ogg` | A fast rise into a sustained body: a blade moving through air and connecting with nothing. |
| `death.ogg` | `dropLeather.ogg` | A gradual rise to a broad plateau, then decay — something heavy settling rather than being struck. Its 0.42s length sits just inside `UnitView.DEATH_SECONDS`. |

Clips were chosen by measuring loudness envelopes, not by reading filenames.
Several plausible-sounding candidates turned out to contain two separate
transients, which would have read as a stutter under a single swing.
