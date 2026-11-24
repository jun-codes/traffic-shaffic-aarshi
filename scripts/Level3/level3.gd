# Level 3: the car has to take the side road at the compulsory-right-turn sign.
# - Reaching the finish line at the bottom of the side road wins the level (finish_line.gd).
# - A U-turn sends the cars back the way they came: they leave on the left and the same
#   "did not reach home" screen shows once the player's car is gone.
# - Driving straight on (never turning): nothing crashes and nothing stops, the cars just
#   drive off the right edge of the screen. Once the player's car is gone the "you did not
#   reach home" screen shows.
# - Any other failure (turning too early or too late onto the grass, being hit by another
#   car, ...) is a crash.
extends Node2D

const MISSED_TURN_X := 490.0   # the side road is to the left of this x; beyond it the turn is missed
const OFFSCREEN_X := 1230.0    # the player's car is completely off the right edge of the screen
const LEFT_OFFSCREEN_X := -90.0  # the player's car has U-turned and left the screen on the left

@onready var roads: TileMapLayer = $Roads
@onready var car: CharacterBody2D = $car
@onready var death: Node2D = $death
@onready var not_home: Node2D = $not_home

var finished := false
var reason := ""      # what went wrong, for the feedback on the failure screens

func _ready() -> void:
	Global.speed_mult = 1.0
	Global.speed_limit_kmh = 50.0
	Global.extra_road_rects.clear()
	# The next level is the highway level.
	Global.next_level = "res://scenes/Level4/level 4.tscn"
	# Every failure goes through _fail so the right screen is chosen.
	car.death.connect(func(): _crashed_into(car.last_hit))
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.has_signal("hit_player"):
			npc.hit_player.connect(func(): _crashed_into(npc))
		if npc.has_signal("crashed"):
			npc.crashed.connect(_other_car_crashed)

func _physics_process(_delta: float) -> void:
	if finished or not Global.play:
		return
	if car.u_turned:
		# U-turned: nothing crashes, the car drives back off the left edge of the screen.
		if car.global_position.x <= LEFT_OFFSCREEN_X:
			finished = true
			reason = "u_turn"
			not_home._on_car_death()
		return
	if not car.turn_sig:
		# Straight on: no crash at the end of the road, the car just keeps driving.
		if car.global_position.x >= OFFSCREEN_X:
			reason = "straight"
			_fail()
		return
	# Turned, but off the road (too early or too late): it is on the grass.
	# On the road = the whole car is on asphalt (tiles with a driving direction), not on the
	# curb or the grass.
	var on_road := true
	for d in [Vector2.ZERO, Vector2(30, 0), Vector2(-30, 0), Vector2(0, 30), Vector2(0, -30)]:
		if not _asphalt_at(car.global_position + d):
			on_road = false
	if not on_road:
		if car.global_position.y < 270.0:         # went up: onto the grass at the top of the road
			reason = "grass_up"
		elif car.global_position.x < 350.0:
			reason = "too_early"
		else:
			reason = "too_late"
		_fail()

func _fail() -> void:
	if finished:
		return
	finished = true
	if not car.turn_sig and car.global_position.x > MISSED_TURN_X:
		not_home._on_car_death()     # drove on past the junction: did not reach home
	else:
		death._on_car_death()        # crashed

func _asphalt_at(p: Vector2) -> bool:
	var tile := roads.get_cell_tile_data(roads.local_to_map(roads.to_local(p)))
	return tile != null and str(tile.get_custom_data("direction")).strip_edges() != ""

# A crash between two cars: ours ran into one, or one ran into ours.
func _crashed_into(other: Node) -> void:
	if finished:
		return
	if car.u_turned:
		reason = "u_turn_crash"
	elif other != null and other.global_position.x < car.global_position.x:
		reason = "hit_from_behind"      # the other car was behind ours
	else:
		reason = "hit_ahead"
	# A collision is always a crash, even when the car had already driven past the side road.
	finished = true
	death._on_car_death()

# --- Feedback on the failure screens ---------------------------------------------------
func death_feedback() -> String:
	match reason:
		"other_crash":
			return "Try finding a way to make everyone drive safely."
		"hit_from_behind":
			return "The reckless driver behind you was going faster than you and rear-ended you. Try again!"
		"hit_ahead", "u_turn_crash":
			return "You ran into the car in front of you."
		"grass_up", "too_early", "too_late":
			return "You crashed into the pavement. Try again."
	return ""

func not_home_feedback() -> String:
	return "The car did not reach home. Try again."

# One of the other cars crashed (into another car or off the road): the level is over.
func _other_car_crashed() -> void:
	if finished:
		return
	finished = true
	reason = "other_crash"
	death._on_car_death()

func death_title() -> String:
	return "A DIFFERENT CAR CRASHED!" if reason == "other_crash" else ""
