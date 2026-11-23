extends SceneTree

const Feed = preload("res://addons/tram_atlas/feed.gd")
const NIGHT := 'Night, "A"'
const FIXTURE := "res://tests/fixtures/synthetic-night.zip"
var failures := 0


func check(value: bool, name: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL ", name)


func _initialize() -> void:
	var feed := Feed.new()
	check(feed.open_zip(FIXTURE), feed.error)
	var night := feed.trips_for("test", "2026-11-23")
	check(night.size() == 1 and night[0].id == NIGHT, "cancellation and exceptional service addition")
	check(feed.trips_for("test", "2026-11-24").size() == 2, "ordinary weekly service")
	check(feed.trips_for("test", "2026-11-22").is_empty(), "Sunday has no service")
	check(feed.trips_for("test", "2026-12-01").is_empty(), "calendar end date")
	check(feed.trips_for("test", "2026-02-30").is_empty() and feed.error != "", "invalid service date")
	var stops := feed.stops_for(NIGHT)
	check(stops.size() == 3, feed.error)
	if stops.size() == 3:
		check(stops[0].name == "Nábřeží, sever" and stops[1].name == 'Můstek "B"', "UTF-8 and CSV quoting")
		check(stops[0].sequence == 10 and stops[2].sequence == 60, "numeric stop sequence")
		check(stops[1].arrival == 87300 and stops[1].departure == 87360, "after-midnight dwell")
	var route := feed.segment(NIGHT, 0, 2)
	check(not route.is_empty(), feed.error)
	if not route.is_empty():
		check(route.points.size() == 4, "preserve original shape bend")
		check(route.points[1].x > 142 and route.points[1].x < 144, "longitude to local metres")
		check(abs(route.points[1].z) < 0.1 and abs(route.points[2].z + 111.2) < 0.2, "north is -Z")
		check(abs(route.stops[1].distance - 254.15) < 1, "distance follows corner")
	var trimmed := feed.segment("daytime", 1, 2)
	check(not trimmed.is_empty(), feed.error)
	if not trimmed.is_empty():
		check(trimmed.points[0].length() < 0.02 and trimmed.stops[0].distance == 0, "slice origin")
		check(abs(trimmed.stops[1].distance - 142.95) < 0.5, "GTFS measures independent of metres")
	check(feed.segment("missing", 0, 2).is_empty() and "shape" in feed.error, "missing geometry diagnostic")
	var templates := feed.trips_for("frequency-test", "2026-11-23")
	check(templates.size() == 1 and templates[0].label.begins_with("Frequency template") and
			templates[0].start_time == -1, "frequency template has no invented departure")
	check(feed.segment("headway", 0, 2).is_empty() and "frequencies.txt" in feed.error,
			"headway template generation explained")
	_check_dates_only()
	if failures == 0:
		print("PASS synthetic weekly and dates-only calendars, frequency templates, CSV, after-midnight times and geometry")
	quit(1 if failures else 0)


func _check_dates_only() -> void:
	# Generate a disposable variant of the same fixture, retaining just the
	# explicit exception schedule. Run through the normal ZIP entry point.
	var temp := FileAccess.create_temp(FileAccess.WRITE_READ, "gtfs-dates-only", "zip", true)
	if temp == null:
		check(false, "could not create dates-only fixture")
		return
	var path := temp.get_path_absolute()
	temp.close()
	var src := ZIPReader.new()
	var dst := ZIPPacker.new()
	if src.open(FIXTURE) != OK or dst.open(path) != OK:
		check(false, "could not open dates-only fixture")
		DirAccess.remove_absolute(path)
		return
	for member in src.get_files():
		if member != "calendar.txt":
			dst.start_file(member)
			dst.write_file(src.read_file(member))
			dst.close_file()
	dst.close()
	src.close()
	var feed := Feed.new()
	check(feed.open_zip(path), "dates-only archive opens: " + feed.error)
	var trips := feed.trips_for("test", "2026-11-23")
	check(trips.size() == 1 and trips[0].id == NIGHT, "dates-only addition")
	check(feed.trips_for("test", "2026-11-24").is_empty(), "dates-only unlisted day")
	feed = null
	check(DirAccess.remove_absolute(path) == OK, "temporary fixture cleanup")
