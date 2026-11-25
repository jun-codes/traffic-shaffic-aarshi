# Level 2: two carriageways separated by a divider with a gap.
# Place the U-TURN sign on the divider just left of the u-bend, then press play.
# The car "sees" the sign when its front reaches the sign (a vertical ray through it).
# Placed correctly -> the U-turn route opens and the car takes it.
# Placed anywhere else -> the car tries to turn there, hits the divider and crashes.
# No sign at all -> it drives straight on into the cow.
extends Node2D

const SRC := 6                 # tileset atlas source id
const CL := 22                 # first column of the U-turn junction
const SHOW_ZONE_HINTS := true

# Where each sign has to be placed (sign centre must be inside the rect).
const ZONES := {
	"u_turn": Rect2(240, 361, 160, 80),     # the left half of the divider, from 4 grid boxes further left than before (x 240) up to the intersection at x=400
}
const SEE_AHEAD := 40.0       # how far in front of its centre the car sees the sign
const SEE_HALF_HEIGHT := 220.0  # the ray only reaches this far above/below the sign (car must be in its vicinity)
const CRASH_Y := 475.0        # car has reached the divider after turning up too early
const OFFSCREEN_X := 1230.0   # the car has driven off the right edge of the screen
const ROADS := [Rect2(-20, 120, 960, 241), Rect2(-20, 441, 960, 210)]   # the two carriageways (top one drives left, bottom one drives right); the turn signs snap to the nearest
const ROAD_DIRS := [Vector2.LEFT, Vector2.RIGHT]
const TURN_REACH := 180.0        # a compulsory turn sign this close (up/down) to the car's lane is seen by it
const CROSS_DISTANCE := 75.0      # the car turns once it has completely crossed the sign
const GAP_X := Vector2(460.0, 580.0)   # the car can drive up through the gap in the divider here
const TOP_CRASH_Y := 165.0        # a car sent up through the gap crashes into the pavement at the top road
const BOTTOM_CRASH_Y := 625.0     # a car sent down crashes into the pavement below the road

@onready var roads: TileMapLayer = $"Map/Roads"
@onready var pause: Button = $"Map/pause"
@onready var car: CharacterBody2D = $"Map/car"
@onready var not_home: Node2D = $not_home
# The compulsory turn signs are not in this level any more (they are introduced in the next one); the code below only
# runs if a level scene adds them again.
@onready var left_item: Node2D = get_node_or_null("left_turn")
@onready var right_item: Node2D = get_node_or_null("turn")

var hint: Node2D
var finished := false
var turn_checked := false
var crashing := false
var crash_kind := ""          # "early" / "late": where the wrongly placed sign sent the car
var crash_time := 0.0
var car_start_x := 0.0
var seen_turns: Array = []

func _ready() -> void:
	Global.safe = false
	Global.play = false
	Global.speed_mult = 1.0
	Global.speed_limit_kmh = 50.0
	# The gap in the divider is road too (it has no tile): signs may not stand in it.
	Global.extra_road_rects.assign([Rect2(437, 361, 163, 80)])
	Global.next_level = Global.next_path_after(scene_file_path)      # the next level in the picker order
	car_start_x = car.global_position.x
	if right_item != null and "turned" in right_item:
		right_item.turned.append(car)       # this script applies the sign, not its own ray
	hint = Node2D.new()
	hint.z_index = 5
	hint.process_mode = Node.PROCESS_MODE_ALWAYS  # root stays pausable so the car waits for play
	hint.draw.connect(_draw_hint)
	add_child(hint)

func _process(_delta: float) -> void:
	hint.queue_redraw()

func _signs() -> Array:
	return get_tree().get_nodes_in_group("signs")

func _placed_ok(kind: String) -> bool:
	for s in _signs():
		if s.kind == kind and ZONES[kind].has_point(s.position):
			return true
	return false

# Paints the direction tiles that lead the car through the gap:
# bottom lane -> right-to-up corner -> straight up -> up-to-left corner -> top lane.
func _open_route() -> void:
	_paint(Rect2i(CL, 19, 10, 10), Vector2i(20, 20))     # RU corner
	_paint(Rect2i(CL - 2, 11, 12, 8), Vector2i(46, 0))   # straight up
	_paint(Rect2i(CL, 1, 10, 10), Vector2i(20, 0))       # UL corner

func _paint(cells: Rect2i, atlas_origin: Vector2i) -> void:
	var source := roads.tile_set.get_source(SRC) as TileSetAtlasSource
	for dx in cells.size.x:
		for dy in cells.size.y:
			var a := atlas_origin + Vector2i(dx, dy)
			if source.has_tile(a):
				roads.set_cell(cells.position + Vector2i(dx, dy), SRC, a)

# The car "sees" the U-turn sign when its front reaches the sign's x and the sign is within
# SEE_HALF_HEIGHT of the car (a vertical ray with limited height through the sign).
func _check_u_turn_ray() -> void:
	if turn_checked:
		return
	for s in _signs():
		if s.kind != "u_turn" or s.is_in_sidebar():
			continue
		if abs(car.global_position.y - s.position.y) > SEE_HALF_HEIGHT:   # too far off the car's road
			continue
		if s.position.x < car_start_x:   # placed behind the car, never seen
			continue
		if car.global_position.x + SEE_AHEAD >= s.position.x:
			turn_checked = true
			if ZONES["u_turn"].has_point(s.position):
				_open_route()            # correct spot: the car takes the U-turn
			else:
				_crash_turn(s)         # wrong spot: it turns here, into the divider
			return

# The compulsory left / right turn signs: the car turns once it has completely crossed the sign and drives
# straight on, so it always ends in a crash (left: into the divider, or up through the gap into the pavement
# of the top road; right: down into the pavement).
func sign_roads() -> Array:
	return ROADS

func sign_road_dirs() -> Array:
	return ROAD_DIRS

func _check_turn_signs() -> void:
	if left_item == null or right_item == null:
		return
	for s in [left_item, right_item]:
		if s in seen_turns or s.global_position.x >= 933.0:
			continue
		if not Global.turn_sign_reached(s.global_position, car.global_position, Vector2.RIGHT, ROADS, ROAD_DIRS):
			continue
		seen_turns.append(s)
		var left: bool = s == left_item
		crashing = true
		crash_kind = ("left_gap" if car.global_position.x >= GAP_X.x and car.global_position.x <= GAP_X.y else "left") if left else "right"
		car.turn_sig = true
		car.velocity = (Vector2.UP if left else Vector2.DOWN) * car.speed * Global.speed_mult
		var t: Array = car.TURNS["RU" if left else "RD"]
		var sprite: AnimatedSprite2D = car.get_node("AnimatedSprite2D")
		sprite.rotation_degrees = t[0]
		sprite.flip_h = t[1]
		sprite.play("turn", car.turn_anim_speed)
		return

func _crash_turn(sign_node: Node) -> void:
	crashing = true
	crash_kind = "late" if sign_node.position.x > ZONES["u_turn"].end.x else "early"
	car.turn_sig = true                  # stop following the road tiles
	car.velocity = Vector2.UP * car.speed * Global.speed_mult
	var sprite: AnimatedSprite2D = car.get_node("AnimatedSprite2D")
	sprite.rotation_degrees = 0
	sprite.flip_h = false
	sprite.play("turn", car.turn_anim_speed)

func _physics_process(delta: float) -> void:
	if finished or not Global.play:
		return
	if crashing:
		crash_time += delta
		# Reached the divider, or the car is wedged against it (the divider to the right of the gap
		# stops it a bit lower down, before it gets as far as CRASH_Y).
		var blocked := crash_time > 0.3 and car.get_real_velocity().length() < 30.0
		var hit := car.global_position.y < CRASH_Y
		if crash_kind == "left_gap":
			hit = car.global_position.y < TOP_CRASH_Y
		elif crash_kind == "right":
			hit = car.global_position.y > BOTTOM_CRASH_Y
		if hit or (blocked and crash_kind != "left_gap"):
			finished = true
			$death._on_car_death()
		return
	_check_turn_signs()
	if crashing:
		return
	_check_u_turn_ray()
	# Never took the U-turn (e.g. the cow was cleared away): no crash, the car just drives off the
	# screen and the "did not reach home" screen shows once it is gone.
	if car.global_position.x >= OFFSCREEN_X:
		finished = true
		not_home._on_car_death()
		return
	if crashing:
		return
	# The cow blocks the car's body, so catch the collision here as a crash.
	if car.global_position.distance_to($Cow.global_position) < 90.0:
		finished = true
		$death._on_car_death()
		return

func _draw_hint() -> void:
	if not SHOW_ZONE_HINTS or Global.play:
		return
	for s in _signs():
		if not s.dragging:
			continue
		var pulse := 0.25 + 0.15 * sin(Time.get_ticks_msec() / 200.0)
		var z: Rect2 = ZONES[s.kind]
		hint.draw_rect(z, Color(0.2, 1.0, 0.5, pulse))
		hint.draw_rect(z, Color(0.2, 1.0, 0.5, 0.9), false, 2.0)

# --- Feedback on the failure screens ---------------------------------------------------
func _placed_u_turn() -> Node:
	for s in _signs():
		if s.kind == "u_turn" and not s.is_in_sidebar():
			return s
	return null

func death_feedback() -> String:
	match crash_kind:
		"left":
			return "The car turned left at the sign and hit the divider. Try again!"
		"left_gap", "right":
			return "You crashed into the pavement. Try again."
	if crash_kind == "late":      # the sign stood past the turn
		return "The sign needs to be placed before the turn so that the car has time to react. Try again!"
	if crash_kind == "early":     # the sign stood before the turn
		return "The car turned the moment it saw the sign, before the turn, and hit the divider. Try again!"
	# No crash at the divider: the car drove on into the cow / pedestrian.
	if _placed_u_turn() != null or (left_item != null and left_item.global_position.x < 933.0) or (right_item != null and right_item.global_position.x < 933.0):  # a sign was placed but the car never reacted to it
		return "The sign was too far from the turn for the car to react to it. Try again!"
	var signal_item := find_child("traffic_signal", true, false) as Node2D
	if signal_item != null and signal_item.global_position.x < 933.0:
		return "Try not to kill pedestrians. Try again!"
	return "Find a way to make the car turn towards its destination."

func not_home_feedback() -> String:
	return "You didn't kill anyone, but that is not your destination. Try again!"
