# Level 5: a cross junction. Our car starts on the left road pointing right; the road across is
# a dual carriageway (cars on the left half drive up, cars on the right half drive down) with
# a divider in the middle that has a gap, like Level 2.
#
# How the level is solved (one item per step):
#  1. GIVE WAY near the junction: the car waits for the fast traffic on the left half, then
#     merges slowly and drives up.
#  2. ONE WAY in the top left (next to the road): without it a car comes down our lane the
#     wrong way and hits us.
#  3. U-TURN on the divider before the gap: the car turns through the gap onto the right half
#     and drives down.
#  4. COMPULSORY LEFT TURN in the top right, just before the road to the right starts: the car
#     turns onto that road and drives towards home.
#  5. CATTLE AHEAD beside that road: the car waits (3 seconds), the slow cow walks off the road,
#     and the car reaches home.
extends Node2D

const HIGHWAY_CAR := preload("res://scenes/Level4/highway_car.tscn")

# --- the map (world pixels) ---
const ARM_Y := 320.0           # upper lane of the horizontal road (the lane our car drives in)
const LINE_X := 175.0          # where the car waits at the give way line (car centre)
const NB_X := 245.0            # lane of the left half our car joins (traffic drives up)
const NB2_X := 305.0           # the other lane of the left half
const SB_X := 575.0            # lane of the right half our car drives down after the U-turn
const SB_W_X := 515.0          # the other lane of the right half
const GAP_Y := 125.0           # middle of the gap in the divider
const ROAD_TOP := 260.0
const CAR_SCALE := 0.55        # the cars of this level are smaller so they fit the lanes

# --- driving ---
const CRUISE := 200.0          # px/s on the first road (50 km/h)
const SLOW := 100.0            # px/s when giving way / merging
const RUN := 120.0             # px/s going up the left half
const DOWN_SPEED := 150.0      # px/s going down the right half and along the last road
const TURN_TIME := 0.7         # seconds a quarter turn takes (the radius follows the speed)
const U_RADIUS := 60.0         # radius of the two quarter turns of the U-turn
const WAIT_Y := 300.0          # a car above this y has already passed the junction
const STOP_SECONDS := 3.0      # the wait at the cattle sign: stop sign time + traffic signal time

# --- where the signs count ---
const GIVE_WAY_RANGE := 300.0  # the give way sign must be this close to the junction (west of it)
const ONE_WAY_RECT := Rect2(0, 0, 215, 290)           # the top left, next to the road
const DIVIDER_X := Vector2(365.0, 455.0)              # the divider (x range)
const LEFT_SIGN_X := Vector2(605.0, 825.0)            # top right, right of the road going down
const CATTLE_X := Vector2(640.0, 720.0)               # beside the last road, before the cow
const CROSS_DISTANCE := 75.0   # a car turns once it has completely crossed the sign
const SIGN_REACH := 150.0     # a stop sign / traffic signal / right turn this close (sideways) to a car is seen by it
const SIGN_STOP_SECONDS := 1.5
const NPC_SIGN_REACH := 100.0 # the other cars only see a stop sign / traffic signal right beside their road
const NPC_TURN_REACH := 150.0 # ... and a compulsory turn sign is seen by every car this close to it, like our car
const TURN_SPEED := 150.0       # the other cars slow down to this when a turn sign sends them round a corner
const NB_CENTER := 275.0       # middle of the left half / the right half (to tell their lanes apart)
const SB_CENTER := 545.0

@onready var car: CharacterBody2D = $car
@onready var roads: TileMapLayer = $Roads
@onready var death: Node2D = $death
@onready var not_home: Node2D = $not_home
@onready var sidebar_rect: Node = $ColorRect
@onready var cow: Node = $Cow
@onready var give_way: Node2D = $give_way
@onready var one_way: Node2D = $one_way
@onready var u_sign: Node2D = $u_turn
@onready var left_sign: Node2D = $left_turn
@onready var cattle_sign: Node2D = $cattle_ahead
@onready var light: Node2D = $traffic_signal
@onready var stop_sign: Node2D = $stop
@onready var right_sign: Node2D = $turn
@onready var nostop_sign: Node2D = $no_stopping

var state := "drive"       # drive, wait, creep, arc, north, cross, south, arm
var speed := CRUISE
var merge_speed := CRUISE
var hold := 0.0            # seconds the car still has to stand at the cattle sign
var cattle_seen := false
var wrong_way_sent := false
var uturning := false
var north_start_y := 0.0
var finished := false
var reason := ""

# the quarter turn being driven
var arc_from := Vector2.RIGHT
var arc_to := Vector2.UP
var arc_radius := 0.0
var arc_speed := 0.0
var arc_theta := 0.0
var arc_start := Vector2.ZERO
var arc_angle_from := 0.0
var arc_angle_to := 0.0
var arc_next := ""
var seen: Array = []         # signs our car already obeyed (stop sign, traffic signal, right turn)
var free_heading := Vector2.RIGHT   # after a compulsory right turn the car just drives on this way
var free_speed := 0.0

func _ready() -> void:
	Global.speed_mult = 1.0
	Global.speed_limit_kmh = 50.0
	Global.extra_road_rects.clear()
	Global.next_level = ""                       # last level for now
	car.turn_sig = true                          # this script drives the car, not the road tiles
	car.scale = Vector2.ONE * CAR_SCALE
	car.global_position = Vector2(60.0, ARM_Y)
	car.car.animation = &"turn"
	car.car.frame = 0                            # facing right
	car.car.rotation_degrees = 0.0
	car.car.flip_h = false
	_set_hitbox_angle(0.0)
	car.death.connect(func(): _crashed_into(car.last_hit))
	# The earlier signs are in the tray too. They work as in the other levels. For our car this script
	# applies them (it drives up and down, the signs' own rays are made for sideways traffic), so the
	# rays must not act on it a second time.
	for s in [light, stop_sign, right_sign]:
		if "turned" in s:
			s.turned.append(car)
		if "stopped" in s:
			s.stopped.append(car)
		if "handled_cars" in s:
			s.handled_cars.append(car)
			s.ray_used = true
	# Traffic on the left half (drives up): a platoon of cars, the first ones are in view.
	for y in [520.0, 820.0, 1120.0, 1420.0, 1720.0]:
		_spawn(NB_X, y, Vector2.UP, 450.0)
	for y in [380.0, 980.0, 1380.0]:
		_spawn(NB2_X, y, Vector2.UP, 450.0)
	# Traffic on the right half (drives down), already gone by the time the car gets there.
	# Both lanes have traffic. The cars of the lane next to the turn (SB_X) obey a compulsory left turn
	# (and so turn onto the cattle road); the ones in the other lane drive straight on. There is only
	# one car in that lane: a second one would run into it while it waits at the cattle sign.
	for y in [-60.0, -330.0, -630.0]:
		_spawn(SB_W_X, y, Vector2.DOWN, 400.0)
	_spawn(SB_X, -180.0, Vector2.DOWN, 400.0)

func _spawn(x: float, y: float, dir: Vector2, spd: float) -> Node:
	var c: CharacterBody2D = HIGHWAY_CAR.instantiate()
	c.position = Vector2(x, y)
	c.scale = Vector2.ONE * CAR_SCALE
	c.direction = dir
	c.speed = spd
	c.skin = "grey"
	c.hit_player.connect(_crashed_into.bind(c))
	c.crashed.connect(_other_car_crashed)
	add_child(c)
	move_child(c, sidebar_rect.get_index())      # drawn below the sidebar
	return c

func _set_hitbox_angle(a: float) -> void:
	car.get_node("CollisionShape2D").rotation = a
	car.get_node("Area2D").rotation = a

# --- where the signs stand -------------------------------------------------------------------
func _placed(s: Node2D) -> bool:
	return s.global_position.x < 933.0

func _give_way_ok() -> bool:
	var p := give_way.global_position
	return _placed(give_way) and p.x < 235.0 and p.distance_to(Vector2(LINE_X, ARM_Y)) <= GIVE_WAY_RANGE

func _one_way_ok() -> bool:
	return _placed(one_way) and ONE_WAY_RECT.has_point(one_way.global_position)

func _u_turn_ok() -> bool:
	var p := u_sign.global_position
	return _placed(u_sign) and p.x >= DIVIDER_X.x and p.x <= DIVIDER_X.y

# The U-turn sign stands on the divider south of the gap: the car turns through the gap. A sign
# on the divider north of the gap is too late: the car turns where it sees it (into the divider).
func _u_turn_before_gap() -> bool:
	return u_sign.global_position.y > GAP_Y + 40.0

func _left_ok() -> bool:
	var p := left_sign.global_position
	return _placed(left_sign) and p.x >= LEFT_SIGN_X.x and p.x <= LEFT_SIGN_X.y

func _cattle_ok() -> bool:
	var p := cattle_sign.global_position
	return _placed(cattle_sign) and p.x >= CATTLE_X.x and p.x <= CATTLE_X.y

# True when no car of the left half is still on its way to (or at) the junction.
func _lane_clear() -> bool:
	for c in get_tree().get_nodes_in_group("npc"):
		if c is CharacterBody2D and "direction" in c and c.direction.y < 0.0 and c.global_position.y > WAIT_Y:
			return false
	return true

# --- the car ---------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if finished or not Global.play:
		return
	_other_cars_obey_signs()
	match state:
		"drive":
			_check_player_signs()
			if state == "drive":
				_drive()
		"wait":
			car.velocity = Vector2.ZERO
			if _lane_clear():
				state = "creep"
		"creep":
			_check_player_signs()
			if state == "creep":
				_creep()
		"arc":
			_arc(delta)
			_check_on_road()
		"north":
			_check_player_signs()
			if state == "north":
				_north()
			_check_on_road()
		"cross":
			_check_player_signs()
			if state == "cross":
				_cross()
			_check_on_road()
		"south":
			_check_player_signs()
			if state == "south":
				_south()
			_check_on_road()
		"arm":
			_check_player_signs()
			if state == "arm":
				_arm()
			_check_on_road()
		"free":
			_check_player_signs()
			if state == "free":
				_free()
			_check_on_road()
	if hold > 0.0:                               # waiting at the cattle sign
		hold -= delta
		car.velocity = Vector2.ZERO
	car.velocity *= Global.speed_mult

func _arc_radius(v: float) -> float:
	return 2.0 * v * TURN_TIME / PI

func _drive() -> void:
	var x := car.global_position.x
	if _give_way_ok():
		var dist := LINE_X - x
		if dist <= 1.0:
			state = "wait"
			car.velocity = Vector2.ZERO
			return
		speed = clampf(dist * 3.0, 40.0, CRUISE)
		merge_speed = SLOW
	else:
		speed = CRUISE
		merge_speed = CRUISE
		if x >= NB_X - _arc_radius(SLOW):
			_merge()
			return
	car.velocity = Vector2(speed, 0.0)

func _creep() -> void:
	car.velocity = Vector2(SLOW, 0.0)
	if car.global_position.x >= NB_X - _arc_radius(SLOW):
		merge_speed = SLOW
		_merge()

func _merge() -> void:
	_start_arc(Vector2.RIGHT, Vector2.UP, _arc_radius(SLOW), merge_speed, "RU", "north")   # always a tight turn: it starts inside the junction

# Starts a quarter turn from heading `from` to heading `to`; the car turns while it keeps moving.
func _start_arc(from: Vector2, to: Vector2, radius: float, v: float, key: String, next: String) -> void:
	state = "arc"
	arc_from = from
	arc_to = to
	arc_radius = radius
	arc_speed = v
	arc_theta = 0.0
	arc_start = car.global_position
	arc_next = next
	arc_angle_from = PI / 2.0 if from.y != 0.0 else 0.0
	arc_angle_to = PI / 2.0 if to.y != 0.0 else 0.0
	var t: Array = car.TURNS[key]
	car.car.rotation_degrees = t[0]
	car.car.flip_h = t[1]
	car.car.stop()
	car.car.frame = 0                            # the "turn" animation from its first frame
	var duration := (PI / 2.0) * radius / v
	car.car.play("turn", 1.0 / duration)

func _arc(delta: float) -> void:
	arc_theta = minf(arc_theta + (arc_speed / arc_radius) * delta, PI / 2.0)
	car.velocity = (arc_from * cos(arc_theta) + arc_to * sin(arc_theta)) * arc_speed
	_set_hitbox_angle(lerpf(arc_angle_from, arc_angle_to, arc_theta / (PI / 2.0)))
	if arc_theta >= PI / 2.0:
		car.global_position = arc_start + (arc_from + arc_to) * arc_radius   # settle exactly
		state = arc_next
		_arrived(arc_next)

func _arrived(next: String) -> void:
	match next:
		"north":
			north_start_y = car.global_position.y
			if not _one_way_ok() and not wrong_way_sent:
				wrong_way_sent = true        # a car comes down our lane the wrong way
				_spawn(NB_X, -90.0, Vector2.DOWN, 250.0)
		"arm":
			pass

func _north() -> void:
	car.velocity = Vector2(0.0, -RUN)
	var y := car.global_position.y
	if _u_turn_ok():
		var turn_y := (GAP_Y + U_RADIUS) if _u_turn_before_gap() else (u_sign.global_position.y - 30.0)
		# The sign counts when it stands ahead of the car; the car turns where it sees it.
		if turn_y <= north_start_y and y <= turn_y:
			uturning = true
			_start_arc(Vector2.UP, Vector2.RIGHT, U_RADIUS, RUN, "UR", "cross")
			return
	if y < -70.0:
		_not_home()

func _cross() -> void:
	car.velocity = Vector2(RUN, 0.0)
	if car.global_position.x >= SB_X - U_RADIUS:
		_start_arc(Vector2.RIGHT, Vector2.DOWN, U_RADIUS, RUN, "RD", "south")

func _south() -> void:
	car.velocity = Vector2(0.0, DOWN_SPEED)
	var y := car.global_position.y
	if y > 700.0:
		_not_home()

func _arm() -> void:
	car.velocity = Vector2(DOWN_SPEED, 0.0)
	if not cattle_seen and _cattle_ok() and car.global_position.x >= cattle_sign.global_position.x - 60.0:
		if not cow.started:
			cattle_seen = true
			hold = STOP_SECONDS                  # the car waits; the cow notices the sign and walks off
			cow.start_walking()
		elif cow.walking:
			hold = 0.2                           # another car already sent the cow away: wait until it is clear
		else:
			cattle_seen = true                   # the cow is gone already: no need to wait

# --- crashes and endings ---------------------------------------------------------------------
func _check_on_road() -> void:
	var p := car.global_position
	if p.y < -60.0 or p.y > 660.0:
		return
	for d in [Vector2.ZERO, Vector2(20, 0), Vector2(-20, 0), Vector2(0, 20), Vector2(0, -20)]:
		if not _asphalt_at(p + d):
			reason = "divider" if (uturning and p.y < ROAD_TOP and p.x < 520.0) else "pavement"
			_fail()
			return

func _crashed_into(other: Node) -> void:
	if finished:
		return
	if other != null and other.is_in_group("cow"):
		reason = "cow"
	elif other != null and "direction" in other and other.direction.y > 0.0 and other.global_position.y < car.global_position.y + 80.0 and other.global_position.x < 320.0:
		reason = "wrong_way"
	else:
		reason = "traffic"
	_fail()

func _other_car_crashed() -> void:
	if finished:
		return
	reason = "other_crash"
	_fail()

func _not_home() -> void:
	if finished:
		return
	finished = true
	not_home._on_car_death()

func _fail() -> void:
	if finished:
		return
	finished = true
	death._on_car_death()

# --- feedback on the failure screens -----------------------------------------------------------
func death_title() -> String:
	return "A DIFFERENT CAR CRASHED!" if reason == "other_crash" else ""

func death_feedback() -> String:
	match reason:
		"other_crash":
			return "Try finding a way to make everyone drive safely."
		"traffic":
			if not _placed(give_way):
				return "Find a way to make the car wait for the traffic to clear."
			return "The Give Way sign needs to be close to the junction, before the car reaches the traffic."
		"wrong_way":
			if not _placed(one_way):
				return "A car drove down your lane the wrong way."
			return "The One Way sign needs to be at the top left, next to the road."
		"divider":
			return "You crashed into the divider. Try again."
		"pavement":
			return "You crashed into the pavement. Try again."
		"cow":
			return "Try not to hit the cow. Try again!"
	return ""

func not_home_feedback() -> String:
	return "The car did not reach home. Try again."

# --- is this point on the road? ---------------------------------------------------------------
# The road is made of tiles from two tile sheets, so the picture itself is asked: a point is on
# the road when the tile pixel there is dark asphalt or a white road marking (not transparent
# and not the grey of a curb).
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

# --- the signs of the earlier levels ------------------------------------------------------------
# The stop sign and the traffic signal stop a car for 1.5 s, the compulsory right turn makes it turn
# right after it has completely crossed the sign (nearly always onto the grass or into the
# traffic). The no stopping sign has no effect of its own here.
func _player_heading() -> Vector2:
	match state:
		"north": return Vector2.UP
		"south": return Vector2.DOWN
		"free": return free_heading
	return Vector2.RIGHT

func _state_speed() -> float:
	match state:
		"north", "cross": return RUN
		"south", "arm": return DOWN_SPEED
		"free": return free_speed
	return maxf(speed, SLOW)

func _check_player_signs() -> void:
	var h := _player_heading()
	var p := car.global_position
	for s in [stop_sign, light]:
		if s in seen or not _placed(s):
			continue
		var rel: Vector2 = p - s.global_position
		if absf(rel.dot(h.rotated(PI / 2.0))) > SIGN_REACH:
			continue
		var d := rel.dot(h)                      # how far the car is past the sign
		if d >= -12.0 and d <= 40.0:
			seen.append(s)
			hold = SIGN_STOP_SECONDS
			if s == light:
				_run_light()
			return
	if right_sign not in seen and _placed(right_sign):
		var rel2: Vector2 = p - right_sign.global_position
		if absf(rel2.dot(h.rotated(PI / 2.0))) <= SIGN_REACH:
			var d2 := rel2.dot(h)
			if d2 >= CROSS_DISTANCE and d2 <= CROSS_DISTANCE + 40.0:
				seen.append(right_sign)
				_turn_right(h)
				return
	if left_sign not in seen and _placed(left_sign):
		var rel3: Vector2 = p - left_sign.global_position
		if absf(rel3.dot(h.rotated(PI / 2.0))) <= SIGN_REACH:
			var d3 := rel3.dot(h)
			if d3 >= CROSS_DISTANCE and d3 <= CROSS_DISTANCE + 40.0:
				seen.append(left_sign)
				_turn_left(h)

func _turn_right(h: Vector2) -> void:
	# The four directions are compared by hand: a rotated vector can come out as (-0.0, 1.0),
	# which is not the same dictionary key as Vector2.DOWN.
	var from_letter := _dir_letter(h)
	var to_letter := ""
	var h1 := Vector2.ZERO
	match from_letter:
		"R":
			to_letter = "D"
			h1 = Vector2.DOWN
		"D":
			to_letter = "L"
			h1 = Vector2.LEFT
		"L":
			to_letter = "U"
			h1 = Vector2.UP
		_:
			to_letter = "R"
			h1 = Vector2.RIGHT
	var v := _state_speed()
	free_heading = h1
	free_speed = v
	_start_arc(_dir_vector(from_letter), h1, _arc_radius(v), v, from_letter + to_letter, "free")

func _dir_letter(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "R" if v.x > 0.0 else "L"
	return "D" if v.y > 0.0 else "U"

func _dir_vector(letter: String) -> Vector2:
	match letter:
		"R": return Vector2.RIGHT
		"D": return Vector2.DOWN
		"L": return Vector2.LEFT
	return Vector2.UP

func _free() -> void:
	car.velocity = free_heading * free_speed
	var p := car.global_position
	if p.x < -120.0 or p.x > 1100.0 or p.y < -120.0 or p.y > 780.0:
		_not_home()

func _run_light() -> void:
	var icon: AnimatedSprite2D = light.traff_icon
	icon.stop()
	icon.frame = 0                                # red
	await get_tree().create_timer(1.0).timeout
	icon.speed_scale = 2.0
	icon.play("traffic")                          # red -> green
	get_tree().create_timer(0.3).timeout.connect(icon.pause)

# The other cars obey the stop sign and the traffic signal as well: a car that comes up to
# one stops for a moment. (Their pile-ups can end the level: "a different car crashed".)
func _other_cars_obey_signs() -> void:
	for c in get_tree().get_nodes_in_group("npc"):
		if not (c is CharacterBody2D and "direction" in c and c.has_method("stop_for")):
			continue
		var done: Array = c.get_meta("seen_signs", [])
		for s in [stop_sign, light]:
			if s in done or not _placed(s):
				continue
			var h: Vector2 = c.direction
			var rel: Vector2 = c.global_position - s.global_position
			if absf(rel.dot(h.rotated(PI / 2.0))) > NPC_SIGN_REACH:
				continue
			var d := rel.dot(h)
			if d >= -12.0 and d <= 40.0:
				done.append(s)
				c.set_meta("seen_signs", done)
				c.stop_for(SIGN_STOP_SECONDS)
				if s == light:
					_run_light()
		# The compulsory turns: every car that comes up to one (and is close enough to it) turns
		# after crossing it, like our car. A turn onto the grass is a crash, a turn onto a road
		# just carries on straight.
		for s in [left_sign, right_sign]:
			if s in done or not _placed(s) or c.turning:
				continue
			var h2: Vector2 = c.direction
			var rel2: Vector2 = c.global_position - s.global_position
			if absf(rel2.dot(h2.rotated(PI / 2.0))) > NPC_TURN_REACH:
				continue
			if not _in_turn_lane(c, s == left_sign):
				continue
			var d2 := rel2.dot(h2)
			if d2 >= CROSS_DISTANCE and d2 <= CROSS_DISTANCE + 40.0:
				done.append(s)
				c.set_meta("seen_signs", done)
				var turned := h2.rotated(PI / 2.0 if s == right_sign else -PI / 2.0)
				c.start_turn(_dir_vector(_dir_letter(turned)), _arc_radius(TURN_SPEED), minf(c.speed, TURN_SPEED))
				c.set_meta("turned_by_sign", true)
		# A car that has been sent onto the cattle road also sees the CATTLE AHEAD sign: it waits
		# and the cow starts to walk away.
		if c.direction.x > 0.0 and not c.turning and cattle_sign not in done and _cattle_ok():
			var cp: Vector2 = c.global_position
			if cp.y > 290.0 and cp.y < 410.0 and cp.x >= cattle_sign.global_position.x - 60.0:
				done.append(cattle_sign)
				c.set_meta("seen_signs", done)
				c.stop_for(STOP_SECONDS)
				cow.start_walking()
		# A car that was sent round a corner has to stay on the asphalt.
		if c.get_meta("turned_by_sign", false) and not c.crash_sent:
			var p: Vector2 = c.global_position
			if p.x > -60.0 and p.x < 940.0 and p.y > -60.0 and p.y < 660.0:
				for off in [Vector2.ZERO, Vector2(18, 0), Vector2(-18, 0), Vector2(0, 18), Vector2(0, -18)]:
					if not _asphalt_at(p + off):
						c.crash_sent = true
						_other_car_crashed()
						break

# Compulsory left turn: the car turns left once it has completely crossed the sign, wherever that
# is. It then drives straight on: onto the last road (home) if that is where it turns, otherwise
# until it leaves the road (a crash) or the screen.
func _turn_left(h: Vector2) -> void:
	var from_letter := _dir_letter(h)
	var to_letter := "U"
	var h1 := Vector2.UP
	match from_letter:
		"R":
			to_letter = "U"
			h1 = Vector2.UP
		"U":
			to_letter = "L"
			h1 = Vector2.LEFT
		"L":
			to_letter = "D"
			h1 = Vector2.DOWN
		_:
			to_letter = "R"
			h1 = Vector2.RIGHT
	var v := _state_speed()
	free_heading = h1
	free_speed = v
	_start_arc(_dir_vector(from_letter), h1, _arc_radius(v), v, from_letter + to_letter, "arm" if to_letter == "R" else "free")

# Only the cars in the lane on the side of the turn take a compulsory turn (the left lane for a
# left turn, the right lane for a right turn); the cars in the other lane drive straight on.
func _in_turn_lane(c: Node, left: bool) -> bool:
	var h: Vector2 = c.direction
	if h.x != 0.0:
		return true                                # a car on a horizontal road: only one lane is used
	var side := h.rotated(-PI / 2.0 if left else PI / 2.0)
	var center := NB_CENTER if c.global_position.x < 420.0 else SB_CENTER
	return (c.global_position.x - center) * side.x > 0.0
