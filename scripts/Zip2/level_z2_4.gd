# Zip code 2, level 5 (scene Zip2/level 4): a T junction. Our car drives right along the upper lane of the road
# across; the only side road goes up from the junction, and HOME is at its top.
#  - Nothing placed: the car just drives on to the right edge and does not get home.
#  - A compulsory LEFT TURN sign beside the road, before the junction: the car turns left once it has
#    completely crossed the sign and drives up the side road to HOME.
#  - The other signs work on the car as well: a STOP sign / TRAFFIC SIGNAL next to the road it drives on stops it for a
#    moment (they belong to one road, see SIGN_RULES.md), a RIGHT turn sends it onto the grass, a U-turn sends it back
#    the way it came (so it does not get home).
extends Node2D

const CAR_SCALE := 0.55
const LANE_Y := 320.0
const START_X := 85.0
const SPEED := 150.0
const TURN_TIME := 0.7            # seconds a quarter turn takes (the radius follows the speed)
const CROSS_DISTANCE := 75.0      # the car turns once it has completely crossed the sign
const SIGN_REACH := 150.0         # a U-turn sign this close (sideways) to the car's lane is seen by it
const STOP_SECONDS := 1.5
const U_RADIUS := 30.0            # a U-turn is two quarter turns with this radius (upper lane -> lower lane)
const OFFSCREEN_X := 1000.0       # driven on past the junction, off the right edge
const ROADS := [Rect2(-20, 260, 960, 180), Rect2(350, -130, 180, 390)]   # the road across and the road up (with their curbs): the signs snap to the nearest one
const WEST_LANE_X := 410.0        # centre of the left lane of the road going up (the car lands here)
const FORGIVE := 45.0             # a turn sign up to one grid box (20 px) too early still works: the car takes a wider arc and lands in its lane

@onready var roads: TileMapLayer = $Roads
@onready var car: CharacterBody2D = $car
@onready var death: Node2D = $death
@onready var not_home: Node2D = $not_home
@onready var left_sign: Node2D = $left_turn
@onready var right_sign: Node2D = $turn
@onready var u_sign: Node2D = $u_turn
@onready var stop_sign: Node2D = $stop
@onready var light: Node2D = $traffic_signal

var state := "drive"        # drive, arc, free
var finished := false
var reason := ""
var hold := 0.0
var arc_radius := 0.0
var arc_theta := 0.0
var arc_start := Vector2.ZERO
var arc_from := Vector2.RIGHT
var arc_to := Vector2.UP
var uturn_next := false      # in the first half of a U-turn
var free_heading := Vector2.RIGHT
var seen: Array = []

func _ready() -> void:
	Global.speed_mult = 1.0
	Global.speed_limit_kmh = 50.0
	Global.extra_road_rects.clear()
	Global.next_level = Global.next_path_after(scene_file_path)
	car.turn_sig = true
	car.scale = Vector2.ONE * CAR_SCALE
	car.global_position = Vector2(START_X, LANE_Y)
	car.car.animation = &"turn"
	car.car.frame = 0
	car.car.rotation_degrees = 0.0
	car.car.flip_h = false
	car.death.connect(func(): _fail("crash"))
	# The signs' own rays are made for the older levels: this script applies the signs to the car.
	if "turned" in right_sign:
		right_sign.turned.append(car)
	if "stopped" in stop_sign:
		stop_sign.stopped.append(car)
	if "handled_cars" in light:
		light.handled_cars.append(car)
	light.ray_used = true

# The signs snap to a road (see Global.sign_heading): this level's roads.
func sign_roads() -> Array:
	return ROADS

func _physics_process(delta: float) -> void:
	if finished or not Global.play:
		return
	match state:
		"drive":
			car.velocity = Vector2(SPEED, 0.0)
			_check_signs(Vector2.RIGHT)
			if car.global_position.x >= OFFSCREEN_X:
				finished = true
				reason = "straight"
				not_home._on_car_death()
		"arc":
			arc_theta = minf(arc_theta + SPEED / arc_radius * delta, PI / 2.0)
			car.velocity = (arc_from * cos(arc_theta) + arc_to * sin(arc_theta)) * SPEED
			var a := lerpf(PI / 2.0 if arc_from.y != 0.0 else 0.0, PI / 2.0 if arc_to.y != 0.0 else 0.0, arc_theta / (PI / 2.0))
			car.get_node("CollisionShape2D").rotation = a
			car.get_node("Area2D").rotation = a
			_check_on_road()
			if arc_theta >= PI / 2.0:
				car.global_position = arc_start + (arc_from + arc_to) * arc_radius
				if uturn_next:                 # second half of the U-turn: down -> left
					uturn_next = false
					_start_arc(Vector2.LEFT, Vector2.DOWN, U_RADIUS)
				else:
					free_heading = arc_to
					state = "free"
		"free":
			car.velocity = free_heading * SPEED
			_check_signs(free_heading)
			_check_on_road()
			if free_heading.x < 0.0 and car.global_position.x < -60.0:      # drove back off the left edge (U-turn)
				finished = true
				reason = "uturn"
				not_home._on_car_death()
				return
	if hold > 0.0:
		hold -= delta
		car.velocity = Vector2.ZERO
	car.velocity *= Global.speed_mult

# --- the signs, for our car ---------------------------------------------------------------------------
func _check_signs(h: Vector2) -> void:
	var p := car.global_position
	# A stop sign / traffic signal belongs to the one road it snapped to (and one direction of it).
	for s in [stop_sign, light]:
		if s in seen or s.global_position.x >= 933.0:
			continue
		if not Global.car_on_sign_road(s.global_position, ROADS, p, h):
			continue
		var d: float = (p - s.global_position).dot(h)
		if d >= -12.0 and d <= 40.0:
			seen.append(s)
			if not Global.sign_stops_heading(s, h):
				continue
			hold = STOP_SECONDS
			if s == light:
				_run_light()
			return
	# Compulsory turns: the road-based rule. The U-turn keeps its reach (it only turns a car driving right).
	for s in [left_sign, right_sign, u_sign]:
		if s in seen or s.global_position.x >= 933.0:
			continue
		if s == u_sign:
			var rel: Vector2 = p - s.global_position
			if h != Vector2.RIGHT or absf(rel.y) > SIGN_REACH or rel.x < CROSS_DISTANCE or rel.x > CROSS_DISTANCE + 40.0:
				continue
			seen.append(s)
			uturn_next = true
			_start_arc(Vector2.DOWN, Vector2.RIGHT, U_RADIUS)
			return
		if Global.turn_sign_reached(s.global_position, p, h, ROADS):
			seen.append(s)
			_start_arc(_snap_dir(h.rotated(-PI / 2.0 if s == left_sign else PI / 2.0)), h)
			return

func _snap_dir(v: Vector2) -> Vector2:
	return Vector2(roundf(v.x), roundf(v.y))

func _dir_letter(v: Vector2) -> String:
	if v.x > 0.5:
		return "R"
	if v.x < -0.5:
		return "L"
	return "D" if v.y > 0.0 else "U"

# A quarter turn from heading `from` to heading `to`. Our car coming from the left and turning up lands in the
# middle of the left lane of the road going up, even if the sign is up to one grid box too early (wider arc).
func _start_arc(to: Vector2, from := Vector2.RIGHT, radius := -1.0) -> void:
	state = "arc"
	arc_from = from
	arc_to = to
	var base := 2.0 * SPEED * TURN_TIME / PI
	if radius > 0.0:
		arc_radius = radius
	elif from == Vector2.RIGHT and to == Vector2.UP:
		arc_radius = clampf(WEST_LANE_X - car.global_position.x, base, base + FORGIVE)
	else:
		arc_radius = base
	arc_theta = 0.0
	arc_start = car.global_position
	var t: Array = car.TURNS[_dir_letter(from) + _dir_letter(to)]
	car.car.rotation_degrees = t[0]
	car.car.flip_h = t[1]
	car.car.stop()
	car.car.frame = 0
	car.car.play("turn", 1.0 / ((PI / 2.0) * arc_radius / SPEED))

# The traffic signal: red for a moment, then green.
func _run_light() -> void:
	var icon: AnimatedSprite2D = light.traff_icon
	icon.stop()
	icon.frame = 0
	await get_tree().create_timer(1.0).timeout
	icon.speed_scale = 2.0
	icon.play("traffic")
	get_tree().create_timer(0.3).timeout.connect(icon.pause)

# The whole car has to stay on the asphalt (not on a curb or the grass).
func _check_on_road() -> void:
	var p := car.global_position
	if p.y < 40.0 or p.y > 700.0 or p.x < 30.0:      # (nearly) off the screen: it just drives off, nothing to check any more
		return
	for d in [Vector2.ZERO, Vector2(20, 0), Vector2(-20, 0), Vector2(0, 20), Vector2(0, -20)]:
		if not _asphalt_at(p + d):
			_fail("pavement")
			return

func _fail(why: String) -> void:
	if finished:
		return
	finished = true
	reason = why
	if why == "pavement" and arc_radius > 0.0 and arc_to == Vector2.UP and arc_from == Vector2.RIGHT:
		reason = "too_early" if arc_start.x + arc_radius < WEST_LANE_X + 10.0 else "too_late"
	death._on_car_death()

func death_feedback() -> String:
	if reason == "too_early":
		return "The car only turns after it has passed the sign."
	if reason == "too_late":
		return "The sign was too far from the turn for the car to react to it. Try again!"
	return "You crashed into the pavement. Try again."

func not_home_feedback() -> String:
	return "The car did not reach home. Try again."

# --- is this point on the asphalt? (the tile pixel is dark asphalt or a white marking) ---
var _sheet_images := {}

func _sheet_image(source_id: int) -> Image:
	if not _sheet_images.has(source_id):
		var src := roads.tile_set.get_source(source_id) as TileSetAtlasSource
		_sheet_images[source_id] = src.texture.get_image()
	return _sheet_images[source_id]

func _asphalt_at(p: Vector2) -> bool:
	var cell := roads.local_to_map(roads.to_local(p))
	var source_id := roads.get_cell_source_id(cell)
	if source_id < 0:
		return false
	var src := roads.tile_set.get_source(source_id) as TileSetAtlasSource
	var size := src.texture_region_size
	var atlas := roads.get_cell_atlas_coords(cell)
	var top_left := roads.map_to_local(cell) - Vector2(size) / 2.0
	var off := roads.to_local(p) - top_left
	var px := clampi(int(off.x), 0, size.x - 1)
	var py := clampi(int(off.y), 0, size.y - 1)
	var c := _sheet_image(source_id).get_pixel(atlas.x * size.x + px, atlas.y * size.y + py)
	if c.a < 0.5:
		return false
	var l := c.get_luminance()
	return l < 0.2 or l > 0.8
