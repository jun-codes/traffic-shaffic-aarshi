#only works for LEVEL 1
#clear condition: if traffic object is inside safe zone

extends Node2D
@onready var traff_icon: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $Label

signal traffic_switched

const SIDEBAR_X := 933.0   # x where the sidebar starts
const CAR_HALF_LENGTH := 45.0   # how far the front of the car is ahead of its centre
var ray_used := false
var npcs_leaving := false
var is_dragging = false
var draggable = false #changes depending on if mouse is inside body or not
var offset: Vector2 #offset between global object position and mouse position

#on game start
func _ready():
	Global.safe = false
	Global.speed_mult = 1.0
	Global.speed_limit_kmh = 50.0
	Global.extra_road_rects.clear()
	Global.play = false
	label.visible = false
	
func _process(_delta):
	# Only one item can be dragged at a time (Global.drag_owner), and a drag can only
	# start when the click lands exactly on this item.
	if not is_instance_valid(Global.drag_owner):
		Global.drag_owner = null
	if Global.drag_owner == null:
		if Input.is_action_just_pressed("click") and not Global.play and Global.mouse_over_area($Area2D):
			Global.drag_owner = self
			offset = get_global_mouse_position() - global_position #calculates offset
			is_dragging = true
			label.visible = false
	elif Global.drag_owner == self:
		if Input.is_action_pressed("click"):
			var fp := Global.area_footprint(self, $Area2D)
			global_position = Global.drag_position(get_global_mouse_position(), offset, fp[0], fp[1], true)
		else:
			_end_drag()

	# While the light is green and the signal is near the NPCs (safe zone), keep
	# telling the NPCs to run off the road.
	if npcs_leaving:
		traffic_switched.emit()

func _end_drag():
	Global.drag_owner = null
	is_dragging = false
	# The mouse may have left the item while dragging: refresh the hover state.
	if draggable and not Global.mouse_over_area($Area2D):
		draggable = false
		scale /= Vector2(1.12, 1.12)
		label.visible = false

func _exit_tree():
	if Global.drag_owner == self:
		Global.drag_owner = null


# --- Ray: a tall, thin box in front of the signal, facing the car ---------
# When the car touches it the car stops for 2 s, the light turns green, then the car
# drives on. If the signal is in the safe zone (near the NPCs) they run off the road
# and the car gets through; otherwise they never see the car and it crashes into them.
func _on_ray_body_entered(body: Node2D) -> void:
	if body.is_in_group("maincar"):
		_car_sees_signal(body)
	elif body.is_in_group("npc") and body.has_method("stop_for"):
		_npc_car_sees_signal(body)

# A signal standing in the NPC safe zone (above or below the road) is always close enough
# for the car to see it, even if it is further from the car's lane than the ray reaches.
func _physics_process(_delta: float) -> void:
	if ray_used or not Global.safe or not Global.play:
		return
	var car := get_tree().get_first_node_in_group("maincar") as Node2D
	if car == null or car.global_position.x > global_position.x:
		return
	var ray_x: float = $Ray/CollisionShape2D.global_position.x - 3.0   # left edge of the ray box
	if car.global_position.x + CAR_HALF_LENGTH >= ray_x:
		_car_sees_signal(car)

func _car_sees_signal(body: Node2D) -> void:
	if ray_used or not Global.play:
		return
	if body.global_position.x > global_position.x:   # already past the signal
		return
	if global_position.x >= SIDEBAR_X:   # still in the sidebar, not placed on the road
		return
	ray_used = true
	var normal_speed: float = Global.speed_mult
	Global.speed_mult = 0.0                          # car stops
	# The pedestrians see the stopped car and start to run off the road right away, not only
	# when the light turns green.
	var safe_now: bool = Global.safe
	if safe_now:
		npcs_leaving = true
	await get_tree().create_timer(1.0).timeout
	traff_icon.speed_scale = 2.0
	traff_icon.play("traffic")                        # red -> green
	get_tree().create_timer(0.3).timeout.connect(traff_icon.pause)   # hold on green
	await get_tree().create_timer(0.5).timeout
	Global.speed_mult = normal_speed                  # car drives on
	if safe_now:
		await get_tree().create_timer(2.0).timeout
		npcs_leaving = false

func _on_area_2d_mouse_entered(): #connected to area2d in object, signals when mouse enters collision shape
	if not is_dragging and not Global.play: #for smooth movement
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


func _on_area_2d_body_entered(body):
	if body.is_in_group('safe'):
		print(Global.safe)
		Global.safe = true
	
func _on_area_2d_body_exited(body):
	if body.is_in_group('safe'):
		print(Global.safe)
		Global.safe = false


# --- NPC cars obey the light as well (e.g. the reckless driver in Level 3) -------------
# Every NPC car that reaches the ray stops for a moment, the light turns green, then it
# drives on. Cars already past the signal, or that already turned off, ignore it.
const NPC_STOP_SECONDS := 1.5
var handled_cars: Array = []

func _npc_car_sees_signal(body: Node2D) -> void:
	if not Global.play or body in handled_cars:
		return
	if global_position.x >= SIDEBAR_X:                # still in the sidebar, not placed
		return
	if body.get("turn_sig"):                          # already turned off this road
		return
	if body.global_position.x > global_position.x:   # already past the signal
		return
	handled_cars.append(body)
	body.stop_for(NPC_STOP_SECONDS)
	traff_icon.stop()
	traff_icon.frame = 0                              # red while the car waits
	await get_tree().create_timer(1.0).timeout
	traff_icon.speed_scale = 2.0
	traff_icon.play("traffic")                        # red -> green
	get_tree().create_timer(0.3).timeout.connect(traff_icon.pause)   # hold on green

