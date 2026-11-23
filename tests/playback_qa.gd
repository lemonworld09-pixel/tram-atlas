extends SceneTree
## Exercise the shipped scene and actual GUI input. Optional argument is a PNG output directory.
var failures := PackedStringArray()
var demo
var route
var car: PathFollow3D
var output := ""
var capture_stops := false

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		capture_stops = args.size() > 1 and args[1] == "stops"
	change_scene_to_file("res://demo/prague.tscn")
	await scene_changed
	await process_frame
	demo = current_scene
	route = demo.get_node("Map/World/Route")
	car = route.get_node("Track/Vehicle")
	var curve: Curve3D = route.get_node("Track").curve
	check(route.playing, "Demo starts playing")
	await click(demo.play_button)
	check(not route.playing, "Pause button stops playback")
	await click(demo.speed_button)
	check(route.speed == 8, "Speed button changes from 4× to 8×")
	for multiplier in [16, 1, 2, 4]:
		await click(demo.speed_button)
		check(route.speed == multiplier, "Speed cycles to %d×" % multiplier)
	var mid_time: float = (route.departures[0] + route.arrivals[1]) * 0.5
	var path_length := curve.get_baked_length()
	# Independently calculated from the official feed, in east/up/south metres.
	var expected_stops := [Vector3(0, 0, 3.00227), Vector3(-630.69501, 0, 29.68909), Vector3(-689.06230, 0, -303.11779)]
	check(absf(path_length - 1005) < 5, "Prague crossing is approximately one kilometre")
	for i in [2, 0, 1, 0]:
		await click(demo.station_buttons[i])
		check(is_equal_approx(route.current_time, route.arrivals[i]), "Clicked stop %d changes service clock" % i)
		var target: Marker3D = route.get_node("Stops").get_child(i)
		check(car.position.distance_to(target.position) < 0.02, "Alignment at " + route.stop_names[i])
		check(car.position.distance_to(expected_stops[i]) < 0.02, "Position agrees with independent GTFS projection")
		print(route.stop_names[i], " ", demo.clock_label.text, " progress=", car.progress, " at=", car.position)
		if capture_stops:
			await capture("stop-%d" % (i + 1))
			await click(demo.view_buttons[1])
			await capture("stop-%d-tram" % (i + 1))
			await click(demo.view_buttons[0])
	# A slider click and drag go through Godot's viewport dispatch and slider quantization.
	var slider: HSlider = demo.slider
	var slider_rect := slider.get_global_rect()
	var thumb_width := slider.get_theme_icon("grabber").get_width()
	var track_start := slider_rect.position.x + thumb_width * 0.5
	var track_width := slider_rect.size.x - thumb_width
	var from := Vector2(track_start + track_width * 0.75, slider_rect.get_center().y)
	var to := Vector2(track_start + track_width * 0.25, from.y)
	mouse(from, true)
	await process_frame
	check(absf(route.current_time - 36180.0) < 1.0, "Slider seeks forward to 10:03")
	var move := InputEventMouseMotion.new()
	move.position = to
	move.global_position = to
	move.relative = to - from
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move, true)
	await process_frame
	mouse(to, false)
	await process_frame
	check(absf(route.current_time - mid_time) < 1.0, "Dragging backward seeks to 10:01")
	var expected := curve.sample_baked(route.distances[1] * 0.5)
	check(car.position.distance_to(expected) < 3, "Tram reaches midpoint of first leg")
	check(car.position.distance_to(Vector3(-315.38163, 0, 15.70062)) < 3, "Midpoint lies above the bridge")
	var tangent := curve.sample_baked(car.progress + 1) - curve.sample_baked(car.progress - 1)
	check((-car.basis.z).dot(tangent.normalized()) > 0.98, "Tram points along track in travel direction")
	print("Bridge scrub ",demo.clock_label.text," progress=",car.progress," at=",car.position," alignment=",(-car.basis.z).dot(tangent.normalized()))
	await capture("prague-crossing")
	await click(demo.view_buttons[1])
	check(demo.near_view, "Tram view toggles on")
	await capture("prague-tram-view")
	await click(demo.view_buttons[0])
	check(not demo.near_view, "Overview restores")
	await click(demo.play_button)
	var resumed := float(route.current_time)
	await create_timer(0.14).timeout
	check(route.current_time > resumed, "Play resumes after backward scrub")
	await click(demo.station_buttons[2])
	await process_frame
	check(not route.playing, "Final stop pauses clock")
	await click(demo.play_button)
	check(route.playing and route.current_time < route.arrivals[0] + 3.0, "Replay restarts at the first stop")
	print("Demo QA failures=",failures.size()," logical viewport=",root.get_visible_rect().size," window=",root.size)
	quit(0 if failures.is_empty() else 1)

func mouse(pos: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	root.push_input(event, true)

func click(button: Control) -> void:
	var p := button.get_global_rect().get_center()
	mouse(p, true)
	mouse(p, false)
	await process_frame

func capture(stem: String) -> void:
	if output.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.save_png(output.path_join(stem + ".png")) == OK, "Save viewport image " + stem)
