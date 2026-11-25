# Autoload: the background music. It looks at the scene that is open and plays the matching track:
#   menus (intro screen, tutorial, level picker, customise, settings) -> intro music
#   every level except the boss level (Level1-4, Zip1, Zip2 ...)                                                        -> normal level music
#   level 5                                                              -> boss level music
# The same track keeps playing across scenes (for example from one level to the next).
extends Node

const TRACKS := {
	"intro": "res://assets/audio/music_intro.mp3",
	"levels": "res://assets/audio/music_levels.mp3",
	"boss": "res://assets/audio/music_boss.mp3",
}
const VOLUME_DB := -8.0        # a little under the sound effects
const FADE := 0.5              # seconds to fade out / in when the track changes
const BUS := "Music"

var player: AudioStreamPlayer
var current := ""
var tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS       # the levels are paused until you press play: music goes on
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
	player = AudioStreamPlayer.new()
	player.bus = BUS
	player.volume_db = VOLUME_DB
	add_child(player)
	apply_volume()

# Sets the volume of the music bus from the saved setting (0 = silent).
func apply_volume() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	var v: float = Global.music_volume
	AudioServer.set_bus_volume_db(idx, linear_to_db(v) if v > 0.001 else -80.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)

func _track_for(path: String) -> String:
	if path.contains("/Level5/"):
		return "boss"
	if path.contains("/Level") or path.contains("/Zip"):      # every level folder (Level1..4, Zip1, Zip2, ...)
		return "levels"
	return "intro"

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == "":
		return
	var wanted := _track_for(scene.scene_file_path)
	if wanted != current:
		_switch_to(wanted)

func _switch_to(id: String) -> void:
	current = id
	if tween != null:
		tween.kill()
	tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if player.playing:
		tween.tween_property(player, "volume_db", -60.0, FADE)
	tween.tween_callback(_start.bind(id))
	tween.tween_property(player, "volume_db", VOLUME_DB, FADE)

func _start(id: String) -> void:
	var stream := load(TRACKS[id]) as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true                           # the track repeats until the scene changes
	player.stream = stream
	player.volume_db = -60.0
	player.play()
