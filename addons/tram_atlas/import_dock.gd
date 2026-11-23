@tool
extends ScrollContainer
## The feed is touched by a single worker at a time. All controls, scene
## construction, resource saves and editor API calls stay on the main thread.

const FeedWorker = preload("res://addons/tram_atlas/feed_worker.gd")
const Builder = preload("res://addons/tram_atlas/route_builder.gd")

var worker := FeedWorker.new()
var busy := false
var feed_error := ""
var route_catalog: Array = []
var done: Callable
var loaded := false
var trips: Array = []
var stops: Array = []
var routes: OptionButton
var directions: OptionButton
var trip_selector: OptionButton
var start_stop: OptionButton
var end_stop: OptionButton
var choose_zip: Button
var generate: Button
var refresh: Button
var date: LineEdit
var search: LineEdit
var search_timer: Timer
var search_pending := false
var source_label: Label
var status: Label
var source_dialog: EditorFileDialog
var save_dialog: EditorFileDialog
var form: VBoxContainer
var segment: Dictionary = {}


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 8)
	add_child(pad)
	form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 5)
	pad.add_child(form)

	choose_zip = Button.new()
	choose_zip.text = "Select GTFS ZIP…"
	choose_zip.pressed.connect(func(): source_dialog.popup_centered_ratio(0.7))
	form.add_child(choose_zip)
	source_label = _label("Choose a local GTFS Schedule archive.")
	source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(HSeparator.new())
	_label("Service date")
	var row := HBoxContainer.new()
	form.add_child(row)
	date = LineEdit.new()
	date.placeholder_text = "YYYY-MM-DD"
	date.size_flags_horizontal = SIZE_EXPAND_FILL
	date.text_changed.connect(func(_text): _invalidate_date())
	date.text_submitted.connect(func(_text): _query_trips())
	row.add_child(date)
	refresh = Button.new()
	refresh.text = "Apply"
	refresh.pressed.connect(_query_trips)
	row.add_child(refresh)
	_label("Route")
	search = LineEdit.new()
	search.placeholder_text = "Find a line…"
	search.clear_button_enabled = true
	search.text_changed.connect(_schedule_search)
	form.add_child(search)
	search_timer = Timer.new()
	search_timer.one_shot = true
	search_timer.wait_time = 0.35
	search_timer.timeout.connect(_refilter_routes)
	add_child(search_timer)
	routes = _choice()
	routes.item_selected.connect(func(_index): _query_trips())
	_label("Direction / destination")
	directions = _choice()
	directions.item_selected.connect(func(_index): _show_direction())
	_label("Trip")
	trip_selector = _choice()
	trip_selector.item_selected.connect(func(_index): _query_stops())
	_label("First stop")
	start_stop = _choice()
	start_stop.item_selected.connect(func(_index): _list_end_stops())
	_label("Last stop")
	end_stop = _choice()
	end_stop.item_selected.connect(func(_index): _segment_status())
	form.add_child(HSeparator.new())
	generate = Button.new()
	generate.text = "Generate route scene…"
	generate.pressed.connect(_prepare_segment)
	form.add_child(generate)
	status = _label("")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_dialog = EditorFileDialog.new()
	source_dialog.name = "ChooseArchive"
	source_dialog.title = "Select a GTFS Schedule ZIP"
	source_dialog.access = FileDialog.ACCESS_FILESYSTEM
	source_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	source_dialog.add_filter("*.zip", "GTFS Schedule ZIP")
	add_child(source_dialog)
	source_dialog.file_selected.connect(_open)
	save_dialog = EditorFileDialog.new()
	save_dialog.name = "SaveRoute"
	save_dialog.title = "Save editable route scene"
	save_dialog.access = FileDialog.ACCESS_RESOURCES
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.add_filter("*.tscn", "Godot scene")
	add_child(save_dialog)
	save_dialog.file_selected.connect(_save)
	_update_controls()
	set_process(false)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	form.add_child(label)
	return label


func _choice() -> OptionButton:
	var control := OptionButton.new()
	control.fit_to_longest_item = false
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	form.add_child(control)
	return control


func _picked(control: OptionButton):
	return control.get_item_metadata(control.selected) if control.selected >= 0 else null


func _add(control: OptionButton, title: String, value: Variant) -> void:
	control.add_item(title)
	control.set_item_metadata(control.item_count - 1, value)
	control.set_item_tooltip(control.item_count - 1, title)


func _update_controls() -> void:
	choose_zip.disabled = busy
	date.editable = loaded and not busy
	refresh.disabled = busy or not loaded or routes.item_count == 0
	search.editable = loaded
	for field: OptionButton in [routes, directions, trip_selector, start_stop, end_stop]:
		field.disabled = busy or field.item_count == 0
		if field.selected >= 0:
			field.tooltip_text = field.get_item_text(field.selected)
	generate.disabled = busy or end_stop.selected < 0


func _work(operation: String, args: Array, callback: Callable, message: String) -> void:
	if busy:
		return
	done = callback
	var err := worker.submit(operation, args)
	if err != OK:
		status.text = "Could not start the feed reader: " + error_string(err)
		_update_controls()
		return
	busy = true
	status.text = message
	_update_controls()
	set_process(true)


func _process(_delta: float) -> void:
	var result := worker.take_result()
	if result.is_empty():
		return
	busy = false
	feed_error = result.error
	set_process(false)
	if search_pending and loaded:
		if search_timer.is_stopped():
			_refilter_routes()
	else:
		done.call(result.value)
	_update_controls()


func finish_work() -> void:
	set_process(false)
	worker.close()
	busy = false


func _open(path: String) -> void:
	if busy:
		return
	loaded = false
	search_pending = false
	search_timer.stop()
	route_catalog.clear()
	routes.clear()
	_clear_trips()
	search.clear()
	source_label.text = path.get_file()
	source_label.tooltip_text = path
	_work("open", [path], _opened, "Reading feed and indexing its timetable…")


func _opened(catalog: Dictionary) -> void:
	if catalog.is_empty():
		status.text = feed_error
		return
	loaded = true
	route_catalog = catalog.routes
	date.text = catalog.date
	_refilter_routes()


func _refilter_routes() -> void:
	if not loaded or busy:
		return
	search_pending = false
	routes.clear()
	_clear_trips()
	var term := search.text.strip_edges().to_lower()
	for route: Dictionary in route_catalog:
		if term.is_empty() or term in str(route.label).to_lower() or term in str(route.id).to_lower():
			_add(routes, route.label, route.id)
	if routes.item_count:
		routes.select(0)
		_query_trips()
	else:
		status.text = "No route matches this search."
		_update_controls()


func _schedule_search(_text: String) -> void:
	if not loaded:
		return
	search_pending = true
	routes.clear()
	_clear_trips()
	_update_controls()
	search_timer.start()


func _invalidate_date() -> void:
	_clear_trips()
	status.text = "Apply the service date to list active trips."
	_update_controls()


func _clear_trips() -> void:
	directions.clear()
	trips = []
	trip_selector.clear()
	_clear_stops()


func _clear_stops() -> void:
	stops = []
	start_stop.clear()
	end_stop.clear()
	segment = {}


func _query_trips() -> void:
	if busy or routes.selected < 0:
		return
	_clear_trips()
	_work("trips", [_picked(routes), date.text.strip_edges()], _received_trips,
			"Finding trips on this service date…")


func _received_trips(result: Array) -> void:
	trips = result
	if trips.is_empty():
		status.text = feed_error if not feed_error.is_empty() else "No active trips on this date."
		return
	var known := {}
	for trip: Dictionary in trips:
		var pair := [str(trip.direction), str(trip.destination)]
		var key := JSON.stringify(pair)
		if known.has(key):
			continue
		known[key] = true
		var title := str(trip.destination)
		if not str(trip.direction).is_empty():
			title = "Direction %s" % trip.direction if title.is_empty() else "%s  ·  %s" % [title, trip.direction]
		_add(directions, "All trips" if title.is_empty() else title, pair)
	directions.select(0)
	_show_direction()


func _show_direction() -> void:
	trip_selector.clear()
	_clear_stops()
	var pick: Array = _picked(directions)
	for trip: Dictionary in trips:
		if pick[0] == str(trip.direction) and pick[1] == str(trip.destination):
			_add(trip_selector, trip.label, trip.id)
	if trip_selector.item_count:
		trip_selector.select(0)
		_query_stops()


func _query_stops() -> void:
	if busy or trip_selector.selected < 0:
		return
	_clear_stops()
	_work("stops", [_picked(trip_selector)], _received_stops, "Reading the trip’s stop times…")


func _received_stops(result: Array) -> void:
	stops = result
	if stops.size() < 2:
		status.text = feed_error if not feed_error.is_empty() else "This trip needs at least two timed stops."
		return
	for index in stops.size() - 1:
		_add(start_stop, _stop_label(index), index)
	start_stop.select(0)
	_list_end_stops()


func _stop_label(index: int) -> String:
	var stop: Dictionary = stops[index]
	var clock := "untimed"
	if int(stop.arrival) >= 0:
		clock = "%02d:%02d" % [floori(stop.arrival / 3600.0), floori(stop.arrival / 60.0) % 60]
	return "%02d   %s  ·  %s" % [index + 1, clock, stop.name]


func _list_end_stops() -> void:
	var old_end = _picked(end_stop)
	end_stop.clear()
	var first: int = _picked(start_stop)
	for index in range(first + 1, stops.size()):
		_add(end_stop, _stop_label(index), index)
	var default_end := mini(first + 2, stops.size() - 1)
	if old_end != null and int(old_end) > first:
		default_end = int(old_end)
	end_stop.select(default_end - first - 1)
	_segment_status()
	_update_controls()


func _segment_status() -> void:
	var count := int(_picked(end_stop)) - int(_picked(start_stop)) + 1
	status.text = "%d consecutive stops selected." % count


func _prepare_segment() -> void:
	if busy or end_stop.selected < 0:
		return
	_work("segment", [_picked(trip_selector), _picked(start_stop), _picked(end_stop)],
			_segment_ready, "Matching stops to the published route shape…")


func _segment_ready(result: Dictionary) -> void:
	if result.is_empty():
		status.text = feed_error
		return
	segment = result
	var route_name := str(segment.route_id).validate_filename()
	save_dialog.current_file = "Route_%s.tscn" % route_name
	status.text = "Choose where to save this route."
	save_dialog.popup_centered_ratio(0.7)


func _save(path: String) -> void:
	if segment.is_empty():
		return
	path = ProjectSettings.localize_path(path.simplify_path())
	if not path.begins_with("res://") or path.get_extension().to_lower() != "tscn":
		status.text = "Save a .tscn file inside this Godot project."
		return
	if path in EditorInterface.get_open_scenes():
		status.text = "This scene is open in the editor. Close it or generate the route under a new filename."
		return
	var root := Builder.build(segment)
	if root == null:
		status.text = "The selected segment has no usable path."
		return
	root.set_meta("service_date", date.text.strip_edges())
	var result := Builder.save_scene(root, path)
	root.free()
	if result != OK:
		status.text = "Could not save the route: " + error_string(result)
		return
	EditorInterface.get_resource_filesystem().update_file(path)
	EditorInterface.open_scene_from_path(path)
	status.text = "Saved %s. Press F6 to play this scene." % path.get_file()
