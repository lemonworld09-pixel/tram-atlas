@tool
extends EditorPlugin

const Dock = preload("res://addons/tram_atlas/import_dock.gd")
var dock: Control


func _enter_tree() -> void:
	dock = Dock.new()
	dock.name = "Tram Atlas"
	add_control_to_dock(DOCK_SLOT_LEFT_BR, dock)


func _exit_tree() -> void:
	if is_instance_valid(dock):
		dock.finish_work()
		remove_control_from_docks(dock)
		dock.queue_free()
