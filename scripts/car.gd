extends CharacterBody2D

@export var tilemap_layer: TileMapLayer
@export var speed: float = 200.0
@export var tile_size: float = 20.0
@export var look_offset: float = -77.0   # negative = turn later, positive = turn earlier
@export var sprite_angle_offset: float = 0.0   # radians
@onready var car: AnimatedSprite2D = $AnimatedSprite2D

@onready var pause: Button = $"../pause"

@export var anim_look_offset: float = -35.0   # when the turn animation starts
@export var turn_anim_speed: float = 3
@export var smooth_turn_radius: float = 0.0   # > 0: the car drives round corners in an arc of this radius instead of turning sharply
var heading: Vector2 = Vector2.ZERO
var anim_played := false   # member variable
var current_direction: Vector2 = Vector2.ZERO
var last_cell := Vector2i(-999, -999)
var previous_direction: Vector2 = Vector2.ZERO
var last_anim_cell := Vector2i(-999, -999)
var turn_sig := false
const CAR_FRAME_1 = preload("uid://bjjk2gbs0vubg")


signal lvl_play
signal death
signal victory

func pause1() -> void:
	get_tree().paused = true

func resume() -> void:
	get_tree().paused = false

func _ready() -> void:
	pause.toggle_mode = true
	# The colour chosen on the customise screen (red = the car as it is in the scene).
	var skin: SpriteFrames = Global.car_frames()
	if skin != null:
		car.sprite_frames = skin
	# The button must keep working while the tree is paused
	pause.icon = load("res://assets/play.png")

	if tilemap_layer == null:
		tilemap_layer = get_node("/root/Level 1/Roads")

	var cell = tilemap_layer.local_to_map(tilemap_layer.to_local(global_position))
	if tilemap_layer.get_cell_tile_data(cell) == null:
		var start_cell = tilemap_layer.get_used_cells()[0]
		global_position = tilemap_layer.to_global(tilemap_layer.map_to_local(start_cell))
		print("Snapped car to road cell: ", start_cell)

	print(tilemap_layer.get_path(), " used: ", tilemap_layer.get_used_rect())
	pause1()
	


# The stop / green light / victory sequence is handled by the traffic signal's ray
# (scripts/traffic_signal.gd).



func _physics_process(_delta: float) -> void:
	update_direction_from_tile()
	if not turn_sig:
		var dir := current_direction
		if smooth_turn_radius > 0.0 and dir != Vector2.ZERO:
			# Round corners in an arc: the heading turns towards the road direction a little
			# each frame instead of jumping.
			if heading == Vector2.ZERO:
				heading = dir
			var step := minf(speed, Global.speed_cap_px()) * Global.speed_mult * _delta / smooth_turn_radius
			heading = heading.rotated(clampf(heading.angle_to(dir), -step, step))
			dir = heading
		velocity = dir * minf(speed, Global.speed_cap_px()) * Global.speed_mult
	move_and_slide()
	_check_hit_npc()
	


func _on_pause_toggled(toggled_on: bool) -> void:
	if toggled_on:
		lvl_play.emit()
		
const TURNS := {
	"RU": [0, false],   "UL": [-90, false],
	"LD": [-180, false], "DR": [-270, false],
	"LU": [0, true],    "DL": [-90, true],
	"RD": [-180, true],  "UR": [-270, true],
}

func update_car_turn() -> void:
	if current_direction == previous_direction:
		return
	car.play("run")
	

	previous_direction = current_direction
	
	
func update_direction_from_tile() -> void:
	# --- direction probe: decides WHEN the car turns ---
	var probe = global_position + current_direction * look_offset
	var cell = tilemap_layer.local_to_map(tilemap_layer.to_local(probe))
	var data = tilemap_layer.get_cell_tile_data(cell)

	if cell != last_cell:
		last_cell = cell

	if data:
		var value := str(data.get_custom_data("direction")).strip_edges().to_upper()
		match value.substr(value.length() - 1, 1):
			"U": current_direction = Vector2.UP
			"D": current_direction = Vector2.DOWN
			"L": current_direction = Vector2.LEFT
			"R": current_direction = Vector2.RIGHT

	# --- animation probe: decides WHEN the turn animation starts ---
	var anim_probe = global_position + current_direction * anim_look_offset
	var anim_cell = tilemap_layer.local_to_map(tilemap_layer.to_local(anim_probe))
	var anim_data = tilemap_layer.get_cell_tile_data(anim_cell)

	var anim_key := ""
	if anim_data:
		var v := str(anim_data.get_custom_data("direction")).strip_edges().to_upper()
		if v.length() >= 2:
			anim_key = v.substr(0, 1) + v.substr(v.length() - 1, 1)

	if TURNS.has(anim_key):
		if not anim_played:
			anim_played = true
			car.rotation_degrees = TURNS[anim_key][0]
			car.flip_h = TURNS[anim_key][1]
			car.play("turn", turn_anim_speed)
	else:
		anim_played = false 			
		
func _on_lvl_play():
	pause.toggle_mode = false
	Global.play = true
	pause.icon = load("res://assets/pause.png")
	update_direction_from_tile()
	resume()
	

func _on_area_2d_body_entered(body):
	if body.is_in_group('npc'):
		print("woah")
		last_hit = body
		death.emit()


func _on_turn_right_turn():
	print("entered")
	turn_sig = true
	car.play("turn", turn_anim_speed)
	velocity = Vector2(0,1) * minf(speed, Global.speed_cap_px()) * Global.speed_mult
	anim_played = true
	car.rotation_degrees = TURNS["RD"][0]
	car.flip_h = TURNS["RD"][1]
	car.play("turn", turn_anim_speed)
	print(speed)
	


# Called by the stop sign: stand still for a while, then carry on at the same speed.
func stop_for(seconds: float) -> void:
	var normal_speed: float = Global.speed_mult
	Global.speed_mult = 0.0
	await get_tree().create_timer(seconds).timeout
	Global.speed_mult = normal_speed


# Crash: the car's body touches an NPC (car or pedestrian), not only its crash area.
var last_hit: Node = null     # what the car crashed into (used for the crash screen feedback)
var hit_npc_sent := false

func _check_hit_npc() -> void:
	if hit_npc_sent:
		return
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider() as Node
		if other != null and other.is_in_group("npc"):
			hit_npc_sent = true
			last_hit = other
			death.emit()
			return


# --- Level 3 direction signs ---------------------------------------------------------------
var u_turned := false          # true once the car made a U-turn
const U_TURN_SHIFT := 66.0     # how far the car drops into the other half of the road when it U-turns

# Compulsory left turn: heading east, turn left = north (onto the grass in Level 3).
func _on_turn_left_turn() -> void:
	if turn_sig:
		return
	turn_sig = true
	velocity = Vector2.UP * minf(speed, Global.speed_cap_px()) * Global.speed_mult
	anim_played = true
	car.rotation_degrees = TURNS["RU"][0]
	car.flip_h = TURNS["RU"][1]
	car.play("turn", turn_anim_speed)

# U-turn: drop into the other half of the road, then drive back the way we came (west).
func _on_u_turn() -> void:
	if turn_sig:
		return
	turn_sig = true
	u_turned = true
	var v := minf(speed, Global.speed_cap_px()) * Global.speed_mult
	velocity = Vector2.DOWN * v
	anim_played = true
	car.rotation_degrees = TURNS["RD"][0]
	car.flip_h = TURNS["RD"][1]
	car.play("turn", turn_anim_speed)
	await get_tree().create_timer(U_TURN_SHIFT / maxf(v, 60.0)).timeout
	velocity = Vector2.LEFT * minf(speed, Global.speed_cap_px()) * Global.speed_mult
	car.rotation_degrees = TURNS["DL"][0]
	car.flip_h = TURNS["DL"][1]
	car.play("turn", turn_anim_speed)
