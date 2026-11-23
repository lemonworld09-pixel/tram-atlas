extends SceneTree

const Feed = preload("res://addons/tram_atlas/feed.gd")
const Builder = preload("res://addons/tram_atlas/route_builder.gd")
const Player = preload("res://addons/tram_atlas/route_player.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var feed := Feed.new()
	if not feed.open_zip("res://tests/fixtures/synthetic-night.zip"):
		printerr(feed.error)
		quit(1)
		return
	var route := Builder.build(feed.segment('Night, "A"', 0, 2))
	route.playing = false
	root.add_child(route)
	var car: PathFollow3D = route.get_node("Track/Vehicle")
	var dwell: Vector3 = route.get_node("Stops").get_child(1).position
	var ok := true
	for seconds in [87300, 87330, 87360, 87840, 87316]:
		route.seek(seconds)
		if seconds != 87840:
			ok = ok and car.position.distance_to(dwell) < 0.02
		else:
			ok = ok and car.position.distance_to(dwell) > 100
		var label: Label = route.get_node("RoutePreview").clock_label
		ok = ok and label.text == Player.format_clock(seconds)
		print(label.text," | ",car.progress," m")
	# Exercise the Inspector property with a user-authored Node3D PackedScene.
	var replacement := PackedScene.new()
	var body := Node3D.new()
	body.set_meta("custom_vehicle", true)
	replacement.pack(body)
	body.free()
	route.vehicle_scene = replacement
	ok = ok and car.get_node("Model").has_meta("custom_vehicle")
	# Save and reload the replacement with the complete route as a new scene.
	var path := "user://synthetic-persistence-test.tscn"
	ok = ok and Builder.save_scene(route, path) == OK
	route.free()
	var saved := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var reopened := saved.instantiate()
	root.add_child(reopened)
	ok = ok and reopened.get_node("Track/Vehicle/Model").has_meta("custom_vehicle")
	reopened.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("After-midnight dwell, custom PackedScene replacement and reload: ",ok)
	quit(0 if ok else 1)
