# Sortie — Act I Coding Brief

- **Date:** 2026-09-07
- **Audience:** the coding agent implementing Act I
- **Baseline:** `main` at `1553384`
- **Narrative source of truth:** `docs/superpowers/specs/2026-09-07-sortie-act-one-story.md` (the story spec)

This brief maps the story spec onto the engine and rules on every point the story spec leaves to interpretation. On a line of dialogue, a cell, a stat, or a map, the story spec wins. On how the engine represents it, this brief wins. Read `AGENTS.md` at the repository root, then the story spec in full, then this brief, then the code named below, before writing the design spec.

## 1. What you are building

Missions `M02_ALE_RUN`, `M03_SILVER_SPOONS`, `M04_FIELD_OVEN`, and `M05_SPICE_WARS` as data in `core/mission_registry.gd`; Sir Roderick's five-state briefing chain plus a terminal state in `scenes/field.gd`; the courtyard mage renamed to Barnaby with his three pages; tests; screenshot probe hooks; and a per-mission balance gate. That is the whole scope.

Not in scope: new victory conditions, reinforcements, timers, any system listed in issue #35, changes to the enemy AI, new art, new field maps, the Sally Port, and any change to M01 beyond the one Roderick tree replacement described in section 4.

## 2. Process

Follow the path the six sub-projects took.

1. **First PR: documents only.** Commit the story spec after normalizing its Markdown for the linter (single H1, unique headings, blank lines around lists, one bullet character; content unchanged). Write `docs/superpowers/specs/2026-09-07-sortie-act-one-design.md` and `docs/superpowers/plans/2026-09-07-sortie-act-one.md`. Open the PR and stop for review.
2. **Implementation PRs** sized as the plan defines, one per task or per mission. Tests first, then code. Each PR waits on `gh pr checks <number> --watch`, then you report green and stop. The owner merges; you never do.

## 3. Engine facts, verified on the baseline

- `core/mission_data.gd` holds: `mission_id`, `title`, `map_ascii`, `player_roster`, `enemy_roster`, `player_spawns`, `enemy_spawns`, `turn_dialogue_triggers` (turn number to `DialogueTree`), `area_dialogue_triggers` (`Rect2i` to `DialogueTree`), `victory_debrief`, `defeat_debrief`, `completion_flag`. Nothing needs adding.
- `MissionRegistry.get_mission(id)` dispatches on the id string and returns `null` otherwise. Add four branches.
- `scenes/battle.gd` pairs `player_roster[i]` with `player_spawns[i]` and likewise for enemies. Spawn lists must have exactly as many cells as units.
- `BattleGrid.from_ascii` accepts only `.` plain, `F` forest, `#` wall. Maps are 10 columns by 8 rows.
- `scenes/game.gd` already sets `defeated_<mission_id>` and the mission's `completion_flag` on victory for any mission id. No change.
- Retry calls `Battle._start_battle()`, which reseeds and clears both the consumed area triggers and the played turn triggers. No change.
- Area triggers fire once, on a player unit's move destination, and only for cells inside the rectangle that the unit can actually stand on.
- `FieldNpc.get_dialogue_for_state` walks `conditional_dialogues` in order and returns the first entry whose condition passes, else the default tree. `EventCondition` is a single key, operator, and value; there is no AND or OR. See ruling 1.
- A dialogue node may carry an `EventAction`; the `[Sortie!]` choice leads to a node whose action is `EventAction.start_battle(id)`. See `_build_roderick()` in `scenes/field.gd`.
- The commander's speaker label is `Sir Roderick`.
- `UnitData` stores `accuracy`, `evasion`, and `crit_rate` as floats in `[0.0, 1.0]`, and `attack_range` as an int.
- The auto-battle harness in `test/test_full_battle.gd` plays the default `Scenario` across seeds 1 to 40 with both sides on autopilot and prints the tally. It does not yet take a mission id.

## 4. Rulings

1. **Roderick's chain is an ordered list, newest mission first.** `conditional_dialogues` becomes five entries, each gated by a single `EventCondition.is_true(...)`, in the order `mission_m05_completed`, `mission_m04_completed`, `mission_m03_completed`, `mission_m02_completed`, `mission_m01_completed`. The default tree stays the M01 briefing. First match wins, which is what makes "X true and Y false" unnecessary. The tree behind `mission_m01_completed` is the M02 briefing from the story spec, and it replaces the current post-victory tree, because its first two pages are that tree's text. The tree behind `mission_m05_completed` is the two-page terminal dialogue with no choices. Give every node an id that is unique across all six trees.
2. **Skirmisher stats.** "Evasion is set to 30" means `evasion = 0.30`. The full line is accuracy `0.90`, evasion `0.30`, crit rate `0.10`. This is not engine work; it is arguments to the existing `_make_unit()`, and the story spec's section 5 is wrong to list it as such. Every other sprite keeps the values already in `core/scenario.gd` and `core/mission_registry.gd`: vanguard `0.90 / 0.05 / 0.05`, scout `0.90 / 0.25 / 0.10`, brute `0.85 / 0.00 / 0.05`, raider `0.90 / 0.10 / 0.15`, mage `0.85 / 0.10 / 0.15`.
3. **The player squad is identical in every mission.** Extract the four-unit roster into one helper and call it from M01 through M05 rather than repeating the four lines five times. Only the spawn cells differ per mission.
4. **Range is exactly the Range column.** Range-2 units with the `raider` sprite keep the slash animation; that is an accepted trade. Note that the squad has no ranged unit, so no range-2 enemy can ever be countered. That is what the balance gate is for; do not compensate for it in code.
5. **The Role column is flavor.** The AI is one expected-value routine for every unit. Nothing blocks, flanks, or crushes walls. Two units may share a name.
6. **Maps, spawns, and trigger rectangles are used exactly as written.** They have been validated: every map is 10 by 8 with legal glyphs, every spawn and trigger cell is walkable, no cell is used twice, no squad member starts inside a trigger. In M04 three enemies start inside the trigger rectangle; that is intended, and cell `(6, 3)` stays free so the trigger still fires.
7. **Barnaby.** Rename the existing courtyard mage NPC so its speaker label and node name read `Barnaby`. Its dialogue becomes one tree of three sequential pages, taken verbatim from the story spec, with no `conditional_dialogues`. Remove its `felt_breeze` conditional tree. Keep the breeze step trigger tile and its ambient text as they are.
8. **Dialogue text is copied verbatim** from the story spec, including punctuation. Do not fix the three-sentence pages; the box already handles them.

## 5. Balance gate

This is an assumption the owner may change before you start. Bands are autopilot-versus-autopilot victory rates across seeds 1 to 40, and autopilot underestimates a human, so the low end of each band is the floor.

| Mission | Victories out of 40 |
| --- | --- |
| M02, M03, M04 | 24 to 34 |
| M05 | 18 to 28 |

Every mission must also reach both outcomes at least once and leave no battle unresolved. Parameterize the harness by mission id, or add a sibling test that does, and run it for each mission. If a mission lands outside its band, adjust enemy HP and attack only, in steps of no more than 3, and write the final numbers back into both the design spec and the story spec's tables so the documents match the code. Record the seed tally for each mission in the design spec the way the handoff once recorded 30 victories and 10 defeats for the default scenario.

## 6. Tests

Mirror the sub-project 6 suite. At minimum:

- **Registry, one test per mission:** map is 10 by 8 and uses only the three glyphs; spawn count equals roster count on both sides; every spawn cell and every trigger cell is walkable; no spawn cell repeats; `completion_flag` is `mission_m0X_completed`; turn-1 tree, area tree, and both debriefs are non-null and open with the expected speaker.
- **Courtyard state machine:** for each of the six world-flag states, Roderick's selected tree opens with the expected first page, and where a `[Sortie!]` choice exists it leads to a `start_battle` action carrying the expected mission id. The terminal state has no choices. Barnaby has exactly three pages and no conditional dialogues.
- **End to end:** extend the existing story flow test so that after an M01 victory, Roderick offers M02 and `[Sortie!]` starts `M02_ALE_RUN`; then drive M02 to victory and assert `mission_m02_completed`.
- **Balance:** the gate in section 5, as a test that fails outside the band.
- **Screenshot probe:** add hooks to capture one new briefing and one new banter. Add every new `SORTIE_*` variable to the harness block in `README.md` in the same PR; the list in the README and the variables in `scenes/screenshot_probe.gd` must match exactly.

## 7. Housekeeping

- Keep `core/` pure. CI greps it for `Node`, `get_tree(`, `Input`, `preload(`, `.tscn`, and any randomness outside `real_roll_source.gd`. `MissionRegistry` stays `RefCounted`.
- Update the code map in `README.md` for any new file, and add any decision you make that this brief does not cover to `docs/DESIGN-NOTES.md`.
- Markdown must pass the repo's Codacy markdownlint: single H1, no two headings with identical text in one file, blank lines above and below every list, one bullet character throughout.
- Code style: tabs; braces on every control-flow statement; no ternaries; one sentence per comment line; empty line after a multiline expression and after a closing brace, none after an opening brace. GDScript strings in this repo use double quotes; match the surrounding code.
- Git: branch names in the form `feature/<description>` with no abbreviations; commit prefixes `feat:`, `test:`, `docs:`, `ci:`; end every commit with `Co-authored-by: <your model name and version> <noreply@<provider domain>>`; ship through `gh pr create`; after opening a PR, check out `main` and delete the local branch; never merge.
- American English in code, comments, and commit messages.
