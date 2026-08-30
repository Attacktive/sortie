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

var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = VOLUME_DB
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
	player.play()

	return player
