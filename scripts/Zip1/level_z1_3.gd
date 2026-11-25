# Zip code 1, level 3: a cross junction, both roads have two lanes. Our car drives right along the
# bottom lane of the road across. Cars come down the road (east lane) from the top, and ONE car comes
# up the same road (west lane) from the bottom.
#  - Nothing done: the car from below runs into us.
#  - A stop sign beside the road below the junction makes that car stop first (a stop sign works on
#    every car that comes up to it close enough: also ours, if it is placed next to our lane). The cars from the top
#    are held by the timed traffic signal, but its default 2 s is too short: they hit us.
#  - Also choosing 5 s on the signal: everything waits until our car is across and the level is won.
extends Node2D

const HIGHWAY_CAR := preload("res://scenes/Level4/highway_car.tscn")

const CAR_SCALE := 0.55
const LANE_Y := 320.0              # upper lane of the road across (the left lane for a car driving right)
const START_X := 85.0
const CAR_SPEED := 150.0
const DOWN_X := 470.0               # lane of the cars coming from the top
const UP_X := 410.0                 # lane of the car coming from the bottom
const TRAFFIC_SPEED := 150.0
const UP_START_Y := 650.0           # just peeking in at the bottom edge of the screen
const QUEUE_GAP := 92.0
const ROADS := [Rect2(-20, 260, 960, 180), Rect2(350, -130, 180, 910)]    # the road across and the road up and down (with their curbs)
const STOP_SECONDS := 1.5

@onready var car: CharacterBody2D = $car
@onready var death: Node2D = $death
@onready var not_home: Node2D = $not_home
@onready var sidebar_rect: Node = $ColorRect
@onready var signal_item: Node2D = $timed_signal
@onready var stop_sign: Node2D = $stop

var finished := false
var reason := ""
var released := false
var up_car: Node2D = null
var car_hold := 0.0                 # seconds our car still stands at a stop sign

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
	# The stop sign's own ray is made for sideways traffic: this script applies it instead.
	stop_sign.stopped.append(car)
	for y in [-20.0, -112.0, -204.0]:
		_spawn(DOWN_X, y, Vector2.DOWN)
	up_car = _spawn(UP_X, UP_START_Y, Vector2.UP)

func _spawn(x: float, y: float, dir: Vector2) -> Node2D:
	var c: CharacterBody2D = HIGHWAY_CAR.instantiate()
	c.position = Vector2(x, y)
	c.scale = Vector2.ONE * CAR_SCALE
	c.direction = dir
	c.speed = TRAFFIC_SPEED
	c.skin = "grey"
	c.hit_player.connect(_crashed_into.bind(c))
	c.crashed.connect(_other_car_crashed)
	add_child(c)
	move_child(c, sidebar_rect.get_index())
	stop_sign.stopped.append(c)
	return c

func _signal_seen() -> bool:
	return signal_item.is_placed() and Global.sign_road(signal_item.global_position, ROADS) >= 0

func _stop_placed() -> bool:
	return stop_sign.global_position.x < 933.0

func _physics_process(delta: float) -> void:
	if finished or not Global.play:
		return
	_stop_sign_vs_cars()
	car.velocity = Vector2(CAR_SPEED, 0.0) * Global.speed_mult
	if car_hold > 0.0:
		car_hold -= delta
		car.velocity = Vector2.ZERO
	_hold_top_cars(delta)

# The stop sign works on every car on the road it stands next to (every lane, both directions; at the
# junction it belongs to the nearest road only): a car that comes up to it stops there once for
# STOP_SECONDS, then drives on.
func _stop_sign_vs_cars() -> void:
	if not _stop_placed():
		return
	var cars: Array = [car]
	cars.append_array(get_tree().get_nodes_in_group("npc"))
	for c in cars:
		if not (c is CharacterBody2D) or c.get_meta("stop_seen", false):
			continue
		var h: Vector2 = Vector2.RIGHT if c == car else c.direction
		if not Global.car_on_sign_road(stop_sign.global_position, ROADS, c.global_position, h):
			continue
		var d: float = (c.global_position - stop_sign.global_position).dot(h)
		if d >= -12.0 and d <= 40.0:
			if not Global.sign_stops_heading(stop_sign, h):
				c.set_meta("stop_seen", true)      # the sign only stops the traffic of one direction
				continue
			c.set_meta("stop_seen", true)
			if c == car:
				car_hold = STOP_SECONDS
			else:
				c.stop_for(STOP_SECONDS)

# The cars on the road the signal stands next to queue up in front of it until it turns green.
func _hold_top_cars(delta: float) -> void:
	if not _signal_seen():
		return
	var cars: Array = []
	for c in get_tree().get_nodes_in_group("npc"):
		if "hold" in c and "direction" in c:
			cars.append(c)
	if signal_item.is_green():
		if not released:
			released = true
			Global.release_signal_road(signal_item, ROADS, cars)
		return
	Global.queue_at_signal(signal_item, ROADS, cars, delta, QUEUE_GAP)

func _crashed_into(other: Node) -> void:
	if finished:
		return
	reason = "up_car" if (other != null and "direction" in other and other.direction.y < 0.0) else "top_traffic"
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
		"other_crash":
			return "Try finding a way to make everyone drive safely."
		"up_car":
			if not _stop_placed():
				return "A car came up the road from below and ran into you. Find a way to make it stop."
			return "The stop sign needs to be closer to the road the car comes up."
		"top_traffic":
			return "The light turned green while you were still crossing. Try a longer red time."
	return ""

func not_home_feedback() -> String:
	return "The car did not reach home. Try again."
