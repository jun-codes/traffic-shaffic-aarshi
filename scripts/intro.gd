extends Node2D

# The menu buttons are part of the artwork, so on hover a cropped copy of the artwork is
# drawn over the button and scaled up slightly. Rects are in screen pixels (art is at 0.6).
const MENU_RECTS := [
	Rect2(414, 216, 312, 63),   # new game
	Rect2(414, 297, 312, 69),   # continue
	Rect2(414, 381, 312, 66),   # levels
	Rect2(414, 462, 312, 69),   # customise
	Rect2(414, 546, 312, 66),   # settings
]
const HOVER_SCALE := 1.08

var overlays: Array[Sprite2D] = []
const BOOK := preload("res://assets/book icon.png")
const BOOK_RECT := Rect2(1008, 518, 112, 112)      # the encyclopedia button, bottom right
var book_hover := false
var book_button: Button

func _ready() -> void:
	# Safety net: never arrive at the menu with the game still paused.
	get_tree().paused = false
	for b in find_children("*", "Button", false):
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# The encyclopedia: a book icon in the bottom right corner.
	book_button = Button.new()
	book_button.flat = true
	book_button.position = BOOK_RECT.position
	book_button.size = BOOK_RECT.size
	book_button.focus_mode = Control.FOCUS_NONE
	book_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	book_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/encyclopedia.tscn"))
	add_child(book_button)
	var book := Sprite2D.new()
	book.name = "BookIcon"
	book.texture = BOOK
	book.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	book.scale = Vector2(0.38, 0.38)        # the picture is 320 px: shown about 120 px wide (the book itself fills most of it)
	book.position = BOOK_RECT.get_center()
	add_child(book)
	var tex: Texture2D = $Sprite2D.texture
	for r in MENU_RECTS:
		var s := Sprite2D.new()
		s.texture = tex
		s.region_enabled = true
		s.region_rect = Rect2(r.position / 0.6, r.size / 0.6)
		s.scale = Vector2(0.6, 0.6)
		s.position = r.get_center()
		s.visible = false
		add_child(s)
		overlays.append(s)

func _process(_delta: float) -> void:
	var mouse := get_global_mouse_position()
	var over := false
	for i in MENU_RECTS.size():
		var hot: bool = MENU_RECTS[i].has_point(mouse)
		over = over or hot
		var target := 0.6 * (HOVER_SCALE if hot else 1.0)
		overlays[i].visible = hot
		overlays[i].scale = overlays[i].scale.lerp(Vector2(target, target), 0.4)
	var book_hot := BOOK_RECT.has_point(mouse)
	var book_sprite := get_node_or_null("BookIcon") as Sprite2D
	if book_sprite != null:
		var bs := 0.38 * (1.12 if book_hot else 1.0)
		book_sprite.scale = book_sprite.scale.lerp(Vector2(bs, bs), 0.4)
	over = over or book_hot
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over else Input.CURSOR_ARROW)

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_button_pressed():
	# New game wipes all saved progress, then the five cutscenes play (the first one appears right away, no fade) and
	# then the tutorial (which ends in level 1).
	Global.reset_progress()
	get_tree().change_scene_to_file("res://scenes/cutscenes.tscn")

func _on_continue_pressed():
	var i := Global.continue_index()
	if i < 0:
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")   # everything finished
	else:
		Global.start_level(i)

func _on_settings_pressed():
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_customise_pressed():
	get_tree().change_scene_to_file("res://scenes/customise.tscn")

func _on_levels_pressed():
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
