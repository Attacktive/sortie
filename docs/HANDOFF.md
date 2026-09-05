# Sortie — Handoff

**Updated:** 2026-08-31
**Branch:** `main` — PRs #1 through #24 merged fast-forward; history is linear.
**Status:** the battle is playable end to end, field mode is fully verified, interaction & dialogue (sub-project 2) is complete, and events & world state (sub-project 3) is complete across all six tasks — `godot scenes/field.tscn` boots a walkable world with trigger zones, map tile mutations, dialogue branching on world flags, and NPC state changes. 206 tests passing, exit 0, enforced by CI on every push and pull request.

A grid-tactics RPG vertical slice in Godot 4.7.2 / GDScript.

---

## Run it

```sh
godot --headless --import   # once on a fresh clone; GUT's class_names need the import cache
godot                       # play the battle
godot scenes/field.tscn     # walk around the field; not wired to the battle yet
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
SORTIE_SHOT=out.png SORTIE_WALK=0,6,3,4 SORTIE_WAIT=0.55 godot --quit-after 600      # capture battle walk mid-stride
SORTIE_SHOT=out.png SORTIE_FIELD_WALK=right SORTIE_WAIT=0.40 godot scenes/field.tscn --quit-after 600 # capture field walk
SORTIE_SHOT=out.png SORTIE_FIELD_WALK=right SORTIE_FIELD_TURN=down,0.40 SORTIE_WAIT=0.42 godot scenes/field.tscn --quit-after 600 # capture field turn
SORTIE_SHOT=out.png SORTIE_FIELD_INTERACT=true SORTIE_WAIT=0.10 godot scenes/field.tscn --quit-after 300 # capture dialogue interaction
SORTIE_SHOT=out.png SORTIE_FIELD_TRIGGER=true SORTIE_WAIT=0.10 godot scenes/field.tscn --quit-after 300 # capture trigger event execution
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

- 201 tests. The rules engine is covered exhaustively; the view state machine has its own suite (`test_battle_flow.gd`), and the input layer above it has another (`test_input.gd`).
- **Input is driven by real events.** `test_input.gd` pushes synthesized `InputEventKey`, `InputEventMouseMotion`, and `InputEventMouseButton` objects through `get_viewport().push_input()`, so assertions travel the whole chain: event → viewport → `_unhandled_input` or GUI focus → cursor → state machine. A full turn is played on the keyboard alone, and an attack is ordered from a keypress through to a resolved exchange. Buttons fire on *release*, so a realistic tap sends both halves.
- **CI** — `.github/workflows/tests.yaml` installs the pinned Godot 4.7.2 Linux build, rebuilds the import cache, and runs the suite on every push to `main` and every pull request. Until this existed, the tests had only ever run on one laptop.
- A headless auto-battle harness plays the real scenario to completion with both sides on autopilot: **30 victories / 10 defeats / 0 unresolved across 40 seeds**, averaging 9.3 team-turns. Proves both endings are reachable and that seeds replay identically.

---

## Field mode — done

Story mode is a JRPG, so the battle is a **component the story mode calls into**, not the spine of the game. That reframing is what the spec and plan are built on.

- Spec: `docs/superpowers/specs/2026-08-30-sortie-field-mode-design.md`
- Plan: `docs/superpowers/plans/2026-08-30-sortie-field-mode.md`

Story mode decomposes into six sub-projects. **Field mode is #1**, and all eight tasks are complete:

| Task | State |
|---|---|
| 1. `Facing` into `core/` | Done, PR #8 |
| 2. `FieldMap` | Done, PR #9 |
| 3. `FieldBody` (Task 4 folded in) | Done, PR #10 |
| 4. Sub-stepping | Folded into 3; see the plan for why |
| 5. `FieldView` — draw the map | Done, PR #11 |
| 6. `FieldPlayer` — input, movement, animation | Done, PR #12 |
| 7. `field.tscn` and the camera | Done, PR #13 |
| 8. Screenshot verification and this document | Done, PR #14 |

177 tests passing.

**It runs.** `godot scenes/field.tscn` boots an 18x12 world with a character you can walk around it: free 8-directional movement, collision against walls and trees, sliding along a wall taken at an angle, a walk cycle, and a camera that follows and stops at the map's edge. It is wired into nothing — `run/main_scene` is still `battle.tscn`, and there is no way from either mode to the other until sub-project 4.

---

## Interaction & dialogue — done

Field interaction and branching dialogue. **Interaction & dialogue is #2**, and all seven tasks are complete:

- Spec: `docs/superpowers/specs/2026-08-31-sortie-dialogue-design.md`
- Plan: `docs/superpowers/plans/2026-08-31-sortie-dialogue.md`

| Task | State |
|---|---|
| 1. Core dialogue data model | Done |
| 2. Core dialogue runner state machine | Done |
| 3. Core interaction geometry | Done |
| 4. Dialogue Box UI component | Done |
| 5. Field NPC Scene | Done |
| 6. Field interaction wiring & player freeze | Done |
| 7. Screenshot probe verification & handoff | Done |

191 tests passing.

**It runs.** Approaching an NPC on the field and pressing `ui_accept` initiates dialogue. The player freezes, the NPC turns to face the player, and a bottom dialogue box displays speaker name, text pages, and interactive branching choices navigated via keyboard or mouse. Closing the dialogue unfreezes the player.

Sub-projects 4 through 6 of story mode — mode flow and battle handoff, save/load, content — each need their own spec. `run/main_scene` stays `battle.tscn` until sub-project 4.

---

## Events & world state — done

World state flag/variable store, trigger engine (step and interaction triggers), dynamic tile mutation, and state-dependent conditional dialogue. **Events & world state is #3**, and all six tasks are complete:

- Spec: `docs/superpowers/specs/2026-08-31-sortie-events-design.md`
- Plan: `docs/superpowers/plans/2026-08-31-sortie-events.md`

| Task | State |
|---|---|
| 1. `WorldState` and `EventCondition` | Done |
| 2. `EventAction`, `EventTrigger`, and `TriggerRegistry` | Done |
| 3. Conditional dialogue selection | Done |
| 4. Dynamic tile mutation in `FieldMap` / `FieldView` | Done |
| 5. Field step & interact event wiring | Done |
| 6. Visual verification and handoff update | Done |

206 tests passing.

**It runs.** Stepping onto trigger tiles fires configured actions (flag mutation, dialogue, tile alterations). Interacting with objects can update flags and mutate map terrain dynamically. NPCs evaluate world flags to offer branching dialogue trees or updated conversations based on story progress.

Sub-projects 4 through 6 of story mode — mode flow and battle handoff, save/load, content — each need their own spec. `run/main_scene` stays `battle.tscn` until sub-project 4.

---

## Not done — pick up here

1. **Play it by hand — both modes.** The field has never been walked; see the paragraph above for what to watch. For the battle this is much narrower than it was: real events now cover selection, movement, cancel, menu focus, and ordering an attack, and the walk and swing are evidenced frame by frame. What no test can answer is whether it *feels* right — cursor speed, whether the menu lands somewhere sensible, whether a turn reads clearly. **Play a full battle to victory and to defeat before trusting it.**
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
| A test that depended on how fast the machine was | The planned wall test held a direction for 120 frames and asserted the character had not passed the wall. Measured in this harness, 120 frames is 0.844 s of summed delta, which at 96 px/s carries the character 81 px — and the wall is 80 px away. One percent faster and it never arrives, so the assertion passes having tested nothing. Travel is summed delta, not frame count, so every machine gives a different answer. It now walks until progress stops, with a frame budget as a stop rather than a schedule. |
| An inequality where the exact number was the whole point | The same test asserted the character had not passed the wall. Passing `FieldBody` the raw sprite position instead of the collision box also stops the character at the wall — sixteen pixels inside it — and satisfies that inequality. Asserting the exact resting position is what catches it: the mutation run reports 96.0 against an expected 80.0, which is the offset itself. |
| A planned test that could not have passed | It read the walk frame after a helper that releases the key, and releasing is exactly what restores the idle frame, so it would have asserted `0 > 0` against a correct implementation. Worth knowing that a plan's test code is a draft, not a fixture: five of this plan's tests have now been rewritten or dropped — one in Task 3, one in Task 5, three in Task 6 — and not one of them because the implementation was wrong. |
| Two identical markdown headings failed CI | Codacy runs markdownlint, and MD024 rejects two headings with the same text anywhere in a file. Two task writeups both ended with "What changed from the plan as written, and why". Nothing local catches this — like the `FUNDING.yml` case above, the first evidence is a red check. Each writeup now names its task. |
| The invariant caught a comment | `## Pure and Node-free on purpose`, in a `core/` file explaining that it does not depend on a Node, trips the Node-free grep. The comment gave way rather than the invariant: a grep blunt enough to be unfoolable beats one clever enough to be wrong. No `core/` file can use that word, even to disclaim it. |
| A camera centered on a corner | A `Node2D`'s position is the top-left of its 64x64 sprite, so the planned field camera — parented at the player's origin — would have put *that corner* at screen center and left the character 32 px down and to the right of it. Permanently, in a game whose entire subject is the thing in the middle of the screen. The planned tests checked what the camera was parented to and what its limits were, never where it sat relative to the character. |
| A scene whose tests could not see it | The rest of the field scene's planned coverage checked the pieces and skipped the relationships between them, which is the only thing a scene *is*. Nothing looked at the view's map, so a `FieldView` with a null map — a black screen with a perfectly functional invisible character walking around on it — would have passed all four. Nothing looked at draw order, so a ground layer painted over the character would have too. Neither was actually wrong in the planned code, unlike the camera above; both are asserted now. |
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
| `core/dialogue_choice.gd` / `dialogue_node.gd` / `dialogue_tree.gd` | **Dialogue.** Graph structure for dialogue nodes and branching choices |
| `core/dialogue_runner.gd` | **Dialogue.** Headless state machine traversing dialogue trees |
| `core/interaction.gd` | **Dialogue.** Interaction probe box geometry for facing checks |
| `core/world_state.gd` | **Events.** Key-value story state container supporting boolean flags, integer counts, and string states |
| `core/event_condition.gd` | **Events.** Pure comparison evaluations (equality and inequalities) against a `WorldState` |
| `core/event_action.gd` | **Events.** Atomic trigger actions (flag mutation, dialogue triggers, tile changes) |
| `core/event_trigger.gd` | **Events.** Step and interact trigger definitions with spatial cells, conditions, and actions |
| `core/trigger_registry.gd` | **Events.** Spatial index mapping grid cells to step and interact triggers |
| `scenes/battle.gd` | **The bridge.** Input → core → view, and the view state machine |
| `scenes/grid_view.gd` | Terrain and overlay rendering |
| `scenes/field_view.gd` | **Field mode.** Draws a `FieldMap` with the battle's terrain art; `layers_for()` holds every decision so `_draw` holds none |
| `scenes/field_player.gd` | **Field mode.** Held input becomes a velocity, `FieldBody` says where it lands; owns the walk cycle and the facing, and no collision rules |
| `scenes/field_npc.gd` | **Dialogue.** NPC scene on field with sprite, collision, facing, and dialogue tree |
| `scenes/field.gd` | **Field mode.** The whole scene — map, view, player, camera, NPC, dialogue box — and the ASCII map itself. `field.tscn` is a bare `Node2D` with this attached |
| `scenes/unit_view.gd` | Directional sprite animation, health bar, flash, death |
| `scenes/combat_animator.gd` | Replays a resolved exchange in order, and owns the sound |
| `scenes/sfx.gd` | Clip paths, the pure outcome-to-clip mapping, and a round-robin voice pool |
| `scenes/cursor.gd` | Keyboard and mouse cell selection |
| `ui/dialogue_box.gd` | **Dialogue.** Text panel, speaker name, choice buttons, keyboard/mouse navigation |
| `ui/` | Action menu, forecast panel, damage numbers, turn banner, result screen, dialogue box |
| `assets/lpc/` | Characters and terrain, CC-BY-SA — attribution files must not be deleted |
| `assets/audio/` | Three CC0 combat sounds, with `CREDITS.md` recording which original became which clip |
| `test/` | 201 tests; `test_full_battle.gd` is the headless auto-battle harness and `test_input.gd` drives the game with real input events |
| `docs/superpowers/specs/` + `plans/` | The design spec and the implementation plan it was built from |
