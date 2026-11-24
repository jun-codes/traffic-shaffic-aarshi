# "Zip code 1" level picker. Level 2 / 3 are greyed out until every earlier level is finished.
# Mouse: click a level. Keyboard: left/right (or up/down) to move the selector, Enter/Space to open.
extends Node2D

const FONT := preload("res://assets/PixelOperator8-Bold.ttf")
const TEAL := Color("0f6b66")
const CREAM := Color("f5e6d3")
const GREY := Color("8a8a8a")
const GOLD := preload("res://assets/gold star.png")
const GRAY := preload("res://assets/gray star.png")
const SIZE := Vector2(180, 150)
const GAP := 30.0

var rects: Array[Rect2] = []
var selected := 0
var hover_i := -1          # level box under the mouse (open ones only)
var hover_back := false

func _ready() -> void:
	get_tree().paused = false
	var n: int = Global.LEVEL_PATHS.size()
	var x0 := (1152.0 - (n * SIZE.x + (n - 1) * GAP)) / 2.0
	for i in n:
		rects.append(Rect2(x0 + i * (SIZE.x + GAP), 270, SIZE.x, SIZE.y))
	# Start on the first level that is open but not finished yet.
	for i in n:
		if Global.is_unlocked(i) and not Global.levels_done[i]:
			selected = i
			break
	queue_redraw()

func _hover(pos: Vector2) -> int:
	for i in rects.size():
		if rects[i].has_point(pos):
			return i
	return -1

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := _hover(get_global_mouse_position())
		if i >= 0 and Global.is_unlocked(i) and i != selected:
			selected = i
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _hover(get_global_mouse_position())
		if i >= 0 and Global.is_unlocked(i):
			Sfx.play("click")
			Global.start_level(i)
		elif _back_rect().has_point(get_global_mouse_position()):
			Sfx.play("click")
			_back()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT, KEY_DOWN, KEY_D, KEY_S:
				_move(1)
			KEY_LEFT, KEY_UP, KEY_A, KEY_W:
				_move(-1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				Sfx.play("click")
				Global.start_level(selected)
			KEY_ESCAPE:
				_back()

func _move(d: int) -> void:
	var i := selected + d
	while i >= 0 and i < rects.size():
		if Global.is_unlocked(i):
			selected = i
			queue_redraw()
			return
		i += d

func _back_rect() -> Rect2:
	return Rect2(20, 20, 150, 44)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/intro.tscn")

func _centered(text: String, rect: Rect2, size: int, col: Color) -> void:
	var s := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(FONT, Vector2(rect.position.x + (rect.size.x - s.x) / 2.0, rect.position.y + (rect.size.y + s.y * 0.7) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color("1c8a5a"))
	draw_rect(Rect2(0, 0, 1152, 648), Color("0f6b66"), false, 16)
	_centered("ZIP CODE 1", Rect2(0, 90, 1152, 90), 56, CREAM)
	for i in rects.size():
		var open: bool = Global.is_unlocked(i)
		var r := rects[i].grow(6.0) if i == hover_i else rects[i]
		draw_rect(r, CREAM if open else GREY)
		draw_rect(r, TEAL if open else Color("555555"), false, 6)
		_centered("LEVEL %d" % (i + 1), r, 22, TEAL if open else Color("555555"))
		if not open:
			_centered("LOCKED", Rect2(r.position.x, r.position.y + 90, r.size.x, 30), 14, Color("555555"))
		elif Global.levels_done[i]:
			for k in 3:
				var tex: Texture2D = GOLD if k < Global.level_stars[i] else GRAY
				draw_texture_rect(tex, Rect2(r.position.x + r.size.x / 2.0 - 63 + k * 44, r.position.y + 88, 38, 38), false)
		if open and i == selected:
			draw_rect(r.grow(10), Color("ffd84a"), false, 6)
	var br := _back_rect().grow(4.0) if hover_back else _back_rect()
	draw_rect(br, CREAM)
	draw_rect(br, TEAL, false, 4)
	_centered("BACK", br, 16, TEAL)

func _process(_delta: float) -> void:
	var m := get_global_mouse_position()
	var i := _hover(m)
	if i >= 0 and not Global.is_unlocked(i):
		i = -1
	var b := _back_rect().has_point(m)
	if i != hover_i or b != hover_back:
		hover_i = i
		hover_back = b
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if (i >= 0 or b) else Input.CURSOR_ARROW)
		queue_redraw()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
