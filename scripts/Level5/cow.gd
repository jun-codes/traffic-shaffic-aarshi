# The cow of Level 5. It stands on the road in front of the home sign and does not move on its
# own. When the car has seen the CATTLE AHEAD sign the cow starts to walk (slowly) off the
# road, with its legs animated. It blocks the car's body, so driving into it is a crash.
extends CharacterBody2D

@export var walk_speed := 24.0          # px/s: very slow (needs about 3 s to be clear of the road)
@export var target_y := 238.0           # it walks up until it is clear of the road

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var walking := false
var started := false          # it has been set walking (by the sign seen by any car); it may already be gone

func _ready() -> void:
	add_to_group("npc")
	add_to_group("cow")
	sprite.animation = &"walk"
	sprite.frame = 0
	sprite.stop()

func start_walking() -> void:
	if started:
		return
	started = true
	walking = true
	sprite.play(&"walk")

func _physics_process(_delta: float) -> void:
	if walking and global_position.y > target_y:
		velocity = Vector2.UP * walk_speed
		move_and_slide()
	elif walking:
		walking = false                  # clear of the road: it stops walking
		velocity = Vector2.ZERO
		sprite.stop()
