extends Node2D
@onready var death: Node2D = $"."
@onready var victory: Node2D = $"."

func _ready() -> void:
	death.hide()
	victory.hide()

func _on_btm_pressed():
	get_tree().paused = false
	Global.play = false
	Global.safe = false
	Global.speed_mult = 1.0
	Global.speed_limit_kmh = 50.0
	get_tree().change_scene_to_file("res://scenes/intro.tscn")

func _on_restart_level_pressed():
	Global.skip_sign_intro = true
	get_tree().paused = false
	Global.play = false
	Global.safe = false
	Global.speed_mult = 1.0
	Global.speed_limit_kmh = 50.0
	get_tree().reload_current_scene()

func _on_next_level_pressed():
	get_tree().paused = false
	Global.play = false
	Global.safe = false
	Global.speed_mult = 1.0
	Global.speed_limit_kmh = 50.0
	get_tree().change_scene_to_file(Global.next_level)

# Once one of the end screens (crash / did not reach home / you did it) is showing, no other one may replace it:
# a car that makes it home after another car crashed does not win, and so on.
func _another_screen_is_showing() -> bool:
	var level := get_parent()
	if level == null:
		return false
	for n in ["death", "not_home", "victory"]:
		var screen := level.get_node_or_null(n) as CanvasItem
		if screen != null and screen != self and screen.visible:
			return true
	return false

func _on_car_death():
	if visible or _another_screen_is_showing():
		return
	Sfx.play("sad" if name == "not_home" else "crash")
	_show_feedback()
	death.show()
	get_tree().paused = true
	
func _on_car_victory() -> void:
	if visible or _another_screen_is_showing():
		return
	Sfx.play("victory")
	var stars := Global.stars_for(Global.items_used(), Global.PAR[maxi(Global.LEVEL_PATHS.find(get_tree().current_scene.scene_file_path), 0)])
	Global.complete_level(get_tree().current_scene.scene_file_path, stars)
	_show_stars(stars)
	# No further level: hide the "next level" button.
	if has_node("next level"):
		get_node("next level").visible = Global.next_level != ""
	victory.show()
	get_tree().paused = true

# Victory screen: three stars between the heading and the buttons, gold for the ones earned.
func _show_stars(earned: int) -> void:
	var gold: Texture2D = load("res://assets/gold star.png")
	var gray: Texture2D = load("res://assets/gray star.png")
	for i in 3:
		var s := Sprite2D.new()
		s.texture = gold if i < earned else gray
		s.scale = Vector2(0.2, 0.2)
		s.position = Vector2((i - 1) * 80, 0)
		add_child(s)

# Failure screens (crash / did not reach home) can tell the player what went wrong. The level's
# root script may provide `death_feedback()` and `not_home_feedback()` returning a sentence.
const FEEDBACK_FONT := preload("res://assets/PixelOperator8-Bold.ttf")

func _show_feedback() -> void:
	var level := get_tree().current_scene
	if level != null and level.has_method("death_title") and name != "not_home" and has_node("Label"):
		var title: String = level.death_title()
		if title != "":
			var heading := get_node("Label") as Label
			heading.text = title
			heading.add_theme_font_size_override("font_size", 40)
	var method := "not_home_feedback" if name == "not_home" else "death_feedback"
	if level == null or not level.has_method(method):
		return
	var text: String = level.call(method)
	if text == "":
		return
	var label := Label.new()
	label.text = text
	label.position = Vector2(-400, -4)
	label.size = Vector2(800, 52)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FEEDBACK_FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("f5e6d3"))
	add_child(label)
