# Zip code 2, level 6: a T junction, the road across has two lanes, the road going up from the middle
# has two lanes too, and HOME is at its top. Our car (upper lane) and a second car (lower lane) drive
# right side by side. A person is standing in the right lane of the road going up (the NPC).
#  - Nothing placed: both cars drive on to the right edge (not home).
#  - Compulsory LEFT TURN only: both cars turn onto the top road (the lower car takes the longer turn and
#    ends in the right lane): it drives into the standing person and the level is over.
#  - A TRAFFIC SIGNAL right next to the person (beside the road going up): it stops both cars in front of him,
#    he sees that and runs off the road (like the pedestrians of level 1), then both cars go, turn, and we get
#    home. A signal further away stops the cars too, but the person does not react.
# Every sign works on every car that is close enough to it (see SIGN_RULES.md): the turn signs reach
# 180 px sideways; the stop sign and the traffic signal work on the whole road they stand next to.
extends Node2D

const HIGHWAY_CAR := preload("res://scenes/Level4/highway_car.tscn")
const PERSON := preload("res://scenes/npc.tscn")      # the pedestrian of level 1

const CAR_SCALE := 0.55
const LANE_Y := 320.0             # upper lane (our car)
const OTHER_Y := 380.0            # lower lane (the second car)
const START_X := 85.0             # both cars start side by side
const PERSON_POS := Vector2(470.0, 100.0)   # the person standing in the right lane of the road going up
const FLEE_TO_X := 585.0          # ... runs to the grass beside the road
const FLEE_SPEED := 110.0
const FLEE_DELAY := 0.4           # seconds after the cars stop
const PERSON_SEE_RANGE := 170.0   # the person only reacts to a signal close to him (he sees the car stop in front of him)
const LANE_GAP := 60.0            # distance between the two lanes: the lower car turns with a radius that much bigger
const SPEED := 150.0
const TURN_TIME := 0.7            # seconds our quarter turn takes (the radius follows the speed)
const CROSS_DISTANCE := 75.0      # a car turns once it has completely crossed the sign
const TURN_REACH := 180.0         # a turn sign this close (sideways) to a car's lane is seen by it
const ROADS := [Rect2(-20, 260, 960, 180), Rect2(350, -130, 180, 390)]   # the road across and the road up (with their curbs): a stop sign / traffic signal belongs to the one it stands next to
const STOP_SECONDS := 1.5
const U_RADIUS := 30.0           # a U-turn is two quarter turns with this radius (half the lane gap: upper lane -> lower lane)
const OFFSCREEN_X := 1000.0       # driven on past the junction, off the right edge
const WEST_LANE_X := 410.0        # centre of the left lane of the road going up (our car lands here)
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
@onready var sidebar_rect: Node = $ColorRect

var other_car: CharacterBody2D      # the second car
var npc: Node2D                    # the standing person
var fleeing := false
var state := "drive"        # drive, arc, free
var finished := false
var reason := ""
var hold := 0.0
var arc_radius := 0.0
var arc_theta := 0.0
var arc_start := Vector2.ZERO
var arc_from := Vector2.RIGHT
var uturn_next := false        # our car is in the first half of a U-turn
var other_uturn := false       # the second car is in the first half of a U-turn
var arc_to := Vector2.UP
var free_heading := Vector2.RIGHT
var seen_car: Array = []
var seen_other: Array = []

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
	car.death.connect(func(): _crashed_into(car.last_hit))
	other_car = _spawn(Vector2(START_X, OTHER_Y), Vector2.RIGHT, SPEED)
	npc = PERSON.instantiate()
	npc.name = "person"
	npc.position = PERSON_POS
	npc.add_to_group("npc")
	add_child(npc)
	move_child(npc, sidebar_rect.get_index())
	# The signs' own rays are made for the older levels: this script applies the signs to the cars.
	for c in [car, other_car]:
		if "turned" in u_sign:
			u_sign.turned.append(c)
		if "stopped" in stop_sign:
			stop_sign.stopped.append(c)
		if "handled_cars" in light:
			light.handled_cars.append(c)
		if "turned" in right_sign:
			right_sign.turned.append(c)
	light.ray_used = true

func _spawn(pos: Vector2, dir: Vector2, spd: float) -> CharacterBody2D:
	var c: CharacterBody2D = HIGHWAY_CAR.instantiate()
	c.position = pos
	c.scale = Vector2.ONE * CAR_SCALE
	c.direction = dir
	c.speed = spd
	c.skin = "grey"
	c.hit_player.connect(_crashed_into.bind(c))
	c.crashed.connect(_other_car_crashed)
	add_child(c)
	move_child(c, sidebar_rect.get_index())
	return c

# The turn signs snap to a road (see Global.sign_heading): this level's roads.
func sign_roads() -> Array:
	return ROADS

func _placed(s: Node2D) -> bool:
	return s.global_position.x < 933.0

func _physics_process(delta: float) -> void:
	if finished or not Global.play:
		return
	if fleeing and is_instance_valid(npc) and npc.position.x < FLEE_TO_X:
		npc.position.x = minf(npc.position.x + FLEE_SPEED * delta, FLEE_TO_X)
	_signs_for_other_car()
	match state:
		"drive":
			car.velocity = Vector2(SPEED, 0.0)
			_signs_for_car(Vector2.RIGHT)
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
			if free_heading.x < 0.0 and car.global_position.x < -60.0:    # drove back off the left edge (U-turn)
				finished = true
				reason = "uturn"
				not_home._on_car_death()
				return
			_signs_for_car(free_heading)
			_check_on_road()
	if hold > 0.0:
		hold -= delta
		car.velocity = Vector2.ZERO
	car.velocity *= Global.speed_mult
	_check_other_car_on_road()

# --- the signs, for our car -----------------------------------------------------------------------
func _signs_for_car(h: Vector2) -> void:
	var p := car.global_position
	for s in [stop_sign, light]:
		if s in seen_car or not _placed(s):
			continue
		if Global.car_on_sign_road(s.global_position, ROADS, p, h) and _at_line(s, p, h):
			seen_car.append(s)
			if not Global.sign_stops_heading(s, h):
				continue
			hold = STOP_SECONDS
			if s == light:
				_run_light()
				_flee_soon()
	for s in [left_sign, right_sign, u_sign]:
		if s in seen_car or not _placed(s):
			continue
		if _turn_reached(s, p, h):
			seen_car.append(s)
			if s == u_sign:
				uturn_next = true
				_start_arc(Vector2.DOWN, Vector2.RIGHT, U_RADIUS)
			else:
				_start_arc(_snap_dir(h.rotated(-PI / 2.0 if s == left_sign else PI / 2.0)), h)
			return

# Has the car at p come up to the line of the stop sign / traffic signal s? On the road across the car stops
# at the sign. On the road going up it stops 52 px before the sign (so a sign right beside the person still
# leaves room), but at the latest at y = 225 (clear of the junction, where the cars have just turned).
func _at_line(s: Node2D, p: Vector2, h: Vector2) -> bool:
	if h == Vector2.RIGHT:
		var d: float = (p - s.global_position).dot(h)
		return d >= -12.0 and d <= 40.0
	var stop_y := minf(s.global_position.y + 52.0, 225.0)
	return p.y <= stop_y and p.y >= stop_y - 60.0

# Radius of the (upper lane) quarter turn started at x: the normal radius, a little wider when the sign stands
# up to about one grid box too early (the car then still lands in the middle of its lane).
func _turn_radius(x: float) -> float:
	var base := 2.0 * SPEED * TURN_TIME / PI
	return clampf(WEST_LANE_X - x, base, base + FORGIVE)

func _start_arc(to: Vector2, from := Vector2.RIGHT, radius := -1.0) -> void:
	state = "arc"
	arc_from = from
	arc_to = to
	arc_radius = radius if radius > 0.0 else (_turn_radius(car.global_position.x) if (from == Vector2.RIGHT and to == Vector2.UP) else 2.0 * SPEED * TURN_TIME / PI)
	arc_theta = 0.0
	arc_start = car.global_position
	var t: Array = car.TURNS[_dir_letter(from) + _dir_letter(to)]
	car.car.rotation_degrees = t[0]
	car.car.flip_h = t[1]
	car.car.stop()
	car.car.frame = 0
	car.car.play("turn", 1.0 / ((PI / 2.0) * arc_radius / SPEED))

# Has the car at p (driving along h) come up to the turn sign s? Left / right turn signs follow the road-based
# rule (the sign belongs to one road and one direction); the U-turn sign keeps its reach.
func _turn_reached(s: Node2D, p: Vector2, h: Vector2) -> bool:
	if s == u_sign:
		var rel: Vector2 = p - s.global_position
		return h == Vector2.RIGHT and absf(rel.y) <= TURN_REACH and rel.x >= CROSS_DISTANCE and rel.x <= CROSS_DISTANCE + 40.0
	return Global.turn_sign_reached(s.global_position, p, h, ROADS)

func _snap_dir(v: Vector2) -> Vector2:
	return Vector2(roundf(v.x), roundf(v.y))

func _dir_letter(v: Vector2) -> String:
	if v.x > 0.5:
		return "R"
	if v.x < -0.5:
		return "L"
	return "D" if v.y > 0.0 else "U"

# --- the same signs, the same rules, for the second car -----------------------------------------------
func _signs_for_other_car() -> void:
	var c := other_car
	if is_instance_valid(c) and other_uturn and not c.turning and c.direction == Vector2.DOWN:
		other_uturn = false                     # second half of the U-turn: down -> left
		c.start_turn(Vector2.LEFT, U_RADIUS, SPEED)
	if not is_instance_valid(c) or c.turning or other_uturn:
		return
	var p := c.global_position
	var h: Vector2 = c.direction
	for s in [stop_sign, light]:
		if s in seen_other or not _placed(s):
			continue
		if Global.car_on_sign_road(s.global_position, ROADS, p, h) and _at_line(s, p, h):
			seen_other.append(s)
			if not Global.sign_stops_heading(s, h):
				continue
			c.stop_for(STOP_SECONDS)
			if s == light:
				_run_light()
				_flee_soon()
	for s in [left_sign, right_sign, u_sign]:
		if s in seen_other or not _placed(s):
			continue
		if _turn_reached(s, p, h):
			seen_other.append(s)
			if s == u_sign:
				other_uturn = true
				c.start_turn(Vector2.DOWN, U_RADIUS, SPEED)
				return
			# The lower car turns around the same corner as ours, so its turn is longer by the lane gap.
			var to := _snap_dir(h.rotated(-PI / 2.0 if s == left_sign else PI / 2.0))
			var r := (_turn_radius(p.x) + LANE_GAP) if h == Vector2.RIGHT else 2.0 * SPEED * TURN_TIME / PI
			c.start_turn(to, r, SPEED)
			return

# The second car, once sent round a corner, has to stay on the asphalt too.
func _check_other_car_on_road() -> void:
	var c := other_car
	if not is_instance_valid(c) or not (c.turning or c.direction.y != 0.0):
		return
	var p := c.global_position
	if p.y < 40.0 or p.y > 660.0 or p.x > 940.0:
		return
	for d in [Vector2.ZERO, Vector2(16, 0), Vector2(-16, 0), Vector2(0, 16), Vector2(0, -16)]:
		if not _asphalt_at(p + d):
			reason = "other_crash"
			_fail()
			return

# The person sees the cars stop and runs off the road (like the pedestrians of level 1).
func _flee_soon() -> void:
	if fleeing or not is_instance_valid(npc):
		return
	if light.global_position.distance_to(npc.global_position) > PERSON_SEE_RANGE:
		return                             # the signal is too far from the person: he does not see the cars stop
	await get_tree().create_timer(FLEE_DELAY).timeout
	fleeing = true

# The traffic signal: red for a moment, then green.
func _run_light() -> void:
	var icon: AnimatedSprite2D = light.traff_icon
	icon.stop()
	icon.frame = 0
	await get_tree().create_timer(1.0).timeout
	icon.speed_scale = 2.0
	icon.play("traffic")
	get_tree().create_timer(0.3).timeout.connect(icon.pause)

# --- crashes and endings ---------------------------------------------------------------------
# Our whole car has to stay on the asphalt (not on a curb or the grass).
func _check_on_road() -> void:
	var p := car.global_position
	if p.y < 40.0:                    # off the top of the screen: nothing to check any more
		return
	for d in [Vector2.ZERO, Vector2(20, 0), Vector2(-20, 0), Vector2(0, 20), Vector2(0, -20)]:
		if not _asphalt_at(p + d):
			if arc_radius > 0.0 and arc_to == Vector2.UP and arc_from == Vector2.RIGHT:
				reason = "too_early" if arc_start.x + arc_radius < WEST_LANE_X + 10.0 else "too_late"
			else:
				reason = "pavement"
			_fail()
			return

func _crashed_into(_other: Node) -> void:
	if finished:
		return
	if _other == other_car:
		reason = "other_car"
	elif _other == npc:
		reason = "person"
	else:
		reason = "crash"
	_fail()

func _other_car_crashed() -> void:
	if finished:
		return
	reason = "other_crash"
	_fail()

func _fail() -> void:
	if finished:
		return
	finished = true
	death._on_car_death()

func death_title() -> String:
	return "A DIFFERENT CAR CRASHED!" if reason == "other_crash" else ""

func death_feedback() -> String:
	match reason:
		"other_car":
			return "You crashed into the other car. Try again."
		"person":
			return "Try not to hit the pedestrian. Try again!"
		"other_crash":
			if _placed(light) and light.global_position.distance_to(npc.global_position) > PERSON_SEE_RANGE:
				return "The person did not see the cars stop. Place the signal closer to them."
			return "The other car ran into the person standing in the lane. Find a way to make them move first."
		"too_early":
			return "The car only turns after it has passed the sign."
		"too_late":
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
