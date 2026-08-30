# Sortie — Handoff

**Updated:** 2026-08-30
**Branch:** `main` — PRs #1 through #4 merged fast-forward; history is linear.
**Status:** playable end to end. 110 tests passing, exit 0, enforced by CI on every push and pull request.

A grid-tactics RPG vertical slice in Godot 4.7.2 / GDScript.

---

## Run it

```sh
godot --headless --import   # once on a fresh clone; GUT's class_names need the import cache
godot                       # play
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit   # test
```

The first and the last of those are exactly what `.github/workflows/tests.yaml`
runs on a fresh Ubuntu runner against a pinned Godot 4.7.2, so the workflow
doubles as executable documentation for the setup. GUT exits non-zero on any
failure, so the build breaks on its own.

There is also a screenshot harness, gated on environment variables so it never runs in normal play:

```sh
SORTIE_SHOT=out.png godot --quit-after 300                       # capture a frame
SORTIE_SHOT=out.png SORTIE_SELECT=9,1 godot --quit-after 300     # capture with a unit inspected
SORTIE_SHOT=out.png SORTIE_ATTACK=0,7,8,0 SORTIE_WAIT=0.32 godot --quit-after 400   # capture mid-swing
SORTIE_SHOT=out.png SORTIE_WALK=0,6,3,4 SORTIE_WAIT=0.55 godot --quit-after 600      # capture mid-stride
```

It lives in `scenes/screenshot_probe.gd`. It is a development affordance rather
than a feature, and it stays: it is how every visual claim in this project was
verified instead of asserted, and it has now caught three bugs of its own.
Vary `SORTIE_WAIT` across several runs and stack the results to inspect an
animation frame by frame — a single capture proves a frame drew, not that a
cycle plays.

---

## Architecture in one paragraph

Two layers, one bridge. Everything in `core/` is plain `RefCounted`/`Resource`
with no `Node`, scene, or `Input` reference, so the whole rules engine runs and
tests headless. Everything in `scenes/` and `ui/` renders state and forwards
input. `scenes/battle.gd` is the only script permitted to touch both, and it is
a view-side state machine.

Two invariants, both enforced by grep rather than good intentions:

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/     # must be empty
grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source  # must be empty
```

If either produces output, something has leaked across the boundary.

---

## Done

### Rules engine (`core/`, no Node in sight)

- **Terrain** — plain / forest (+2 defence, +0.20 evasion) / wall, as a lookup table.
- **`BattleGrid`** with `from_ascii()`, so every test declares its board as a picture. Highest-leverage thing in the codebase for test readability.
- **Movement** — Dijkstra flood fill, not BFS, because forest costs 2 and a plain detour can beat crossing it. One pass yields the reachable set *and* the path to every cell in it. Enemies block; allies are passable but not landable.
- **`Movement.threat_cells()`** — the union of attack range over the whole movement field, for showing an enemy's reach.
- **Combat** — `forecast()` is pure and consumes no rolls; `resolve()` draws hit → crit → variance in that fixed order, conditionally, so a miss costs exactly one roll. `exchange()` adds a counterattack that rolls fully independently.
- **`RollSource`** — all randomness is injected. `RealRollSource` is seeded and the seed is printed at battle start, so any battle replays exactly. `ScriptedRollSource` queues literal rolls, so tests state intent instead of relying on magic seeds.
- **Turn order** — phases, spent-flag handling, victory/defeat detection.
- **Enemy AI** — expected-value scoring with a kill bonus, ties broken row-major so the same board always yields the same decision.
- **Scenario** — the 10×8 map and six-unit roster.

### Presentation

- Textured terrain with three grass variants picked by a hash of cell coordinates, so the field varies without a visible repeat and looks identical on every run.
- Directional sprite animation: 9-frame walk and 6-frame slash, four facings each, driven from LPC sheets. Both are verified from captured frames — the walk cycle advances its legs, interpolates between cells, and turns corners with the feather trailing the direction of travel.
- Damage numbers (crits gold and larger, misses grey), hit flash, death fade, turn banner.
- Damage forecast panel, action menu, movement and attack overlays, enemy threat overlay.

### Verification

- 108 tests. The rules engine is covered exhaustively; the view state machine has its own suite (`test_battle_flow.gd`).
- **CI** — `.github/workflows/tests.yaml` installs the pinned Godot 4.7.2 Linux build, rebuilds the import cache, and runs the suite on every push to `main` and every pull request. Until this existed, the tests had only ever run on one laptop.
- A headless auto-battle harness plays the real scenario to completion with both sides on autopilot: **30 victories / 10 defeats / 0 unresolved across 40 seeds**, averaging 9.3 team-turns. Proves both endings are reachable and that seeds replay identically.

---

## Not done — pick up here

1. **Play the interactive loop by hand.** Still the biggest gap, though a narrower one than it was. `test_battle_flow.gd` covers the state machine and the animations are now evidenced frame by frame, but nothing exercises real input events — clicking, keyboard cursor movement, menu focus. **Play a full battle to victory and to defeat before trusting it.**
2. **Sound.** There is none. Even three effects (hit, miss, death) would move the needle more than most visual work at this point.
3. **Everything the slice deliberately excluded:** story, save/load, levelling, recruitment, multiple maps, classes, permadeath. Each is its own spec.

---

## Known issues and risks

| Issue | Detail |
|---|---|
| **Interactive coverage** | See "Not done" #1. The rules are provably correct; the wiring between input and rules is not. |
| **Art licence is share-alike** | LPC art is CC-BY-SA 3.0 / GPL 3.0. The OpenGameART page also lists OGA-BY, but the manifest *inside the download* names only the first two, so this project follows the stricter bundled manifest. Source code stays MIT; the share-alike obligation attaches to the artwork. `assets/lpc/ATTRIBUTION-tile-atlas.txt` must not be deleted. |
| **`github-advanced-security` fails** | Not a finding. The Copilot-based scanner crashes with `CAPIError: 400 The requested model is not supported.` before analysing anything, so it reports failure without ever having looked at the code. Nothing in the repo can fix it. Codacy and CodeFactor both pass. |
| **Dependabot watched an empty folder** | It was configured for `github-actions` with `directory: '/.github'`, but there were no workflows at all. Now `/`, which is what the ecosystem expects. |
| **Codacy lints Markdown** | It flagged six markdownlint violations in this file — lists need a blank line above and below. Worth remembering when adding docs. |

---

## Decisions worth not re-litigating

- **Cell size is 64px** because an LPC character is exactly 64×64 and LPC terrain is exactly a 2×2 block of 32px tiles. Every pixel on screen is therefore the same size. Mixing scale factors is what makes pixel art look wrong.
- **The Archer became a Mage.** No archer existed in the art; a wizard preserves the design intent exactly — fragile, strikes at range 2, cannot be countered by melee.
- **Roll order is a contract**, not an implementation detail. Changing it invalidates every saved seed, so the tests pin it.
- **The damage floor of 1 applies before the crit multiplier**, so a crit is always a clean 3× of the hit it replaces.
- **No tuning pass was needed.** 9.3 team-turns is ~4.6 full rounds, inside the 4–6 target, and 75/25 means losing is possible without being likely.

---

## Bugs found during implementation

Kept because the shapes recur, and each was patched back into the plan so it does not mislead the next reader.

| Bug | Why it happened |
|---|---|
| A\* could never chase anyone | Opposing units are marked solid for the approach pathfind — including the chase target's own cell. A\* cannot path *onto* a solid cell, so every advance silently returned the origin. |
| The action menu was a dead end | Three compounding causes: the cursor was fully deactivated so it never emitted a cancel, `_on_cancel` had no branch for that state, and nothing recorded where the unit started. |
| `remove_unit` erased by cell alone | Could evict whoever had since moved onto a dead unit's old cell. Now identity-checked and idempotent. |
| Death fade never played | `refresh()` hid dead units immediately, cutting off the animation before it started. |
| Kenney sprites were the wrong *shape* | Their 16px characters are tokens — the opaque region is a rounded blob filling the tile with no negative space and no feet. Checking the sample sheet for *style* was not enough. |
| The pine tree was invisible | Green tree on green grass; only its dark outline survived. Caught by looking at a screenshot rather than trusting the composite. |
| The screenshot harness could save nothing | With a short `SORTIE_WAIT` the timer expired before the first frame was ever drawn, and the capture was written anyway — an all-black PNG, `mean=0 stddev=0`, reported as a successful verification. It now awaits `RenderingServer.frame_post_draw` first. A verification tool that fails silently is worse than none. |
| `FUNDING.yaml` was silently ignored | GitHub reads `.github/FUNDING.yml` and nothing else. A `.yaml` sibling produces no error and no sponsor button — confirmed by fetching the repo page and finding no funding link at all. Renamed. The house style prefers `.yaml`, but this is the documented exception for tools that only accept `.yml`. |
| Variant type inference | Godot 4.7 treats inferring a type from a Variant value as an error, so `:=` fails on the flood fill's frontier variable. |

---

## Map of the code

| Path | Responsibility |
|---|---|
| `core/terrain.gd` | Terrain enum plus cost / defence / evasion lookups |
| `core/unit_data.gd` | `Resource`: stats, team, animation sheet paths |
| `core/battle_unit.gd` | Runtime state — hp, cell, has_acted |
| `core/battle_grid.gd` | Tiles, terrain, occupancy, ASCII construction |
| `core/movement_field.gd` | One flood fill's results: costs and paths |
| `core/movement.gd` | Flood fill, attack-range geometry, threat maps |
| `core/roll_source.gd` + `real_` + `scripted_` | Injectable randomness |
| `core/attack_forecast.gd` / `attack_result.gd` / `combat_exchange.gd` | Combat value types |
| `core/combat.gd` | Forecast, resolution, exchange |
| `core/turn_order.gd` | Phase machine, victory/defeat |
| `core/ai_decision.gd` / `enemy_ai.gd` | Expected-value target selection |
| `core/scenario.gd` | The map and the roster |
| `scenes/battle.gd` | **The bridge.** Input → core → view, and the view state machine |
| `scenes/grid_view.gd` | Terrain and overlay rendering |
| `scenes/unit_view.gd` | Directional sprite animation, health bar, flash, death |
| `scenes/combat_animator.gd` | Replays a resolved exchange in order |
| `scenes/cursor.gd` | Keyboard and mouse cell selection |
| `ui/` | Action menu, forecast panel, damage numbers, turn banner, result screen |
| `test/` | 108 tests; `test_full_battle.gd` is the headless auto-battle harness |
| `docs/superpowers/specs/` + `plans/` | The design spec and the implementation plan it was built from |
