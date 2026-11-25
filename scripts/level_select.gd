# Level picker: one page per zip code (3 levels each). The arrows (or Left / Right keys) go to the next / previous
# zip code. A level is greyed out until every made level before it is finished; levels that are not made yet
# ("" in Global.LEVEL_PATHS) say COMING SOON and do nothing.
# Mouse: click a level or an arrow. Keyboard: left/right (or up/down) move the selector (and change page),
# Enter/Space open the level, Esc goes back to the menu.
extends Node2D

const FONT := preload("res://assets/PixelOperator8-Bold.ttf")
const TEAL := Color("0f6b66")
const CREAM := Color("f5e6d3")
const GREY := Color("8a8a8a")
const YELLOW := Color("ffd84a")
const GOLD := preload("res://assets/gold star.png")
const GRAY := preload("res://assets/gray star.png")
const SIZE := Vector2(180, 150)
const GAP := 30.0
const BOX_Y := 270.0

var rects: Array[Rect2] = []        # the three level boxes of a page (index 0..2)
var page := 0                       # zip code shown (0-based)
var selected := 0
var hover_i := -1                   # level box under the mouse (open ones only), as a level index
var hover_back := false
var hover_arrow := 0                # -1 previous page arrow, 1 next page arrow, 0 none

func _pages() -> int:
	return int(ceil(float(Global.LEVEL_PATHS.size()) / Global.LEVELS_PER_ZIP))

func _ready() -> void:
	get_tree().paused = false
	var per: int = Global.LEVELS_PER_ZIP
	var x0 := (1152.0 - (per * SIZE.x + (per - 1) * GAP)) / 2.0
	for k in per:
		rects.append(Rect2(x0 + k * (SIZE.x + GAP), BOX_Y, SIZE.x, SIZE.y))
	# Start on the first level that is open but not finished yet (on its zip code page).
	for i in Global.LEVEL_PATHS.size():
		if Global.is_unlocked(i) and not Global.levels_done[i]:
			selected = i
			break
	page = selected / Global.LEVELS_PER_ZIP
	queue_redraw()

func _level_at(pos: Vector2) -> int:
	for k in rects.size():
		if rects[k].has_point(pos):
			var i: int = page * Global.LEVELS_PER_ZIP + k
			if i < Global.LEVEL_PATHS.size():
				return i
	return -1

func _arrow_rect(dir: int) -> Rect2:
	return Rect2(60, 295, 90, 100) if dir < 0 else Rect2(1002, 295, 90, 100)

func _arrow_at(pos: Vector2) -> int:
	if page > 0 and _arrow_rect(-1).has_point(pos):
		return -1
	if page < _pages() - 1 and _arrow_rect(1).has_point(pos):
		return 1
	return 0

func _go_page(d: int) -> void:
	page = clampi(page + d, 0, _pages() - 1)
	# the selector goes to an open level of the new page, if there is one
	var first: int = page * Global.LEVELS_PER_ZIP
	for k in Global.LEVELS_PER_ZIP:
		if Global.is_unlocked(first + k):
			selected = first + k
			break
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := _level_at(get_global_mouse_position())
		if i >= 0 and Global.is_unlocked(i) and i != selected:
			selected = i
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		var i := _level_at(m)
		var a := _arrow_at(m)
		if i >= 0 and Global.is_unlocked(i):
			Sfx.play("click")
			Global.start_level(i)
		elif a != 0:
			Sfx.play("click")
			_go_page(a)
		elif _back_rect().has_point(m):
			Sfx.play("click")
			_back()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S:
				_move(1)
			KEY_LEFT, KEY_A, KEY_UP, KEY_W:
				_move(-1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if Global.is_unlocked(selected):
					Sfx.play("click")
					Global.start_level(selected)
			KEY_ESCAPE:
				_back()

# Moves the selector to the next open level in that direction (the page follows it).
func _move(d: int) -> void:
	var i := selected + d
	while i >= 0 and i < Global.LEVEL_PATHS.size():
		if Global.is_unlocked(i):
			selected = i
			page = i / Global.LEVELS_PER_ZIP
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

func _draw_arrow(dir: int) -> void:
	var r := _arrow_rect(dir)
	if hover_arrow == dir:
		r = r.grow(5.0)
	draw_rect(r, CREAM)
	draw_rect(r, TEAL, false, 5)
	var c := r.get_center()
	var s := 22.0 * dir
	draw_colored_polygon(PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s * 0.6, -26), c + Vector2(-s * 0.6, 26)]), TEAL)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color("1c8a5a"))
	draw_rect(Rect2(0, 0, 1152, 648), TEAL, false, 16)
	_centered("ZIP CODE %d" % (page + 1), Rect2(0, 90, 1152, 90), 56, CREAM)
	for k in rects.size():
		var i: int = page * Global.LEVELS_PER_ZIP + k
		if i >= Global.LEVEL_PATHS.size():
			continue
		var open: bool = Global.is_unlocked(i)
		var r := rects[k].grow(6.0) if i == hover_i else rects[k]
		draw_rect(r, CREAM if open else GREY)
		draw_rect(r, TEAL if open else Color("555555"), false, 6)
		var title_rect := Rect2(r.position.x, r.position.y - 14, r.size.x, r.size.y) if open and Global.levels_done[i] else r
		_centered("LEVEL %d" % (i + 1), title_rect, 22, TEAL if open else Color("555555"))
		if not Global.level_exists(i):
			_centered("COMING SOON", Rect2(r.position.x, r.position.y + 90, r.size.x, 30), 12, Color("555555"))
		elif not open:
			_centered("LOCKED", Rect2(r.position.x, r.position.y + 90, r.size.x, 30), 14, Color("555555"))
		elif Global.levels_done[i]:
			for s in 3:
				var tex: Texture2D = GOLD if s < Global.level_stars[i] else GRAY
				draw_texture_rect(tex, Rect2(r.position.x + r.size.x / 2.0 - 63 + s * 44, r.position.y + 88, 38, 38), false)
		if open and i == selected:
			draw_rect(r.grow(10), YELLOW, false, 6)
	if page > 0:
		_draw_arrow(-1)
	if page < _pages() - 1:
		_draw_arrow(1)
	# The stars earned so far (top right).
	var total := str(Global.total_stars())
	var tw := FONT.get_string_size(total, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(FONT, Vector2(1112 - 48 - tw - 12, 59), total, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, CREAM)
	draw_texture_rect(GOLD, Rect2(1112 - 48, 22, 44, 44), false)
	var br := _back_rect().grow(4.0) if hover_back else _back_rect()
	draw_rect(br, CREAM)
	draw_rect(br, TEAL, false, 4)
	_centered("BACK", br, 16, TEAL)

func _process(_delta: float) -> void:
	var m := get_global_mouse_position()
	var i := _level_at(m)
	if i >= 0 and not Global.is_unlocked(i):
		i = -1
	var b := _back_rect().has_point(m)
	var a := _arrow_at(m)
	if i != hover_i or b != hover_back or a != hover_arrow:
		hover_i = i
		hover_back = b
		hover_arrow = a
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if (i >= 0 or b or a != 0) else Input.CURSOR_ARROW)
		queue_redraw()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
