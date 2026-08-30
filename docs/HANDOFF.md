# Sortie — Handoff

**Updated:** 2026-08-30
**Branch:** `main` — PRs #1 through #11 merged fast-forward; history is linear.
**Status:** the battle is playable end to end. Field mode is four tasks into eight and does not run yet. 163 tests passing, exit 0, enforced by CI on every push and pull request.

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
- Combat sound: an impact on a landed blow, a whiff on a miss, a heavy settle on a death, from a four-voice pool so a killing blow does not cut its own hit short. Each play is nudged in pitch and level, because one sample repeated verbatim is what makes an effect read as cheap.
- Damage forecast panel, action menu, movement and attack overlays, enemy threat overlay.

### Verification

- 163 tests. The rules engine is covered exhaustively; the view state machine has its own suite (`test_battle_flow.gd`), and the input layer above it has another (`test_input.gd`).
- **Input is driven by real events.** `test_input.gd` pushes synthesized `InputEventKey`, `InputEventMouseMotion`, and `InputEventMouseButton` objects through `get_viewport().push_input()`, so assertions travel the whole chain: event → viewport → `_unhandled_input` or GUI focus → cursor → state machine. A full turn is played on the keyboard alone, and an attack is ordered from a keypress through to a resolved exchange. Buttons fire on *release*, so a realistic tap sends both halves.
- **CI** — `.github/workflows/tests.yaml` installs the pinned Godot 4.7.2 Linux build, rebuilds the import cache, and runs the suite on every push to `main` and every pull request. Until this existed, the tests had only ever run on one laptop.
- A headless auto-battle harness plays the real scenario to completion with both sides on autopilot: **30 victories / 10 defeats / 0 unresolved across 40 seeds**, averaging 9.3 team-turns. Proves both endings are reachable and that seeds replay identically.

---

## Field mode — in progress

Story mode is a JRPG, so the battle is a **component the story mode calls into**, not the spine of the game. That reframing is what the spec and plan are built on.

- Spec: `docs/superpowers/specs/2026-08-30-sortie-field-mode-design.md`
- Plan: `docs/superpowers/plans/2026-08-30-sortie-field-mode.md`

Story mode decomposes into six sub-projects. **Field mode is #1**, and it is four tasks in:

| Task | State |
|---|---|
| 1. `Facing` into `core/` | Done, PR #8 |
| 2. `FieldMap` | Done, PR #9 |
| 3. `FieldBody` (Task 4 folded in) | Done, PR #10 |
| 4. Sub-stepping | Folded into 3; see the plan for why |
| 5. `FieldView` — draw the map | Done, PR #11 |
| 6. `FieldPlayer` — input, movement, animation | **Next.** 6 tests. This is the one where you can finally walk |
| 7. `field.tscn` and the camera | Not started |
| 8. Screenshot verification and this document | Not started |

Target on completion is 173 tests.

**Nothing renders yet.** `FieldView` can draw a map, but nothing constructs one: there is no field scene, no player, and no entry point. Task 7 is the first point where `godot scenes/field.tscn` does anything.

Sub-projects 2 through 6 of story mode — interaction and dialogue, events and world state, mode flow and battle handoff, save/load, content — each need their own spec. `run/main_scene` stays `battle.tscn` until sub-project 4.

---

## Not done — pick up here

1. **Play the interactive loop by hand.** Much narrower than it was: real events now cover selection, movement, cancel, menu focus, and ordering an attack, and the walk and swing are evidenced frame by frame. What no test can answer is whether it *feels* right — cursor speed, whether the menu lands somewhere sensible, whether a turn reads clearly. **Play a full battle to victory and to defeat before trusting it.**
2. **More sound.** Two threads here, both needing ears rather than analysis.

   - The three combat clips were called "clunky but ok-ish" on first listen, and pitch jitter was the answer to that. If they still read as repetitive, the next lever is a second variant per event — `Sfx.play()` would take an array and pick from it. Sixteen single-transient impacts under 0.45s were catalogued in the pack; `bookPlace2` has almost exactly `chop`'s envelope. Whether it *sounds* right is not something an envelope can settle.
   - The whiff is 0.60s against a 0.43s swing and starts at the impact frame, so it trails past the animation. A whiff is arguably the sound of the swing itself and belongs at the start of the motion. That change was deliberately not made without someone hearing it first.
   - Nothing outside combat makes any sound: no cursor blip, no menu click, no music.
3. **Everything the slice deliberately excluded:** save/load, leveling, recruitment, multiple maps, classes, permadeath. Each is its own spec. Story is no longer on this list — it is underway above.

---

## Known issues and risks

| Issue | Detail |
|---|---|
| **Interactive coverage** | See "Not done" #1. The rules are provably correct; the wiring between input and rules is not. |
| **Audio licence is not** | The three sounds are Kenney RPG Audio, CC0. Chosen so a second share-alike obligation was not taken on for three files. `assets/audio/CREDITS.md` records which original became which clip. |
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
| The cursor ignored the event it was handed | Mouse motion called `get_local_mouse_position()` — a fresh query of the display server — rather than reading `event.position`. It works in a real window, so nothing was visibly broken, but it answers "where is the pointer now" instead of "where did this event happen", and it made the entire pointer path untestable: headless has no mouse, so it read `(0, 0)` forever and `Input.warp_mouse` did not help. Found the moment real events were pointed at it. |
| A test that hung instead of failing | The first input tests awaited `walk_finished` and `animator.finished` bare. Unwire the thing that starts them and the await never returns, so a broken build hangs CI rather than reporting a failure. Both are now `wait_for_signal(..., seconds)` with the result asserted. |
| A task boundary in the wrong place | The plan split `FieldBody` from its sub-stepping guard, on the theory that a working sweep came first and tunneling was a refinement on top. Six of the sweep's own tests failed until sub-stepping existed, because they walk into walls at 1000 px/s and a sweep only inspects where the box lands, not what it passed over. A task has to be the smallest unit that can pass its own tests. |
| A test that was wrong while the code was right | The wall-slide test drove 1000 px north against 200 px east and expected the character pinned to the wall. It is not — it slides, clears the wall's eastern edge, and correctly continues north. The tempting fix is to change the code until the assertion goes green, which would have broken sliding to satisfy a carelessly posed question. It recurred one task later: a `FieldView` test asserted the grass under a wall at (2,0) matches the grass at (0,0), contradicting the per-cell variant hash the view exists to use. Twice now, so assume a third. |
| A view that drew nothing and passed | `FieldView` first decided its grass-then-solid layering inside `_draw`. Deleting the solid layer outright — every wall and tree invisible, which is the worst failure this code has — passed every test. Nothing headless can see into `_draw`, so anything it alone decides is untested by construction. The decision moved out to `layers_for()` and `_draw` became a loop with no opinions. What is left inside `_draw` needs a screenshot, not a test. |
| The invariant caught a comment | `## Pure and Node-free on purpose`, in a `core/` file explaining that it does not depend on a Node, trips the Node-free grep. The comment gave way rather than the invariant: a grep blunt enough to be unfoolable beats one clever enough to be wrong. No `core/` file can use that word, even to disclaim it. |
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
| `core/facing.gd` | The four LPC sheet rows; `from_motion` for walking, `toward` for aiming |
| `core/field_map.gd` | **Field mode.** The walkable world from ASCII: size, solidity, glyphs, box-to-tile overlap |
| `core/field_body.gd` | **Field mode.** Axis-separated movement and collision, sub-stepped so a hitched frame cannot tunnel |
| `scenes/battle.gd` | **The bridge.** Input → core → view, and the view state machine |
| `scenes/grid_view.gd` | Terrain and overlay rendering |
| `scenes/field_view.gd` | **Field mode.** Draws a `FieldMap` with the battle's terrain art; `layers_for()` holds every decision so `_draw` holds none |
| `scenes/unit_view.gd` | Directional sprite animation, health bar, flash, death |
| `scenes/combat_animator.gd` | Replays a resolved exchange in order, and owns the sound |
| `scenes/sfx.gd` | Clip paths, the pure outcome-to-clip mapping, and a round-robin voice pool |
| `scenes/cursor.gd` | Keyboard and mouse cell selection |
| `ui/` | Action menu, forecast panel, damage numbers, turn banner, result screen |
| `assets/lpc/` | Characters and terrain, CC-BY-SA — attribution files must not be deleted |
| `assets/audio/` | Three CC0 combat sounds, with `CREDITS.md` recording which original became which clip |
| `test/` | 163 tests; `test_full_battle.gd` is the headless auto-battle harness and `test_input.gd` drives the game with real input events |
| `docs/superpowers/specs/` + `plans/` | The design spec and the implementation plan it was built from |
