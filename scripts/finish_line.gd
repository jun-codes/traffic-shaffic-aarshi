# Finish line of a level: the HOME sign lying across the road, its arrows pointing the way the
# car has to go. When the player's car reaches it, a moment later,
# the victory screen shows.
extends Area2D

@export var size: Vector2 = Vector2(12, 120)   # width x height of the strip that detects the car
@export var heading: Vector2 = Vector2.RIGHT    # the direction the winning car drives in
@export var sprite_scale: float = 0.25          # size of the HOME picture

const SIGN := preload("res://assets/finish line.png")   # the arrows in the picture point up
const WIN_DELAY := 0.5

var reached := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1                  # sees the cars
	input_pickable = false
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = size / 2.0
	add_child(cs)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if reached or not Global.play or not body.is_in_group("maincar"):
		return
	reached = true
	await get_tree().create_timer(WIN_DELAY).timeout
	var victory := _find_victory()
	if victory != null:
		victory._on_car_victory()

# The level's victory screen is a child named "victory" of the level root.
func _find_victory() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_node("victory"):
			return n.get_node("victory")
		n = n.get_parent()
	return null

# Rotation that makes the picture's up-arrows point along `heading`.
func _angle() -> float:
	return heading.angle() + PI / 2.0

func _draw() -> void:
	# Just the HOME sign: it does not light up when the car crosses it.
	draw_set_transform(size / 2.0, _angle(), Vector2(sprite_scale, sprite_scale))
	draw_texture(SIGN, -SIGN.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
