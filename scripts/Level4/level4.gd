# Level 4: join the highway from the side road.
# - The player's car drives up the side road and turns left into the lane of fast cars.
# - Without a GIVE WAY sign (below the highway, close to the junction) it just drives on and is
#   hit by the traffic.
# - With the sign it stops at the line, waits until the lane is clear, then merges slowly.
# - A car in front brakes to a halt in that lane, unless a NO STOPPING OR STANDING sign stands
#   next to the spot where it stops. If it stops, our car runs into it. Otherwise we reach the
#   finish line at the left end of the highway.
# The signs of the earlier levels are in the tray too and work as they always do: the traffic
# signal and the stop sign stop a car, the compulsory turns / U-turn make it turn where the
# sign stands (that is almost always the wrong place here).
extends Node2D

const HIGHWAY_CAR := preload("res://scenes/Level4/highway_car.tscn")

const LANE_X := 382.0          # x of the lane going up the side road
const CAR_SCALE := 0.55        # the cars of this level are a bit smaller so they fit the lanes
const LINE_Y := 420.0          # where the car waits at the give way line (car centre)
const WEST_LANE_Y := 322.0     # centre of the lane going left (inside the curbs)
const EAST_LANE_Y := 256.0     # centre of the lane going right (inside the curbs)
const START_Y := 612.0
const CRUISE := 200.0          # px/s up the side road (50 km/h)
const SLOW := 100.0            # px/s when giving way / merging
const MERGE_TIME := 0.7        # seconds the turn onto the highway takes
const GIVE_WAY_RANGE := 300.0  # a give way sign this close to the junction (and below the highway) counts
const SIGN_REACH := 170.0      # a sign this close (sideways) to the side road is seen by our car
const STOP_SECONDS := 1.5
const WEST_SPEED := 500.0
const EAST_SPEED := 450.0
const WEST_CARS := [700.0, 1025.0, 1350.0, 1675.0]   # x of the cars coming from the right
const STALL_CAR_X := 2000.0
const STALL_X := 170.0
const WAIT_X := 300.0          # a car left of this has already passed the junction
const U_RADIUS := 28.0

@onready var car: CharacterBody2D = $car
@onready var roads: TileMapLayer = $Roads
@onready var death: Node2D = $death
@onready var not_home: Node2D = $not_home
@onready var sidebar_rect: Node = $ColorRect
@onready var give_way: Node2D = $give_way
@onready var light: Node2D = $"traffic signal"
@onready var stop_sign: Node2D = $stop
@onready var right_sign: Node2D = $turn
@onready var left_sign: Node2D = $left_turn
@onready var u_sign: Node2D = $u_turn

var state := "drive"           # drive -> wait -> creep -> merge -> run (or a turn state after a sign)
var speed := CRUISE
var merge_speed := CRUISE
var theta := 0.0
var turn_kind := ""            # right / uturn1 / uturn2 : which arc the car is driving
var turn_speed := CRUISE
var hold := 0.0                # seconds the car still has to stand (stop sign / traffic signal)
var seen: Array = []           # signs our car already obeyed
var finished := false
var reason := ""               # what went wrong, for the feedback on the failure screens
var east_timer := 0.3
var spawn_count := 0

func _ready() -> void:
	Global.speed_mult = 1.0
	Global.speed_limit_kmh = 50.0
	Global.extra_road_rects.clear()
	Global.next_level = "res://scenes/Level5/level 5.tscn"
	car.turn_sig = true                          # this script drives the car, not the road tiles
	car.scale = Vector2.ONE * CAR_SCALE
	car.global_position = Vector2(LANE_X, START_Y)
	# Facing up: the last frame of the turn animation is the car seen from the front.
	car.car.animation = &"turn"
	car.car.frame = 4
	car.car.rotation_degrees = 0.0
	car.car.flip_h = false
	_set_hitbox_angle(PI / 2.0)
	car.death.connect(func(): _crashed_into(car.last_hit))
	# The signs' own rays are made for cars driving sideways; for our car (driving up the side
	# road) this script applies the signs, so the rays must not act on it as well.
	for s in [light, stop_sign, right_sign, left_sign, u_sign]:
		if "turned" in s:
			s.turned.append(car)
		if "stopped" in s:
			s.stopped.append(car)
		if "handled_cars" in s:
			s.handled_cars.append(car)
			s.ray_used = true
	# Traffic: the cars on the highway are in place from the start (the right-hand ones wait
	# behind the sidebar), the lane going right gets new cars while the level runs.
	var skins := ["grey", "grey", "grey", "grey"]
	for i in WEST_CARS.size():
		_spawn(WEST_CARS[i], WEST_LANE_Y, Vector2.LEFT, WEST_SPEED, skins[i])
	var stall := _spawn(STALL_CAR_X, WEST_LANE_Y, Vector2.LEFT, WEST_SPEED, "grey")
	stall.stalls = true
	stall.stall_x = STALL_X
	_spawn(120.0, EAST_LANE_Y, Vector2.RIGHT, EAST_SPEED, "grey")
	_spawn(430.0, EAST_LANE_Y, Vector2.RIGHT, EAST_SPEED, "grey")
	_spawn(760.0, EAST_LANE_Y, Vector2.RIGHT, EAST_SPEED, "grey")

func _spawn(x: float, y: float, dir: Vector2, spd: float, skin: String) -> Node:
	var c: CharacterBody2D = HIGHWAY_CAR.instantiate()
	c.position = Vector2(x, y)
	c.scale = Vector2.ONE * CAR_SCALE
	c.direction = dir
	c.speed = spd
	c.skin = skin
	c.hit_player.connect(_crashed_into.bind(c))
	c.crashed.connect(_other_car_crashed)
	add_child(c)
	move_child(c, sidebar_rect.get_index())      # drawn below the sidebar
	return c

func _set_hitbox_angle(a: float) -> void:
	car.get_node("CollisionShape2D").rotation = a
	car.get_node("Area2D").rotation = a

func _give_way_placed_right() -> bool:
	# On the side-road side of the highway (below it), anywhere reasonably close to the junction.
	var p := give_way.global_position
	return p.x < 933.0 and p.y > WEST_LANE_Y + 60.0 and p.distance_to(Vector2(LANE_X, LINE_Y)) <= GIVE_WAY_RANGE

# True when no car of the left-going lane is still on its way to (or in) the junction.
func _lane_clear() -> bool:
	for c in get_tree().get_nodes_in_group("npc"):
		if c is CharacterBody2D and c.direction.x < 0 and not c.stopped and c.global_position.x > WAIT_X:
			return false
	return true

func _physics_process(delta: float) -> void:
	if finished or not Global.play:
		return
	_eastbound_traffic(delta)
	match state:
		"drive":
			_check_signs()
			if state == "drive":
				_drive()
		"wait":
			car.velocity = Vector2.ZERO
			_wait()
		"creep":
			_check_signs()
			if state == "creep":
				_creep()
		"merge":
			_merge(delta)
			_check_on_road()
		"run":
			_run(delta)
			_check_on_road()
		"turn":
			_turn(delta)
			_check_on_road()
		"off":
			_off()
			_check_on_road()
		"down":
			_down()
	if hold > 0.0:                               # standing at a stop sign / traffic signal
		hold -= delta
		car.velocity = Vector2.ZERO
	car.velocity *= Global.speed_mult

func _eastbound_traffic(delta: float) -> void:
	east_timer -= delta
	if east_timer <= 0.0:
		spawn_count += 1
		east_timer = 0.8 + 0.5 * float((spawn_count * 7) % 3)
		_spawn(-70.0, EAST_LANE_Y, Vector2.RIGHT, EAST_SPEED, "grey")

func _arc_radius(v: float) -> float:
	return 2.0 * v * MERGE_TIME / PI

# --- the signs of the other levels, applied to our car on the side road -------------------
func _check_signs() -> void:
	for s in [stop_sign, light, right_sign, left_sign, u_sign]:
		if s in seen or s.global_position.x >= 933.0:
			continue
		var p: Vector2 = s.global_position
		if absf(p.x - LANE_X) > SIGN_REACH or p.y < WEST_LANE_Y + 50.0:
			continue
		# The compulsory turns are only obeyed once the car has completely crossed the sign.
		var cross := 75.0 if (s == left_sign or s == right_sign) else -12.0
		if car.global_position.y > p.y - cross:   # our car has not reached / crossed the sign yet
			continue
		seen.append(s)
		if s == stop_sign:
			hold = STOP_SECONDS
		elif s == light:
			hold = STOP_SECONDS
			_run_light()
		elif s == left_sign:
			merge_speed = maxf(speed, 40.0)
			_begin_merge()                        # compulsory left: turn left right here
			return
		elif s == right_sign:
			_begin_turn("right")
			return
		elif s == u_sign:
			_begin_turn("uturn1")
			return

func _run_light() -> void:
	var icon: AnimatedSprite2D = light.traff_icon
	icon.stop()
	icon.frame = 0                                # red while the car waits
	await get_tree().create_timer(1.0).timeout
	icon.speed_scale = 2.0
	icon.play("traffic")                          # red -> green
	get_tree().create_timer(0.3).timeout.connect(icon.pause)

func _drive() -> void:
	var y := car.global_position.y
	if _give_way_placed_right():
		# Slow down towards the line and stop there.
		var dist := y - LINE_Y
		if dist <= 1.0:
			state = "wait"
			car.velocity = Vector2.ZERO
			return
		speed = clampf(dist * 3.0, 40.0, CRUISE)
		merge_speed = SLOW
	else:
		speed = CRUISE
		merge_speed = CRUISE
		if y <= WEST_LANE_Y + _arc_radius(merge_speed):
			_begin_merge()
			return
	car.velocity = Vector2(0, -speed)

func _wait() -> void:
	if _lane_clear():
		state = "creep"

func _creep() -> void:
	# Lane is clear: roll forward slowly to where the turn starts.
	car.velocity = Vector2(0, -SLOW)
	if car.global_position.y <= WEST_LANE_Y + _arc_radius(SLOW):
		merge_speed = SLOW
		_begin_merge()

func _begin_merge() -> void:
	state = "merge"
	theta = 0.0
	car.car.rotation_degrees = -90.0              # the "turn" animation, turning from up to left
	car.car.flip_h = false
	car.car.stop()
	car.car.frame = 0                             # start the turn animation from its first frame
	car.car.play("turn", 1.0 / MERGE_TIME)

func _merge(delta: float) -> void:
	var w := (PI / 2.0) / MERGE_TIME
	theta = minf(theta + w * delta, PI / 2.0)
	car.velocity = Vector2(-sin(theta), -cos(theta)) * merge_speed
	_set_hitbox_angle(PI / 2.0 * (1.0 - theta / (PI / 2.0)))
	if theta >= PI / 2.0:
		if absf(car.global_position.y - WEST_LANE_Y) < 14.0:
			car.global_position.y = WEST_LANE_Y   # turned at the junction: settle in the lane
		state = "run"
		speed = merge_speed

func _run(delta: float) -> void:
	speed = minf(speed + 60.0 * delta, 150.0)      # pull away gently
	car.velocity = Vector2.LEFT * speed
	if absf(car.global_position.y - WEST_LANE_Y) < 14.0:
		car.global_position.y = WEST_LANE_Y

# --- turning at a sign of another level (a right turn / U-turn sign on the side road) ----
func _begin_turn(kind: String) -> void:
	state = "turn"
	turn_kind = kind
	theta = 0.0
	turn_speed = maxf(speed, 40.0)
	var key := "UR" if kind != "uturn2" else "RD"
	var t: Array = car.TURNS[key]
	car.car.rotation_degrees = t[0]
	car.car.flip_h = t[1]
	car.car.stop()
	car.car.frame = 0
	var radius := U_RADIUS if kind != "right" else _arc_radius(turn_speed)
	var quarter_time := (PI / 2.0 * radius) / turn_speed
	car.car.play("turn", 1.0 / quarter_time)

func _turn(delta: float) -> void:
	var radius := U_RADIUS if turn_kind != "right" else _arc_radius(turn_speed)
	var w := turn_speed / radius
	theta = minf(theta + w * delta, PI / 2.0)
	if turn_kind == "uturn2":
		car.velocity = Vector2(cos(theta), sin(theta)) * turn_speed        # right -> down
	else:
		car.velocity = Vector2(sin(theta), -cos(theta)) * turn_speed       # up -> right
	if theta >= PI / 2.0:
		match turn_kind:
			"right":
				state = "off"
			"uturn1":
				_begin_turn("uturn2")
			"uturn2":
				state = "down"

func _off() -> void:
	car.velocity = Vector2.RIGHT * turn_speed       # driving on to the right, away from the road

func _down() -> void:
	car.velocity = Vector2.DOWN * turn_speed
	if car.global_position.y > 700.0:               # drove back off the bottom of the screen
		finished = true
		reason = "u_turn"
		not_home._on_car_death()

# Turned away from the road (onto the grass): crash.
func _check_on_road() -> void:
	var cell := roads.local_to_map(roads.to_local(car.global_position))
	if roads.get_cell_tile_data(cell) == null:
		if state == "turn" or state == "off":
			reason = "right_off"
		elif left_sign in seen:
			reason = "left_off"
		else:
			reason = "off_road"
		_fail()

func _fail() -> void:
	if finished:
		return
	finished = true
	death._on_car_death()

# A crash with another car: the stopped car in the lane ahead, or the fast traffic.
func _crashed_into(other: Node) -> void:
	if finished:
		return
	if right_sign in seen:
		reason = "right_traffic"
	elif left_sign in seen:
		reason = "left_traffic"
	elif other != null and "stopped" in other and other.stopped:
		reason = "stalled_car"
	else:
		reason = "traffic"
	_fail()

# --- Feedback on the failure screens ---------------------------------------------------
func death_feedback() -> String:
	match reason:
		"other_crash":
			return "Try finding a way to make everyone drive safely."
		"traffic":
			if give_way.global_position.x >= 933.0:
				return "Find a way to make the car wait for the traffic to clear."
			return "The Give Way sign needs to be on the side road, close to the junction."
		"stalled_car":
			var nostop: Node2D = $no_stopping
			if nostop.global_position.x >= 933.0:
				return "The car ahead stopped in the lane and you ran into it."
			return "The No Stopping sign needs to be closer to the car that stops."
		"left_traffic", "right_traffic":
			return "You ran into the fast traffic. Try again."
		"left_off", "right_off", "off_road":
			return "You crashed into the pavement. Try again."
	return ""

func not_home_feedback() -> String:
	return "The car did not reach home. Try again."

# Two other cars crashed into each other: the level is over.
func _other_car_crashed() -> void:
	if finished:
		return
	finished = true
	reason = "other_crash"
	death._on_car_death()

func death_title() -> String:
	return "A DIFFERENT CAR CRASHED!" if reason == "other_crash" else ""
