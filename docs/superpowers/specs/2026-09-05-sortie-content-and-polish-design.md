# Sortie — Content & Polish Design Spec (Sub-project 6)

- **Date:** 2026-09-05
- **Status:** Draft, pending user review
- **Engine:** Godot 4.7.2 stable, GDScript
- **Precedes:** `2026-09-05-sortie-save-and-load-design.md` established state persistence; this delivers the playable narrative campaign vertical slice

## 1. Purpose

Sortie has established all foundational systems: tactical grid combat (Sub-project 1), field exploration and interaction (Sub-project 2), event scripting and world flags (Sub-project 3), mode orchestration and transitions (Sub-project 4), and atomic disk save/load persistence (Sub-project 5).

Sub-project 6 implements **Content & Polish**, delivering the first complete narrative sortie: **"The Cabbage Trajectory" (Mission `M01_CABBAGE`)**:

1. **Home Base Exploration (Highspire Courtyard)**: The field represents the royal garrison grounds. The player speaks with Commander Sir Roderick stationed by the Sally Port gate to receive the mission briefing.
2. **Mission Briefing & Branching Flow**: Sir Roderick explains the grave dishonor facing Highspire (the enemy catapult launching rotten brassicas into the royal herb garden). The player chooses `[Sortie!]` to embark immediately or `[Prepare]` to explore the courtyard or save the game.
3. **Pure Domain Mission Model (`MissionData` & `MissionRegistry`)**: Pure `RefCounted` domain models in `core/` representing mission parameters: map layout, predefined player and enemy rosters, turn-based banter triggers, area-based dialogue triggers, and resolution debrief sequences.
4. **Parameterized Battle Initialization**: `Battle` accepts a `mission_id` (defaulting to `"default"` for sandbox/quick battle testing), populating the tactical grid with custom terrain and rosters.
5. **In-Combat Modal Banter**:
   - *Turn 1 Start*: Scout Pip and Vanguard banter on why they are risking their lives for vegetables before player input begins.
   - *Area Trigger (Catapult Zone)*: When any player unit reaches the catapult grounds, input pauses and the Brute politely announces the gentle dismantling of the siege weapon. Triggers are consumed one-shot to avoid repeated interruptions.
6. **Victory & Defeat Debrief Sequences**:
   - *Victory*: Plays Raider's debrief regarding dismantled catapult parts and a hazard fee, transitions through the Victory ResultScreen, and returns to Highspire Courtyard with `"mission_m01_completed"` marked in `WorldState`.
   - *Defeat*: Plays Vanguard's humorous retreat call ("a glorious tactical withdrawal from incoming cruciferous projectiles") before the Defeat ResultScreen.
7. **Home Base Reactivity**: Sir Roderick's dialogue and the Sally Port interactable update dynamically to celebrate the rosemary salvation and tease the next sortie (`M02_ALE_RUN`).

**Done means:**

- Launching "New Game" spawns the player in Highspire Courtyard.
- Interacting with Sir Roderick plays the full briefing dialogue with `[Sortie!]` and `[Prepare]` options.
- Choosing `[Sortie!]` initiates the screen transition and launches Mission `M01_CABBAGE`.
- Battle spawns 4 player units (Vanguard, Scout, Brute, Raider) and 4 enemy units on the trench map.
- Turn 1 start triggers Pip/Vanguard modal banter before unit commands unlock.
- Stepping into the 2x2 Catapult Zone fires the Brute dialogue modal once.
- Winning the battle triggers Raider's debrief and returns to the courtyard with updated NPC dialogues.
- Losing the battle triggers Vanguard's defeat debrief and allows retry or return to title.
- Core two-layer architecture is strictly preserved (`core/mission_data.gd` and `core/mission_registry.gd` remain pure `RefCounted` with zero Node or scene-tree dependencies).
- All headless GUT tests pass.

**Explicit non-goals for this sub-project:**

- Implementing Act I missions beyond M01 (M02 Ale Run is teased narratively, not implemented in this slice).
- Dynamic party roster selection UI (player squad is preset to the 4 canonical LPC classes).
- Mid-battle save state persistence.
- Inventory or item equipment screens.

---

## 2. Where this sits

Story mode roadmap:

| # | Sub-project | Status | Delivers |
| --- | --- | --- | --- |
| 1 | Field mode | Done, PRs #8–#14 | Walkable map, collision, camera |
| 2 | Interaction & dialogue | Done, PR #16 | Facing interaction, dialogue box, branching choices |
| 3 | Events & world state | Done, PRs #17, #24, #26 | Step/interact triggers, world flags, conditional choices, tile mutation |
| 4 | Mode flow & battle handoff | Done, PR #28 | Title $\leftrightarrow$ Field $\leftrightarrow$ Battle lifecycle, transitions, defeat flow |
| 5 | Save & load | Done, PR #29 | Disk persistence of WorldState, field snapshots, 10-slot management |
| **6** | **Content & polish** | **This spec** | Highspire Courtyard, Mission M01, in-battle modal dialogue, story loop |

---

## 3. Architecture

Following the project's two-layer architecture, mission definitions and event rules stay pure in `core/`, while presentation in `scenes/` and `ui/` handles rendering and user interaction:

```text
┌─────────────────────────────────────────────────────────────┐
│                            CORE                             │
│                                                             │
│  core/mission_data.gd (RefCounted)                          │
│    ├── ID, title, ASCII map, player/enemy rosters           │
│    ├── Turn dialogue triggers & Area dialogue triggers      │
│    └── Victory / defeat debrief dialogue trees              │
│                                                             │
│  core/mission_registry.gd (RefCounted)                      │
│    └── Static registry providing M01_CABBAGE and scenarios  │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                      SCENES & UI                            │
│                                                             │
│  scenes/field.gd (Highspire Courtyard)                      │
│    ├── Commander Sir Roderick NPC (briefing DialogueTree)   │
│    ├── Sally Port gate interactable (world-flag reactive)   │
│    └── Emits EventAction.start_battle("M01_CABBAGE")        │
│                                                             │
│  scenes/battle.gd (Tactical Encounter)                      │
│    ├── Parameterized battle initialization by mission_id    │
│    ├── Turn 1 start banter modal via DialogueBox            │
│    ├── CatapultZone area modal via DialogueBox (one-shot)   │
│    └── Victory/Defeat debriefs before ResultScreen          │
│                                                             │
│  scenes/game.gd (Coordinator)                               │
│    ├── Routes start_battle(mission_id)                      │
│    └── Sets "mission_m01_completed" on victory handoff      │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Domain Models & Data Contracts (`core/`)

### 4.1 `MissionData` (`core/mission_data.gd`)

Pure `RefCounted` data object holding mission specifications:

```gdscript
class_name MissionData
extends RefCounted

var mission_id: String = ""
var title: String = ""
var map_ascii: PackedStringArray = []
var player_roster: Array[UnitData] = []
var enemy_roster: Array[UnitData] = []
var player_spawns: Array[Vector2i] = []
var enemy_spawns: Array[Vector2i] = []

## Turn number -> DialogueTree played at player turn start.
var turn_dialogue_triggers: Dictionary = {}

## Rect2i bounds -> DialogueTree played when a player unit enters.
var area_dialogue_triggers: Dictionary = {}

## Dialogue played immediately upon battle victory before ResultScreen.
var victory_debrief: DialogueTree = null

## Dialogue played immediately upon battle defeat before ResultScreen.
var defeat_debrief: DialogueTree = null

## WorldState flag set to true upon victorious completion.
var completion_flag: String = "mission_m01_completed"
```

### 4.2 `MissionRegistry` (`core/mission_registry.gd`)

Static factory creating mission payloads:

- `static func get_mission(mission_id: String) -> MissionData`:
  - Returns configured `MissionData` for `"M01_CABBAGE"`.
  - Returns `null` if unrecognized.

### 4.3 Mission `M01_CABBAGE`: "The Cabbage Trajectory"

#### Map Layout (`map_trench_outer`)

A 10x8 tactical battlefield depicting the outer siege perimeter:

```text
..F....F..
.##....##.
..........
...####...
...####...
..........
.##....##.
..F....F..
```

- Forest tiles (`F`) provide defensive cover (2 defense, -10% hit).
- Wall tiles (`#`) represent earthen berms and barricades.
- Catapult Zone: `Rect2i(Vector2i(7, 2), Vector2i(3, 4))` located at the enemy backline.

#### Roster & Spawns

- **Player Squad**:
  - `Vanguard` (HP 24, Atk 9, Def 4, Move 3) at `(0, 6)`
  - `Scout` ("Pip", HP 14, Atk 6, Def 0, Move 5) at `(1, 7)`
  - `Brute` (HP 26, Atk 10, Def 3, Move 3) at `(0, 7)`
  - `Raider` (HP 18, Atk 8, Def 1, Move 4) at `(1, 6)`
- **Enemy Siege Squad**:
  - `Siege Vanguard` (HP 22, Atk 8, Def 3, Move 3) at `(8, 2)`
  - `Catapult Guard Brute` (HP 24, Atk 9, Def 2, Move 3) at `(9, 3)`
  - `Slinger Scout` (HP 14, Atk 6, Def 0, Move 5) at `(8, 5)`
  - `Artillery Raider` (HP 16, Atk 7, Def 1, Move 4) at `(9, 4)`

---

## 5. In-Combat Modal Banter & State Machine (`scenes/battle.gd`)

### 5.1 State Transitions with In-Combat Dialogue

```text
[Turn 1 Start] ──► Has Turn Banter? ──Yes──► Push DialogueBox ──► On Finished ──► SELECTING_UNIT
                         │
                         No
                         ▼
                   SELECTING_UNIT ──► Unit Moves ──► In CatapultZone & Unconsumed?
                                                            │
                                                     Yes    No
                                                      │     │
                                                      ▼     ▼
                                              Push DialogueBox ──► On Finished ──► CHOOSING_ACTION
```

### 5.2 Trigger Details

1. **Turn Start Banter (`turn_dialogue_triggers[1]`)**:
   - Checked in `_start_turn()` before unit selection unlocks.
   - Dialogue Tree:
     - Node `start` (Speaker: `"Scout"`): "Couldn't we just... close the windows? Why are we risking our lives for vegetables?" $\to$ `next: "response"`
     - Node `response` (Speaker: `"Vanguard"`): "Because chivalry does not flinch before foul brassicas, Pip! Forward!"
   - While dialogue is active:
     - `_cursor.deactivate()`
     - Input events forwarded exclusively to `_dialogue_box`
     - On `dialogue_box.finished`: `_dialogue_box.queue_free()`, `_cursor.activate()`, proceed to player selection.

2. **Area Trigger (`CatapultZone`)**:
   - Checked in `_on_unit_moved(unit, destination)` immediately after the movement tween completes.
   - Evaluates if `destination` falls inside any unconsumed `Rect2i` key in `mission.area_dialogue_triggers`.
   - If triggered:
     - Appends rect to `_consumed_area_triggers`.
     - Delays action menu opening.
     - Dialogue Tree:
       - Node `start` (Speaker: `"Brute"`): "Excuse me, friends. I am going to gently dismantle your siege weapon now. Please step back so no one gets wood splinters."
     - On `dialogue_box.finished`: opens `_action_menu` on `destination` so the unit can attack or wait.

### 5.3 Battle Resolution Debriefs

1. **Victory Flow**:
   - `TurnOrder` detects all enemy units defeated.
   - `Battle` checks `mission.victory_debrief`.
   - Displays debrief `DialogueTree`:
     - Node `start` (Speaker: `"Raider"`): "Catapult wrecked, boss. Also, I found twelve silver coins in their tool chest." $\to$ `next: "payout"`
     - Node `payout` (Speaker: `"Raider"`): "Consider it an environmental hazard fee."
   - Upon completion, presents `ResultScreen` ("VICTORY").
   - Clicking "Continue" emits `battle_completed(true)`.

2. **Defeat Flow**:
   - `TurnOrder` detects all player units defeated.
   - `Battle` checks `mission.defeat_debrief`.
   - Displays debrief `DialogueTree`:
     - Node `start` (Speaker: `"Vanguard"`): "A glorious tactical withdrawal from incoming cruciferous projectiles! Fall back and regroup!"
   - Upon completion, presents `ResultScreen` ("DEFEAT") with "Retry Battle" and "Return to Title".

---

## 6. Highspire Courtyard & World Reactivity (`scenes/field.gd`)

### 6.1 Courtyard Elements

1. **Commander Sir Roderick (NPC)**:
   - Placed near the northern gatehouse at `Vector2i(8, 2)`.
   - Uses `brute_walkcycle.png` (commanding presence in knightly attire).
   - Facing South toward the courtyard center.
2. **Sally Port (Interactive Prop / Tile Trigger)**:
   - Located at `Vector2i(9, 1)` (the heavy archway exiting the courtyard).

### 6.2 Dialogue Flows & World State Progression

1. **Initial State (`mission_m01_completed == false`)**:
   - **Sir Roderick Interaction**:
     - Node `start`: "Men, today Highspire faces its gravest dishonor."
     - Node `cause`: "The enemy has assembled a catapult 80 paces out, and they are launching rotten produce into the royal herb garden."
     - Node `mission`: "We sally out, dismantle the contraption, and preserve the King's rosemary!"
     - Choices:
       - `"[Sortie!]"` $\to$ Emits `EventAction.start_battle("M01_CABBAGE")`.
       - `"[Prepare]"` $\to$ "Hurry, Pip. Every second we tarry is another bruised turnip in His Majesty's parsley."
   - **Sally Port Interaction**:
     - "The Sally Port is barred until Sir Roderick sounds the sortie order."

2. **Completed State (`mission_m01_completed == true`)**:
   - **Sir Roderick Interaction**:
     - Node `start`: "Splendid work out there! The royal herb garden is safe. The scout reports the remaining cabbage hurled over the ramparts was surprisingly edible in soup."
     - Node `next_tease`: "Catch your breath—word has it our ale shipment down south has run into trouble."
   - **Sally Port Interaction**:
     - "The field beyond is quiet. Catapult splinters litter the hillside."

---

## 7. Testing Strategy

### 7.1 Automated Unit & Integration Tests (Headless GUT)

1. **`test_mission_data.gd`**:
   - Verifies `MissionData` structure, field types, and default values.
   - Verifies `MissionRegistry.get_mission("M01_CABBAGE")` returns valid rosters, ASCII map, and dialogue trees.
2. **`test_battle_mission_flow.gd`**:
   - Tests parameterizing `Battle` with `"M01_CABBAGE"`.
   - Verifies player team contains Vanguard, Scout, Brute, Raider at correct spawn cells.
   - Verifies enemy team contains 4 siege units.
   - Simulates turn 1 phase start: verifies turn dialogue triggers and pauses input.
   - Simulates player unit entering `CatapultZone`: verifies area banter triggers once and marks consumed.
   - Simulates battle victory: verifies victory debrief fires before result screen.
   - Simulates battle defeat: verifies defeat debrief fires before result screen.
3. **`test_highspire_courtyard.gd`**:
   - Verifies Sir Roderick NPC exists with correct dialogue tree and choices.
   - Verifies `[Sortie!]` choice emits `EventAction.start_battle("M01_CABBAGE")`.
   - Verifies `WorldState` condition switches dialogue after `"mission_m01_completed"` is set.
4. **`test_story_mission_end_to_end.gd`**:
   - Full flow: New Game $\to$ Courtyard $\to$ Talk to Sir Roderick $\to$ Sortie $\to$ Battle $\to$ Victory $\to$ Return to Courtyard with completed dialogue.

### 7.2 Visual Probe Verification (`scenes/screenshot_probe.gd`)

- `SORTIE_MISSION_BRIEF`: Captures screenshot of Sir Roderick's cabbage briefing with the `[Sortie!]` choice.
- `SORTIE_BATTLE_BANTER`: Captures screenshot of Scout Pip and Vanguard's Turn 1 mid-battle banter.
- `SORTIE_CATAPULT_BANTER`: Captures screenshot of the Brute's Catapult Zone dialogue overlay.
