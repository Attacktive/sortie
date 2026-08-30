extends GutTest

## The worst case inside a single exchange: the attack hits and kills, and the
## counter hits and kills. Four clips overlap, so four voices is the floor.
const OVERLAPPING_IN_ONE_EXCHANGE := 4

func test_every_sound_effect_resolves() -> void:
	for path: String in Sfx.CLIPS:
		assert_true(ResourceLoader.exists(path), "missing sound effect: %s" % path)

func test_every_sound_effect_loads_as_audio() -> void:
	for path: String in Sfx.CLIPS:
		var stream: AudioStream = load(path)
		assert_not_null(stream, "%s did not load as an AudioStream" % path)
		assert_gt(stream.get_length(), 0.0, "%s is silent" % path)

## A killing blow plays the hit and the death within the same half second, so a
## single player would cut the first one off. That is the only reason the pool exists.
func test_overlapping_sounds_take_separate_voices() -> void:
	var sfx: Sfx = add_child_autofree(Sfx.new())

	assert_ne(sfx.play(Sfx.HIT), sfx.play(Sfx.DEATH), "two sounds in a row shared one voice")

func test_the_pool_covers_the_worst_case_exchange() -> void:
	assert_gte(Sfx.VOICES, OVERLAPPING_IN_ONE_EXCHANGE, "a full exchange can overlap %d clips" % OVERLAPPING_IN_ONE_EXCHANGE)

## Voices are reused round-robin, so the pool must wrap rather than run off the end.
func test_the_pool_wraps_around() -> void:
	var sfx: Sfx = add_child_autofree(Sfx.new())
	var first := sfx.play(Sfx.HIT)

	for i in Sfx.VOICES - 1:
		sfx.play(Sfx.MISS)

	assert_eq(sfx.play(Sfx.HIT), first, "the pool should return to its first voice")

func test_the_impact_clip_follows_the_outcome() -> void:
	assert_eq(Sfx.impact_clip(true), Sfx.HIT, "a landed blow should sound like an impact")
	assert_eq(Sfx.impact_clip(false), Sfx.MISS, "a whiff should not sound like an impact")

func test_the_three_clips_are_distinct() -> void:
	assert_eq(Sfx.CLIPS.size(), 3, "the pack is meant to hold exactly three sounds")
	assert_eq([Sfx.HIT, Sfx.MISS, Sfx.DEATH].size(), Sfx.CLIPS.size(), "a copy-paste would point two events at one file")

## Wiring rather than rules. Every sound bug in a project like this is the same
## bug: the code is correct and nothing ever calls it. So this drives a real
## swing through the real scene and then asks the pool what it played.
func test_a_real_attack_actually_makes_a_noise() -> void:
	var battle: Battle = load("res://scenes/battle.tscn").instantiate()
	add_child_autofree(battle)
	await get_tree().process_frame

	## Hit, no crit, mid variance — queued twice, because the target counters.
	battle._rolls = ScriptedRollSource.new([0.0, 0.99, 0.5, 0.0, 0.99, 0.5])

	var attacker := battle._grid.unit_at(Vector2i(0, 7))
	var target := battle._grid.unit_at(Vector2i(8, 0))
	var beside := target.cell + Vector2i(-1, 0)

	battle._grid.move_unit(attacker, beside)
	battle._views[attacker].snap()
	battle._try_select(beside)
	battle._state = Battle.State.CHOOSING_TARGET
	battle._try_attack(target.cell)

	await battle._animator.finished

	## _try_attack is still unwinding when the signal fires; letting it finish
	## keeps the scene from being torn down out from under a live coroutine.
	await get_tree().process_frame
	await get_tree().process_frame

	assert_has(_clips_played(battle), Sfx.HIT, "a blow landed and nothing was heard")

## Voices keep whatever stream they last played, so the pool is its own record.
func _clips_played(battle: Battle) -> Array[String]:
	var played: Array[String] = []

	for player in battle._animator._sfx._players:
		if player.stream != null:
			played.append(player.stream.resource_path)

	return played
