# Autoload with the shared UI polish:
# - every Button gets a "clickable" hand cursor and, if it shows text or an icon, grows slightly
#   on hover (the pause button never grows, and only its icon counts as clickable for the cursor);
# - in the levels the hand cursor also shows over draggable items.
extends Node

const HOVER_SCALE := 1.08

var _hand := false

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	var b := n as Button
	if b == null:
		return
	if b.name != "pause":      # the pause button's cursor is handled by its icon in _process
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(_clicked.bind(b))
	b.mouse_entered.connect(_grow.bind(b, HOVER_SCALE))
	b.mouse_exited.connect(_grow.bind(b, 1.0))

# Click sound of a button. The play button is silent once the level is running (it can no
# longer be pressed to do anything then).
func _clicked(b: Button) -> void:
	if b.name == "pause" and Global.play:
		return
	Sfx.play("click")

func _grow(b: Button, s: float) -> void:
	if b.name == "pause" or (b.text == "" and b.icon == null):
		return          # no scaling for the pause button or invisible click areas
	b.pivot_offset = b.size / 2.0
	var t := b.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(b, "scale", Vector2(s, s), 0.08)

# A draggable item: a Node2D with an info-box "Label" and a sprite child.
func _is_item(n: Node) -> bool:
	return n is Node2D and n.has_node("Label") and (n.has_node("Sprite2D") or n.has_node("AnimatedSprite2D"))

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pause := scene.find_child("pause", true, false) as Button
	if pause == null:
		return                                  # menus handle their own cursor
	var mouse: Vector2 = scene.get_global_mouse_position()
	var hot := false

	if pause.icon != null:
		var size := pause.icon.get_size() * pause.scale
		var center := pause.global_position + pause.size * pause.scale / 2.0
		hot = Rect2(center - size / 2.0, size).has_point(mouse)

	if not hot and not Global.play:
		for n in scene.find_children("*", "Node2D", true, false):
			if n.is_in_group("signs") and n.has_method("_hit"):          # Level 2 sign
				hot = n._hit(mouse)
			elif _is_item(n):
				var area := n.get_node_or_null("Area2D") as Area2D
				hot = area != null and Global.mouse_over_area(area)
			if hot:
				break

	# Set the cursor directly: the big invisible pause button would otherwise keep the arrow.
	if hot:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND)
	elif _hand:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	_hand = hot
