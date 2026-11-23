@tool
extends RefCounted
## A feed belongs to one persistent worker from creation through disposal.
## The editor receives detached snapshots and never touches the live indexes.

const Feed = preload("res://addons/tram_atlas/feed.gd")

var _thread := Thread.new()
var _mutex := Mutex.new()
var _wake := Semaphore.new()
var _job: Dictionary = {}
var _answer: Dictionary = {}
var _stopping := false


func submit(operation: String, args: Array) -> Error:
	if not _thread.is_started():
		var err := _thread.start(_run)
		if err != OK:
			return err
	_mutex.lock()
	_job = {"operation": operation, "args": args}
	_mutex.unlock()
	_wake.post()
	return OK


func take_result() -> Dictionary:
	_mutex.lock()
	var completed := _answer
	_answer = {}
	_mutex.unlock()
	return completed


func close() -> void:
	if not _thread.is_started():
		return
	_mutex.lock()
	_stopping = true
	_mutex.unlock()
	_wake.post()
	_thread.wait_to_finish()


func _run() -> void:
	var feed = Feed.new()
	while true:
		_wake.wait()
		_mutex.lock()
		var stop := _stopping
		var job := _job
		_job = {}
		_mutex.unlock()
		if stop:
			return
		var args: Array = job.args
		var value
		match job.operation:
			"open":
				feed = Feed.new()
				if feed.open_zip(args[0]):
					value = {"routes": feed.routes.duplicate(true), "date": feed.suggested_date}
				else:
					value = {}
			"trips":
				value = feed.trips_for(args[0], args[1]).duplicate(true)
			"stops":
				value = feed.stops_for(args[0]).duplicate(true)
			"segment":
				value = feed.segment(args[0], args[1], args[2]).duplicate(true)
		_mutex.lock()
		_answer = {"value": value, "error": feed.error}
		_mutex.unlock()
