extends CharacterBody2D


## Car colour. "default" keeps the colour set in npc_car.tscn.
@export_enum("default", "cyan", "purp", "grey") var skin: String = "default"
@export var tilemap_layer: TileMapLayer
@export var speed: float = 120
@export var tile_size: float = 20.0
@export var look_offset: float = -77.0   # negative = turn later, positive = turn earlier
@export var sprite_angle_offset: float = 0.0   # radians
@onready var car: AnimatedSprite2D = $AnimatedSprite2D

@export var anim_look_offset: float = -35.0   # when the turn animation starts
@export var turn_anim_speed: float = 3
var anim_played := false   # member variable
var current_direction: Vector2 = Vector2.ZERO
var last_cell := Vector2i(-999, -999)
var previous_direction: Vector2 = Vector2.ZERO
var last_anim_cell := Vector2i(-999, -999)
var turn_sig = false
const CAR_FRAME_1 = preload("uid://bjjk2gbs0vubg")


func _ready() -> void:
	if skin != "default":
		car.sprite_frames = load("res://assets/cars/%s_frames.tres" % skin)
	if tilemap_layer == null:
		tilemap_layer = get_parent().get_node("Roads")

	var cell = tilemap_layer.local_to_map(tilemap_layer.to_local(global_position))
	if tilemap_layer.get_cell_tile_data(cell) == null:
		var start_cell = tilemap_layer.get_used_cells()[0]
		global_position = tilemap_layer.to_global(tilemap_layer.map_to_local(start_cell))
		print("Snapped car to road cell: ", start_cell)

	print(tilemap_layer.get_path(), " used: ", tilemap_layer.get_used_rect())


func _physics_process(_delta: float) -> void:
	update_direction_from_tile()
	if not turn_sig:
		velocity = current_direction * minf(speed, Global.speed_cap_px())
	move_and_slide()
	_check_hit_player()
	_check_off_road()

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




# Called by the compulsory-right-turn sign: this car turns right (down the side road)
# at the sign, just like the player's car does.
func _on_turn_right_turn() -> void:
	turn_sig = true
	velocity = Vector2.DOWN * minf(speed, Global.speed_cap_px())
	anim_played = true
	car.rotation_degrees = TURNS["RD"][0]
	car.flip_h = TURNS["RD"][1]
	car.play("turn", turn_anim_speed)


# Called by the stop sign: stand still for a while, then carry on at the same speed.
func stop_for(seconds: float) -> void:
	var normal_speed := speed
	speed = 0.0
	await get_tree().create_timer(seconds).timeout
	if speed == 0.0:
		speed = normal_speed


# Crash: this car touches the player's car (for example the reckless driver rear-ending it).
# The level connects this signal to the crash screen.
signal hit_player
var hit_sent := false

# Crash of this car on its own or with another NPC car (not the player): the level ends with
# "a different car crashed".
signal crashed
var crash_sent := false

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


# --- Level 3 direction signs (the NPC cars obey them like the player's car) -----------------
const U_TURN_SHIFT := 66.0     # how far the car drops into the other half of the road when it U-turns

# Compulsory left turn: heading east, turn left = north (onto the grass in Level 3).
func _on_turn_left_turn() -> void:
	if turn_sig:
		return
	turn_sig = true
	velocity = Vector2.UP * minf(speed, Global.speed_cap_px())
	anim_played = true
	car.rotation_degrees = TURNS["RU"][0]
	car.flip_h = TURNS["RU"][1]
	car.play("turn", turn_anim_speed)

# U-turn: drop into the other half of the road, then drive back the way we came (west).
func _on_u_turn() -> void:
	if turn_sig:
		return
	turn_sig = true
	var v := minf(speed, Global.speed_cap_px())
	velocity = Vector2.DOWN * v
	anim_played = true
	car.rotation_degrees = TURNS["RD"][0]
	car.flip_h = TURNS["RD"][1]
	car.play("turn", turn_anim_speed)
	await get_tree().create_timer(U_TURN_SHIFT / maxf(v, 60.0)).timeout
	velocity = Vector2.LEFT * minf(speed, Global.speed_cap_px())
	car.rotation_degrees = TURNS["DL"][0]
	car.flip_h = TURNS["DL"][1]
	car.play("turn", turn_anim_speed)

# After this car has turned off the main road (a compulsory turn) it has to stay on asphalt,
# like the player's car: the whole car on a tile that has a driving direction.
func _check_off_road() -> void:
	if crash_sent or not turn_sig:
		return
	if global_position.x < 0.0 or global_position.x > 933.0 or global_position.y < 0.0 or global_position.y > 640.0:
		return                                  # off the screen: nothing to check
	for d in [Vector2.ZERO, Vector2(30, 0), Vector2(-30, 0), Vector2(0, 30), Vector2(0, -30)]:
		var tile := tilemap_layer.get_cell_tile_data(tilemap_layer.local_to_map(tilemap_layer.to_local(global_position + d)))
		if tile == null or str(tile.get_custom_data("direction")).strip_edges() == "":
			crash_sent = true
			crashed.emit()
			return
