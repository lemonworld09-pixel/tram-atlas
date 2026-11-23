@tool
extends RefCounted
## Project a published polyline into a local east/up/south frame, then trim it
## without simplifying its vertices. GTFS measures are only used as parameters:
## the resulting distances are always geometric metres.

const EARTH_RADIUS := 6371008.8
var error := ""
var _lat := 0.0
var _lon := 0.0
var _points := PackedVector3Array()
var _metres := PackedFloat64Array()
var _measures := PackedFloat64Array()
var _measured_metres := PackedFloat64Array()


func _project(lat: float, lon: float) -> Vector3:
	return Vector3(EARTH_RADIUS * deg_to_rad(wrapf(lon - _lon, -180.0, 180.0)) * cos(deg_to_rad(_lat)),
		0.0, -EARTH_RADIUS * deg_to_rad(lat - _lat))


func _point_at(distance: float) -> Vector3:
	var high := _metres.bsearch(distance)
	if high == 0:
		return _points[0]
	if high >= _metres.size():
		return _points[-1]
	var t := inverse_lerp(_metres[high - 1], _metres[high], distance)
	return _points[high - 1].lerp(_points[high], t)


func _measure_at(value: float) -> float:
	if _measures.size() < 2 or not is_finite(value):
		return NAN
	if value < _measures[0] or value > _measures[-1]:
		return NAN
	var high := _measures.bsearch(value)
	if _measures[high] == value:
		return _measured_metres[high]
	var t := inverse_lerp(_measures[high - 1], _measures[high], value)
	return lerpf(_measured_metres[high - 1], _measured_metres[high], t)


func slice(header: PackedStringArray, rows: Array[PackedStringArray], calls: Array[Dictionary],
		first: int, last: int) -> Dictionary:
	if rows.size() < 2:
		error = "fewer than two published geometry points."
		return {}
	var lat_i := header.find("shape_pt_lat")
	var lon_i := header.find("shape_pt_lon")
	var seq_i := header.find("shape_pt_sequence")
	var measure_i := header.find("shape_dist_traveled")
	var required_i := maxi(seq_i, maxi(lat_i, lon_i))
	for row in rows:
		if row.size() <= required_i or not row[lat_i].is_valid_float() or not row[lon_i].is_valid_float() or not row[seq_i].is_valid_int():
			error = "incomplete or nonnumeric geometry point."
			return {}
		if absf(row[lat_i].to_float()) > 90 or absf(row[lon_i].to_float()) > 180:
			error = "shape coordinates are outside the WGS84 latitude/longitude ranges."
			return {}
	rows.sort_custom(func(a: PackedStringArray, b: PackedStringArray): return int(a[seq_i]) < int(b[seq_i]))
	_lat = calls[first].lat if is_finite(calls[first].lat) else float(rows[0][lat_i])
	_lon = calls[first].lon if is_finite(calls[first].lon) else float(rows[0][lon_i])
	for row in rows:
		var p := _project(float(row[lat_i]), float(row[lon_i]))
		if _points.is_empty():
			_metres.append(0)
			_points.append(p)
		elif _points[-1].distance_squared_to(p) > 0.000001:
			_metres.append(_metres[-1] + _points[-1].distance_to(p))
			_points.append(p)
		if measure_i >= 0 and measure_i < row.size() and row[measure_i].is_valid_float():
			var m := row[measure_i].to_float()
			if not _measures.is_empty() and m < _measures[-1]:
				error = "shape_dist_traveled decreases across the shape."
				return {}
			if _measures.is_empty() or m > _measures[-1]:
				_measures.append(m)
				_measured_metres.append(_metres[-1])
	if _points.size() < 2:
		error = "all published geometry points coincide."
		return {}
	var offsets := PackedFloat64Array()
	var complete := true
	for i in range(first, last + 1):
		var m := _measure_at(calls[i].measure)
		offsets.append(m)
		complete = complete and is_finite(m)
	if not complete:
		# Consider all calls, even for a short slice: earlier/later stops often
		# disambiguate a shared section of track on a loop or out-and-back trip.
		offsets = _match_in_order(calls, first, last)
		if offsets.is_empty():
			return {}
	for i in range(1, offsets.size()):
		if offsets[i] < offsets[i - 1]:
			error = "published stop distances run backwards."
			return {}
	if offsets[-1] - offsets[0] < 0.01:
		error = "selected stops occupy the same point on the published shape."
		return {}
	var points := PackedVector3Array([_point_at(offsets[0])])
	for i in range(_metres.bsearch(offsets[0], false), _metres.bsearch(offsets[-1])):
		points.append(_points[i])
	points.append(_point_at(offsets[-1]))
	var stops: Array[Dictionary] = []
	for i in range(offsets.size()):
		var stop := calls[first + i].duplicate()
		stop.distance = offsets[i] - offsets[0]
		stop.position = _point_at(offsets[i])
		stops.append(stop)
	return {"points": points, "stops": stops, "origin_lat": _lat, "origin_lon": _lon}


func _match_in_order(calls: Array[Dictionary], first: int, last: int) -> PackedFloat64Array:
	# Dynamic programming finds the least total squared platform-to-track error
	# among monotonically ordered projections, including exact measure anchors.
	# Prefix minima keep this linear in (stops × shape segments).
	var layers: Array[Dictionary] = []
	var previous_d := PackedFloat64Array()
	var previous_cost := PackedFloat64Array()
	for i in range(calls.size()):
		var call := calls[i]
		var d := PackedFloat64Array()
		var costs := PackedFloat64Array()
		var anchor := _measure_at(call.measure)
		if is_finite(anchor):
			d.append(anchor)
			costs.append(0.0)
		elif is_finite(call.lat) and is_finite(call.lon):
			var platform := _project(call.lat, call.lon)
			for j in range(1, _points.size()):
				var a := _points[j - 1]
				var v := _points[j] - a
				var t := clampf((platform - a).dot(v) / v.length_squared(), 0.0, 1.0)
				d.append(lerpf(_metres[j - 1], _metres[j], t))
				costs.append(platform.distance_squared_to(a + t * v))
		elif i >= first and i <= last:
			error = "stop '%s' has neither a location nor a usable published shape distance." % call.name
			return PackedFloat64Array()
		else:
			continue
		var back := PackedInt32Array()
		if not layers.is_empty():
			var k := 0
			var best := INF
			var best_index := -1
			for j in range(d.size()):
				while k < previous_d.size() and previous_d[k] <= d[j]:
					if previous_cost[k] < best:
						best = previous_cost[k]
						best_index = k
					k += 1
				costs[j] += best
				back.append(best_index)
		layers.append({"distance": d, "back": back, "call": i})
		previous_d = d
		previous_cost = costs
	var winner := 0
	for j in range(1, previous_cost.size()):
		if previous_cost[j] < previous_cost[winner]:
			winner = j
	if not is_finite(previous_cost[winner]):
		error = "stops cannot be matched in order to the published shape."
		return PackedFloat64Array()
	var selected := PackedFloat64Array()
	selected.resize(last - first + 1)
	for j in range(layers.size() - 1, -1, -1):
		var layer := layers[j]
		var i: int = layer.call
		if i >= first and i <= last:
			var offset: float = layer.distance[winner]
			selected[i - first] = offset
			# GTFS recommends stops lie within 100 m of their shape. Reject
			# clearly unrelated geometry rather than silently moving a platform.
			if not is_finite(_measure_at(calls[i].measure)) and _point_at(offset).distance_to(_project(calls[i].lat, calls[i].lon)) > 500.0:
				error = "stop '%s' is over 500 m from the ordered shape." % calls[i].name
				return PackedFloat64Array()
		if j > 0:
			winner = layer.back[winner]
	return selected
