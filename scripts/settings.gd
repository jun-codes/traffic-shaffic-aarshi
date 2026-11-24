# Settings screen: two sliders, the volume of the sound effects and the volume of the music.
# Drag a slider or click on it. Keyboard: up / down choose the slider, left / right change it,
# Esc goes back. The values are saved.
extends Node2D

const FONT := preload("res://assets/PixelOperator8-Bold.ttf")
const TEAL := Color("0f6b66")
const CREAM := Color("f5e6d3")
const YELLOW := Color("ffd84a")
const GREEN := Color("1c8a5a")
const CARD := Rect2(176, 150, 800, 360)
const TRACK_X := 236.0
const TRACK_W := 680.0
const ROW_Y := [180.0, 340.0]                 # top of each slider block inside the card
const STEP := 0.05
const TITLES := ["EFFECTS VOLUME", "MUSIC VOLUME"]

var dragging := -1          # slider being dragged (-1 = none)
var focus := 0              # slider the keyboard changes
var hover_slider := -1
var hover_back := false

func _back_rect() -> Rect2:
	return Rect2(20, 20, 150, 44)

func _value(i: int) -> float:
	return Global.sfx_volume if i == 0 else Global.music_volume

func _set_value(i: int, v: float) -> void:
	v = snappedf(clampf(v, 0.0, 1.0), 0.01)
	if i == 0:
		Global.set_sfx_volume(v)
	else:
		Global.set_music_volume(v)
	queue_redraw()

func _track(i: int) -> Rect2:
	return Rect2(TRACK_X, ROW_Y[i] + 70.0, TRACK_W, 26.0)

func _handle_rect(i: int) -> Rect2:
	var t := _track(i)
	var x := t.position.x + t.size.x * _value(i)
	return Rect2(x - 16, t.position.y - 14, 32, t.size.y + 28)

func _volume_at(i: int, x: float) -> float:
	return clampf((x - TRACK_X) / TRACK_W, 0.0, 1.0)

func _slider_at(m: Vector2) -> int:
	for i in 2:
		if _track(i).grow_individual(10, 22, 10, 22).has_point(m) or _handle_rect(i).has_point(m):
			return i
	return -1

func _ready() -> void:
	get_tree().paused = false
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if event.pressed:
			var i := _slider_at(m)
			if i >= 0:
				dragging = i
				focus = i
				_set_value(i, _volume_at(i, m.x))
			elif _back_rect().has_point(m):
				Sfx.play("click")
				_back()
		elif dragging >= 0:
			var done := dragging
			dragging = -1
			Global.save_settings()
			if done == 0:
				Sfx.play("click")             # so the new effects volume can be heard
	elif event is InputEventMouseMotion and dragging >= 0:
		_set_value(dragging, _volume_at(dragging, get_global_mouse_position().x))
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				focus = 0
				queue_redraw()
			KEY_DOWN, KEY_S:
				focus = 1
				queue_redraw()
			KEY_LEFT, KEY_A:
				_set_value(focus, _value(focus) - STEP)
				Global.save_settings()
				if focus == 0:
					Sfx.play("click")
			KEY_RIGHT, KEY_D:
				_set_value(focus, _value(focus) + STEP)
				Global.save_settings()
				if focus == 0:
					Sfx.play("click")
			KEY_ESCAPE:
				_back()

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/intro.tscn")

func _process(_delta: float) -> void:
	var m := get_global_mouse_position()
	var h := _slider_at(m)
	var b := _back_rect().has_point(m)
	if h != hover_slider or b != hover_back:
		hover_slider = h
		hover_back = b
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if (h >= 0 or b) else Input.CURSOR_ARROW)
		queue_redraw()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _centered(text: String, rect: Rect2, size: int, col: Color) -> void:
	var s := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(FONT, Vector2(rect.position.x + (rect.size.x - s.x) / 2.0, rect.position.y + (rect.size.y + s.y * 0.7) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), GREEN)
	draw_rect(Rect2(0, 0, 1152, 648), TEAL, false, 16)
	_centered("SETTINGS", Rect2(0, 50, 1152, 70), 56, CREAM)

	draw_rect(CARD, CREAM)
	draw_rect(CARD, TEAL, false, 6)
	for i in 2:
		var top: float = ROW_Y[i]
		var picked: bool = (focus == i and dragging < 0) or dragging == i
		draw_string(FONT, Vector2(TRACK_X, top + 36.0), TITLES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, TEAL)
		var pct := "%d%%" % roundi(_value(i) * 100.0)
		var pct_w := FONT.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		draw_string(FONT, Vector2(TRACK_X + TRACK_W - pct_w, top + 38.0), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, GREEN)
		# the slider: dark bar, the filled part in yellow, a square handle
		var t := _track(i)
		draw_rect(t, Color("1f1d24"))
		draw_rect(Rect2(t.position, Vector2(t.size.x * _value(i), t.size.y)), YELLOW)
		draw_rect(t, TEAL, false, 4)
		var hr := _handle_rect(i).grow(3.0) if (hover_slider == i or dragging == i) else _handle_rect(i)
		draw_rect(hr, CREAM)
		draw_rect(hr, YELLOW if picked else TEAL, false, 4)
		_centered("0", Rect2(t.position.x - 30, t.end.y + 18, 60, 24), 14, TEAL)
		_centered("100", Rect2(t.end.x - 30, t.end.y + 18, 60, 24), 14, TEAL)

	var br := _back_rect().grow(4.0) if hover_back else _back_rect()
	draw_rect(br, CREAM)
	draw_rect(br, TEAL, false, 4)
	_centered("BACK", br, 16, TEAL)
