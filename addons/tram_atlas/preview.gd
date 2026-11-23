extends Node3D
## Self-contained playable surroundings for a freshly imported route.

@onready var route = get_parent()
var camera: Camera3D
var timeline: HSlider
var clock_label: Label
var stop_label: Label
var play_button: Button


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#d7e1dd")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ffffff")
	env.ambient_light_energy = 0.52
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -28, 0)
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	add_child(sun)

	var curve: Curve3D = route.get_node("Track").curve
	var points := curve.tessellate(5, 1.0)
	if points.size() < 2:
		return
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var ground := BoxMesh.new()
	ground.size = Vector3(bounds.size.x + 600.0, 0.3, bounds.size.z + 600.0)
	var ground_node := MeshInstance3D.new()
	ground_node.mesh = ground
	ground_node.position = bounds.get_center() - Vector3.UP * 0.25
	var map_paper := ShaderMaterial.new()
	map_paper.shader = preload("res://addons/tram_atlas/survey_grid.gdshader")
	ground_node.material_override = map_paper
	add_child(ground_node)
	_strip(points, 0.0, 2.3, -0.05, Color("#8f918a"))
	for offset in [-0.72, 0.72]:
		_strip(points, offset, 0.085, 0.0, Color("#39474a"))

	for i in route.stop_names.size():
		var label := Label3D.new()
		label.text = route.stop_names[i]
		label.position = curve.sample_baked(route.distances[i]) + Vector3.UP * 6
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 42
		label.pixel_size = 0.034
		label.outline_size = 8
		add_child(label)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 58.0
	camera.far = 1000.0
	add_child(camera)
	camera.make_current()
	_build_controls()
	route.sampled.connect(_update)
	route.playback_changed.connect(_update_play_button)
	_update(route.current_time)
	_update_play_button()


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


func _strip(points: PackedVector3Array, offset: float, half_width: float, y: float, color: Color) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := _material(color)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.set_material(mat)
	var left := Vector3.ZERO
	var right := Vector3.ZERO
	for i in points.size():
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var normal := tangent.cross(Vector3.UP).normalized()
		var center := points[i] + Vector3.UP * y + normal * offset
		var next_left := center - normal * half_width
		var next_right := center + normal * half_width
		if i > 0:
			for vertex: Vector3 in [left, next_right, right, left, next_left, next_right]:
				mesh.set_normal(Vector3.UP)
				mesh.add_vertex(vertex)
		left = next_left
		right = next_right
	var node := MeshInstance3D.new()
	node.mesh = mesh.commit()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _build_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = -108
	panel.offset_bottom = -16
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#18332f")
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	stack.add_child(controls)
	play_button = Button.new()
	play_button.pressed.connect(route.toggle_playback)
	controls.add_child(play_button)
	clock_label = Label.new()
	controls.add_child(clock_label)
	stop_label = Label.new()
	stop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stop_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	controls.add_child(stop_label)
	var speeds := OptionButton.new()
	speeds.tooltip_text = "Simulation speed"
	var options: Array[float] = [1.0, 4.0, 12.0, 36.0]
	if not options.has(route.speed):
		options.append(route.speed)
		options.sort()
	for speed in options:
		speeds.add_item("%s×" % speed)
	speeds.select(options.find(route.speed))
	speeds.item_selected.connect(func(index: int): route.speed = options[index])
	controls.add_child(speeds)
	timeline = HSlider.new()
	timeline.tooltip_text = "Service time"
	timeline.min_value = route.arrivals[0]
	timeline.max_value = route.departures[-1]
	timeline.step = 0.25
	timeline.value_changed.connect(route.seek)
	stack.add_child(timeline)


func _update(seconds: float) -> void:
	timeline.set_value_no_signal(seconds)
	clock_label.text = route.format_clock(seconds)
	var index := 0
	while index < route.stop_names.size() - 1 and seconds > route.departures[index]:
		index += 1
	var prefix := "Next  ·  " if seconds < route.arrivals[index] else ""
	stop_label.text = prefix + route.stop_names[index]
	var target: Vector3 = route.get_node("Track/Vehicle").position
	camera.position = target + Vector3(46, 48, 52)
	camera.look_at(target + Vector3.UP * 1.5)


func _update_play_button() -> void:
	if route.playing:
		play_button.text = "Pause"
	elif route.current_time >= route.departures[-1]:
		play_button.text = "Replay"
	else:
		play_button.text = "Play"
