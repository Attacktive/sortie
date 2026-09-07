# Act I Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Act I content encompassing missions M02 through M05, including Sir Roderick's sequential briefing chain, Barnaby's static dialogue, skirmisher archetype stats, pure grid/unit builders, and auto-battle balance verification.

**Architecture:** Following the two-layer architecture, missions exist purely as data structures returned by `MissionRegistry` in `core/`. `MissionRegistry` exposes pure static builders to construct and populate battle grids headlessly and for `scenes/battle.gd`. `scenes/field.gd` maintains the sequential state logic for NPC interactions. The `test/test_full_battle.gd` harness runs headless auto-battles against core data to verify balance bands.

**Tech Stack:** Godot 4.7.2 stable, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-09-07-sortie-act-one-design.md`

## Global Constraints

These apply to every task below:

- **Indent with tabs.** Never spaces.
- **Never hard-wrap for length.** One sentence per physical line, comments included.
- **Single blank lines before and after lists, headings, and dividers.** (MD012 clean).
- **Match the surrounding file's function spacing in GDScript** (e.g., two blank lines in `core/mission_registry.gd`).
- **Prefer `if` over the ternary operator.**
- **American English** in prose, comments, and identifiers.
- **`core/` stays free of the scene tree.** After every task touching `core/`, both invariants must produce no output:

  ```sh
  grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
  grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source
  ```

- **All existing tests must keep passing.** Run the full suite:

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
  ```

- **A new `.gd` file needs its `.uid` committed.** Run `godot --headless --import` before `git add`.
- **Commits use `feat`/`fix`/`test`/`docs`.** Add the trailer naming your own model name and version from your runtime identity:
  `Co-authored-by: <Model Name> <176961590+gemini-code-assist[bot]@users.noreply.github.com>` (or matching provider).

---

### Task 1a: Core Mission Builders & Harness Parameterization

Implement the uniform player roster helper, pure static battle grid/unit builders in `MissionRegistry`, refactor `scenes/battle.gd` to use them, and parameterize the auto-battle harness.

**Files:**

- Modify: `core/mission_registry.gd`
- Modify: `scenes/battle.gd`
- Modify: `test/test_full_battle.gd`

- [ ] **Step 1: Write failing test in `test/test_full_battle.gd`:**
  - Add `test_m01_cabbage_via_mission_harness`: runs `M01_CABBAGE` through `_play_mission()` across seeds 1 to 40.
  - Asserts all 40 seeds resolve (`unresolved == 0`), both victory and defeat are reached, and prints the baseline tally with `gut.p()`.
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_full_battle.gd -gexit
  ```

- [ ] **Step 3: Implement core builders and parameterization:**
  - In `core/mission_registry.gd`, implement `static func _get_player_roster() -> Array[UnitData]` and use it in `_build_m01_cabbage()`.
  - In `core/mission_registry.gd`, implement:
    - `static func build_battle_grid(mission: MissionData) -> BattleGrid`
    - `static func populate_units(grid: BattleGrid, mission: MissionData) -> Dictionary` placing each unit with `grid.place_unit()`.
  - In `scenes/battle.gd:79-98`, refactor battle initialization to call `MissionRegistry.build_battle_grid()` and `MissionRegistry.populate_units()`.
  - In `test/test_full_battle.gd`, retain parameterless `_play()` calling `Scenario`, and add `_play_mission(mission: MissionData, seed_val: int) -> Dictionary`.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_full_battle.gd -gexit
  ```

- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
  grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source
  git add core/mission_registry.gd scenes/battle.gd test/test_full_battle.gd
  git commit -m "feat: add core mission builders and parameterize battle harness"
  ```

---

### Task 1b: Barnaby NPC & Sequential Dialogue

Rename the courtyard mage NPC to Barnaby and replace its dialogue with the 3-page sequential tree without conditionals.

**Files:**

- Modify: `scenes/field.gd`
- Modify: `test/test_highspire_courtyard.gd`

- [ ] **Step 1: Write failing test in `test/test_highspire_courtyard.gd`:**
  - Add `test_barnaby_dialogue_is_sequential_and_unconditional`: asserts node name is `Barnaby`, speaker label is `Barnaby`, dialogue has exactly 3 pages with expected text, and `conditional_dialogues` is empty.
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_highspire_courtyard.gd -gexit
  ```

- [ ] **Step 3: Implement Barnaby updates:**
  - In `scenes/field.gd`, rename the mage node from `FieldNpc` to `Barnaby` and set speaker label to `Barnaby`.
  - Replace dialogue tree with the 3-page sequential text from the story spec.
  - Remove `felt_breeze` conditional tree while leaving the ambient breeze step trigger tile and text intact.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_highspire_courtyard.gd -gexit
  ```

- [ ] **Step 5: Commit:**

  ```sh
  git add scenes/field.gd test/test_highspire_courtyard.gd
  git commit -m "feat: rename courtyard mage to Barnaby and set sequential dialogue"
  ```

---

### Task 2: Mission M02_ALE_RUN

Implement the M02 mission in the registry with its unique map, rosters, triggers, debriefs, and skirmisher stats.

**Files:**

- Modify: `core/mission_registry.gd`
- Modify: `test/test_mission_data.gd`

- [ ] **Step 1: Write failing test in `test/test_mission_data.gd`:**
  - `test_m02_ale_run_configuration`: Asserts the full checklist required by section 6:
    - Map is 10 columns by 8 rows (`map_ascii.size() == 8`, row lengths 10).
    - Map uses only the three legal glyphs (`.`, `F`, `#`).
    - Spawn count equals roster count on both sides (`player_spawns.size() == player_roster.size()` and `enemy_spawns.size() == enemy_roster.size()`).
    - Every spawn cell is walkable (not `#`).
    - Every trigger cell in the area trigger rectangle is walkable (not `#`).
    - No spawn cell repeats (all player and enemy spawn coordinates are distinct).
    - `completion_flag` is `"mission_m02_completed"`.
    - Title is `"The Seasonal Ale Run"`.
    - Turn-1 dialogue tree is non-null and opens with Scout.
    - Area trigger tree is non-null and opens with Brute.
    - Victory debrief is non-null and opens with Raider.
    - Defeat debrief is non-null and opens with Vanguard.
    - Skirmisher enemies have `evasion == 0.30`.
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_mission_data.gd -gexit
  ```

- [ ] **Step 3: Implement M02:**
  - Add `M02_ALE_RUN` branch in `MissionRegistry.get_mission(id)`.
  - Pass `_get_player_roster()` for player roster.
  - Define skirmisher enemies with `evasion = 0.30` in `_make_unit()` arguments.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_mission_data.gd -gexit
  ```

- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
  grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source
  git add core/mission_registry.gd test/test_mission_data.gd
  git commit -m "feat: implement M02_ALE_RUN mission data"
  ```

---

### Task 3: Mission M03_SILVER_SPOONS

Implement the M03 mission in the registry.

**Files:**

- Modify: `core/mission_registry.gd`
- Modify: `test/test_mission_data.gd`

- [ ] **Step 1: Write failing test in `test/test_mission_data.gd`:**
  - `test_m03_silver_spoons_configuration`: Asserts the same full checklist as M02:
    - 10x8 dimensions, only legal glyphs, spawn counts match rosters, all spawns and trigger cells walkable, no duplicate spawns.
    - Title is `"The Royal Cutlery"`.
    - `completion_flag` is `"mission_m03_completed"`.
    - Turn-1 tree opens with Scout, area trigger tree opens with Brute, victory debrief opens with Raider, defeat debrief opens with Vanguard.
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_mission_data.gd -gexit
  ```

- [ ] **Step 3: Implement M03:**
  - Add `M03_SILVER_SPOONS` branch in `MissionRegistry.get_mission(id)`.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_mission_data.gd -gexit
  ```

- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
  grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source
  git add core/mission_registry.gd test/test_mission_data.gd
  git commit -m "feat: implement M03_SILVER_SPOONS mission data"
  ```

---

### Task 4: Mission M04_FIELD_OVEN

Implement the M04 mission in the registry.

**Files:**

- Modify: `core/mission_registry.gd`
- Modify: `test/test_mission_data.gd`

- [ ] **Step 1: Write failing test in `test/test_mission_data.gd`:**
  - `test_m04_field_oven_configuration`: Asserts the same full checklist as M02:
    - 10x8 dimensions, only legal glyphs, spawn counts match rosters, all spawns and trigger cells walkable, no duplicate spawns.
    - Title is `"The Tactical Bakery"`.
    - `completion_flag` is `"mission_m04_completed"`.
    - Turn-1 tree opens with Scout, area trigger tree opens with Brute, victory debrief opens with Raider, defeat debrief opens with Vanguard.
    - Asserts 3 enemies spawn inside area trigger rectangle per brief, while cell `(6, 3)` remains free for player triggering.
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_mission_data.gd -gexit
  ```

- [ ] **Step 3: Implement M04:**
  - Add `M04_FIELD_OVEN` branch in `MissionRegistry.get_mission(id)`.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_mission_data.gd -gexit
  ```

- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
  grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source
  git add core/mission_registry.gd test/test_mission_data.gd
  git commit -m "feat: implement M04_FIELD_OVEN mission data"
  ```

---

### Task 5: Mission M05_SPICE_WARS

Implement the M05 mission in the registry.

**Files:**

- Modify: `core/mission_registry.gd`
- Modify: `test/test_mission_data.gd`

- [ ] **Step 1: Write failing test in `test/test_mission_data.gd`:**
  - `test_m05_spice_wars_configuration`: Asserts the same full checklist as M02:
    - 10x8 dimensions, only legal glyphs, spawn counts match rosters, all spawns and trigger cells walkable, no duplicate spawns.
    - Title is `"The Paprika Defense"`.
    - `completion_flag` is `"mission_m05_completed"`.
    - Turn-1 tree opens with Scout, area trigger tree opens with Brute, victory debrief opens with Raider, defeat debrief opens with Vanguard.
    - General Malakor stats are explicitly verified: 40 HP, 12 Atk, Range 2.
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_mission_data.gd -gexit
  ```

- [ ] **Step 3: Implement M05:**
  - Add `M05_SPICE_WARS` branch in `MissionRegistry.get_mission(id)`.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_mission_data.gd -gexit
  ```

- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
  grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source
  git add core/mission_registry.gd test/test_mission_data.gd
  git commit -m "feat: implement M05_SPICE_WARS mission data"
  ```

---

### Task 6: Sir Roderick's Briefing Chain & E2E Flow

Update the field sequence state machine, screenshot probe hooks, and test the end-to-end flow.

**Files:**

- Modify: `scenes/field.gd`
- Modify: `scenes/screenshot_probe.gd`
- Modify: `README.md`
- Modify: `test/test_highspire_courtyard.gd`
- Modify: `test/test_story_mission_end_to_end.gd`

- [ ] **Step 1: Write failing tests:**
  - In `test/test_highspire_courtyard.gd`: Test all six world-flag states of Sir Roderick's `conditional_dialogues`, checking for correct first page, `start_battle` actions carrying expected mission IDs, and asserting that the terminal state has no choices.
  - In `test/test_highspire_courtyard.gd`: Update `test_sir_roderick_updates_dialogue_after_mission_completion` to assert the M02 briefing starting node (`m02_briefing_ale`) instead of `post_victory`.
  - In `test/test_story_mission_end_to_end.gd`: Extend end-to-end flow test to complete M01, accept M02, drive M02 to victory, and assert `mission_m02_completed`.
- [ ] **Step 2: Run tests to verify they fail.**
- [ ] **Step 3: Implement field state chain & probes:**
  - In `scenes/field.gd`, replace Roderick's conditional dialogues with the 5 sequential flag checks (`mission_m05_completed` down to `mission_m01_completed`).
  - Leave M01 node IDs intact; use descriptive, mission-prefixed node IDs for new trees (e.g., `m02_briefing_ale`, `m05_action_sortie`, `terminal_feast`).
  - Add new screenshot probe hooks for a new briefing and banter to `scenes/screenshot_probe.gd`, and update `README.md` to reflect them exactly.
- [ ] **Step 4: Run tests to verify they pass.**
- [ ] **Step 5: Commit:**

  ```sh
  git add scenes/field.gd scenes/screenshot_probe.gd README.md test/test_highspire_courtyard.gd test/test_story_mission_end_to_end.gd
  git commit -m "feat: implement Sir Roderick's briefing chain and extend story flow"
  ```

---

### Task 7: Balance Gate

Run the auto-battle harness for M02-M05, adjust stats to hit target win-rate bands, and update documentation.

**Files:**

- Modify: `core/mission_registry.gd`
- Modify: `test/test_full_battle.gd`
- Modify: `docs/superpowers/specs/2026-09-07-sortie-act-one-design.md`
- Modify: `docs/superpowers/specs/2026-09-07-sortie-act-one-story.md`
- Modify: `docs/DESIGN-NOTES.md`

- [ ] **Step 1: Write the balance gate test:**
  - Add `test_act_one_missions_balance_bands` in `test/test_full_battle.gd` iterating `["M02_ALE_RUN", "M03_SILVER_SPOONS", "M04_FIELD_OVEN", "M05_SPICE_WARS"]`, running 40 seeds each.
  - Assert `assert_between(victories, 24, 34)` for M02–M04, and `assert_between(victories, 18, 28)` for M05.
  - Assert `assert_gt(victories, 0)`, `assert_gt(defeats, 0)`, and `assert_eq(unresolved, 0)` per mission.
  - Print tally line using `gut.p("Mission %s: %d victories, %d defeats, %d unresolved" % [id, victories, defeats, unresolved])`.
- [ ] **Step 2: Run the test to check initial balance.**
- [ ] **Step 3: Adjust stats:**
  - If any mission fails the band, adjust enemy HP and Attack in steps of no more than 3 in `core/mission_registry.gd` until the test passes.
- [ ] **Step 4: Update Documentation:**
  - Record the final HP/Atk numbers and the seed tally back into `docs/superpowers/specs/2026-09-07-sortie-act-one-design.md` and `docs/superpowers/specs/2026-09-07-sortie-act-one-story.md`.
  - Record any decisions not covered in the brief in `docs/DESIGN-NOTES.md`.
- [ ] **Step 5: Verify tests and commit:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
  git add core/mission_registry.gd test/test_full_battle.gd docs/superpowers/specs/ docs/DESIGN-NOTES.md
  git commit -m "test: balance Act I missions against target win-rate bands"
  ```
