# Zip code 1, level 2: a cross junction. Our car drives right along the bottom lane of the road
# across the screen; cars come down the road from the top. Without help they drive into the junction
# and hit us. The timed traffic signal (placed beside the road the cars come down, before the junction)
# makes them wait until its red time is over (2 s or 5 s, chosen on the signal). With 2 s they are let
# go while our car is still crossing and hit it; with 5 s our car is across before they move.
extends Node2D

const HIGHWAY_CAR := preload("res://scenes/Level4/highway_car.tscn")

const CAR_SCALE := 0.55
const LANE_Y := 380.0               # bottom lane of the horizontal road
const START_X := 85.0
const CAR_SPEED := 150.0
const LANE_X := 470.0               # lane the traffic drives down (east lane of the road across)
const TRAFFIC_SPEED := 150.0
const QUEUE_GAP := 92.0             # distance between waiting cars
const ROADS := [Rect2(-20, 260, 960, 180), Rect2(350, -130, 180, 910)]    # the road across and the road up and down (with their curbs)

@onready var car: CharacterBody2D = $car
@onready var death: Node2D = $death
@onready var not_home: Node2D = $not_home
@onready var sidebar_rect: Node = $ColorRect
@onready var signal_item: Node2D = $timed_signal

var finished := false
var reason := ""
var released := false

func _ready() -> void:
	Global.speed_mult = 1.0
	Global.speed_limit_kmh = 50.0
	Global.extra_road_rects.clear()
	Global.next_level = Global.next_path_after(scene_file_path)
	car.turn_sig = true                          # this script drives the car, not the road tiles
	car.scale = Vector2.ONE * CAR_SCALE
	car.global_position = Vector2(START_X, LANE_Y)
	car.car.animation = &"turn"
	car.car.frame = 0
	car.car.rotation_degrees = 0.0
	car.car.flip_h = false
	car.death.connect(func(): _crashed_into(car.last_hit))
	for y in [-20.0, -112.0, -204.0]:
		_spawn(LANE_X, y)

func _spawn(x: float, y: float) -> void:
	var c: CharacterBody2D = HIGHWAY_CAR.instantiate()
	c.position = Vector2(x, y)
	c.scale = Vector2.ONE * CAR_SCALE
	c.direction = Vector2.DOWN
	c.speed = TRAFFIC_SPEED
	c.skin = "grey"
	c.hit_player.connect(_crashed_into.bind(c))
	c.crashed.connect(_other_car_crashed)
	add_child(c)
	move_child(c, sidebar_rect.get_index())

func _signal_seen() -> bool:
	return signal_item.is_placed() and Global.sign_road(signal_item.global_position, ROADS) >= 0

func _physics_process(delta: float) -> void:
	if finished or not Global.play:
		return
	car.velocity = Vector2(CAR_SPEED, 0.0) * Global.speed_mult
	if not _signal_seen():
		return
	var cars: Array = []
	for c in get_tree().get_nodes_in_group("npc"):
		if "hold" in c and "direction" in c:
			cars.append(c)
	if signal_item.is_green():
		if not released:                          # green: everybody on the signal's road goes
			released = true
			Global.release_signal_road(signal_item, ROADS, cars)
		return
	# Red: the cars on the signal's road stop in a queue in front of it.
	Global.queue_at_signal(signal_item, ROADS, cars, delta, QUEUE_GAP)

func _crashed_into(_other: Node) -> void:
	if finished:
		return
	reason = "traffic"
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
		"traffic":
			if not _signal_seen():
				if signal_item.is_placed():
					return "The signal needs to be beside the road the traffic comes down, before the junction."
				return "Find a way to make the traffic wait while you cross."
			return "The light turned green while you were still crossing. Try a longer red time."
	return ""

func not_home_feedback() -> String:
	return "The car did not reach home. Try again."
