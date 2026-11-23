extends Control
## Screen-space annotations projected from the miniature's local metre grid.
const SERIF = preload("res://demo/type/DMSerifText-Regular.ttf")
const SANS = preload("res://demo/type/Barlow-SemiBold.ttf")
const MONO = preload("res://demo/type/IBMPlexMono-Medium.ttf")
const INK := Color("#224940")
const PAPER := Color("#faf6e9")
const RED := Color("#a93724")

var world: SubViewport
var stage: Node3D
var car: PathFollow3D
var badge := StyleBoxFlat.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	badge.bg_color = RED
	badge.set_corner_radius_all(3)

func _point(camera: Camera3D, position_3d: Vector3) -> Vector2:
	return camera.unproject_position(position_3d) * size / Vector2(world.size)

func _draw() -> void:
	if not is_instance_valid(world) or not is_instance_valid(stage):
		return
	var camera := world.get_camera_3d()
	if camera == null:
		return
	var river := _point(camera, stage.to_global(Vector3(189, -8, 95)))
	var bridge := _point(camera, stage.to_global(Vector3(192, 0, -10)))
	if Rect2(Vector2(30, 60), size - Vector2(130, 110)).has_point(river):
		draw_string(SERIF, river, "Vltava", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(INK, 0.83))
	if Rect2(Vector2(55, 95), size - Vector2(160, 145)).has_point(bridge):
		draw_line(bridge, bridge + Vector2(-8, -17), Color(INK, 0.65), 1.2, true)
		var origin := bridge + Vector2(-47, -42)
		draw_rect(Rect2(origin, Vector2(89, 23)), Color(PAPER, 0.92))
		draw_string(MONO, origin + Vector2(6, 16), "MOST LEGIÍ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	var tram := _point(camera, car.global_position + Vector3.UP * 4)
	draw_line(tram + Vector2(1, -1), tram + Vector2(8, -14), RED, 1.6, true)
	var origin := tram + Vector2(-6, -34)
	draw_style_box(badge, Rect2(origin, Vector2(28, 20)))
	draw_string(SANS, origin + Vector2(0, 15), "22", HORIZONTAL_ALIGNMENT_CENTER, 28, 15, PAPER)
