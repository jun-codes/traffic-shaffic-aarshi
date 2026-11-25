# Draggable stop sign of Level 3.
# Drag it from the sidebar onto the grass next to the road (it can't stand on the road).
# Every car that reaches the line in front of it stops for a moment, the player's car and
# the NPC cars alike - so putting it in front of the reckless driver stops him.
extends Node2D

@onready var label: Label = $Label

const SIDEBAR_X := 933.0    # x where the sidebar starts
const STOP_SECONDS := 1.5
var stopped: Array = []      # cars that already stopped at this sign

var is_dragging := false
var draggable := false       # mouse is over the sign
var offset: Vector2          # offset between the sign's position and the mouse when grabbed

func _ready():
	label.visible = false

# --- Dragging (only one item at a time, never onto the road) ---
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
			global_position = Global.drag_position(get_global_mouse_position(), offset, fp[0], fp[1], true)
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

# --- Ray: every car must stop before the sign ---------------------------------------
# A tall, thin area a little before the sign. A car (ours or an NPC car) that drives into
# it stops there for STOP_SECONDS (no light to wait for), then drives on.
func _on_ray_body_entered(body: Node2D) -> void:
	if global_position.x >= SIDEBAR_X:                # still in the sidebar, not placed
		return
	if body in stopped or not body.has_method("stop_for"):
		return
	if body.get("turn_sig"):                          # already turned off this road
		return
	if body.global_position.x > global_position.x:   # already past the sign
		return
	stopped.append(body)
	body.stop_for(STOP_SECONDS)
