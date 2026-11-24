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
	"u_turn": Rect2(320, 361, 80, 80),     # divider: 4 grid boxes to the left of the intersection at x=400
}
const SEE_AHEAD := 40.0       # how far in front of its centre the car sees the sign
const SEE_HALF_HEIGHT := 220.0  # the ray only reaches this far above/below the sign (car must be in its vicinity)
const CRASH_Y := 475.0        # car has reached the divider after turning up too early
const OFFSCREEN_X := 1230.0   # the car has driven off the right edge of the screen

@onready var roads: TileMapLayer = $"Map/Roads"
@onready var pause: Button = $"Map/pause"
@onready var car: CharacterBody2D = $"Map/car"
@onready var not_home: Node2D = $not_home

var hint: Node2D
var finished := false
var turn_checked := false
var crashing := false
var crash_kind := ""          # "early" / "late": where the wrongly placed sign sent the car
var crash_time := 0.0
var car_start_x := 0.0

func _ready() -> void:
	Global.safe = false
	Global.play = false
	Global.speed_mult = 1.0
	Global.speed_limit_kmh = 50.0
	# The gap in the divider is road too (it has no tile): signs may not stand in it.
	Global.extra_road_rects.assign([Rect2(437, 361, 163, 80)])
	Global.next_level = "res://scenes/Level3/level 3.tscn"
	car_start_x = car.global_position.x
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
		if car.global_position.y < CRASH_Y or blocked:
			finished = true
			$death._on_car_death()
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
	if crash_kind == "late":      # the sign stood past the turn
		return "The sign needs to be placed before the turn so that the car has time to react. Try again!"
	if crash_kind == "early":     # the sign stood before the turn
		return "The car turned the moment it saw the sign, before the turn, and hit the divider. Try again!"
	# No crash at the divider: the car drove on into the cow / pedestrian.
	if _placed_u_turn() != null:  # a sign was placed but the car never reacted to it
		return "The sign was too far from the turn for the car to react to it. Try again!"
	var signal_item := find_child("traffic_signal", true, false) as Node2D
	if signal_item != null and signal_item.global_position.x < 933.0:
		return "Try not to kill pedestrians. Try again!"
	return "Find a way to make the car turn towards its destination."

func not_home_feedback() -> String:
	return "You didn't kill anyone, but that is not your destination. Try again!"
