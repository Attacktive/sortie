class_name Sfx
extends Node

## The combat sound effects, plus a small pool of players so they stop cutting
## each other off.
##
## Clips are addressed by path rather than by handing callers a stream, so the
## call site names what happened and a missing file fails a test instead of
## playing silence.

const HIT := "res://assets/audio/hit.ogg"
const MISS := "res://assets/audio/miss.ogg"
const DEATH := "res://assets/audio/death.ogg"

const CLIPS := [HIT, MISS, DEATH]

## A killing blow plays a hit and a death within the same half second, and the
## counterattack can do it again before either has finished.
const VOICES := 4

const VOLUME_DB := -6.0

## Playing one sample verbatim every time is what makes an effect read as cheap,
## and a counterattack fires the same clip again half a second later.
## Nudging each play breaks the sameness without touching the clips themselves.
##
## This is the one place randomness is drawn outside a RollSource, and it is
## deliberate: it is presentation only, it lives outside core/, and it cannot
## reach the rules, so a replayed seed still produces the identical battle.
const PITCH_JITTER := 0.12
const VOLUME_JITTER_DB := 1.5

var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

## Which clip a swing calls for at the moment the blade arrives.
## Pure, so the mapping is pinned by a test rather than buried in the animator.
static func impact_clip(hit: bool) -> String:
	if hit:
		return HIT

	return MISS

## Plays a clip on the next voice in the pool, round-robin, and returns the
## player that took it.
func play(path: String) -> AudioStreamPlayer:
	var player := _players[_next]
	_next = (_next + 1) % VOICES

	player.stream = load(path)
	player.pitch_scale = randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	player.volume_db = VOLUME_DB + randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB)
	player.play()

	return player
