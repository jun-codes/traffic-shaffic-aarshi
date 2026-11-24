# Autoload: plays the game's sound effects. Sfx.play("click" / "crash" / "victory" / "sad").
# All effects go through the "SFX" audio bus, whose volume is the slider on the settings screen.
extends Node

var SOUNDS := {
	"click": load("res://assets/audio/click.mp3"),
	"crash": load("res://assets/audio/crash.mp3"),
	"victory": load("res://assets/audio/victory.mp3"),
	"sad": load("res://assets/audio/sad.mp3"),
}
const VOLUME_DB := {"click": -6.0, "crash": -3.0, "victory": -3.0, "sad": -3.0}
const BUS := "SFX"

var players := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS       # the end screens pause the game: sounds must still play
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
	for id in SOUNDS:
		var p := AudioStreamPlayer.new()
		p.stream = SOUNDS[id]
		p.volume_db = VOLUME_DB[id]
		p.bus = BUS
		add_child(p)
		players[id] = p
	apply_volume()

# Sets the volume of the effects bus from the saved setting (0 = silent).
func apply_volume() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	var v: float = Global.sfx_volume
	AudioServer.set_bus_volume_db(idx, linear_to_db(v) if v > 0.001 else -80.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)

func play(id: String) -> void:
	if players.has(id):
		players[id].play()
