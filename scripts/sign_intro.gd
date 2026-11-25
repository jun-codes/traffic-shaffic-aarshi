# Autoload: mini tutorials shown before a level starts ("NEW SIGN UNLOCKED", clickable signs, the reckless
# driver ...). When a level that introduces something opens, a screen shows it with a picture and a description
# (for signs: the same text as the hover box in the item tray) before the level starts. Several pages can follow
# each other. They are shown only the first time a level is played in a game (Global.seen_intros, saved; a new game clears it), never on a restart or when the level is played again.
# The name, picture and description of a sign are read from the sign's own scene, so they always match the tray.
extends Node

const FONT := preload("res://assets/PixelOperator8-Bold.ttf")
const TEAL := Color("0f6b66")
const CREAM := Color("f5e6d3")
const GREEN := Color("1c8a5a")
const YELLOW := Color("ffd84a")
const INK := Color("1d2a2a")

# level scene -> pages. A page: optional "heading" (default NEW SIGN UNLOCKED / NEW SIGNS UNLOCKED) and its
# "cards". A card: the sign's "scene" (title, picture and description are read from it) or a "texture" with its own
# "title" and "text"; "title" / "text" override what is read; "extra" is added after the description;
# "clickable" draws a white border following the picture's exact outline (the sign is already placed and can be clicked).
const INTROS := {
	"res://scenes/Level1/level 1.tscn": [{"cards": [{"scene": "res://scenes/object.tscn"}]}],
	"res://scenes/Zip1/level 2.tscn": [{
		"heading": "NEW: CLICKABLE SIGNS",
		"cards": [{"scene": "res://scenes/object.tscn", "title": "ADJUSTABLE SIGNS", "clickable": true,
			"text": "A sign with a white border around it is already placed and can be clicked to adjust it. Click this signal to set its red light to 2 or 5 seconds."}]}],
	"res://scenes/Zip1/level 3.tscn": [{"cards": [{"scene": "res://scenes/Level3/stop.tscn"}]}],
	"res://scenes/Zip2/level 4.tscn": [{"cards": [
		{"scene": "res://scenes/Level5/left_turn.tscn"}, {"scene": "res://scenes/Level3/right_turn.tscn"}]}],
	"res://scenes/Level2/level 2.tscn": [{"cards": [{"scene": "res://scenes/Level5/u_turn.tscn"}]}],
	"res://scenes/Level3/level 3.tscn": [
		{"cards": [{"scene": "res://scenes/Level3/speed_limit.tscn", "clickable": true,
			"extra": " It is already placed: click it to change the limit."}]},
		{"heading": "WATCH OUT!", "cards": [{"texture": "res://assets/cars/reckless_frame_1.png", "title": "RECKLESS DRIVER",
			"text": "Some drivers drive recklessly: they do not follow good driving practices. Watch out for them, and use signs to make them drive carefully."}]}],
	"res://scenes/Level4/level 4.tscn": [{"cards": [
		{"scene": "res://scenes/Level4/give_way.tscn"}, {"scene": "res://scenes/Level4/no_stopping.tscn"}]}],
	"res://scenes/Level5/level 5.tscn": [{"cards": [
		{"scene": "res://scenes/Level5/one_way.tscn"}, {"scene": "res://scenes/Level5/cattle_ahead.tscn"}]}],
}

# Every sign, in the order the game introduces them (the encyclopedia shows them in this order).
const SIGN_LIST := [
	"res://scenes/object.tscn",
	"res://scenes/Level3/stop.tscn",
	"res://scenes/Level5/u_turn.tscn",
	"res://scenes/Level5/left_turn.tscn",
	"res://scenes/Level3/right_turn.tscn",
	"res://scenes/Level3/speed_limit.tscn",
	"res://scenes/Level4/give_way.tscn",
	"res://scenes/Level4/no_stopping.tscn",
	"res://scenes/Level5/one_way.tscn",
	"res://scenes/Level5/cattle_ahead.tscn",
]

var last_scene: Node = null
var layer: CanvasLayer = null
var root: Control = null
var pages: Array = []
var page_index := 0
var page_nodes: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Progress made before the encyclopedia existed: the signs of every finished level are unlocked.
	for level_path in INTROS:
		var idx: int = Global.LEVEL_PATHS.find(level_path)
		if idx >= 0 and Global.levels_done[idx]:
			Global.mark_intro_seen(level_path, false)
			for page in INTROS[level_path]:
				for card in page["cards"]:
					if card.has("scene"):
						Global.unlock_sign(card["scene"], false)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == last_scene:
		return
	last_scene = scene
	if layer != null:
		_close()
	if scene == null or not INTROS.has(scene.scene_file_path):
		return
	for page in INTROS[scene.scene_file_path]:                    # the signs of this level go into the encyclopedia
		for card in page["cards"]:
			if card.has("scene"):
				Global.unlock_sign(card["scene"])
	if Global.skip_sign_intro:                    # the level was restarted, not opened
		Global.skip_sign_intro = false
		return
	if Global.intro_seen(scene.scene_file_path):  # only the first time a level is played (until a new game)
		return
	Global.mark_intro_seen(scene.scene_file_path)
	_open(INTROS[scene.scene_file_path])

# --- reading a sign's scene ------------------------------------------------------------------------
func _read_sign(path: String) -> Dictionary:
	var info := {"title": "", "text": "", "tex": null}
	var packed := load(path) as PackedScene
	if packed == null:
		return info
	var st := packed.get_state()
	for i in st.get_node_count():
		var props := {}
		for j in st.get_node_property_count(i):
			props[st.get_node_property_name(i, j)] = st.get_node_property_value(i, j)
		if props.has("title"):
			info["title"] = str(props["title"])
			info["text"] = str(props.get("description", ""))
		var node_name := str(st.get_node_name(i))
		if node_name == "Sprite2D" and props.has("texture") and info["tex"] == null:
			info["tex"] = props["texture"]
		elif node_name == "AnimatedSprite2D" and props.has("sprite_frames") and info["tex"] == null:
			var frames := props["sprite_frames"] as SpriteFrames
			var anim := str(props.get("animation", "default"))
			if frames != null and frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
				info["tex"] = frames.get_frame_texture(anim, 0)
	return info

# --- the screens -----------------------------------------------------------------------------------
func _open(new_pages: Array) -> void:
	pages = new_pages
	page_index = 0
	layer = CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP      # nothing underneath can be clicked
	layer.add_child(root)
	Global.drag_owner = root                             # and no item can be picked up
	var back := ColorRect.new()
	back.color = GREEN
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	var frame := ReferenceRect.new()
	frame.border_color = TEAL
	frame.border_width = 16.0
	frame.editor_only = false
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	_show_page()

func _show_page() -> void:
	for n in page_nodes:
		if is_instance_valid(n):
			n.queue_free()
	page_nodes.clear()
	var page: Dictionary = pages[page_index]
	var cards: Array = page["cards"]
	var heading: String = page.get("heading", "NEW SIGNS UNLOCKED" if cards.size() > 1 else "NEW SIGN UNLOCKED")
	_label(heading, Rect2(0, 50, 1152, 70), 44, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	var w := 400.0
	var gap := 40.0
	var x0 := (1152.0 - (cards.size() * w + (cards.size() - 1) * gap)) / 2.0
	for k in cards.size():
		_card(cards[k], Rect2(x0 + k * (w + gap), 135, w, 385))
	var last := page_index == pages.size() - 1
	var button := Button.new()
	button.text = "CONTINUE" if last else "NEXT"
	button.position = Vector2(426, 550)
	button.size = Vector2(300, 56)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = YELLOW if st == "hover" else CREAM
		sb.border_color = TEAL
		sb.set_border_width_all(5)
		button.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(c, TEAL)
	button.pressed.connect(_continue)
	root.add_child(button)
	page_nodes.append(button)

func _card(entry: Dictionary, rect: Rect2) -> void:
	var info := {"title": "", "text": "", "tex": null}
	if entry.has("scene"):
		info = _read_sign(entry["scene"])
	elif entry.has("texture"):
		info["tex"] = load(entry["texture"])
	var title: String = entry.get("title", info["title"])
	var text: String = entry.get("text", info["text"] + entry.get("extra", ""))
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.border_color = TEAL
	sb.set_border_width_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	page_nodes.append(panel)
	var pic_rect := Rect2(rect.position.x + (rect.size.x - 150.0) / 2.0, rect.position.y + 24, 150, 150)
	if entry.get("clickable", false):
		var grass := ColorRect.new()
		grass.color = GREEN
		grass.position = pic_rect.grow(14).position
		grass.size = pic_rect.grow(14).size
		grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(grass)
		page_nodes.append(grass)
	if info["tex"] != null:
		var pic := TextureRect.new()
		pic.texture = info["tex"]
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = pic_rect.position
		pic.size = pic_rect.size
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(pic)
		page_nodes.append(pic)
		if entry.get("clickable", false):
			_border(info["tex"], pic_rect)
	_label(title, Rect2(rect.position.x + 16, rect.position.y + 190, rect.size.x - 32, 56), 20, TEAL, HORIZONTAL_ALIGNMENT_CENTER)
	_label(text, Rect2(rect.position.x + 20, rect.position.y + 250, rect.size.x - 40, 125), 14, INK, HORIZONTAL_ALIGNMENT_CENTER)

# The solid white border of a clickable sign, following the exact outline of the picture (on grass green, like in the
# levels).
func _border(tex: Texture2D, box: Rect2) -> void:
	var ts := tex.get_size()
	var k := minf(box.size.x / ts.x, box.size.y / ts.y)
	var shown := Rect2(box.get_center() - ts * k / 2.0, ts * k)         # where the picture really is (aspect kept)
	var line: ImageTexture = (load("res://scripts/click_outline.gd") as GDScript).trace(tex, k, 3)
	if line == null:
		return
	var pic := TextureRect.new()
	pic.texture = line
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.position = shown.position - Vector2(3, 3)
	pic.size = Vector2(line.get_size())
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pic)
	page_nodes.append(pic)

func _label(text: String, rect: Rect2, size: int, color: Color, align: int) -> void:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART      # before the size, or the label first grows to fit the whole line
	l.custom_minimum_size = Vector2(rect.size.x, 0)
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = align as HorizontalAlignment
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	page_nodes.append(l)

func _unhandled_input(event: InputEvent) -> void:
	if layer == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_continue()

func _continue() -> void:
	Sfx.play("click")
	if page_index < pages.size() - 1:
		page_index += 1
		_show_page()
	else:
		_close()

func _close() -> void:
	if layer == null:
		return
	if Global.drag_owner == root:
		Global.drag_owner = null
	layer.queue_free()
	layer = null
	root = null
