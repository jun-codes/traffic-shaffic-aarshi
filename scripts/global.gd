extends Node

var safe: bool = false
var play: bool = false
var speed_mult: float = 1
var current_scene

# Scene the "next level" button on the victory screen opens.
var next_level: String = "res://scenes/Level2/level 2.tscn"

# Set when a level is restarted (restart button): the "new sign unlocked" screen is only shown when a level is opened.
var skip_sign_intro := false

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
	if _curb_free():
		return road_pixel(p)                    # only the asphalt (and markings) blocks signs, not the curbs around it
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
func _grid_drag_position(mouse: Vector2, grab_offset: Vector2, rel: Rect2, round_shape: bool) -> Vector2:
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

# `flush` (stop signs and traffic signals): the item also slides up to two grid steps towards the nearest
# road so that it sits flush against the edge of the road, with no gap.
func drag_position(mouse: Vector2, grab_offset: Vector2, rel: Rect2 = Rect2(-1, -1, 2, 2), round_shape := false, flush := false) -> Vector2:
	var p := _grid_drag_position(mouse, grab_offset, rel, round_shape)
	if flush:
		p = flush_to_road(p, rel, round_shape, mouse - grab_offset)
	return p

# Moves the item (that stands next to a road, not on it) towards the road until it touches the VISIBLE edge of the road (rounded corners included).
# (`wanted` is where the mouse wants the item: when two roads are equally close, for example the divider between two
# carriageways, the item goes to the road on the side of the mouse.)
func flush_to_road(p: Vector2, rel: Rect2, round_shape: bool, wanted := Vector2.ZERO) -> Vector2:
	var key := [p, rel, round_shape, wanted]
	if key == _flush_key:
		return _flush_result
	var best := p
	if not _visual_hit(p, rel, round_shape):
		var toward := wanted - p
		var moves := {}                          # direction -> how far to slide until it touches the road
		for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			for s in range(1, FLUSH_RANGE + 1):
				if _visual_hit(p + dir * s, rel, round_shape):
					moves[dir] = s - 1
					break
		# A road on both sides (the divider between two carriageways): the mouse decides which one.
		for pair in [[Vector2.LEFT, Vector2.RIGHT], [Vector2.UP, Vector2.DOWN]]:
			if moves.has(pair[0]) and moves.has(pair[1]):
				var d: float = toward.dot(pair[0])
				if absf(d) > 4.0:
					moves.erase(pair[1] if d > 0.0 else pair[0])
		var best_move := FLUSH_RANGE + 1
		for dir in moves:
			if moves[dir] < best_move:
				best_move = moves[dir]
				best = p + dir * best_move
	_flush_key = key
	_flush_result = best
	return best

const FLUSH_RANGE := 40          # a sign within this many px of a road slides flush against it
var _flush_key: Array = []
var _flush_result := Vector2.ZERO
var _road_images := {}

# True if a VISIBLE road / curb pixel (not the see-through corner of a rounded tile, not the grass) is at p.
func road_pixel(p: Vector2) -> bool:
	for rect in extra_road_rects:
		if rect.has_point(p):
			return true
	for layer in get_tree().get_nodes_in_group("road_layer"):
		var l := layer as TileMapLayer
		if l == null:
			continue
		var cell := l.local_to_map(l.to_local(p))
		var sid := l.get_cell_source_id(cell)
		if sid < 0:
			continue
		var src := l.tile_set.get_source(sid) as TileSetAtlasSource
		if not _road_images.has(sid):
			_road_images[sid] = src.texture.get_image()
		var size := src.texture_region_size
		var atlas := l.get_cell_atlas_coords(cell)
		var off := l.to_local(p) - (l.map_to_local(cell) - Vector2(size) / 2.0)
		var px := clampi(int(off.x), 0, size.x - 1)
		var py := clampi(int(off.y), 0, size.y - 1)
		var img: Image = _road_images[sid]
		var c: Color = img.get_pixel(atlas.x * size.x + px, atlas.y * size.y + py)
		if c.a >= 0.5:
			if not _curb_free():
				return true
			var lum := c.get_luminance()              # dark asphalt or a white marking; the grey curb does not count
			if lum < 0.2 or lum > 0.8:
				return true
	return false

# Does any part of the item (collision box / circle at `center`) touch a visible road pixel?
func _visual_hit(center: Vector2, rel: Rect2, round_shape: bool) -> bool:
	var r := Rect2(center + rel.position, rel.size)
	var nx := maxi(1, ceili(r.size.x / 4.0))
	var ny := maxi(1, ceili(r.size.y / 4.0))
	for i in range(nx + 1):
		for j in range(ny + 1):
			var u := float(i) / nx
			var v := float(j) / ny
			if round_shape:
				var ex := (u - 0.5) * 2.0
				var ey := (v - 0.5) * 2.0
				if ex * ex + ey * ey > 1.0:
					continue
			if road_pixel(r.position + Vector2(u * r.size.x, v * r.size.y)):
				return true
	return false

# --- Speed limit (Level 3 speed sign) ---
# The limit set on the sign caps the speed of EVERY car. 50 km/h = 200 px/s, 30 km/h = 120 px/s.
var speed_limit_kmh: float = 50.0

func speed_cap_px() -> float:
	return 200.0 * speed_limit_kmh / 50.0

# --- Level progress (saved between runs) ---
# 9 levels in 3 zip codes (3 each). "" = level not made yet (its button does nothing).
const LEVEL_PATHS := [
	"res://scenes/Level1/level 1.tscn",    # zip 1
	"res://scenes/Zip1/level 2.tscn",
	"res://scenes/Zip1/level 3.tscn",
	"res://scenes/Level2/level 2.tscn",       # zip 2 (level 4: the U-turn level)
	"res://scenes/Zip2/level 4.tscn",         # level 5: the T junction with the compulsory left / right turns
	"res://scenes/Zip2/level 6.tscn",
	"res://scenes/Level3/level 3.tscn",    # zip 3
	"res://scenes/Level4/level 4.tscn",
	"res://scenes/Level5/level 5.tscn",
]
const LEVELS_PER_ZIP := 3
const SAVE_PATH := "user://progress.cfg"
const OLD_SLOTS := [0, 3, 6, 7, 8]            # where the 5 levels of the old save format moved to
var levels_done: Array = []
var level_stars: Array = []      # best star rating per level (0 = never finished)
var unlocked_signs: Array = []         # scene paths of the signs introduced so far (for the encyclopedia)
var seen_intros: Array = []            # levels whose mini tutorial (new sign, clickable signs ...) was already shown in this game

func _init() -> void:
	for i in LEVEL_PATHS.size():
		levels_done.append(false)
		level_stars.append(0)

# True if level i has been made.
func level_exists(i: int) -> bool:
	return i >= 0 and i < LEVEL_PATHS.size() and LEVEL_PATHS[i] != ""

# --- Car colour (chosen on the customise screen, used for the player car in the whole game) ---
const CAR_SKINS := [["red", "RED"], ["cyan", "CYAN"], ["purp", "PURPLE"]]   # [id, name]
# Total stars needed to unlock each colour (red is always open).
const SKIN_STARS := {"red": 0, "cyan": 9, "purp": 18}
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

# All the stars earned so far (the best rating of every level, added up).
func total_stars() -> int:
	var n := 0
	for v in level_stars:
		n += int(v)
	return n

func skin_unlocked(id: String) -> bool:
	return total_stars() >= int(SKIN_STARS.get(id, 0))

func set_car_skin(id: String) -> void:
	if not skin_unlocked(id):
		return
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
	cfg.set_value("meta", "version", 3)
	cfg.set_value("signs", "unlocked", unlocked_signs)
	cfg.set_value("signs", "intros_seen", seen_intros)
	cfg.set_value("settings", "car_skin", car_skin)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.save(SAVE_PATH)

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		car_skin = str(cfg.get_value("settings", "car_skin", "red"))
		unlocked_signs = Array(cfg.get_value("signs", "unlocked", []))
		seen_intros = Array(cfg.get_value("signs", "intros_seen", []))
		sfx_volume = clampf(float(cfg.get_value("settings", "sfx_volume", 1.0)), 0.0, 1.0)
		music_volume = clampf(float(cfg.get_value("settings", "music_volume", 1.0)), 0.0, 1.0)
		var version := int(cfg.get_value("meta", "version", 1))
		if int(cfg.get_value("meta", "version", 1)) < 2:
			# Old save: 5 levels in a row, now spread over the 9 slots.
			for k in OLD_SLOTS.size():
				levels_done[OLD_SLOTS[k]] = bool(cfg.get_value("done", str(k), false))
				level_stars[OLD_SLOTS[k]] = int(cfg.get_value("stars", str(k), 0))
		else:
			for i in LEVEL_PATHS.size():
				levels_done[i] = bool(cfg.get_value("done", str(i), false))
				level_stars[i] = int(cfg.get_value("stars", str(i), 0))
			if version < 3:                  # levels 4 and 5 were swapped: swap their progress too
				var d: bool = levels_done[3]
				levels_done[3] = levels_done[4]
				levels_done[4] = d
				var st: int = level_stars[3]
				level_stars[3] = level_stars[4]
				level_stars[4] = st
	if not skin_unlocked(car_skin):          # a colour whose stars are gone (new game) goes back to red
		car_skin = "red"

# TEMPORARY: true = every level that exists is open (for testing). Set to false to bring the locks back.
const UNLOCK_ALL := false

# Level i (0-based) is open when it exists and every made level before it has been finished
# (levels that are not made yet do not block).
func is_unlocked(i: int) -> bool:
	if not level_exists(i):
		return false
	if UNLOCK_ALL:
		return true
	for k in i:
		if level_exists(k) and not levels_done[k]:
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
	next_level = ""
	for k in range(i + 1, LEVEL_PATHS.size()):
		if level_exists(k):
			next_level = LEVEL_PATHS[k]
			break
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
const PAR := [1, 1, 2, 1, 1, 2, 1, 2, 5]      # indexed by level slot (blank slots are unused)

func stars_for(items: int, par: int = 1) -> int:
	return 3 if items <= par else (2 if items == par + 1 else 1)

# New game: forget every finished level and star, and overwrite the save file.
func reset_progress() -> void:
	unlocked_signs = []                      # the encyclopedia starts empty again
	seen_intros = []                         # every mini tutorial is shown again, once
	for i in LEVEL_PATHS.size():
		levels_done[i] = false
		level_stars[i] = 0
	car_skin = "red"           # the coloured cars are locked again (they need stars)
	_save()          # rewrites the save file with no progress

# Encyclopedia: a sign is unlocked once the level that introduces it has been opened.
func unlock_sign(scene_path: String, save := true) -> void:
	if scene_path in unlocked_signs:
		return
	unlocked_signs.append(scene_path)
	if save:
		_save()

func sign_unlocked(scene_path: String) -> bool:
	return scene_path in unlocked_signs

# Mini tutorials are shown only the first time a level is played (until a new game).
func intro_seen(level_path: String) -> bool:
	return level_path in seen_intros

func mark_intro_seen(level_path: String, save := true) -> void:
	if level_path in seen_intros:
		return
	seen_intros.append(level_path)
	if save:
		_save()

# Continue: first level that is open but not finished yet (the level picker if everything is done).
func continue_index() -> int:
	for i in LEVEL_PATHS.size():
		if level_exists(i) and not levels_done[i]:
			return i
	return -1

# The path of the next level that exists after the level with this scene path ("" = none).
func next_path_after(path: String) -> String:
	var i := LEVEL_PATHS.find(path)
	for k in range(i + 1, LEVEL_PATHS.size()):
		if level_exists(k):
			return LEVEL_PATHS[k]
	return ""

# Where the seconds of a traffic signal are written: above it, but below it when the spot above
# lies on a road (the signal stands on the pavement below the road).
func signal_count_pos(p: Vector2) -> Vector2:
	var above := Vector2(p.x - 40.0, p.y - 70.0)
	if is_road(Vector2(p.x, p.y - 62.0)) or is_road(Vector2(p.x, p.y - 45.0)):
		return Vector2(p.x - 40.0, p.y + 46.0)
	return above

# A level can let signs stand right up to the asphalt, over the curbs: it provides `sign_curb_free() -> true`.
var _curb_scene: Node = null
var _curb_value := false

func _curb_free() -> bool:
	var scene := get_tree().current_scene
	if scene != _curb_scene:
		_curb_scene = scene
		_curb_value = scene != null and scene.has_method("sign_curb_free") and scene.sign_curb_free()
	return _curb_value

# --- Stop signs and traffic signals belong to ONE road ---------------------------------------------
# A stop sign / traffic signal works on the whole road it stands next to (every lane, both directions),
# never on a crossing road: at a junction it snaps to the nearest road. A level lists its roads as
# Rect2s (the road including its curbs); a sign further than ROAD_ADJACENT from every road does nothing.
const ROAD_ADJACENT := 130.0

func rect_distance(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()

# Index of the road (in `roads`) the sign at `p` stands next to: the nearest one, -1 if none is close.
func sign_road(p: Vector2, roads: Array) -> int:
	var best := -1
	var best_d := ROAD_ADJACENT
	for i in roads.size():
		var d := rect_distance(p, roads[i])
		if d <= best_d:
			best_d = d
			best = i
	return best

# A road runs along its longer side.
func road_axis(r: Rect2) -> Vector2:
	return Vector2.RIGHT if r.size.x >= r.size.y else Vector2.DOWN

# True if a car at `car_pos` driving along `heading` is on the road the sign stands next to.
func car_on_sign_road(sign_pos: Vector2, roads: Array, car_pos: Vector2, heading: Vector2) -> bool:
	var i := sign_road(sign_pos, roads)
	if i < 0:
		return false
	var r: Rect2 = roads[i]
	return r.has_point(car_pos) and absf(heading.dot(road_axis(r))) > 0.5

# While the signal is red the cars on its road (every lane, both directions) queue up in front of it:
# each car stops when it comes up to the signal, the next one behind it. `cars` are highway cars.
func queue_at_signal(sign: Node2D, roads: Array, cars: Array, delta: float, gap: float) -> void:
	var sign_pos := sign.global_position
	for dir in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		if sign.has_meta("stop_dir") and sign.get_meta("stop_dir") != dir:
			continue                           # a sign only stops the traffic of ONE direction
		var group: Array = []
		for c in cars:
			if c.direction == dir and car_on_sign_road(sign_pos, roads, c.global_position, dir):
				var p: float = (c.global_position - sign_pos).dot(dir)
				if p < 40.0:                       # not past the signal yet
					group.append([p, c])
		group.sort_custom(func(a, b): return a[0] > b[0])
		for i in group.size():
			var limit := -12.0 - i * gap
			var p: float = group[i][0]
			var c: Node2D = group[i][1]
			if p + c.speed * delta >= limit:
				if not sign.has_meta("stop_dir"):
					sign.set_meta("stop_dir", dir)      # the first car to reach the sign decides which way it works
				c.global_position -= dir * maxf(p - limit, 0.0)
				c.hold = 0.1

# The cars on the signal's road go (the signal turned green).
func release_signal_road(sign: Node2D, roads: Array, cars: Array) -> void:
	for c in cars:
		if sign.has_meta("stop_dir") and c.direction == sign.get_meta("stop_dir") and car_on_sign_road(sign.global_position, roads, c.global_position, c.direction):
			c.hold = 0.0

# A stop sign / traffic signal only stops the traffic of ONE direction (like in real life): the direction of
# the first car that comes up to it. Cars coming from the opposite direction ignore it.
func sign_stops_heading(sign: Node2D, heading: Vector2) -> bool:
	if not sign.has_meta("stop_dir"):
		sign.set_meta("stop_dir", heading)
		return true
	return sign.get_meta("stop_dir") == heading

# --- Compulsory left / right turn signs belong to ONE road, and to one direction of it -------------
# A level that uses road-based turn signs provides `sign_roads()` (the Rect2 of every road, with its curbs)
# and optionally `sign_road_dirs()` (a fixed travel direction per road, for one-way carriageways; ZERO =
# two-way). The sign snaps to the nearest road. On a two-way road it points the way the traffic goes on the
# side of the road where it stands (traffic keeps to the left: a sign above an eastbound-right road points
# right, below it points left; left of a vertical road it points up, right of it down), and it only
# affects the cars of that road driving that way. Levels without `sign_roads()` keep the old behaviour.
const TURN_CROSS := 75.0          # a car turns once it has completely crossed the sign

func level_roads() -> Array:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("sign_roads"):
		return scene.sign_roads()
	return []

func level_road_dirs() -> Array:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("sign_road_dirs"):
		return scene.sign_road_dirs()
	return []

# Direction of travel the turn sign at `p` points in (ZERO: no road close enough).
func sign_heading(p: Vector2, roads: Array = [], dirs: Array = []) -> Vector2:
	if roads.is_empty():
		roads = level_roads()
		dirs = level_road_dirs()
	var i := sign_road(p, roads)
	if i < 0:
		return Vector2.ZERO
	if i < dirs.size() and dirs[i] != Vector2.ZERO:
		return dirs[i]
	var r: Rect2 = roads[i]
	var c := r.get_center()
	if road_axis(r) == Vector2.RIGHT:
		return Vector2.RIGHT if p.y < c.y else Vector2.LEFT
	return Vector2.UP if p.x < c.x else Vector2.DOWN

# Rotation of the sign picture (the picture's arrow points up) for a sign pointing along `heading`.
func heading_degrees(heading: Vector2) -> float:
	if heading == Vector2.RIGHT:
		return 90.0
	if heading == Vector2.DOWN:
		return 180.0
	if heading == Vector2.LEFT:
		return -90.0
	return 0.0

# Rotation for a turn sign item: 0 in the tray or away from every road.
func turn_sign_degrees(sign: Node2D) -> float:
	if sign.global_position.x >= 933.0:
		return 0.0
	return heading_degrees(sign_heading(sign.global_position))

# Has a car at `car_pos` driving along `heading` just completely crossed the turn sign at `sign_pos`
# (and is it on the sign's road, driving the way the sign points)? Then it turns now.
func turn_sign_reached(sign_pos: Vector2, car_pos: Vector2, heading: Vector2, roads: Array, dirs: Array = []) -> bool:
	if sign_pos.x >= 933.0:
		return false
	var f := sign_heading(sign_pos, roads, dirs)
	if f == Vector2.ZERO or f != heading:
		return false
	var i := sign_road(sign_pos, roads)
	var r: Rect2 = roads[i]
	if not r.has_point(car_pos):
		return false
	var along: float = (car_pos - sign_pos).dot(heading)
	return along >= TURN_CROSS and along <= TURN_CROSS + 40.0
