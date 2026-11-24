# A car on the Level 4 highway. It drives straight along the road at a fixed speed and is
# removed once it has left the screen. The "stalling" car brakes to a halt at one spot of
# the road unless a no-stopping-or-standing sign stands next to it.
extends CharacterBody2D

@export_enum("default", "cyan", "purp", "grey") var skin: String = "default"
@export var speed: float = 500.0
@export var direction: Vector2 = Vector2.LEFT
@export var stalls := false           # brakes to a stop at stall_x (unless the sign is there)
@export var stall_x := 170.0
@export var stop_zone := 210.0        # a no-stopping sign this close to the stopping spot is "next to" the car
const BRAKE_DISTANCE := 400.0         # how far before stall_x the car starts to brake

@onready var car: AnimatedSprite2D = $AnimatedSprite2D

signal hit_player
var hit_sent := false
signal crashed                 # crash with another car on the highway (not the player)
var crash_sent := false
var braking := false
var decel := 0.0
var stopped := false
var decided := false
var art_up := false                # drawn as the car seen facing up (cars that drive up or down the screen)
var turning := false             # driving a quarter turn after a compulsory turn sign (Level 5)
var turn_from := Vector2.ZERO
var turn_to := Vector2.ZERO
var turn_radius := 60.0
var turn_theta := 0.0

func _ready() -> void:
	add_to_group("npc")
	if skin != "default":
		car.sprite_frames = load("res://assets/cars/%s_frames.tres" % skin)
	car.animation = &"turn"
	car.frame = 0
	car.flip_h = direction.x < 0         # the artwork faces right
	if direction.y != 0.0:               # a car driving up or down the screen (Level 5)
		art_up = true
		car.frame = 4                    # the last frame of the turn animation: the car seen facing up
		car.flip_h = false
		car.rotation_degrees = 0.0 if direction.y < 0.0 else 180.0
		$CollisionShape2D.rotation = PI / 2.0

func _physics_process(delta: float) -> void:
	if stalls and not decided and global_position.x <= stall_x + BRAKE_DISTANCE:
		decided = true
		if not _no_stopping_sign_nearby():
			braking = true
			decel = speed * speed / (2.0 * BRAKE_DISTANCE)   # stops exactly at stall_x
	if braking and not stopped:
		speed = maxf(speed - decel * delta, 0.0)
		if speed <= 0.0:
			stopped = true
	var heading := direction
	if turning:
		turn_theta = minf(turn_theta + speed / turn_radius * delta, PI / 2.0)
		heading = turn_from * cos(turn_theta) + turn_to * sin(turn_theta)
		if art_up:
			car.rotation = heading.angle() + PI / 2.0
			$CollisionShape2D.rotation = PI / 2.0 if absf(heading.y) > absf(heading.x) else 0.0
		if turn_theta >= PI / 2.0:
			turning = false
			direction = turn_to
	if hold > 0.0:
		hold -= delta
		velocity = Vector2.ZERO
	else:
		velocity = heading * speed
	move_and_slide()
	_check_hit_player()
	# Gone off the screen: remove it.
	var gone_x := (direction.x < 0 and global_position.x < -130.0) or (direction.x > 0 and global_position.x > 1010.0)
	var gone_y := (direction.y < 0 and global_position.y < -170.0) or (direction.y > 0 and global_position.y > 830.0)
	if gone_x or gone_y:
		queue_free()

func _no_stopping_sign_nearby() -> bool:
	var spot := Vector2(stall_x, global_position.y)
	for s in get_tree().get_nodes_in_group("level4_signs"):
		if s.name == "no_stopping" and s.is_placed() and s.global_position.distance_to(spot) <= stop_zone:
			return true
	return false

func _check_hit_player() -> void:
	if hit_sent:
		return
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider() as Node
		if other != null and other.is_in_group("maincar"):
			hit_sent = true
			hit_player.emit()
			return
		if other is CharacterBody2D and other != self and other.is_in_group("npc") and not crash_sent:
			crash_sent = true
			crashed.emit()
			return

# A stop sign or traffic signal stops this car for a moment as well (it then carries on).
var hold := 0.0

func stop_for(seconds: float) -> void:
	hold = maxf(hold, seconds)

# A compulsory left / right turn sign (Level 5): this car turns a quarter turn to `new_dir`
# (a radius is the width of the turn) and then drives straight on.
func start_turn(new_dir: Vector2, radius: float, new_speed := -1.0) -> void:
	if turning:
		return
	if new_speed > 0.0:
		speed = new_speed                # the car slows down for the turn
	turning = true
	turn_from = direction
	turn_to = new_dir
	turn_radius = maxf(radius, 20.0)
	turn_theta = 0.0
