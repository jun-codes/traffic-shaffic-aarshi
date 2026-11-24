# Tutorial slide show, shown when a new game starts. Your car explains how the game works,
# one slide at a time, with typed-out dialogue and the game's own art.
# Next: click the button, Enter, Space or the right arrow. Back: left arrow. Skip: Esc.
extends Node2D

const FONT := preload("res://assets/PixelOperator8-Bold.ttf")
const TEAL := Color("0f6b66")
const CREAM := Color("f5e6d3")
const YELLOW := Color("ffd84a")
const GREEN := Color("1c8a5a")
const ASPHALT := Color("2b2830")
const CURB := Color("5b6165")

const T_FINISH := preload("res://assets/finish line.png")
const T_STOP := preload("res://assets/stop sign.png")
const T_GIVE := preload("res://assets/give way sign.png")
const T_NOSTOP := preload("res://assets/no stopping or standing.png")
const T_RIGHT := preload("res://assets/compulsory right turn.png")
const T_LEFT := preload("res://assets/compulsory left turn.png")
const T_UTURN := preload("res://assets/u-turn.png")
const T_PLAY := preload("res://assets/play.png")
const T_PAUSE := preload("res://assets/pause.png")
const T_RED := preload("res://assets/traffic red light.png")
const T_GREEN := preload("res://assets/traffic green light.png")
const T_GOLD := preload("res://assets/gold star.png")
const T_GRAY := preload("res://assets/gray star.png")
const T_CAR := preload("res://assets/carFrame1.png")
const T_GREY := preload("res://assets/cars/grey_frame_1.png")
# The car seen from the side in every colour.
const T_SIDE := {
	"red": preload("res://assets/carFrame1.png"),
	"cyan": preload("res://assets/cars/cyan_frame_1.png"),
	"purp": preload("res://assets/cars/purp_frame_1.png"),
}
const T_PED := preload("res://assets/npcs/red_front.png")

# Each slide: title, what the car says, and which picture to draw.
const SLIDES := [
	{"title": "WELCOME!", "pic": "car",
	 "text": "Hi! I'm your car. I know where home is, but I can't read the road. That's where you come in. Let me show you how this works."},
	{"title": "YOUR CAR", "pic": "colours",
	 "text": "I am the {COLOR} car, and I need to get home. All the other cars on the road are grey. Look out for them!"},
	{"title": "GET HOME", "pic": "finish",
	 "text": "Every level ends at a home tile like this one. Get me to it safely. No crashes, no wrong turns, and no running anybody over."},
	{"title": "THE ITEMS TRAY", "pic": "tray",
	 "text": "On the right side of every level is the items tray. It holds the road signs and signals you can use to guide me."},
	{"title": "PLACING SIGNS", "pic": "place",
	 "text": "Drag an item out of the tray to place it. The cars obey that sign wherever you put it, so where you put it matters. Too far away and nobody sees it."},
	{"title": "PRESS PLAY", "pic": "play",
	 "text": "When you are ready, press the play button in the top left corner. Once you press play you cannot control anything any more, so place your items first."},
	{"title": "EVERYONE OBEYS", "pic": "signals",
	 "text": "Signs and signals work on every car on the road, and pedestrians react to them as well. Think about who has to stop, and who has to go."},
	{"title": "FEWER SIGNS, MORE STARS", "pic": "stars",
	 "text": "Every level has a smallest number of items that solves it. Use just that many and you earn three stars. Every extra item costs you a star."},
	{"title": "GOOD LUCK!", "pic": "car",
	 "text": "There is more than one way to solve each level. Experiment, see what happens, and stay safe on the road!"},
]
const CHARS_PER_SECOND := 55.0

const BOX := Rect2(60, 410, 1032, 170)

var index := 0
var shown := 0.0               # characters of the dialogue typed so far
var hover := ""                # "next" / "back" / "skip" under the mouse
var time := 0.0

func _ready() -> void:
	get_tree().paused = false
	queue_redraw()

func _next_rect() -> Rect2:
	return Rect2(922, 592, 170, 36)

func _back_rect() -> Rect2:
	return Rect2(60, 592, 130, 36)

func _skip_rect() -> Rect2:
	return Rect2(1000, 20, 130, 36)

func _text() -> String:
	return String(SLIDES[index]["text"]).replace("{COLOR}", _skin_name())

func _typed() -> bool:
	return int(shown) >= _text().length()

func _go(step: int) -> void:
	var to := index + step
	if to < 0:
		return
	Sfx.play("click")
	if to >= SLIDES.size():
		_finish()
		return
	index = to
	shown = 0.0

func _finish() -> void:
	Global.start_level(0)

func _advance() -> void:
	if not _typed():
		shown = _text().length()       # first press shows the whole sentence
		Sfx.play("click")
	else:
		_go(1)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if _skip_rect().has_point(m):
			Sfx.play("click")
			_finish()
		elif _next_rect().has_point(m) or BOX.has_point(m):
			_advance()
		elif index > 0 and _back_rect().has_point(m):
			_go(-1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_RIGHT:
				_advance()
			KEY_LEFT:
				_go(-1)
			KEY_ESCAPE:
				_finish()

func _process(delta: float) -> void:
	time += delta
	if not _typed():
		shown += CHARS_PER_SECOND * delta
	var m := get_global_mouse_position()
	var h := ""
	if _skip_rect().has_point(m):
		h = "skip"
	elif _next_rect().has_point(m):
		h = "next"
	elif index > 0 and _back_rect().has_point(m):
		h = "back"
	if h != hover:
		hover = h
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if h != "" else Input.CURSOR_ARROW)
	queue_redraw()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

# --- drawing helpers ------------------------------------------------------------------------
func _centered(text: String, rect: Rect2, size: int, col: Color) -> void:
	var s := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(FONT, Vector2(rect.position.x + (rect.size.x - s.x) / 2.0, rect.position.y + (rect.size.y + s.y * 0.7) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _button(rect: Rect2, text: String, id: String) -> void:
	var r := rect.grow(4.0) if hover == id else rect
	draw_rect(r, CREAM)
	draw_rect(r, TEAL, false, 4)
	_centered(text, r, 14, TEAL)

func _pic(tex: Texture2D, center: Vector2, size: float) -> void:
	draw_texture_rect(tex, Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size)), false)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), GREEN)
	draw_rect(Rect2(0, 0, 1152, 648), TEAL, false, 16)
	var slide: Dictionary = SLIDES[index]
	_centered(slide["title"], Rect2(0, 40, 1152, 60), 40 if String(slide["title"]).length() <= 14 else 32, CREAM)
	_picture(slide["pic"])

	# The dialogue box: the car on the left, what it says on the right.
	draw_rect(BOX, CREAM)
	draw_rect(BOX, TEAL, false, 6)
	var portrait := Rect2(BOX.position.x + 18, BOX.position.y + 18, 134, 134)
	draw_rect(portrait, ASPHALT)
	draw_rect(portrait, TEAL, false, 4)
	draw_texture_rect(_car_tex(), Rect2(portrait.position + Vector2(3, 3), Vector2(128, 128)), false)
	draw_string(FONT, Vector2(BOX.position.x + 176, BOX.position.y + 36), "YOUR CAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GREEN)
	var typed := _text().substr(0, int(shown))
	_wrapped(typed, Vector2(BOX.position.x + 176, BOX.position.y + 70), 830.0, 18, 30.0, TEAL)
	if _typed() and int(time * 2.0) % 2 == 0:       # blinking "more" arrow
		draw_string(FONT, Vector2(BOX.end.x - 40, BOX.end.y - 18), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEAL)

	_centered("%d / %d" % [index + 1, SLIDES.size()], Rect2(450, 592, 252, 36), 14, CREAM)
	_button(_next_rect(), "START" if index == SLIDES.size() - 1 else "NEXT", "next")
	if index > 0:
		_button(_back_rect(), "BACK", "back")
	if index < SLIDES.size() - 1:
		_button(_skip_rect(), "SKIP", "skip")

# --- the pictures ----------------------------------------------------------------------------
func _road(rect: Rect2) -> void:
	draw_rect(rect, ASPHALT)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 10), CURB)
	draw_rect(Rect2(rect.position.x, rect.end.y - 10, rect.size.x, 10), CURB)
	var x := rect.position.x + 14
	while x < rect.end.x - 40:
		draw_rect(Rect2(x, rect.get_center().y - 4, 44, 8), Color("f2f2f2"))
		x += 78

func _picture(id: String) -> void:
	match id:
		"car":
			# The car, bobbing a little.
			var bob := sin(time * 3.0) * 6.0
			draw_texture_rect(_car_tex(), Rect2(436, 112 + bob, 280, 280), false)
		"colours":
			# you (in the colour picked on the customise screen) and everybody else (grey)
			var name_up: String = _skin_name().to_upper()
			draw_texture_rect(_car_tex(), Rect2(176, 120, 300, 300), false)
			_centered("YOU: " + name_up, Rect2(176, 100, 300, 30), 18, CREAM)
			draw_texture_rect(T_GREY, Rect2(676, 120, 300, 300), false)
			_centered("EVERYONE ELSE: GREY", Rect2(676, 100, 300, 30), 18, CREAM)
		"finish":
			_road(Rect2(150, 200, 852, 170))
			var h := 0.42
			draw_set_transform(Vector2(780, 285), PI / 2.0, Vector2(h, h))
			draw_texture(T_FINISH, -T_FINISH.get_size() / 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_texture_rect(T_CAR, Rect2(240 + fmod(time * 90.0, 330.0), 215, 140, 140), false)
		"tray":
			var tray := Rect2(436, 108, 280, 292)
			draw_rect(tray, Color("0b0b12"))
			draw_rect(tray, TEAL, false, 6)
			_centered("ITEMS", Rect2(tray.position.x, tray.position.y + 6, tray.size.x, 36), 24, CREAM)
			var signs := [T_STOP, T_RIGHT, T_GIVE, T_NOSTOP, T_UTURN, T_LEFT]
			for i in signs.size():
				# every sign stays inside the tray: two columns, three rows under the heading
				var c := Vector2(tray.position.x + 80 + (i % 2) * 120, tray.position.y + 94 + (i / 2) * 76)
				_pic(signs[i], c, 62)
		"place":
			draw_rect(Rect2(190, 112, 772, 288), Color("167a4e"))
			_road(Rect2(190, 230, 772, 150))
			# the small tray on the right: the sign is dragged out of it and placed beside the road
			var tray2 := Rect2(850, 120, 100, 100)
			draw_rect(tray2, Color("0b0b12"))
			draw_rect(tray2, TEAL, false, 4)
			var ct := fmod(time, 6.5)
			var k := smoothstep(0.3, 1.9, ct)
			var sign_pos := Vector2(900, 170).lerp(Vector2(430, 165), k)
			_pic(T_STOP, sign_pos, 64)
			# then the car drives up and obeys it
			var car_x := 190.0 + clampf((ct - 2.2) / 1.6, 0.0, 1.0) * 120.0
			draw_texture_rect(_car_tex(), Rect2(car_x, 245, 120, 120), false)
		"play":
			var pulse := 1.0 + 0.08 * sin(time * 5.0)
			_pic(T_PLAY, Vector2(380, 245), 200.0 * pulse)
			_centered("PRESS PLAY", Rect2(240, 350, 280, 30), 16, CREAM)
			_pic(T_PAUSE, Vector2(780, 245), 180)
			_centered("THEN NOTHING CAN BE CHANGED", Rect2(560, 350, 440, 30), 14, CREAM)
		"signals":
			var road := Rect2(150, 230, 852, 150)
			_road(road)
			var ct2 := fmod(time, 9.0)
			# a small traffic light on the grass beside the road: red while the car waits, then green
			var green := ct2 > 4.6
			draw_texture_rect(T_GREEN if green else T_RED, Rect2(458, 100, 42, 122), false)
			# the car stops in front of the light, then drives on
			var cx := 150.0
			if ct2 < 2.4:
				cx = lerpf(150.0, 330.0, ct2 / 2.4)
			elif ct2 < 5.2:
				cx = 330.0
			else:
				cx = 330.0 + (ct2 - 5.2) * 180.0
			draw_texture_rect(_car_tex(), Rect2(cx, 245, 120, 120), false)
			# a pedestrian crosses while the car waits
			var py := 170.0
			if ct2 >= 2.4 and ct2 < 4.4:
				py = lerpf(170.0, 470.0, (ct2 - 2.4) / 2.0)
			elif ct2 >= 4.4:
				py = 470.0
			draw_texture_rect(T_PED, Rect2(552, py - 50, 37, 100), false)
		"stars":
			var rows := [
				[3, "JUST THE ITEMS YOU NEED"],
				[2, "ONE EXTRA ITEM"],
				[1, "TWO OR MORE EXTRA"],
			]
			for r in rows.size():
				var y := 112.0 + r * 98.0
				for i in 3:
					draw_texture_rect(T_GOLD if i < rows[r][0] else T_GRAY, Rect2(250 + i * 92, y, 88, 88), false)
				_left(rows[r][1], Rect2(560, y, 460, 88), 18, CREAM)

func _left(text: String, rect: Rect2, size: int, col: Color) -> void:
	var s := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(FONT, Vector2(rect.position.x, rect.position.y + (rect.size.y + s.y * 0.7) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# Draws text word-wrapped to `width`, `line_height` pixels between the lines.
func _wrapped(text: String, pos: Vector2, width: float, size: int, line_height: float, col: Color) -> void:
	var line := ""
	var y := pos.y
	for word in text.split(" "):
		var trial: String = word if line == "" else line + " " + word
		if FONT.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			draw_string(FONT, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			y += line_height
			line = word
		else:
			line = trial
	if line != "":
		draw_string(FONT, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# The car in the player's colour (the car seen from the side, picked on the customise screen).
func _car_tex() -> Texture2D:
	return T_SIDE.get(Global.car_skin, T_CAR)

# Name of the picked colour ("red", "cyan", "purple").
func _skin_name() -> String:
	for s in Global.CAR_SKINS:
		if s[0] == Global.car_skin:
			return str(s[1]).to_lower()
	return "red"
