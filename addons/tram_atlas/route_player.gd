@tool
extends Node3D
## A service-day clock driving an ordinary PathFollow3D. Time is seconds
## since the beginning of the GTFS service day and can exceed 86400.

signal sampled(seconds: float)
signal playback_changed

const Preview = preload("res://addons/tram_atlas/preview.gd")
const DefaultTram = preload("res://addons/tram_atlas/streetcar.tscn")

@export_group("Presentation")
## A Node3D scene. +Y is up, -Z faces forward, and the origin is at rail level.
@export var vehicle_scene: PackedScene = DefaultTram:
	set(value):
		vehicle_scene = value
		if is_node_ready():
			_replace_model()
## Add neutral surroundings, a camera, stop signs and timetable controls at runtime.
@export var preview_enabled := true
@export_range(0.25, 64.0, 0.25, "or_greater") var speed := 4.0
@export var playing := true

@export_group("Timetable")
@export var stop_names := PackedStringArray()
@export var arrivals := PackedInt32Array()
@export var departures := PackedInt32Array()
@export var distances := PackedFloat64Array()

var current_time := 0.0
var _model: Node3D


func _ready() -> void:
	set_process(false)
	_replace_model()
	var count := arrivals.size()
	if count < 2 or departures.size() != count or distances.size() != count or stop_names.size() != count:
		push_warning("Transit route needs at least two matching stops, arrivals, departures and distances.")
		return
	if not get_node_or_null("Track/Vehicle"):
		push_warning("Transit route needs a PathFollow3D at Track/Vehicle.")
		return
	seek(arrivals[0])
	if Engine.is_editor_hint():
		return
	if preview_enabled:
		var preview := Preview.new()
		preview.name = "RoutePreview"
		add_child(preview)
	set_process(true)


func _process(delta: float) -> void:
	if playing:
		seek(current_time + delta * speed)
		if current_time >= departures[-1]:
			playing = false
			playback_changed.emit()


## Positions the vehicle immediately. Calling seek does not change play/pause.
func seek(seconds: float) -> void:
	if arrivals.is_empty() or not is_inside_tree():
		return
	current_time = clampf(seconds, arrivals[0], departures[-1])
	var follower: PathFollow3D = get_node("Track/Vehicle")
	follower.progress = distance_at(current_time)
	sampled.emit(current_time)


## A fresh lookup on every sample supports jumps in either direction and dwell.
func distance_at(seconds: float) -> float:
	var last := departures.size() - 1
	if last < 0:
		return 0.0
	for i in last:
		if seconds <= departures[i]:
			return distances[i]
		if seconds < arrivals[i + 1]:
			var t := inverse_lerp(departures[i], arrivals[i + 1], seconds)
			return lerpf(distances[i], distances[i + 1], t)
	return distances[last]


func toggle_playback() -> void:
	if not playing and current_time >= departures[-1]:
		seek(arrivals[0])
	playing = not playing
	playback_changed.emit()


static func format_clock(seconds: float) -> String:
	var whole := floori(seconds)
	return "%02d:%02d:%02d" % [floori(whole / 3600.0), floori(whole / 60.0) % 60, whole % 60]


func _replace_model() -> void:
	var follower := get_node_or_null("Track/Vehicle")
	if not follower:
		return
	if is_instance_valid(_model):
		follower.remove_child(_model)
		_model.free()
		_model = null
	var source := vehicle_scene if vehicle_scene != null else DefaultTram
	var instance := source.instantiate()
	if not instance is Node3D:
		push_warning("Vehicle Scene needs a Node3D root.")
		instance.free()
		return
	_model = instance
	_model.name = "Model"
	follower.add_child(_model)
