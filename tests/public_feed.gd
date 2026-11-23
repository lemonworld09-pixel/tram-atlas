extends SceneTree
## Usage: godot --headless -s tests/public_feed.gd -- archive.zip route_id YYYY-MM-DD
const Feed = preload("res://addons/tram_atlas/feed.gd")
const Builder = preload("res://addons/tram_atlas/route_builder.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		printerr("Expected ZIP path, GTFS route_id and service date.")
		quit(1)
		return
	var feed := Feed.new()
	if not feed.open_zip(args[0]):
		printerr(feed.error)
		quit(1)
		return
	var options := feed.trips_for(args[1], args[2])
	var why := feed.error
	for trip in options:
		var stops := feed.stops_for(trip.id)
		if stops.size() < 3:
			continue
		var segment := feed.segment(trip.id, 0, 2)
		if segment.is_empty():
			why = feed.error
			continue
		var route := Builder.build(segment)
		route.preview_enabled = false
		root.add_child(route)
		route.playing = false
		var path: Path3D = route.get_node("Track")
		var vehicle: PathFollow3D = route.get_node("Track/Vehicle")
		var good := path.curve.point_count >= 2
		for i in [2, 0, 1]:
			route.seek(route.arrivals[i])
			good = good and vehicle.position.distance_to(route.get_node("Stops").get_child(i).position) < 0.04
		print("route=",args[1]," trip=",trip.id," date=",args[2]," trips=",options.size(),
				" stops=",route.stop_names," arrivals=",route.arrivals," length=",path.curve.get_baked_length(),
				" vertices=",path.curve.point_count," stop_seek_match=",good)
		route.free()
		quit(0 if good else 1)
		return
	printerr("No playable three-stop stretch: ", why)
	quit(1)
