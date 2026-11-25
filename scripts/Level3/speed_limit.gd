# Speed limit sign of Level 3. Click it before pressing play and choose 30 or 50.
# The limit caps the speed of every car (see Global.speed_cap_px). It starts on 50.
# Once play is pressed the speed is frozen: the sign can't be opened or changed any more.
extends Node2D
@onready var label: Label = $Label
@onready var speed_sign: AnimatedSprite2D = $AnimatedSprite2D

signal clicked
signal unclicked
var inarea: bool = false
var frozen := false

func _ready():
	label.visible = false
	(load("res://scripts/click_outline.gd") as GDScript).attach(self)               # a white border: this placed sign can be clicked
	if inarea:
		scale /= Vector2(1.12, 1.12)
	inarea = false
	frozen = false
	Global.speed_limit_kmh = 50.0     # always starts on 50 (also after a restart)
	speed_sign.play("50")

func _process(_delta):
	if Global.play:
		if not frozen:                # play was just pressed: close the 30/50 buttons for good
			frozen = true
			label.visible = false
			unclicked.emit()
		return
	if Input.is_action_just_pressed("click") and inarea:
		label.visible = false
		clicked.emit()

func _on_area_2d_mouse_entered():
	if Global.play:
		return
	label.visible = true
	if not inarea:
		scale *= Vector2(1.12, 1.12)
	inarea = true

func _on_area_2d_mouse_exited():
	label.visible = false
	if inarea:
		scale /= Vector2(1.12, 1.12)
	inarea = false

func _on_thirty_pressed():
	if Global.play:                   # frozen
		return
	Global.speed_limit_kmh = 30.0
	unclicked.emit()
	speed_sign.play("30")

func _on_fifty_pressed():
	if Global.play:                   # frozen
		return
	Global.speed_limit_kmh = 50.0
	unclicked.emit()
	speed_sign.play("50")
