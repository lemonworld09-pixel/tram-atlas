@tool
extends RefCounted
## Converts a selected GTFS segment to independently editable scene nodes.

const Player = preload("res://addons/tram_atlas/route_player.gd")


static func build(segment: Dictionary) -> Node3D:
	var points: PackedVector3Array = segment.points
	var stops: Array = segment.stops
	if points.size() < 2 or stops.size() < 2:
		return null

	var root := Player.new()
	root.name = "TransitRoute"
	root.set_meta("gtfs_route_id", segment.route_id)
	root.set_meta("gtfs_trip_id", segment.trip_id)
	root.set_meta("destination", segment.destination)
	root.set_meta("origin_latitude", segment.origin_lat)
	root.set_meta("origin_longitude", segment.origin_lon)

	var track := Path3D.new()
	track.name = "Track"
	track.curve = Curve3D.new()
	track.curve.bake_interval = 1.0
	for point in points:
		track.curve.add_point(point)
	_attach(track, root, root)

	var follower := PathFollow3D.new()
	follower.name = "Vehicle"
	follower.loop = false
	follower.cubic_interp = false
	follower.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	follower.transform = Transform3D(Basis.looking_at(points[1] - points[0]), points[0])
	_attach(follower, track, root)

	var markers := Node3D.new()
	markers.name = "Stops"
	_attach(markers, root, root)
	for index in stops.size():
		var stop: Dictionary = stops[index]
		var marker := Marker3D.new()
		marker.name = ("%02d %s" % [index + 1, stop.name]).validate_node_name()
		marker.position = track.curve.sample_baked(stop.distance)
		marker.set_meta("gtfs_stop_id", stop.id)
		marker.set_meta("stop_sequence", stop.sequence)
		marker.set_meta("arrival", stop.arrival)
		marker.set_meta("departure", stop.departure)
		_attach(marker, markers, root)
		root.arrivals.append(stop.arrival)
		root.departures.append(stop.departure)
		root.stop_names.append(stop.name)
		root.distances.append(stop.distance)
	return root


static func save_scene(root: Node3D, path: String) -> Error:
	var scene := PackedScene.new()
	var error := scene.pack(root)
	if error != OK:
		return error
	return ResourceSaver.save(scene, path)


static func _attach(child: Node, parent: Node, owner: Node) -> void:
	parent.add_child(child)
	child.owner = owner
