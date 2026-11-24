# Customise screen: a big car facing up on the left, the colour options on the right. Picking
# a colour changes the car and is saved; it is used for the player's car in every level.
# Mouse: click an option. Keyboard: up/down, Enter. Esc or BACK returns to the menu.
extends Node2D

const FONT := preload("res://assets/PixelOperator8-Bold.ttf")
const TEAL := Color("0f6b66")
const CREAM := Color("f5e6d3")
const YELLOW := Color("ffd84a")
# The car of every colour, seen from above and facing up (the last frame of its animation).
const PICTURES := {
	"red": preload("res://assets/car frame 5.png"),
	"cyan": preload("res://assets/cars/cyan_frame_5.png"),
	"purp": preload("res://assets/cars/purp_frame_5.png"),
}
const SWATCH := {
	"red": Color("6e0a2e"),
	"cyan": Color("0f5f73"),
	"purp": Color("4a2c78"),
}
const CAR_CARD := Rect2(130, 150, 400, 470)
const OPTION_SIZE := Vector2(400, 96)
const OPTION_X := 620.0
const OPTION_Y := 215.0
const OPTION_GAP := 26.0

var rects: Array[Rect2] = []
var focus := 0          # option the keyboard / mouse is on
var hover_i := -1
var hover_back := false

func _ready() -> void:
	get_tree().paused = false
	for i in Global.CAR_SKINS.size():
		rects.append(Rect2(OPTION_X, OPTION_Y + i * (OPTION_SIZE.y + OPTION_GAP), OPTION_SIZE.x, OPTION_SIZE.y))
		if Global.CAR_SKINS[i][0] == Global.car_skin:
			focus = i
	queue_redraw()

func _back_rect() -> Rect2:
	return Rect2(20, 20, 150, 44)

func _hover(pos: Vector2) -> int:
	for i in rects.size():
		if rects[i].has_point(pos):
			return i
	return -1

func _choose(i: int) -> void:
	Sfx.play("click")
	focus = i
	Global.set_car_skin(Global.CAR_SKINS[i][0])
	queue_redraw()

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/intro.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		var i := _hover(m)
		if i >= 0:
			_choose(i)
		elif _back_rect().has_point(m):
			Sfx.play("click")
			_back()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_DOWN, KEY_RIGHT, KEY_S, KEY_D:
				focus = mini(focus + 1, rects.size() - 1)
				queue_redraw()
			KEY_UP, KEY_LEFT, KEY_W, KEY_A:
				focus = maxi(focus - 1, 0)
				queue_redraw()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_choose(focus)
			KEY_ESCAPE:
				_back()

func _process(_delta: float) -> void:
	var m := get_global_mouse_position()
	var i := _hover(m)
	var b := _back_rect().has_point(m)
	if i != hover_i or b != hover_back:
		hover_i = i
		hover_back = b
		if i >= 0:
			focus = i
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if (i >= 0 or b) else Input.CURSOR_ARROW)
		queue_redraw()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _centered(text: String, rect: Rect2, size: int, col: Color) -> void:
	var s := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(FONT, Vector2(rect.position.x + (rect.size.x - s.x) / 2.0, rect.position.y + (rect.size.y + s.y * 0.7) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _left(text: String, rect: Rect2, size: int, col: Color) -> void:
	var s := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(FONT, Vector2(rect.position.x, rect.position.y + (rect.size.y + s.y * 0.7) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color("1c8a5a"))
	draw_rect(Rect2(0, 0, 1152, 648), TEAL, false, 16)
	_centered("CUSTOMISE", Rect2(0, 60, 1152, 70), 56, CREAM)

	# The car, facing up, in the chosen colour.
	var tex: Texture2D = PICTURES[Global.car_skin]
	var size := 480.0                       # 1.5 x the 320 px picture: every art pixel is 15 px
	var top_left := Vector2(CAR_CARD.get_center().x - size / 2.0, CAR_CARD.get_center().y - size / 2.0 + 8.0)
	draw_texture_rect(tex, Rect2(top_left, Vector2(size, size)), false)

	# The colour options.
	for i in rects.size():
		var id: String = Global.CAR_SKINS[i][0]
		var r := rects[i].grow(6.0) if i == hover_i else rects[i]
		var chosen: bool = id == Global.car_skin
		draw_rect(r, CREAM)
		draw_rect(r, TEAL, false, 6)
		var swatch := Rect2(r.position.x + 22, r.position.y + (r.size.y - 52) / 2.0, 52, 52)
		draw_rect(swatch, SWATCH[id])
		draw_rect(swatch, TEAL, false, 4)
		_left(Global.CAR_SKINS[i][1], Rect2(r.position.x + 100, r.position.y, 200, r.size.y), 26, TEAL)
		if chosen:
			_left("IN USE", Rect2(r.position.x + 296, r.position.y, 100, r.size.y), 14, Color("1c8a5a"))
			draw_rect(r.grow(10), YELLOW, false, 6)
		elif i == focus:
			draw_rect(r.grow(10), Color(YELLOW.r, YELLOW.g, YELLOW.b, 0.55), false, 4)
	var br := _back_rect().grow(4.0) if hover_back else _back_rect()
	draw_rect(br, CREAM)
	draw_rect(br, TEAL, false, 4)
	_centered("BACK", br, 16, TEAL)
