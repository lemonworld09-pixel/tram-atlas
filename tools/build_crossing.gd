extends SceneTree
## Rebuild the shipped editable route through the same feed and scene builder as the dock.
const Feed = preload("res://addons/tram_atlas/feed.gd")
const Builder = preload("res://addons/tram_atlas/route_builder.gd")

func _initialize() -> void:
	var feed := Feed.new()
	var args := OS.get_cmdline_user_args()
	var source := args[0] if args.size() else "res://demo/data/prague-22.zip"
	if not feed.open_zip(source):
		_fail(feed.error)
		return
	var candidates := feed.trips_for("L22", "2026-11-23")
	var selected := "22_33955_260831"
	if not candidates.any(func(trip: Dictionary): return trip.id == selected):
		_fail("Requested trip is not active on 23 November 2026.")
		return
	var segment := feed.segment(selected, 26, 28)
	if segment.is_empty():
		_fail(feed.error)
		return
	var scene := Builder.build(segment)
	scene.set_meta("service_date", "2026-11-23")
	var destination := args[1] if args.size() > 1 else "res://demo/data/crossing.tscn"
	var result := Builder.save_scene(scene, destination)
	print("Prague trip ", selected, " | ", candidates.size(), " active line 22 trips | ",
			segment.points.size(), " shape vertices | ", scene.stop_names, " | ", scene.distances,
			" m | ", scene.arrivals, " service seconds")
	scene.free()
	quit(0 if result == OK else 1)

func _fail(message: String) -> void:
	printerr(message)
	quit(1)
