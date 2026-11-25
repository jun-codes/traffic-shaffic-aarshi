# Encyclopedia: every sign of the game with the same description as the hover box in the item tray, always visible.
# Only the signs that have been unlocked (their level was opened) show their picture, name and description. The
# others are a flat grey silhouette with its outline and a ? inside, "???" as the name and no description.
# Esc or BACK returns to the menu.
extends Node2D

const FONT := preload("res://assets/PixelOperator8-Bold.ttf")
const TEAL := Color("0f6b66")
const CREAM := Color("f5e6d3")
const INK := Color("1d2a2a")
const GREY := Color("8a8a8a")
const DARK_GREY := Color("555555")
const OUTLINE := preload("res://scripts/click_outline.gd")

const CARD := Vector2(510, 92)
const COL_X := [50.0, 592.0]
const TOP := 112.0
const ROW_GAP := 100.0
const PIC := 72.0

var infos: Array = []          # per sign: {title, text, tex, outline}
var hover_back := false

func _ready() -> void:
	get_tree().paused = false
	for path in SignIntro.SIGN_LIST:
		var info: Dictionary = SignIntro._read_sign(path)
		if info["tex"] != null:
			var tex: Texture2D = info["tex"]
			var k := minf(PIC / tex.get_size().x, PIC / tex.get_size().y)
			info["k"] = k
			info["outline"] = OUTLINE.trace(tex, k, 2)
			info["flat"] = OUTLINE.silhouette(tex, k, Color(0.5, 0.5, 0.5))
		infos.append(info)
	queue_redraw()

func _back_rect() -> Rect2:
	return Rect2(20, 20, 150, 44)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/intro.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _back_rect().has_point(get_global_mouse_position()):
			Sfx.play("click")
			_back()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_back()

func _process(_delta: float) -> void:
	var b := _back_rect().has_point(get_global_mouse_position())
	if b != hover_back:
		hover_back = b
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if b else Input.CURSOR_ARROW)
		queue_redraw()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _centered(text: String, rect: Rect2, size: int, col: Color) -> void:
	var s := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(FONT, Vector2(rect.position.x + (rect.size.x - s.x) / 2.0, rect.position.y + (rect.size.y + s.y * 0.7) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color("1c8a5a"))
	draw_rect(Rect2(0, 0, 1152, 648), TEAL, false, 16)
	_centered("ENCYCLOPEDIA", Rect2(0, 22, 1152, 70), 44, CREAM)
	for i in infos.size():
		var info: Dictionary = infos[i]
		var path: String = SignIntro.SIGN_LIST[i]
		var open: bool = Global.sign_unlocked(path)
		var r := Rect2(COL_X[i / 5], TOP + (i % 5) * ROW_GAP, CARD.x, CARD.y)
		draw_rect(r, CREAM if open else GREY)
		draw_rect(r, TEAL if open else DARK_GREY, false, 6)
		# the picture: the sign itself, or for a locked sign just its outline on a grey silhouette
		var box := Rect2(r.position.x + 16, r.position.y + (r.size.y - PIC) / 2.0, PIC, PIC)
		if info["tex"] != null:
			var tex: Texture2D = info["tex"]
			var k: float = info["k"]
			var shown := Rect2(box.get_center() - tex.get_size() * k / 2.0, tex.get_size() * k)
			if open:
				draw_texture_rect(tex, shown, false)
			else:
				# locked: the whole inside of the sign is flat grey (nothing of the sign shows), with its outline and a ?
				var flat: ImageTexture = info["flat"]
				if flat != null:
					draw_texture_rect(flat, shown, false)
				var line: ImageTexture = info["outline"]
				if line != null:
					draw_texture_rect(line, Rect2(shown.position - Vector2(2, 2), line.get_size()), false, Color(0.82, 0.82, 0.82, 1.0))
				_centered("?", Rect2(shown.position, shown.size), int(minf(shown.size.x, shown.size.y) * 0.62), Color(0.92, 0.92, 0.92))
		var title: String = info["title"] if open else "???"
		var text: String = info["text"] if open else ""
		var tx := r.position.x + 108.0
		draw_string(FONT, Vector2(tx, r.position.y + 30), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 124, 17, TEAL if open else DARK_GREY)
		draw_multiline_string(FONT, Vector2(tx, r.position.y + 52), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 124, 12, 3, INK if open else DARK_GREY)
	var br := _back_rect().grow(4.0) if hover_back else _back_rect()
	draw_rect(br, CREAM)
	draw_rect(br, TEAL, false, 4)
	_centered("BACK", br, 16, TEAL)
