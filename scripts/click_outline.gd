# Solid white border around a sign that is already placed and can be clicked to adjust it (the adjustable traffic
# signal, the speed limit sign). The border follows the exact outline of the sign's picture (it is traced from the
# picture's own pixels), follows the sign, grows with it when the mouse is over it, and disappears once the level
# is running (nothing can be adjusted any more then).
extends Node2D

const WHITE := Color(1, 1, 1, 1)
const THICKNESS := 2            # px on screen

var target: Node2D
var area: Area2D
var sprite: Node2D
var outline: ImageTexture
var pad := 0.0                  # extra px around the picture (the border)
var base_scale := Vector2.ONE   # the sprite's scale on screen when the border was built

static func attach(sign_node: Node2D) -> void:
	var o: Node2D = (load("res://scripts/click_outline.gd") as GDScript).new()
	o.target = sign_node
	o.area = sign_node.get_node("Area2D")
	o.sprite = sign_node.get_node_or_null("AnimatedSprite2D")
	if o.sprite == null:
		o.sprite = sign_node.get_node_or_null("Sprite2D")
	sign_node.add_child(o)

# The picture of a sprite node (the first frame of an animation).
static func sprite_texture(s: Node) -> Texture2D:
	if s is AnimatedSprite2D:
		var frames := (s as AnimatedSprite2D).sprite_frames
		var anim := (s as AnimatedSprite2D).animation
		if frames != null and frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
			return frames.get_frame_texture(anim, 0)
	elif s is Sprite2D:
		return (s as Sprite2D).texture
	return null

# Traces the outline of a picture: `k` is how many screen px one texture px is, `thick` the border width in screen
# px. Returns an image at SCREEN resolution (1 texel = 1 px) that is white exactly where the border goes: every
# transparent pixel within `thick` px of an opaque pixel of the picture. The image is bigger than the picture by
# `thick` px on every side.
static func trace(tex: Texture2D, k: float, thick: int) -> ImageTexture:
	var img := tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var w := maxi(4, int(round(img.get_width() * k)))
	var h := maxi(4, int(round(img.get_height() * k)))
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var ow := w + 2 * thick
	var oh := h + 2 * thick
	var solid := PackedByteArray()
	solid.resize(ow * oh)
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a >= 0.5:
				solid[(y + thick) * ow + (x + thick)] = 1
	var out := Image.create(ow, oh, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in oh:
		for x in ow:
			if solid[y * ow + x] == 1:
				continue
			var hit := false
			for dy in range(-thick, thick + 1):
				for dx in range(-thick, thick + 1):
					if dx * dx + dy * dy > thick * thick:
						continue
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < ow and ny < oh and solid[ny * ow + nx] == 1:
						hit = true
						break
				if hit:
					break
			if hit:
				out.set_pixel(x, y, WHITE)
	return ImageTexture.create_from_image(out)

func _ready() -> void:
	top_level = true                  # not scaled with the sign
	z_index = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprite != null:
		var tex := sprite_texture(sprite)
		base_scale = sprite.get_global_transform().get_scale().abs()
		if tex != null:
			outline = trace(tex, base_scale.x, THICKNESS)
			pad = THICKNESS

func _process(_delta: float) -> void:
	visible = is_instance_valid(target) and not Global.play and target.global_position.x < 933.0
	if visible:
		global_position = target.global_position
		queue_redraw()

func _draw() -> void:
	if outline == null or sprite == null or not is_instance_valid(target):
		return
	var ratio: Vector2 = sprite.get_global_transform().get_scale().abs() / base_scale     # the sign grows when hovered
	var size := Vector2(outline.get_size()) * ratio
	var centre: Vector2 = sprite.global_position - target.global_position
	draw_texture_rect(outline, Rect2(centre - size / 2.0, size), false)

# A flat one-colour copy of a picture: every visible pixel becomes `color` (used for the locked signs of the
# encyclopedia: the sign itself must not be recognisable). `k` is how many screen px one texture px is.
static func silhouette(tex: Texture2D, k: float, color: Color) -> ImageTexture:
	var img := tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var w := maxi(4, int(round(img.get_width() * k)))
	var h := maxi(4, int(round(img.get_height() * k)))
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	for y in h:
		for x in w:
			img.set_pixel(x, y, color if img.get_pixel(x, y).a >= 0.5 else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
