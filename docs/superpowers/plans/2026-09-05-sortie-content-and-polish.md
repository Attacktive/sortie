# Content & Polish (Sub-project 6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Sub-project 6 (Content & Polish) delivering the playable narrative campaign vertical slice for Mission `M01_CABBAGE` ("The Cabbage Trajectory"): Highspire Courtyard home base, Commander Sir Roderick NPC, modal in-combat banter, catapult area trigger, victory/defeat debriefs, and world state reactivity.

**Architecture:** Following the project's two-layer architecture, `core/mission_data.gd` and `core/mission_registry.gd` encapsulate mission domain specifications as pure `RefCounted` objects with zero scene-tree dependencies. `scenes/field.gd` hosts the Highspire Courtyard with Commander Sir Roderick and the Sally Port gate. `scenes/battle.gd` parameterizes tactical encounters by mission ID, providing modal `DialogueBox` overlays for turn-start and area triggers. `scenes/game.gd` coordinates mission routing and world flag progression.

**Tech Stack:** Godot 4.7.2 stable, GDScript, GUT 9.7.1 headless test runner.

**Spec:** `docs/superpowers/specs/2026-09-05-sortie-content-and-polish-design.md`

## Global Constraints

- Two-layer architecture: `core/` contains pure `RefCounted`/`Resource` objects with zero `Node`, scene tree, `Input`, `preload()`, or RNG calls.
- Indent with tabs.
- Never hard-wrap comments (one sentence per physical line).
- Two blank lines between top-level GDScript functions.
- Single blank lines before and after markdown lists, headings, and dividers (MD012/MD022/MD031/MD032 clean).
- Headless testing: all tests pass via `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`.
- Co-authored commit trailer: `Co-authored-by: Gemini 3.8 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>`.

---

### Task 1: Core Domain Mission Model (`MissionData`)

**Files:**

- Create: `core/mission_data.gd`
- Test: `test/test_mission_data.gd`

**Interfaces:**

- Produces: `MissionData` class with fields `mission_id`, `title`, `map_ascii`, `player_roster`, `enemy_roster`, `player_spawns`, `enemy_spawns`, `turn_dialogue_triggers`, `area_dialogue_triggers`, `victory_debrief`, `defeat_debrief`, `completion_flag`.

- [ ] **Step 1: Write the failing test**

Create `test/test_mission_data.gd`:

```gdscript
class_name TestMissionData
extends GutTest


func test_mission_data_defaults_and_properties() -> void:
    var mission := MissionData.new()
    assert_eq(mission.mission_id, "")
    assert_eq(mission.title, "")
    assert_eq(mission.map_ascii.size(), 0)
    assert_eq(mission.player_roster.size(), 0)
    assert_eq(mission.enemy_roster.size(), 0)
    assert_eq(mission.player_spawns.size(), 0)
    assert_eq(mission.enemy_spawns.size(), 0)
    assert_eq(mission.turn_dialogue_triggers.size(), 0)
    assert_eq(mission.area_dialogue_triggers.size(), 0)
    assert_null(mission.victory_debrief)
    assert_null(mission.defeat_debrief)
    assert_eq(mission.completion_flag, "mission_m01_completed")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_mission_data.gd -gexit`
Expected: FAIL (`MissionData` not found)

- [ ] **Step 3: Write minimal implementation**

Create `core/mission_data.gd`:

```gdscript
class_name MissionData
extends RefCounted

## Pure domain representation of a narrative combat mission/sortie.

var mission_id: String = ""
var title: String = ""
var map_ascii: PackedStringArray = []
var player_roster: Array[UnitData] = []
var enemy_roster: Array[UnitData] = []
var player_spawns: Array[Vector2i] = []
var enemy_spawns: Array[Vector2i] = []

## Turn number (int) -> DialogueTree played at player turn start.
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

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_mission_data.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add core/mission_data.gd test/test_mission_data.gd*
git commit -m "feat: implement MissionData domain model

Co-authored-by: Gemini 3.8 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 2: Core Mission Registry (`MissionRegistry`) with `M01_CABBAGE`

**Files:**

- Create: `core/mission_registry.gd`
- Modify: `test/test_mission_data.gd`

**Interfaces:**

- Consumes: `MissionData`, `DialogueTree`, `UnitData`.
- Produces: `MissionRegistry.get_mission(mission_id: String) -> MissionData`.

- [ ] **Step 1: Write the failing test**

Append to `test/test_mission_data.gd`:

```gdscript
func test_mission_registry_builds_m01_cabbage() -> void:
    var mission := MissionRegistry.get_mission("M01_CABBAGE")
    assert_not_null(mission)
    assert_eq(mission.mission_id, "M01_CABBAGE")
    assert_eq(mission.title, "The Cabbage Trajectory")
    assert_eq(mission.map_ascii.size(), 8)
    assert_eq(mission.player_roster.size(), 4)
    assert_eq(mission.enemy_roster.size(), 4)
    assert_eq(mission.player_spawns.size(), 4)
    assert_eq(mission.enemy_spawns.size(), 4)
    assert_true(mission.turn_dialogue_triggers.has(1))
    assert_gt(mission.area_dialogue_triggers.size(), 0)
    assert_not_null(mission.victory_debrief)
    assert_not_null(mission.defeat_debrief)
    assert_eq(mission.completion_flag, "mission_m01_completed")


func test_mission_registry_unknown_returns_null() -> void:
    assert_null(MissionRegistry.get_mission("NON_EXISTENT"))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_mission_data.gd -gexit`
Expected: FAIL (`MissionRegistry` not found)

- [ ] **Step 3: Write minimal implementation**

Create `core/mission_registry.gd`:

```gdscript
class_name MissionRegistry
extends RefCounted

## Static factory and repository of narrative sortie missions.

const M01_MAP := [
    "..F....F..",
    ".##....##.",
    "..........",
    "...####...",
    "...####...",
    "..........",
    ".##....##.",
    "..F....F..",

]


static func get_mission(mission_id: String) -> MissionData:
    if mission_id == "M01_CABBAGE":
        return _build_m01_cabbage()

    return null


static func _build_m01_cabbage() -> MissionData:
    var mission := MissionData.new()
    mission.mission_id = "M01_CABBAGE"
    mission.title = "The Cabbage Trajectory"
    mission.map_ascii = PackedStringArray(M01_MAP)

    mission.player_roster = [
        _make_unit("Vanguard", 24, 9, 4, 0.90, 0.05, 0.05, 3, 1, UnitData.Team.PLAYER, "vanguard"),
        _make_unit("Scout", 14, 6, 0, 0.90, 0.25, 0.10, 5, 1, UnitData.Team.PLAYER, "scout"),
        _make_unit("Brute", 26, 10, 3, 0.85, 0.00, 0.05, 3, 1, UnitData.Team.PLAYER, "brute"),
        _make_unit("Raider", 18, 8, 1, 0.90, 0.10, 0.15, 4, 1, UnitData.Team.PLAYER, "raider"),
    ]
    mission.player_spawns = [
        Vector2i(0, 6),
        Vector2i(1, 7),
        Vector2i(0, 7),
        Vector2i(1, 6),
    ]

    mission.enemy_roster = [
        _make_unit("Siege Vanguard", 22, 8, 3, 0.90, 0.05, 0.05, 3, 1, UnitData.Team.ENEMY, "vanguard"),
        _make_unit("Catapult Guard", 24, 9, 2, 0.85, 0.00, 0.05, 3, 1, UnitData.Team.ENEMY, "brute"),
        _make_unit("Slinger", 14, 6, 0, 0.90, 0.25, 0.10, 5, 1, UnitData.Team.ENEMY, "scout"),
        _make_unit("Artillery Raider", 16, 7, 1, 0.90, 0.10, 0.15, 4, 1, UnitData.Team.ENEMY, "raider"),
    ]
    mission.enemy_spawns = [
        Vector2i(8, 2),
        Vector2i(9, 3),
        Vector2i(8, 5),
        Vector2i(9, 4),
    ]

    mission.turn_dialogue_triggers[1] = DialogueTree.from_dict({
        "start": "pip_wonder",
        "nodes": {
            "pip_wonder": {
                "speaker": "Scout",
                "text": "Couldn't we just... close the windows? Why are we risking our lives for vegetables?",
                "next": "vanguard_chivalry",
            },
            "vanguard_chivalry": {
                "speaker": "Vanguard",
                "text": "Because chivalry does not flinch before foul brassicas, Pip! Forward!",
            },
        },
    })

    var catapult_zone := Rect2i(Vector2i(7, 2), Vector2i(3, 4))
    mission.area_dialogue_triggers[catapult_zone] = DialogueTree.from_dict({
        "start": "brute_dismantle",
        "nodes": {
            "brute_dismantle": {
                "speaker": "Brute",
                "text": "Excuse me, friends. I am going to gently dismantle your siege weapon now. Please step back so no one gets wood splinters.",
            },
        },
    })

    mission.victory_debrief = DialogueTree.from_dict({
        "start": "wrecked",
        "nodes": {
            "wrecked": {
                "speaker": "Raider",
                "text": "Catapult wrecked, boss. Also, I found twelve silver coins in their tool chest.",
                "next": "fee",
            },
            "fee": {
                "speaker": "Raider",
                "text": "Consider it an environmental hazard fee.",
            },
        },
    })

    mission.defeat_debrief = DialogueTree.from_dict({
        "start": "retreat",
        "nodes": {
            "retreat": {
                "speaker": "Vanguard",
                "text": "A glorious tactical withdrawal from incoming cruciferous projectiles! Fall back and regroup!",
            },
        },
    })

    mission.completion_flag = "mission_m01_completed"
    return mission


static func _make_unit(
    unit_name: String,
    max_hp: int,
    attack: int,
    defense: int,
    accuracy: float,
    evasion: float,
    crit_rate: float,
    move_range: int,
    attack_range: int,
    team: UnitData.Team,
    art: String

) -> UnitData:
    var data := UnitData.new()
    data.unit_name = unit_name
    data.max_hp = max_hp
    data.attack = attack
    data.defense = defense
    data.accuracy = accuracy
    data.evasion = evasion
    data.crit_rate = crit_rate
    data.move_range = move_range
    data.attack_range = attack_range
    data.team = team
    data.sprite_walk = "res://assets/lpc/units/%s_walkcycle.png" % art
    data.sprite_slash = "res://assets/lpc/units/%s_slash.png" % art

    return data
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_mission_data.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add core/mission_registry.gd test/test_mission_data.gd*
git commit -m "feat: implement MissionRegistry with M01_CABBAGE mission data

Co-authored-by: Gemini 3.8 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 3: Battle Parameterization & Mission Grid / Roster Initialization

**Files:**

- Modify: `scenes/battle.gd`
- Create: `test/test_battle_mission.gd`

**Interfaces:**

- Consumes: `MissionRegistry`, `MissionData`.
- Produces: `Battle.mission_id: String`, initialized tactical battlefield from mission specifications.

- [ ] **Step 1: Write the failing test**

Create `test/test_battle_mission.gd`:

```gdscript
class_name TestBattleMission
extends GutTest


func test_battle_parameterized_with_m01_spawns_mission_squads() -> void:
    var battle: Battle = load("res://scenes/battle.tscn").instantiate()
    battle.mission_id = "M01_CABBAGE"
    add_child_autofree(battle)
    await get_tree().process_frame

    var grid: BattleGrid = battle._grid
    assert_not_null(grid)
    var players := grid.living_units_of_team(UnitData.Team.PLAYER)
    var enemies := grid.living_units_of_team(UnitData.Team.ENEMY)

    assert_eq(players.size(), 4)
    assert_eq(enemies.size(), 4)

    assert_eq(grid.unit_at(Vector2i(0, 6)).data.unit_name, "Vanguard")
    assert_eq(grid.unit_at(Vector2i(1, 7)).data.unit_name, "Scout")
    assert_eq(grid.unit_at(Vector2i(0, 7)).data.unit_name, "Brute")
    assert_eq(grid.unit_at(Vector2i(1, 6)).data.unit_name, "Raider")

    assert_eq(grid.unit_at(Vector2i(8, 2)).data.unit_name, "Siege Vanguard")
    assert_eq(grid.unit_at(Vector2i(9, 3)).data.unit_name, "Catapult Guard")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_battle_mission.gd -gexit`
Expected: FAIL (`mission_id` property not on Battle, or wrong units spawned)

- [ ] **Step 3: Modify `scenes/battle.gd`**

In `scenes/battle.gd`:
Add property:

```gdscript
var mission_id: String = "default"
var _mission: MissionData = null
```

In `_start_battle()`:

```gdscript
    if mission_id != "default":
        _mission = MissionRegistry.get_mission(mission_id)

    if _mission != null:
        _grid = BattleGrid.from_ascii(_mission.map_ascii)
        _turns = TurnOrder.new(_grid)
        _build_views_for_mission()
    else:
        _grid = Scenario.build_grid()
        _turns = TurnOrder.new(_grid)
        _build_views()

    _enter_unit_selection()
    _banner.announce("Your Turn", CombatAnimator.PLAYER_COLOR)
```

Add `_build_views_for_mission()`:

```gdscript
func _build_views_for_mission() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()

    _views.clear()

    _grid_view = GridView.new()
    _grid_view.grid = _grid
    _grid_view.position = MARGIN
    add_child(_grid_view)

    for i in _mission.player_roster.size():
        var data := _mission.player_roster[i]
        var cell := _mission.player_spawns[i]
        var unit := BattleUnit.new(data, cell)
        _grid.place_unit(unit, cell)
        var view := UnitView.new()
        view.setup(unit)
        _grid_view.add_child(view)
        _views[unit] = view

    for i in _mission.enemy_roster.size():
        var data := _mission.enemy_roster[i]
        var cell := _mission.enemy_spawns[i]
        var unit := BattleUnit.new(data, cell)
        _grid.place_unit(unit, cell)
        var view := UnitView.new()
        view.setup(unit)
        _grid_view.add_child(view)
        _views[unit] = view

    _cursor = Cursor.new()
    _cursor.grid = _grid
    _cursor.moved.connect(_on_cursor_moved)
    _cursor.activated.connect(_on_cursor_activated)
    _cursor.cancelled.connect(_on_cursor_cancelled)
    _grid_view.add_child(_cursor)

    _forecast_panel = ForecastPanel.new()
    _forecast_panel.position = Vector2(MARGIN.x, MARGIN.y + _grid.height * GridGeometry.CELL_SIZE + 10)
    add_child(_forecast_panel)

    _action_menu = ActionMenu.new()
    _action_menu.action_selected.connect(_on_action_selected)
    _action_menu.cancelled.connect(_on_action_menu_cancelled)
    add_child(_action_menu)

    _result_screen = ResultScreen.new()
    _result_screen.continue_pressed.connect(_on_result_continue_pressed)
    _result_screen.retry_pressed.connect(_on_result_retry_pressed)
    _result_screen.title_pressed.connect(_on_result_title_pressed)
    add_child(_result_screen)

    _animator = CombatAnimator.new()
    add_child(_animator)

    _banner = TurnBanner.new()
    add_child(_banner)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_battle_mission.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scenes/battle.gd test/test_battle_mission.gd*
git commit -m "feat: parameterize Battle scene initialization by mission_id

Co-authored-by: Gemini 3.8 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 4: In-Combat Modal Dialogue System (Turn Start & Area Triggers)

**Files:**

- Modify: `scenes/battle.gd`
- Create: `test/test_battle_mission_dialogue.gd`

**Interfaces:**

- Consumes: `DialogueBox`, `DialogueTree`, `MissionData`.
- Produces: Modal dialogue pause on turn 1 start and Catapult Zone entry.

- [ ] **Step 1: Write the failing test**

Create `test/test_battle_mission_dialogue.gd`:

```gdscript
class_name TestBattleMissionDialogue
extends GutTest


func test_turn_start_dialogue_modal_locks_input_and_completes() -> void:
    var battle: Battle = load("res://scenes/battle.tscn").instantiate()
    battle.mission_id = "M01_CABBAGE"
    add_child_autofree(battle)
    await get_tree().process_frame

    var dialogue: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
    assert_not_null(dialogue, "DialogueBox should be spawned on Turn 1 start")
    assert_false(battle._cursor.is_active(), "Cursor should be locked during dialogue")

    dialogue.handle_input_action("ui_accept")
    dialogue.handle_input_action("ui_accept")
    await get_tree().process_frame

    assert_null(battle.get_node_or_null("BattleDialogueBox"))
    assert_true(battle._cursor.is_active(), "Cursor unlocks when dialogue finishes")


func test_area_trigger_fires_once_when_entering_catapult_zone() -> void:
    var battle: Battle = load("res://scenes/battle.tscn").instantiate()
    battle.mission_id = "M01_CABBAGE"
    add_child_autofree(battle)
    await get_tree().process_frame

    var turn_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
    if turn_dlg != null:
        turn_dlg.handle_input_action("ui_accept")
        turn_dlg.handle_input_action("ui_accept")
        await get_tree().process_frame

    var brute: BattleUnit = battle._grid.unit_at(Vector2i(0, 7))
    battle._move_unit(brute, Vector2i(7, 2))
    await get_tree().process_frame

    var area_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
    assert_not_null(area_dlg, "Area dialogue fires when entering CatapultZone")
    area_dlg.handle_input_action("ui_accept")
    await get_tree().process_frame

    assert_null(battle.get_node_or_null("BattleDialogueBox"))
    assert_true(battle._consumed_area_triggers.has(Rect2i(Vector2i(7, 2), Vector2i(3, 4))))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_battle_mission_dialogue.gd -gexit`
Expected: FAIL (Turn dialogue not attached as `BattleDialogueBox`)

- [ ] **Step 3: Modify `scenes/battle.gd`**

In `scenes/battle.gd`:
Add tracking variables:

```gdscript
var _turn_count: int = 1
var _consumed_area_triggers: Array[Rect2i] = []
var _battle_dialogue: DialogueBox = null
```

Add helper `_play_modal_dialogue(tree: DialogueTree, on_complete: Callable)`:

```gdscript
func _play_modal_dialogue(tree: DialogueTree, on_complete: Callable) -> void:
    _cursor.deactivate()
    _battle_dialogue = DialogueBox.new()
    _battle_dialogue.name = "BattleDialogueBox"
    add_child(_battle_dialogue)
    _battle_dialogue.finished.connect(func() -> void:
        _battle_dialogue.queue_free()
        _battle_dialogue = null
        on_complete.call()
    )
    _battle_dialogue.start_dialogue(tree)
```

In `_unhandled_input(event: InputEvent)`:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if _battle_dialogue != null:
        if event.is_action_pressed("ui_accept"):
            _battle_dialogue.handle_input_action("ui_accept")
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("ui_up"):
            _battle_dialogue.handle_input_action("ui_up")
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("ui_down"):
            _battle_dialogue.handle_input_action("ui_down")
            get_viewport().set_input_as_handled()
        return
```

In `_enter_unit_selection()`:
Check `_mission.turn_dialogue_triggers`:

```gdscript
func _enter_unit_selection() -> void:
    _state = State.SELECTING_UNIT
    _selected = null
    _field = null

    if _mission != null and _mission.turn_dialogue_triggers.has(_turn_count):
        var tree: DialogueTree = _mission.turn_dialogue_triggers[_turn_count]
        _play_modal_dialogue(tree, func() -> void:
            _cursor.activate()
        )
    else:
        _cursor.activate()
```

In `_move_unit(unit: BattleUnit, destination: Vector2i)`:
Check area triggers after move:

```gdscript
    # ... after unit repositioning ...
    var triggered_tree: DialogueTree = null
    if _mission != null:
        for area: Rect2i in _mission.area_dialogue_triggers.keys():
            if not _consumed_area_triggers.has(area) and area.has_point(destination):
                _consumed_area_triggers.append(area)
                triggered_tree = _mission.area_dialogue_triggers[area]
                break

    if triggered_tree != null:
        _play_modal_dialogue(triggered_tree, func() -> void:
            _open_action_menu(unit, destination)
        )
    else:
        _open_action_menu(unit, destination)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_battle_mission_dialogue.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scenes/battle.gd test/test_battle_mission_dialogue.gd*
git commit -m "feat: implement modal in-combat turn and area dialogue triggers

Co-authored-by: Gemini 3.8 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 5: Victory & Defeat Debrief Sequences in Battle

**Files:**

- Modify: `scenes/battle.gd`
- Create: `test/test_battle_debrief.gd`

**Interfaces:**

- Consumes: `MissionData.victory_debrief`, `MissionData.defeat_debrief`.
- Produces: Modal debrief presentation prior to displaying ResultScreen.

- [ ] **Step 1: Write the failing test**

Create `test/test_battle_debrief.gd`:

```gdscript
class_name TestBattleDebrief
extends GutTest


func test_victory_triggers_victory_debrief_before_result_screen() -> void:
    var battle: Battle = load("res://scenes/battle.tscn").instantiate()
    battle.mission_id = "M01_CABBAGE"
    add_child_autofree(battle)
    await get_tree().process_frame

    var turn_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
    if turn_dlg != null:
        turn_dlg.handle_input_action("ui_accept")
        turn_dlg.handle_input_action("ui_accept")
        await get_tree().process_frame

    for enemy in battle._grid.living_units_of_team(UnitData.Team.ENEMY):
        enemy.current_hp = 0

    battle._check_battle_resolution()
    await get_tree().process_frame

    var debrief_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
    assert_not_null(debrief_dlg, "Victory debrief displays on victory")
    assert_false(battle._result_screen.visible, "Result screen waits for debrief")

    debrief_dlg.handle_input_action("ui_accept")
    debrief_dlg.handle_input_action("ui_accept")
    await get_tree().process_frame

    assert_true(battle._result_screen.visible, "Result screen shows after debrief")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_battle_debrief.gd -gexit`
Expected: FAIL (Debrief dialogue box not spawned)

- [ ] **Step 3: Modify `scenes/battle.gd`**

In `_check_battle_resolution()`:

```gdscript
    if resolution == TurnOrder.Resolution.VICTORY:
        _state = State.RESOLVED
        _cursor.deactivate()
        if _mission != null and _mission.victory_debrief != null:
            _play_modal_dialogue(_mission.victory_debrief, func() -> void:
                _result_screen.show_victory()
            )
        else:
            _result_screen.show_victory()
    elif resolution == TurnOrder.Resolution.DEFEAT:
        _state = State.RESOLVED
        _cursor.deactivate()
        if _mission != null and _mission.defeat_debrief != null:
            _play_modal_dialogue(_mission.defeat_debrief, func() -> void:
                _result_screen.show_defeat()
            )
        else:
            _result_screen.show_defeat()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_battle_debrief.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scenes/battle.gd test/test_battle_debrief.gd*
git commit -m "feat: implement victory and defeat debrief modal sequences

Co-authored-by: Gemini 3.8 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 6: Highspire Courtyard Home Base & Commander Sir Roderick

**Files:**

- Modify: `scenes/field.gd`
- Create: `test/test_highspire_courtyard.gd`

**Interfaces:**

- Consumes: `WorldState`, `DialogueTree`, `EventAction.start_battle("M01_CABBAGE")`.
- Produces: Sir Roderick NPC briefing, `[Sortie!]` / `[Prepare]` choices, reactive dialogue after mission completion.

- [ ] **Step 1: Write the failing test**

Create `test/test_highspire_courtyard.gd`:

```gdscript
class_name TestHighspireCourtyard
extends GutTest


func test_sir_roderick_presents_cabbage_briefing_with_sortie_choice() -> void:
    var field: Field = load("res://scenes/field.tscn").instantiate()
    add_child_autofree(field)
    await get_tree().process_frame

    var roderick: FieldNpc = field.get_node_or_null("SirRoderick")
    assert_not_null(roderick, "Sir Roderick NPC exists in courtyard")

    var dialogue: DialogueTree = roderick.get_dialogue_for_state(field.world_state)
    assert_not_null(dialogue)
    var start_node := dialogue.get_node("start")
    assert_string_contains(start_node.text, "gravest dishonor")


func test_sir_roderick_updates_dialogue_after_mission_completion() -> void:
    var field: Field = load("res://scenes/field.tscn").instantiate()
    add_child_autofree(field)
    await get_tree().process_frame

    field.world_state.set_flag("mission_m01_completed", true)
    var roderick: FieldNpc = field.get_node_or_null("SirRoderick")
    var dialogue: DialogueTree = roderick.get_dialogue_for_state(field.world_state)

    var start_node := dialogue.get_node("start")
    assert_string_contains(start_node.text, "Splendid work out there")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_highspire_courtyard.gd -gexit`
Expected: FAIL (`SirRoderick` NPC not found)

- [ ] **Step 3: Modify `scenes/field.gd`**

In `scenes/field.gd`:
Define Sir Roderick position and sheet:

```gdscript
const RODERICK_CELL := Vector2i(8, 2)
const RODERICK_SHEET := "res://assets/lpc/units/brute_walkcycle.png"
```

In `_build_npc()`:
Set up Sir Roderick with briefing and completed conditional dialogue trees:

```gdscript
func _build_roderick() -> void:
    var roderick := FieldNpc.new()
    roderick.name = "SirRoderick"

    var briefing := DialogueTree.from_dict({
        "start": "briefing_dishonor",
        "nodes": {
            "briefing_dishonor": {
                "speaker": "Sir Roderick",
                "text": "Men, today Highspire faces its gravest dishonor.",
                "next": "briefing_catapult",
            },
            "briefing_catapult": {
                "speaker": "Sir Roderick",
                "text": "The enemy has assembled a catapult 80 paces out, and they are launching rotten produce into the royal herb garden.",
                "next": "briefing_sally",
            },
            "briefing_sally": {
                "speaker": "Sir Roderick",
                "text": "We sally out, dismantle the contraption, and preserve the King's rosemary!",
                "choices": [
                    {"label": "[Sortie!]", "next": "action_sortie"},
                    {"label": "[Prepare]", "next": "action_prepare"},
                ],
            },
            "action_sortie": {
                "speaker": "Sir Roderick",
                "text": "Sound the charge!",
                "action": EventAction.start_battle("M01_CABBAGE"),
            },
            "action_prepare": {
                "speaker": "Sir Roderick",
                "text": "Hurry, Pip. Every second we tarry is another bruised turnip in His Majesty's parsley.",
            },
        },
    })

    var victory_debrief := DialogueTree.from_dict({
        "start": "post_victory",
        "nodes": {
            "post_victory": {
                "speaker": "Sir Roderick",
                "text": "Splendid work out there! The royal herb garden is safe. The scout reports the remaining cabbage hurled over the ramparts was surprisingly edible in soup.",
                "next": "post_tease",
            },
            "post_tease": {
                "speaker": "Sir Roderick",
                "text": "Catch your breath—word has it our ale shipment down south has run into trouble.",
            },
        },
    })

    roderick.setup(RODERICK_SHEET, "Sir Roderick", briefing)
    roderick.conditional_dialogues = [
        {
            "condition": EventCondition.is_true("mission_m01_completed"),
            "dialogue": victory_debrief,
        },
    ]

    roderick.position = GridGeometry.cell_to_position(RODERICK_CELL)
    add_child(roderick)
```

In `_ready()`:
Call `_build_roderick()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_highspire_courtyard.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scenes/field.gd test/test_highspire_courtyard.gd*
git commit -m "feat: add Commander Sir Roderick and cabbage briefing in Highspire Courtyard

Co-authored-by: Gemini 3.8 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 7: Game Coordinator Mission Routing & End-to-End Campaign Flow

**Files:**

- Modify: `scenes/game.gd`
- Create: `test/test_story_mission_end_to_end.gd`

**Interfaces:**

- Consumes: `Game`, `MissionRegistry`, `WorldState`.
- Produces: Complete narrative campaign loop (Courtyard $\to$ Sortie $\to$ Battle $\to$ Victory $\to$ Debrief $\to$ Courtyard with flag).

- [ ] **Step 1: Write the failing test**

Create `test/test_story_mission_end_to_end.gd`:

```gdscript
class_name TestStoryMissionEndToEnd
extends GutTest


func test_full_cabbage_mission_loop() -> void:
    var game: Game = load("res://scenes/game.tscn").instantiate()
    add_child_autofree(game)
    await get_tree().process_frame

    game.start_new_game()
    await get_tree().process_frame
    assert_eq(game.current_mode, Game.Mode.FIELD)

    # Simulate Sir Roderick Sortie choice triggering battle
    game.start_battle("M01_CABBAGE", false)
    await get_tree().process_frame
    assert_eq(game.current_mode, Game.Mode.BATTLE)

    var battle: Battle = game.get_active_scene()
    assert_eq(battle.mission_id, "M01_CABBAGE")

    # Dismiss turn 1 banter
    var turn_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
    if turn_dlg != null:
        turn_dlg.handle_input_action("ui_accept")
        turn_dlg.handle_input_action("ui_accept")
        await get_tree().process_frame

    # Eliminate enemy squad to trigger victory
    for enemy in battle._grid.living_units_of_team(UnitData.Team.ENEMY):
        enemy.current_hp = 0
    battle._check_battle_resolution()
    await get_tree().process_frame

    # Dismiss victory debrief
    var debrief_dlg: DialogueBox = battle.get_node_or_null("BattleDialogueBox")
    if debrief_dlg != null:
        debrief_dlg.handle_input_action("ui_accept")
        debrief_dlg.handle_input_action("ui_accept")
        await get_tree().process_frame

    # Click continue on result screen
    battle._on_result_continue_pressed()
    await get_tree().process_frame
    await get_tree().process_frame

    assert_eq(game.current_mode, Game.Mode.FIELD)
    assert_true(game.world_state.has_flag("mission_m01_completed"))
    assert_true(game.world_state.get_flag("mission_m01_completed"))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_story_mission_end_to_end.gd -gexit`
Expected: FAIL (`start_battle` does not configure `battle.mission_id`, or `mission_m01_completed` flag not set on victory)

- [ ] **Step 3: Modify `scenes/game.gd`**

In `scenes/game.gd`:
In `start_battle(battle_id: String = "default", is_quick: bool = false)`:
Pass `battle_id` to `battle.mission_id`:

```gdscript
func start_battle(battle_id: String = "default", is_quick: bool = false) -> void:
    # ...
    _switch_scene(battle, func(new_scene: Node) -> void:
        var b: Battle = new_scene as Battle
        b.mission_id = battle_id
        b.battle_completed.connect(_on_battle_completed)
        b.retry_requested.connect(func() -> void: start_battle(battle_id, is_quick))
        b.title_requested.connect(_show_title)
    )
```

In `_on_battle_completed(victory: bool)`:
Update mission completion flag:

```gdscript
func _on_battle_completed(victory: bool) -> void:
    if not victory:
        return

    if _current_battle_id != "default":
        var mission := MissionRegistry.get_mission(_current_battle_id)
        if mission != null and mission.completion_flag != "":
            _world_state.set_flag(mission.completion_flag, true)

    _show_field(field_restore_data)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_story_mission_end_to_end.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scenes/game.gd test/test_story_mission_end_to_end.gd*
git commit -m "feat: route mission_id in Game coordinator and record victory flag

Co-authored-by: Gemini 3.8 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 8: Visual Probe Verification & Handoff Update

**Files:**

- Modify: `scenes/screenshot_probe.gd`
- Modify: `docs/HANDOFF.md`

**Interfaces:**

- Consumes: Vision tool, `docs/HANDOFF.md`.
- Produces: Visual verification screenshots, updated status table, and roadmap completion notes.

- [ ] **Step 1: Add probe hooks in `scenes/screenshot_probe.gd`**

Add hooks `SORTIE_MISSION_BRIEF` and `SORTIE_BATTLE_BANTER` to stage and capture the mission briefing in Highspire Courtyard and in-combat banter.

- [ ] **Step 2: Capture and verify screenshots**

Run:

```bash
SORTIE_SHOT=/tmp/mission_brief.png SORTIE_MISSION_BRIEF=true godot scenes/game.tscn --quit-after 60
SORTIE_SHOT=/tmp/battle_banter.png SORTIE_BATTLE_BANTER=true godot scenes/game.tscn --quit-after 60
```

Use `read` with `?q=` to verify:

- `mission_brief.png` shows Sir Roderick briefing the player with `[Sortie!]` choice.
- `battle_banter.png` shows Scout Pip and Vanguard banter on the trench map.

- [ ] **Step 3: Update `docs/HANDOFF.md`**

Update:

- Branch and status headers.
- Total passing test count.
- Sub-project 6 completion table and narrative summary.
- Screenshot recipe instructions.

- [ ] **Step 4: Verify test suite and markdownlint**

Run:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
npx markdownlint-cli --disable MD013 --disable MD060 -- docs/HANDOFF.md
```

Expected: All tests pass, 0 markdownlint errors.

- [ ] **Step 5: Commit**

```bash
git add scenes/screenshot_probe.gd docs/HANDOFF.md
git commit -m "docs: add probe hooks and update HANDOFF.md for Sub-project 6

Co-authored-by: Gemini 3.8 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```
