# Timed traffic signal (zip code 1, level 2). Drag it from the tray onto the grass beside the road the
# traffic comes down. Click it (without dragging) to choose how long the red light lasts: 2 or 5 seconds
# (it starts on 2). When play is pressed the red light counts down, then turns green. The level script
# makes the traffic wait for the red light.
extends Node2D

const FONT := preload("res://assets/PixelOperator8-Bold.ttf")
const SIDEBAR_X := 933.0
const CHOICES := [2, 5]
const DEFAULT_SECONDS := 2

@onready var label: Label = $Label           # the hover info box
@onready var light: AnimatedSprite2D = $AnimatedSprite2D

var seconds := DEFAULT_SECONDS               # the chosen red time
var remaining := float(DEFAULT_SECONDS)      # counts down while playing
@export var locked := false              # fixed on the map: it can be clicked to change the time but not dragged
var is_dragging := false
var draggable := false
var offset: Vector2
var grab_start := Vector2.ZERO
var count_label: Label
var chooser: VBoxContainer

func _ready() -> void:
	label.visible = false
	add_to_group("z1_signals")
	if locked:
		(load("res://scripts/click_outline.gd") as GDScript).attach(self)               # a white border: this placed sign can be clicked
	light.stop()
	light.frame = 0
	# the countdown number above the signal (top_level: not scaled with the signal)
	count_label = Label.new()
	count_label.top_level = true
	count_label.z_index = 50
	count_label.add_theme_font_override("font", FONT)
	count_label.add_theme_font_size_override("font_size", 18)
	count_label.add_theme_color_override("font_color", Color("fff4d6"))
	count_label.add_theme_color_override("font_outline_color", Color("1a1a1a"))
	count_label.add_theme_constant_override("outline_size", 6)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.size = Vector2(80, 24)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(count_label)
	# the 2 / 5 choice buttons
	# The choice buttons look exactly like the ones of the Level 3 speed limit sign: a column of big
	# buttons ("2", "5") at the sign, drawn at the sign's size (scale 0.3).
	chooser = VBoxContainer.new()
	chooser.top_level = true
	chooser.z_index = 100
	chooser.visible = false
	chooser.scale = Vector2(0.3, 0.3)
	chooser.size = Vector2(615, 450)
	for s in CHOICES:
		var b := Button.new()
		b.text = str(s)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 98)
		b.pressed.connect(_choose.bind(s))
		chooser.add_child(b)
	add_child(chooser)
	_refresh()

func is_placed() -> bool:
	return global_position.x < SIDEBAR_X

func is_green() -> bool:
	return Global.play and is_placed() and remaining <= 0.0

func _choose(s: int) -> void:
	if Global.play:
		return
	Sfx.play("click")
	seconds = s
	remaining = float(s)
	chooser.visible = false
	_refresh()

func _refresh() -> void:
	var p := global_position
	count_label.visible = is_placed() and not _level_over()
	count_label.position = Global.signal_count_pos(p)
	if Global.play and remaining <= 0.0:
		count_label.text = "GO"
	elif Global.play:
		count_label.text = "%ds" % ceili(remaining)
	else:
		count_label.text = "%ds" % seconds
	light.frame = 1 if (Global.play and is_placed() and remaining <= 0.0) else 0
	chooser.position = p

func _process(_delta: float) -> void:
	if not is_instance_valid(Global.drag_owner):
		Global.drag_owner = null
	if Global.play:
		chooser.visible = false
	if chooser.visible and Input.is_action_just_pressed("click"):
		if not Rect2(chooser.global_position, chooser.size * chooser.scale).has_point(get_global_mouse_position()) and not Global.mouse_over_area($Area2D):
			chooser.visible = false
	if Global.drag_owner == null:
		if locked:
			if Input.is_action_just_pressed("click") and not Global.play and Global.mouse_over_area($Area2D):
				label.visible = false
				chooser.visible = true
		elif Input.is_action_just_pressed("click") and not Global.play and Global.mouse_over_area($Area2D):
			Global.drag_owner = self
			offset = get_global_mouse_position() - global_position
			grab_start = global_position
			is_dragging = true
			label.visible = false
			chooser.visible = false
	elif Global.drag_owner == self:
		if Input.is_action_pressed("click"):
			var fp := Global.area_footprint(self, $Area2D)
			global_position = Global.drag_position(get_global_mouse_position(), offset, fp[0], fp[1], true)
		else:
			_end_drag()
	_refresh()

func _physics_process(delta: float) -> void:
	if Global.play and not get_tree().paused and is_placed() and remaining > 0.0:
		remaining = maxf(remaining - delta, 0.0)

func _end_drag() -> void:
	Global.drag_owner = null
	is_dragging = false
	# a click that did not move the signal opens the 2 / 5 buttons
	if is_placed() and global_position.distance_to(grab_start) < 4.0 and not Global.play:
		chooser.visible = true
	if draggable and not Global.mouse_over_area($Area2D):
		draggable = false
		scale /= Vector2(1.12, 1.12)
		label.visible = false

func _exit_tree() -> void:
	if Global.drag_owner == self:
		Global.drag_owner = null

func _on_area_2d_mouse_entered() -> void:
	if not is_dragging and not Global.play:
		scale *= Vector2(1.12, 1.12)
		draggable = true
		label.visible = not chooser.visible
	if is_dragging:
		label.visible = false

func _on_area_2d_mouse_exited() -> void:
	if not is_dragging and not Global.play:
		scale /= Vector2(1.12, 1.12)
		draggable = false
		label.visible = false

# True while a crash / victory / not-home screen is showing (the number must not show on top of it).
func _level_over() -> bool:
	var level := get_parent()
	for n in ["death", "not_home", "victory"]:
		var screen := level.get_node_or_null(n) as CanvasItem
		if screen != null and screen.visible:
			return true
	return false
