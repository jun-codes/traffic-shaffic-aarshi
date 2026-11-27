# The five cutscenes shown after NEW GAME, one after the other, before the tutorial. The first picture is just there
# (no fade); between the pictures there is a fade out to black and a fade in, and the last one fades out to black. Click / Enter / Space (or the NEXT
# button) starts the transition to the next picture right away; Esc (or the SKIP button) skips the rest.
extends Node2D

const PICTURES := [
	preload("res://assets/cutscenes/cutscene_1.png"),
	preload("res://assets/cutscenes/cutscene_2.png"),
	preload("res://assets/cutscenes/cutscene_3.png"),
	preload("res://assets/cutscenes/cutscene_4.png"),
	preload("res://assets/cutscenes/cutscene_5.png"),
]
const FONT := preload("res://assets/PixelOperator8-Bold.ttf")
const NEXT_SCENE := "res://scenes/tutorial.tscn"
const FADE := 0.9              # seconds to fade in / out between the pictures
const HOLD := 4.5              # seconds a picture stays

var picture: TextureRect
var cover: ColorRect           # black, in front of the picture: its alpha is the fade
var next_button: Button
var skip_button: Button
var index := 0
var tween: Tween
var leaving := false           # the fade out of the current picture has started

func _ready() -> void:
	get_tree().paused = false
	var layer := CanvasLayer.new()
	add_child(layer)
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE           # (a ColorRect swallows clicks by default)
	layer.add_child(back)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(picture)
	# Small NEXT and SKIP buttons in the bottom right, in the style of the tutorial buttons (cream with a teal border).
	next_button = _make_button("NEXT", Rect2(894, 580, 96, 30), _leave)
	skip_button = _make_button("SKIP", Rect2(1000, 580, 96, 30), _skip_all)
	layer.add_child(next_button)
	layer.add_child(skip_button)
	cover = ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cover)
	_show(0)

func _make_button(text: String, rect: Rect2, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 14)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("f5e6d3")
		sb.border_color = Color("0f6b66")
		sb.set_border_width_all(4)
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color("0f6b66"))
	b.pressed.connect(action)
	return b

func _show(i: int, fade := true) -> void:
	index = i
	leaving = false
	picture.texture = PICTURES[i]
	if tween != null:
		tween.kill()
	tween = create_tween()
	if i == 0 or not fade:
		cover.color.a = 0.0                                     # the first picture, and a picture you clicked to, are simply there
	else:
		tween.tween_property(cover, "color:a", 0.0, FADE)         # fade in from black
	tween.tween_interval(HOLD)
	tween.tween_callback(_leave)

# Fade out to black, then the next picture (or the tutorial after the last one).
func _leave() -> void:
	if leaving:
		return
	leaving = true
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_property(cover, "color:a", 1.0, FADE)
	tween.tween_callback(_next)

func _next() -> void:
	if index + 1 < PICTURES.size():
		_show(index + 1)
	else:
		get_tree().change_scene_to_file(NEXT_SCENE)

func _skip_all() -> void:
	if tween != null:
		tween.kill()
	get_tree().change_scene_to_file(NEXT_SCENE)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_viewport().get_mouse_position()
		if next_button.get_global_rect().has_point(m) or skip_button.get_global_rect().has_point(m):
			return                                          # the buttons handle their own clicks
		_leave()                                          # the transition starts on the click itself
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_skip_all()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_RIGHT]:
			_leave()
