# Draggable sign of Level 4. Drag it from the sidebar onto the grass (never onto the road).
# It has no effect of its own: the level (give way) or the car that would stop (no stopping)
# checks whether it stands close enough to the right spot.
extends Node2D

@onready var label: Label = $Label

const SIDEBAR_X := 933.0    # x where the sidebar starts

var is_dragging := false
var draggable := false       # mouse is over the sign
var offset: Vector2          # offset between the sign's position and the mouse when grabbed

func _ready():
	label.visible = false
	add_to_group("level4_signs")

func is_placed() -> bool:
	return global_position.x < SIDEBAR_X

func _process(_delta):
	if not is_instance_valid(Global.drag_owner):
		Global.drag_owner = null
	if Global.drag_owner == null:
		if Input.is_action_just_pressed("click") and not Global.play and Global.mouse_over_area($Area2D):
			Global.drag_owner = self
			offset = get_global_mouse_position() - global_position
			is_dragging = true
			label.visible = false
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
