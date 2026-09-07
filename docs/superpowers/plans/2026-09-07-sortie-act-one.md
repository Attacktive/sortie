# Act I Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Act I content encompassing missions M02 through M05, including Sir Roderick's sequential briefing chain, Barnaby's static dialogue, and skirmisher archetype stats. Verify balance through the auto-battle harness.

**Architecture:** Following the two-layer architecture, missions exist purely as data structures returned by `MissionRegistry` in `core/`. `scenes/field.gd` maintains the sequential state logic for NPC interactions. The `test/test_full_battle.gd` harness runs headless auto-battles against core data to verify balance bands.

**Tech Stack:** Godot 4.7.2 stable, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-09-07-sortie-act-one-design.md`

## Global Constraints

These apply to every task below:

- **Indent with tabs.** Never spaces.
- **Never hard-wrap for length.** One sentence per physical line, comments included.
- **Single blank lines before and after lists, headings, and dividers.** (MD012 clean).
- **Single blank line between functions in GDScript.**
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
- **Commits use `feat`/`fix`/`test`/`docs`.** Add the trailer:
  `Co-authored-by: Gemini 3.1 Pro <176961590+gemini-code-assist[bot]@users.noreply.github.com>`.

---

### Task 1: Core Setup & Barnaby

Extract the uniform player roster to a helper, parameterize the auto-battle harness, and update the courtyard mage to Barnaby.

- [ ] **Step 1: Write failing tests:**
  - Update `test/test_field.gd` (or relevant test) to assert the courtyard mage node is named `Barnaby` and has exactly three pages of sequential dialogue with no conditionals.
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field.gd -gexit
  ```

- [ ] **Step 3: Implement core setup:**
  - In `core/mission_registry.gd`, create `_get_player_roster() -> Array[UnitData]`.
  - In `scenes/field.gd`, rename the mage to `Barnaby`, remove `felt_breeze` conditionals, and apply the 3-page sequential dialogue from the spec.
  - In `test/test_full_battle.gd`, add a `mission_id` parameter to the harness, defaulting to M01.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field.gd -gexit
  ```

- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  git add core/mission_registry.gd scenes/field.gd test/test_full_battle.gd
  git commit -m "feat: extract player roster, update Barnaby, and parameterize auto-battle harness"
  ```

---

### Task 2: Mission M02_ALE_RUN

Implement the M02 mission in the registry with its unique map, rosters, triggers, and debriefs.

- [ ] **Step 1: Write failing tests in `test/test_mission_registry.gd`:**
  - `test_m02_ale_run_configuration`: Asserts 10x8 map, valid glyphs, correct spawn/roster counts, valid walkable triggers/spawns, and correct `completion_flag` (`mission_m02_completed`).
- [ ] **Step 2: Run test to verify it fails.**
- [ ] **Step 3: Implement M02:**
  - Add `M02_ALE_RUN` branch in `MissionRegistry.get_mission(id)`.
  - Define skirmisher enemies with `evasion = 0.30` in `_make_unit()` arguments.
- [ ] **Step 4: Run test to verify it passes.**
- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  git add core/mission_registry.gd test/test_mission_registry.gd
  git commit -m "feat: implement M02_ALE_RUN mission data"
  ```

---

### Task 3: Mission M03_SILVER_SPOONS

Implement the M03 mission in the registry.

- [ ] **Step 1: Write failing tests in `test/test_mission_registry.gd`:**
  - `test_m03_silver_spoons_configuration` (same assertions as M02).
- [ ] **Step 2: Run test to verify it fails.**
- [ ] **Step 3: Implement M03:**
  - Add `M03_SILVER_SPOONS` branch in `MissionRegistry`.
- [ ] **Step 4: Run test to verify it passes.**
- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  git add core/mission_registry.gd test/test_mission_registry.gd
  git commit -m "feat: implement M03_SILVER_SPOONS mission data"
  ```

---

### Task 4: Mission M04_FIELD_OVEN

Implement the M04 mission in the registry.

- [ ] **Step 1: Write failing tests in `test/test_mission_registry.gd`:**
  - `test_m04_field_oven_configuration` (same assertions as M02).
- [ ] **Step 2: Run test to verify it fails.**
- [ ] **Step 3: Implement M04:**
  - Add `M04_FIELD_OVEN` branch in `MissionRegistry`. Note 3 enemies spawn inside the area trigger rectangle per the brief.
- [ ] **Step 4: Run test to verify it passes.**
- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  git add core/mission_registry.gd test/test_mission_registry.gd
  git commit -m "feat: implement M04_FIELD_OVEN mission data"
  ```

---

### Task 5: Mission M05_SPICE_WARS

Implement the M05 mission in the registry.

- [ ] **Step 1: Write failing tests in `test/test_mission_registry.gd`:**
  - `test_m05_spice_wars_configuration` (same assertions as M02).
- [ ] **Step 2: Run test to verify it fails.**
- [ ] **Step 3: Implement M05:**
  - Add `M05_SPICE_WARS` branch in `MissionRegistry`. Set General Malakor to 40 HP, 12 Atk, Range 2.
- [ ] **Step 4: Run test to verify it passes.**
- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  git add core/mission_registry.gd test/test_mission_registry.gd
  git commit -m "feat: implement M05_SPICE_WARS mission data"
  ```

---

### Task 6: Sir Roderick's Briefing Chain & E2E Flow

Update the field sequence state machine and test the end-to-end flow.

- [ ] **Step 1: Write failing tests:**
  - In `test/test_field.gd`: Test all six world-flag states of Sir Roderick's `conditional_dialogues`, checking for the correct first page and `start_battle` actions.
  - In `test/test_story_flow.gd`: Extend the end-to-end flow test to complete M01, accept M02, drive M02 to victory, and assert `mission_m02_completed`.
- [ ] **Step 2: Run tests to verify they fail.**
- [ ] **Step 3: Implement field state chain:**
  - In `scenes/field.gd`, replace Roderick's conditional dialogues with the 5 sequential flag checks (`mission_m05_completed` down to `mission_m01_completed`).
  - Add unique node IDs (e.g., `m01_node_1`) across all trees.
  - Add new screenshot probe hooks for a new briefing and banter to `scenes/screenshot_probe.gd`, and update `README.md` to reflect them exactly.
- [ ] **Step 4: Run tests to verify they pass.**
- [ ] **Step 5: Commit:**

  ```sh
  git add scenes/field.gd scenes/screenshot_probe.gd README.md test/test_field.gd test/test_story_flow.gd
  git commit -m "feat: implement Sir Roderick's briefing chain and E2E flow"
  ```

---

### Task 7: Balance Gate

Run the auto-battle harness for M02-M05 and adjust stats to hit the target win-rate bands.

- [ ] **Step 1: Write the balance gate test:**
  - Add a test in `test/test_full_battle.gd` (or sibling) that iterates `["M02_ALE_RUN", "M03_SILVER_SPOONS", "M04_FIELD_OVEN", "M05_SPICE_WARS"]`, running 40 seeds each, and `assert_between()` on the victory count (24-34 for M02-M04; 18-28 for M05). Also assert both outcomes are reached at least once per mission.
- [ ] **Step 2: Run the test to check initial balance.**
- [ ] **Step 3: Adjust stats:**
  - If any mission fails the band, adjust enemy HP and Attack in steps of no more than 3 in `core/mission_registry.gd` until the test passes.
- [ ] **Step 4: Update Documentation:**
  - Record the final HP/Atk numbers and the seed tally back into `docs/superpowers/specs/2026-09-07-sortie-act-one-design.md` and `docs/superpowers/specs/2026-09-07-sortie-act-one-story.md`.
- [ ] **Step 5: Verify tests and commit:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
  git add core/mission_registry.gd test/test_full_battle.gd docs/superpowers/specs/
  git commit -m "test: balance Act I missions against target win-rate bands"
  ```
