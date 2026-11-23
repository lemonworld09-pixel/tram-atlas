@tool
extends RefCounted
## Local GTFS Schedule catalog. One caller may use an instance at a time.

const Index = preload("csv_index.gd")
const Geometry = preload("shape_slice.gd")
const WEEK := ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
var routes: Array[Dictionary] = []
var suggested_date := ""
var error := ""
var _trips := {}
var _trips_by_route := {}
var _stations := {}
var _weekly := {}
var _exceptions := {}
var _members := {}
var _zip: ZIPReader
var _times: Index
var _shapes: Index
var _last_trip := ""
var _last_stops: Array[Dictionary] = []
var _earliest := ""


func open_zip(path: String) -> bool:
	error = ""
	suggested_date = ""
	routes.clear()
	_trips.clear()
	_trips_by_route.clear()
	_stations.clear()
	_weekly.clear()
	_exceptions.clear()
	_members.clear()
	_earliest = ""
	_times = null
	_shapes = null
	_last_trip = ""
	_last_stops.clear()
	_zip = ZIPReader.new()
	if _zip.open(path) != OK:
		error = "Could not open this local ZIP file."
		return false
	var tables := ["routes", "trips", "stops", "stop_times", "shapes", "calendar", "calendar_dates", "frequencies"]
	for member in _zip.get_files():
		var base := member.get_file()
		if member.begins_with("__MACOSX/") or not base.ends_with(".txt"):
			continue
		var table := base.trim_suffix(".txt")
		if table not in tables:
			continue
		if _members.has(table):
			error = "Multiple %s files in one ZIP. Select a single GTFS Schedule feed." % base
			return false
		_members[table] = member
	for name in ["routes", "trips", "stops", "stop_times"]:
		if not _members.has(name):
			error = "The ZIP is missing %s.txt." % name
			return false
	if not _members.has("calendar") and not _members.has("calendar_dates"):
		error = "The ZIP needs calendar.txt or calendar_dates.txt to resolve service dates."
		return false
	var ok := _read("routes", ["route_id"], ["route_short_name", "route_long_name"], _add_route)
	ok = ok and _read("trips", ["trip_id", "route_id", "service_id"],
			["direction_id", "trip_headsign", "shape_id", "trip_short_name"], _add_trip)
	ok = ok and _read("stops", ["stop_id"], ["stop_name", "stop_lat", "stop_lon"], _add_station)
	if ok and _members.has("calendar"):
		ok = _read("calendar", ["service_id", "start_date", "end_date"] + WEEK, [], _add_calendar)
	if ok and _members.has("calendar_dates"):
		ok = _read("calendar_dates", ["service_id", "date", "exception_type"], [], _add_exception)
	if ok and _members.has("frequencies"):
		ok = _read("frequencies", ["trip_id"], [], _add_frequency)
	if not ok:
		return false
	if routes.is_empty() or _trips.is_empty():
		error = "No routes or trips in the timetable."
		return false
	_times = Index.new()
	if not _times.build(_zip.read_file(_members.stop_times), "trip_id",
			["trip_id", "stop_sequence", "stop_id", "arrival_time", "departure_time"]):
		error = "stop_times.txt: " + _times.error
		return false
	routes.sort_custom(func(a: Dictionary, b: Dictionary): return a.label.naturalnocasecmp_to(b.label) < 0)
	suggested_date = _suggest_date()
	return true


func _read(table: String, required: Array, optional: Array, consume: Callable) -> bool:
	var file := FileAccess.create_temp(FileAccess.WRITE_READ, "gtfs", "csv")
	if file == null:
		error = "Could not allocate a temporary CSV reader."
		return false
	file.store_buffer(_zip.read_file(_members[table]))
	var length := file.get_position()
	file.seek(0)
	var header := file.get_csv_line()
	if not header.is_empty():
		header[0] = header[0].trim_prefix("\uFEFF")
	var columns := {}
	for key in required + optional:
		var i := header.find(key)
		if i < 0 and key in required:
			error = "%s.txt is missing the '%s' column." % [table, key]
			return false
		columns[key] = i
	while file.get_position() < length:
		var values := file.get_csv_line()
		if values.size() == 1 and values[0].is_empty():
			continue
		var row := {}
		for key in columns:
			var i: int = columns[key]
			row[key] = values[i] if i >= 0 and i < values.size() else ""
		consume.call(row)
	return true


func _add_route(row: Dictionary) -> void:
	var title := PackedStringArray()
	for name in [row.route_short_name, row.route_long_name]:
		if name != "" and not title.has(name):
			title.append(name)
	routes.append({"id": row.route_id, "label": "  ·  ".join(title) if title.size() else row.route_id})


func _add_trip(row: Dictionary) -> void:
	var id: String = row.trip_id
	_trips[id] = {"id": id, "route_id": row.route_id, "service_id": row.service_id,
		"direction": row.direction_id, "destination": row.trip_headsign, "shape_id": row.shape_id,
		"label": id if row.trip_short_name.is_empty() else "%s · %s" % [row.trip_short_name, id]}
	if not _trips_by_route.has(row.route_id):
		_trips_by_route[row.route_id] = []
	_trips_by_route[row.route_id].append(id)


func _add_station(row: Dictionary) -> void:
	_stations[row.stop_id] = {
		"name": row.stop_name if not row.stop_name.is_empty() else row.stop_id,
		"lat": row.stop_lat.to_float() if row.stop_lat.is_valid_float() else NAN,
		"lon": row.stop_lon.to_float() if row.stop_lon.is_valid_float() else NAN
	}


func _add_calendar(row: Dictionary) -> void:
	_weekly[row.service_id] = row
	if _earliest == "" or row.start_date < _earliest:
		_earliest = row.start_date


func _add_exception(row: Dictionary) -> void:
	if not _exceptions.has(row.date):
		_exceptions[row.date] = {}
	_exceptions[row.date][row.service_id] = row.exception_type == "1"
	if row.exception_type == "1" and (_earliest == "" or row.date < _earliest):
		_earliest = row.date


func _add_frequency(row: Dictionary) -> void:
	if not _trips.has(row.trip_id):
		return
	var trip: Dictionary = _trips[row.trip_id]
	if not trip.has("frequency_template"):
		trip.frequency_template = true
		trip.start_time = -1
		trip.label = "Frequency template  ·  " + trip.label


static func _iso(key: String) -> String:
	return "%s-%s-%s" % [key.substr(0, 4), key.substr(4, 2), key.substr(6, 2)]


static func _date_key(date: String) -> String:
	var key := date.replace("-", "")
	if key.length() != 8 or not key.is_valid_int() or date not in [key, _iso(key)]:
		return ""
	var month := int(key.substr(4, 2))
	var day := int(key.substr(6, 2))
	var year := int(key.substr(0, 4))
	var leap := (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
	var days := [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if month < 1 or month > 12 or day < 1 or day > days[month - 1]:
		return ""
	return key


func _services(key: String) -> Dictionary:
	var midnight := Time.get_unix_time_from_datetime_string(_iso(key) + "T00:00:00")
	var day: String = WEEK[Time.get_date_dict_from_unix_time(midnight).weekday]
	var active := {}
	for id in _weekly:
		var cal: Dictionary = _weekly[id]
		if key >= cal.start_date and key <= cal.end_date and cal[day] == "1":
			active[id] = true
	var changes: Dictionary = _exceptions.get(key, {})
	for id in changes:
		if changes[id]:
			active[id] = true
		else:
			active.erase(id)
	return active


func _suggest_date() -> String:
	var today := Time.get_date_string_from_system()
	if not _services(today.replace("-", "")).is_empty():
		return today
	if _date_key(_earliest) == "":
		return today
	var stamp := Time.get_unix_time_from_datetime_string(_iso(_earliest) + "T00:00:00")
	for n in range(7):
		var candidate := Time.get_date_string_from_unix_time(stamp + n * 86400)
		if not _services(candidate.replace("-", "")).is_empty():
			return candidate
	return _iso(_earliest)


func trips_for(route_id: String, date: String) -> Array[Dictionary]:
	error = ""
	var result: Array[Dictionary] = []
	var key := _date_key(date)
	if key.is_empty():
		error = "Enter a valid service date in YYYY-MM-DD format."
		return result
	var active := _services(key)
	for id in _trips_by_route.get(route_id, []):
		var trip: Dictionary = _trips[id]
		if not active.has(trip.service_id):
			continue
		if not trip.has("start_time"):
			# GTFS permits unordered rows and arbitrary first stop_sequence numbers.
			var first_sequence := 9223372036854775807
			var last_sequence := -1
			var first := ""
			var seq_col := _times.header.find("stop_sequence")
			var time_col := _times.header.find("departure_time")
			var stop_col := _times.header.find("stop_id")
			var required_col := maxi(stop_col, maxi(seq_col, time_col))
			var terminal := ""
			for values in _times.rows(id):
				if values.size() <= required_col:
					continue
				var sequence := int(values[seq_col])
				if sequence < first_sequence:
					first_sequence = sequence
					first = values[time_col]
				if sequence > last_sequence:
					last_sequence = sequence
					terminal = values[stop_col]
			trip.start_time = seconds(first)
			if trip.destination.is_empty() and _stations.has(terminal):
				trip.destination = _stations[terminal].name
			if not first.is_empty():
				trip.label = first + "  ·  " + trip.label
		result.append(trip)
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		if a.start_time == b.start_time:
			return a.id.naturalnocasecmp_to(b.id) < 0
		return a.start_time < b.start_time)
	return result


static func seconds(value: String) -> int:
	var parts := value.split(":")
	if parts.size() != 3:
		return -1
	for part in parts:
		if not part.is_valid_int() or int(part) < 0:
			return -1
	if int(parts[1]) > 59 or int(parts[2]) > 59:
		return -1
	return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])


func stops_for(trip_id: String) -> Array[Dictionary]:
	error = ""
	if trip_id == _last_trip and not _last_stops.is_empty():
		return _last_stops
	var ordered: Array[Dictionary] = []
	if not _trips.has(trip_id):
		error = "Unknown trip ID."
		return ordered
	if _trips[trip_id].has("frequency_template"):
		error = "Trip %s is a frequencies.txt template. Select a scheduled trip with explicit stop times. Headway-based departures are not expanded." % trip_id
		return ordered
	var col := {}
	for name in ["stop_id", "stop_sequence", "arrival_time", "departure_time", "shape_dist_traveled"]:
		col[name] = _times.header.find(name)
	for values in _times.rows(trip_id):
		if values.size() <= maxi(maxi(col.stop_id, col.stop_sequence), maxi(col.arrival_time, col.departure_time)):
			error = "A stop_times.txt row is incomplete for trip " + trip_id
			return []
		var id := values[col.stop_id]
		if not _stations.has(id):
			error = "Trip %s references unknown stop '%s'." % [trip_id, id]
			return []
		var s: Dictionary = _stations[id].duplicate()
		var dist := ""
		if col.shape_dist_traveled >= 0 and col.shape_dist_traveled < values.size():
			dist = values[col.shape_dist_traveled]
		s.merge({"id": id, "sequence": int(values[col.stop_sequence]),
			"arrival": seconds(values[col.arrival_time]), "departure": seconds(values[col.departure_time]),
			"measure": dist.to_float() if dist.is_valid_float() else NAN})
		ordered.append(s)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary): return a.sequence < b.sequence)
	if ordered.size() < 2:
		error = "This trip has fewer than two stop times."
		return []
	_last_trip = trip_id
	_last_stops = ordered
	return ordered


func segment(trip_id: String, first: int, last: int) -> Dictionary:
	var calls := stops_for(trip_id)
	if not error.is_empty():
		return {}
	if first < 0 or last >= calls.size() or last <= first:
		error = "Choose at least two consecutive stops in timetable order."
		return {}
	var previous := -1
	for i in range(first, last + 1):
		var s := calls[i]
		if s.arrival < 0 or s.departure < 0:
			error = "Stop '%s' has no complete published arrival/departure time. Choose a fully timed stretch." % s.name
			return {}
		if s.departure < s.arrival or s.arrival < previous:
			error = "Nonchronological stop times at '%s'." % s.name
			return {}
		previous = s.departure
	var trip: Dictionary = _trips[trip_id]
	if trip.shape_id == "" or not _members.has("shapes"):
		error = "Trip %s has no usable published shape (shape_id or shapes.txt is missing)." % trip_id
		return {}
	if _shapes == null:
		_shapes = Index.new()
		if not _shapes.build(_zip.read_file(_members.shapes), "shape_id",
				["shape_id", "shape_pt_lat", "shape_pt_lon", "shape_pt_sequence"]):
			error = "shapes.txt: " + _shapes.error
			_shapes = null
			return {}
	var geometry := Geometry.new()
	var result := geometry.slice(_shapes.header, _shapes.rows(trip.shape_id), calls, first, last)
	if result.is_empty():
		error = "Shape %s: %s" % [trip.shape_id, geometry.error]
		return {}
	result.merge({"trip_id": trip_id, "route_id": trip.route_id, "destination": trip.destination,
		"shape_id": trip.shape_id, "service_id": trip.service_id})
	return result
