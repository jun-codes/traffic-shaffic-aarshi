extends Node

var safe: bool = false
var play: bool = false
var speed_mult: float = 1
var current_scene

# Scene the "next level" button on the victory screen opens.
var next_level: String = "res://scenes/Level2/level 2.tscn"

# --- Dragging items (traffic signal, right turn sign ...) ---
# Same snapping grid as Level 2 (in pixels).
const GRID := 20
# The one item currently being dragged; nothing else may move while this is set.
var drag_owner: Node = null

# True if the mouse is exactly over the given Area2D (independent of hover flags).
func mouse_over_area(area: Area2D) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = area.get_global_mouse_position()
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for r in area.get_world_2d().direct_space_state.intersect_point(q, 16):
		if r.collider == area:
			return true
	return false

# Level 2 style snapping: the grabbed point stays under the mouse, position snaps to GRID.
func snap_drag(mouse: Vector2, grab_offset: Vector2) -> Vector2:
	var m := mouse - grab_offset
	return Vector2(snappedf(m.x, GRID), snappedf(m.y, GRID))

# --- Signs cannot stand on the road ---
# Every level tags its road TileMapLayer with the group "road_layer". A level can also
# list extra road areas that have no tile (e.g. the gap in the Level 2 divider).
var extra_road_rects: Array[Rect2] = []

# True if the point lies on a road tile (curbs included) or in an extra road area.
func is_road(p: Vector2) -> bool:
	for rect in extra_road_rects:
		if rect.has_point(p):
			return true
	for layer in get_tree().get_nodes_in_group("road_layer"):
		var l := layer as TileMapLayer
		if l != null and l.get_cell_tile_data(l.local_to_map(l.to_local(p))) != null:
			return true
	return false

# True if ANY part of the item's collision shape touches the road when the item's origin
# is at `center`. `rel` is the shape's bounding box relative to the item's origin;
# `round_shape` means the shape is a circle/ellipse (corners of the box don't count).
func footprint_on_road(center: Vector2, rel: Rect2, round_shape: bool) -> bool:
	var r := Rect2(center + rel.position, rel.size)
	if round_shape:
		# The outline of the circle/ellipse (a plain grid of points can skip its top and
		# bottom edge by a few pixels).
		var middle := r.position + r.size / 2.0
		var half := r.size / 2.0
		var points := maxi(16, ceili(PI * (half.x + half.y) / 6.0))
		for k in points:
			var a := TAU * k / points
			if is_road(middle + Vector2(cos(a) * half.x, sin(a) * half.y)):
				return true
	var nx := maxi(1, ceili(r.size.x / 8.0))     # sample every <= 8 px (tiles are >= 15 px)
	var ny := maxi(1, ceili(r.size.y / 8.0))
	for i in range(nx + 1):
		for j in range(ny + 1):
			var u := float(i) / nx
			var v := float(j) / ny
			if round_shape:
				var ex := (u - 0.5) * 2.0
				var ey := (v - 0.5) * 2.0
				if ex * ex + ey * ey > 1.0:
					continue
			if is_road(r.position + Vector2(u * r.size.x, v * r.size.y)):
				return true
	return false

const HOVER_SCALE := 1.12     # how much an item grows while the mouse is on it

# Bounding box (relative to the item's origin) and shape kind of the item's Area2D shape.
# Returns [Rect2, bool is_round].
func area_footprint(item: Node2D, area: Area2D) -> Array:
	for child in area.get_children():
		var cs := child as CollisionShape2D
		if cs != null and cs.shape != null:
			var world: Rect2 = cs.global_transform * cs.shape.get_rect()
			# Items grow a little while the mouse is on them (hover). The road check uses the
			# normal size, otherwise a hovered item would not fit into spots it does fit once
			# it is dropped (for example the thin divider islands of Level 2).
			var k := 1.0 / HOVER_SCALE if item.get("draggable") == true else 1.0
			return [Rect2((world.position - item.global_position) * k, world.size * k), cs.shape is CircleShape2D]
	return [Rect2(-10, -10, 20, 20), false]

# Where a dragged item should be: the snapped position under the mouse, but if any part of
# the item would touch the road it skips over the road to the nearest spot where it
# doesn't (grass, or the Level 2 divider).
func drag_position(mouse: Vector2, grab_offset: Vector2, rel: Rect2 = Rect2(-1, -1, 2, 2), round_shape := false) -> Vector2:
	var wanted := mouse - grab_offset
	var p := snap_drag(mouse, grab_offset)
	if not footprint_on_road(p, rel, round_shape):
		return p
	var best := p
	var best_d := INF
	for r in range(1, 41):                       # search rings of grid points around it
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := p + Vector2(dx, dy) * GRID
				if q.x < GRID * 2 or q.x > 1140.0 or q.y < GRID * 2 or q.y > 630.0:
					continue
				var d := q.distance_to(wanted)
				if d >= best_d:                  # cheaper test first
					continue
				if footprint_on_road(q, rel, round_shape):
					continue
				best_d = d
				best = q
		if best_d <= r * GRID:                   # nothing in a wider ring can be closer
			break
	return best

# --- Speed limit (Level 3 speed sign) ---
# The limit set on the sign caps the speed of EVERY car. 50 km/h = 200 px/s, 30 km/h = 120 px/s.
var speed_limit_kmh: float = 50.0

func speed_cap_px() -> float:
	return 200.0 * speed_limit_kmh / 50.0

# --- Level progress (saved between runs) ---
const LEVEL_PATHS := [
	"res://scenes/Level1/level 1.tscn",
	"res://scenes/Level2/level 2.tscn",
	"res://scenes/Level3/level 3.tscn",
	"res://scenes/Level4/level 4.tscn",
	"res://scenes/Level5/level 5.tscn",
]
const SAVE_PATH := "user://progress.cfg"
var levels_done: Array = [false, false, false, false, false]
var level_stars: Array = [0, 0, 0, 0, 0]      # best star rating per level (0 = never finished)

# --- Car colour (chosen on the customise screen, used for the player car in the whole game) ---
const CAR_SKINS := [["red", "RED"], ["cyan", "CYAN"], ["purp", "PURPLE"]]   # [id, name]
var car_skin := "red"
var sfx_volume := 1.0        # 0..1, volume of the sound effects (settings screen)
var music_volume := 1.0      # 0..1, volume of the background music (settings screen)

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	Music.apply_volume()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	Sfx.apply_volume()

func save_settings() -> void:
	_save()

func set_car_skin(id: String) -> void:
	car_skin = id
	_save()

# The sprite frames of the player car in the chosen colour (null = the red car of the scene).
func car_frames() -> SpriteFrames:
	if car_skin == "red":
		return null
	return load("res://assets/cars/%s_frames.tres" % car_skin) as SpriteFrames

func _save() -> void:
	var cfg := ConfigFile.new()
	for k in LEVEL_PATHS.size():
		cfg.set_value("done", str(k), levels_done[k])
		cfg.set_value("stars", str(k), level_stars[k])
	cfg.set_value("settings", "car_skin", car_skin)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.save(SAVE_PATH)

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		car_skin = str(cfg.get_value("settings", "car_skin", "red"))
		sfx_volume = clampf(float(cfg.get_value("settings", "sfx_volume", 1.0)), 0.0, 1.0)
		music_volume = clampf(float(cfg.get_value("settings", "music_volume", 1.0)), 0.0, 1.0)
		for i in LEVEL_PATHS.size():
			levels_done[i] = bool(cfg.get_value("done", str(i), false))
			level_stars[i] = int(cfg.get_value("stars", str(i), 0))

# Level i (0-based) is open when every level before it has been finished.
func is_unlocked(i: int) -> bool:
	for k in i:
		if not levels_done[k]:
			return false
	return true

func complete_level(path: String, stars: int = 1) -> void:
	var i := LEVEL_PATHS.find(path)
	if i < 0:
		return
	levels_done[i] = true
	level_stars[i] = maxi(level_stars[i], stars)
	_save()

# Opens level i from the menu; "next level" then follows on to the one after it.
func start_level(i: int) -> void:
	next_level = LEVEL_PATHS[i + 1] if i + 1 < LEVEL_PATHS.size() else ""
	get_tree().change_scene_to_file(LEVEL_PATHS[i])

# --- Scoring ---
# Stars depend on how many items (signs) the player placed on the map: 1 item = 3 stars (the
# optimal solution of every level), 2 items = 2 stars, 3 or more = 1 star. The Level 3 speed
# limit sign is not counted (changing the limit is free).
func items_used() -> int:
	var scene := get_tree().current_scene
	var used := 0
	for n in scene.find_children("*", "Node2D", true, false):
		var is_item: bool = n.is_in_group("signs") or (n.has_node("Label") and (n.has_node("Sprite2D") or n.has_node("AnimatedSprite2D")))
		if not is_item or n.has_node("speed buttons"):
			continue
		if n.global_position.x < 933.0:        # left the sidebar tray = placed on the map
			used += 1
	return used

# Fewest items that can win each level (Level 4 needs both its signs, Level 5 all five of its items).
const PAR := [1, 1, 1, 2, 5]

func stars_for(items: int, par: int = 1) -> int:
	return 3 if items <= par else (2 if items == par + 1 else 1)

# New game: forget every finished level and star, and overwrite the save file.
func reset_progress() -> void:
	levels_done = [false, false, false, false, false]
	level_stars = [0, 0, 0, 0, 0]
	_save()          # rewrites the save file with no progress (the car colour is kept)

# Continue: first level that is open but not finished yet (the level picker if everything is done).
func continue_index() -> int:
	for i in LEVEL_PATHS.size():
		if not levels_done[i]:
			return i
	return -1
