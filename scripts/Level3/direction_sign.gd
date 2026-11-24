# Draggable direction sign of Level 3 (compulsory left turn, U-turn, ...).
# Drag it from the sidebar onto the grass next to the road (never onto the road). Every car
# that drives into the line in front of it - the player's car and the NPC cars alike -
# performs the sign's manoeuvre (it calls `car_method` on the car).
extends Node2D

@export var car_method: StringName = &"_on_turn_left_turn"   # what a car does at this sign
@export var drag_rotation_degrees := 90.0                    # the picture turns this much once picked up
@export var cross_distance := 0.0   # the car must drive this far past the sign before it reacts (0 = right away)

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D

const SIDEBAR_X := 933.0    # x where the sidebar starts
var is_dragging := false
var draggable := false      # mouse is over the sign
var offset: Vector2         # offset between the sign's position and the mouse when grabbed
var turned: Array = []      # cars that already obeyed this sign
var waiting: Array = []     # cars that saw the sign and are driving up to it

func _ready():
	label.visible = false
	sprite.rotation_degrees = 0

func _process(_delta):
	if not is_instance_valid(Global.drag_owner):
		Global.drag_owner = null
	if Global.drag_owner == null:
		if Input.is_action_just_pressed("click") and not Global.play and Global.mouse_over_area($Area2D):
			Global.drag_owner = self
			offset = get_global_mouse_position() - global_position
			is_dragging = true
			label.visible = false
			sprite.rotation_degrees = drag_rotation_degrees
	elif Global.drag_owner == self:
		if Input.is_action_pressed("click"):
			var fp := Global.area_footprint(self, $Area2D)
			global_position = Global.drag_position(get_global_mouse_position(), offset, fp[0], fp[1])
		else:
			_end_drag()

func _end_drag():
	Global.drag_owner = null
	is_dragging = false
	if draggable and not Global.mouse_over_area($Area2D):   # the mouse left the sign while dragging
		draggable = false
		scale /= Vector2(1.12, 1.12)
		label.visible = false

func _exit_tree():
	if Global.drag_owner == self:
		Global.drag_owner = null

func _on_area_2d_mouse_entered():
	if not is_dragging and not Global.play:
		scale *= Vector2(1.12, 1.12)
		draggable = true
		label.visible = true
	if is_dragging:
		label.visible = false

func _on_area_2d_mouse_exited():
	if not is_dragging and not Global.play:
		scale /= Vector2(1.12, 1.12)
		draggable = false
		label.visible = false

# A car drives into the ray in front of the sign and obeys it.
func _on_ray_body_entered(body: Node2D) -> void:
	if global_position.x >= SIDEBAR_X:                # still in the sidebar, not placed: does nothing
		return
	if not Global.play or body in turned or not body.has_method(car_method):
		return
	if body.global_position.x > global_position.x:   # cars already past the sign never see it
		return
	turned.append(body)
	if cross_distance <= 0.0:
		body.call(car_method)
	else:
		waiting.append(body)             # first it has to drive past the sign

# A car that saw the sign turns only once it has crossed it.
func _physics_process(_delta: float) -> void:
	if not Global.play:
		return
	for b in waiting.duplicate():
		if not is_instance_valid(b):
			waiting.erase(b)
		elif b.global_position.x >= global_position.x + cross_distance:
			waiting.erase(b)
			b.call(car_method)
