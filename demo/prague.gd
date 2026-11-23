extends Control

const SERIF = preload("res://demo/type/DMSerifText-Regular.ttf")
const SANS = preload("res://demo/type/Barlow-SemiBold.ttf")
const MONO = preload("res://demo/type/IBMPlexMono-Medium.ttf")
const Symbol = preload("res://demo/atlas_symbol.gd")
const MapNotes = preload("res://demo/map_notes.gd")
const INK := Color("#233e35")
const PAPER := Color("#faf6e9")
const FAINT := Color("#667568")
const RULE := Color("#d5d3bd")
const VERMILION := Color("#aa3926")
const AMBER := Color("#f2b268")
const SPEEDS := [1.0, 2.0, 4.0, 8.0, 16.0]

@onready var route = $Map/World/Route
@onready var stage = $Map/World/Scenery
@onready var vehicle: PathFollow3D = $Map/World/Route/Track/Vehicle
var hud := Control.new()
var clock_label := Label.new()
var slider := HSlider.new()
var play_button := Button.new()
var play_icon = Symbol.new()
var speed_button := Button.new()
var view_buttons: Array[Button] = []
var station_buttons: Array[Button] = []
var time_panel := Control.new()
var near_view := false
var speed_index := 2
var last_station := -2
var last_clock := -1
var last_play_icon := ""
var title_card := PanelContainer.new()
var map_notes := MapNotes.new()

func _ready() -> void:
	stage.build_for_path($Map/World/Route/Track)
	route.speed = SPEEDS[speed_index]
	route.playing = true
	# Update the clock and the camera after the route has advanced each frame.
	process_priority = 5
	hud.name = "AtlasHUD"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_notes.world = $Map/World
	map_notes.stage = stage
	map_notes.car = vehicle
	hud.add_child(map_notes)
	_fill(map_notes, 0, 72, 0, 130)
	_make_header()
	_make_caption()
	_make_timetable()
	_refresh_view()
	stage.frame_vehicle(vehicle.global_position, true)
	get_window().min_size = Vector2i(760, 520)
	_sync()

func _style(color: Color, radius: int = 0, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border.a > 0.0:
		style.set_border_width_all(1)
		style.border_color = border
	return style

func _type(control: Control, font: Font, pixels: int, color: Color) -> void:
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", pixels)
	control.add_theme_color_override("font_color", color)

func _label(content: String, font: Font, pixels: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type(label, font, pixels, color)
	return label

func _row(parent: Node, separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row

func _flex(parent: Node) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)

func _panel(parent: Node, name_text: String, color: Color) -> Panel:
	var panel := Panel.new()
	panel.name = name_text
	panel.add_theme_stylebox_override("panel", _style(color))
	parent.add_child(panel)
	return panel

func _fill(control: Control, left: int = 0, top: int = 0, right: int = 0, bottom: int = 0) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = left
	control.offset_top = top
	control.offset_right = -right
	control.offset_bottom = -bottom

func _button(button: Button, caption: String, base: Color, foreground: Color, size_px: int = 16) -> void:
	button.text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_type(button, SANS, size_px, foreground)
	for state in ["hover", "pressed", "focus", "hover_pressed"]:
		button.add_theme_color_override("font_" + state + "_color", foreground)
	button.add_theme_stylebox_override("normal", _style(base, 5))
	button.add_theme_stylebox_override("hover", _style(base.lightened(0.09), 5))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.07), 5))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 5, AMBER))

func _make_header() -> void:
	var header := _panel(hud, "Header", INK)
	header.anchor_right = 1
	header.offset_bottom = 72
	var row := _row(header, 14)
	_fill(row, 26, 11, 28, 11)
	var mark = Symbol.new()
	mark.custom_minimum_size.x = 40
	row.add_child(mark)
	row.add_child(_label("Tram Atlas", SERIF, 34, PAPER))
	var divider := ColorRect.new()
	divider.color = Color("#577062")
	divider.custom_minimum_size = Vector2(1, 23)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(divider)
	row.add_child(_label("PRAHA  /  CZECHIA", MONO, 14, Color("#d6dfca")))
	_flex(row)
	var toggle := _row(row, 3)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for caption in ["Overview", "Tram view"]:
		var button := Button.new()
		button.name = caption.replace(" ", "")
		button.custom_minimum_size = Vector2(97, 38)
		button.tooltip_text = "Switch camera (V)"
		toggle.add_child(button)
		view_buttons.append(button)
		button.pressed.connect(_change_view.bind(caption == "Tram view"))

func _make_caption() -> void:
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_card.name = "MapCaption"
	var card := _style(Color(PAPER, 0.96), 5)
	card.content_margin_left = 18
	card.content_margin_right = 20
	card.content_margin_top = 11
	card.content_margin_bottom = 12
	title_card.add_theme_stylebox_override("panel", card)
	hud.add_child(title_card)
	title_card.position = Vector2(28, 91)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	title_card.add_child(stack)
	var line := _row(stack, 9)
	var badge := Label.new()
	badge.text = " 22 "
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type(badge, SANS, 19, PAPER)
	badge.add_theme_stylebox_override("normal", _style(VERMILION, 3))
	line.add_child(badge)
	line.add_child(_label("TOWARD BÍLÁ HORA", MONO, 14, INK))
	stack.add_child(_label("The Vltava crossing", SERIF, 40, INK))

func _make_timetable() -> void:
	var footer := _panel(hud, "Timetable", PAPER)
	footer.anchor_top = 1
	footer.anchor_right = 1
	footer.anchor_bottom = 1
	footer.offset_top = -130
	var rule := ColorRect.new()
	rule.color = RULE
	rule.anchor_right = 1
	rule.offset_bottom = 1
	footer.add_child(rule)
	var row := _row(footer, 32)
	_fill(row, 32, 15, 32, 15)
	var time_box := VBoxContainer.new()
	time_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_box.add_theme_constant_override("separation", -3)
	row.add_child(time_box)
	time_box.add_child(_label("SERVICE TIME", MONO, 12, FAINT))
	_type(clock_label, MONO, 34, INK)
	clock_label.name = "Clock"
	time_box.add_child(clock_label)
	time_box.add_child(_label("MON  23 NOV 2026", MONO, 12, FAINT))
	var divider := ColorRect.new()
	divider.color = RULE
	divider.custom_minimum_size = Vector2(1, 70)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(divider)
	time_panel.name = "StopTimetable"
	time_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(time_panel)
	slider.name = "TimeScrubber"
	slider.min_value = route.arrivals[0]
	slider.max_value = route.departures[-1]
	slider.step = 0.1
	slider.anchor_right = 1
	slider.offset_top = 47
	slider.offset_bottom = 73
	slider.tooltip_text = "Scrub the timetable"
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.add_theme_stylebox_override("slider", _track_style(RULE))
	for key in ["grabber_area", "grabber_area_highlight"]:
		slider.add_theme_stylebox_override(key, _track_style(VERMILION))
	var knob := GradientTexture2D.new()
	knob.width = 18
	knob.height = 18
	knob.fill = GradientTexture2D.FILL_RADIAL
	knob.fill_from = Vector2(0.5, 0.5)
	knob.fill_to = Vector2(1, 0.5)
	knob.gradient = Gradient.new()
	knob.gradient.offsets = PackedFloat32Array([0, .46, .5, .80, .86, 1])
	knob.gradient.colors = PackedColorArray([PAPER, PAPER, VERMILION, VERMILION, Color(VERMILION, 0), Color(VERMILION, 0)])
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	time_panel.add_child(slider)
	slider.value_changed.connect(_seek)
	for index in route.stop_names.size():
		var ratio := inverse_lerp(float(route.arrivals[0]), float(route.departures[-1]), float(route.arrivals[index]))
		var alignment := HORIZONTAL_ALIGNMENT_CENTER
		if index == 0: alignment = HORIZONTAL_ALIGNMENT_LEFT
		elif index == route.stop_names.size() - 1: alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var button := Button.new()
		button.text = route.stop_names[index]
		button.name = "Station%d" % (index + 1)
		button.tooltip_text = "Go to " + button.text
		button.alignment = alignment
		button.flat = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_type(button, SANS, 20, INK)
		button.add_theme_color_override("font_hover_color", VERMILION)
		button.add_theme_color_override("font_pressed_color", VERMILION)
		button.add_theme_color_override("font_focus_color", VERMILION)
		time_panel.add_child(button)
		_position_label(button, ratio, 8, 46)
		button.pressed.connect(_seek.bind(float(route.arrivals[index])))
		station_buttons.append(button)
		var time := _label(_format_time(route.arrivals[index]).left(5), MONO, 14, FAINT)
		time.horizontal_alignment = alignment
		time_panel.add_child(time)
		_position_label(time, ratio, 70, 98)
	var actions := _row(row, 6)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speed_button.name = "Speed"
	speed_button.custom_minimum_size = Vector2(52, 44)
	speed_button.tooltip_text = "Cycle playback speed (S)"
	_button(speed_button, "4×", Color("#e5e6d7"), INK, 18)
	actions.add_child(speed_button)
	speed_button.pressed.connect(_cycle_speed)
	play_button.name = "PlayPause"
	play_button.custom_minimum_size = Vector2(50, 44)
	_button(play_button, "", INK, PAPER)
	actions.add_child(play_button)
	play_button.add_child(play_icon)
	play_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_icon.ink = PAPER
	_fill(play_icon)
	play_button.pressed.connect(_toggle)

func _track_style(color: Color) -> StyleBoxFlat:
	var style := _style(color, 2)
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _position_label(control: Control, ratio: float, top: float, bottom: float) -> void:
	control.anchor_left = ratio
	control.anchor_right = ratio
	control.offset_left = -160 * ratio
	control.offset_right = 160 * (1.0 - ratio)
	control.offset_top = top
	control.offset_bottom = bottom

func _format_time(seconds: int) -> String:
	return route.format_clock(seconds)

func _change_view(close: bool) -> void:
	near_view = close
	map_notes.visible = not close
	_refresh_view()
	stage.set_tram_view(close)
	stage.frame_vehicle(vehicle.global_position, true)

func _refresh_view() -> void:
	for i in view_buttons.size():
		var selected := near_view == (i == 1)
		var button := view_buttons[i]
		_button(button, ["Overview", "Tram view"][i], PAPER if selected else Color("#385448"), INK if selected else PAPER)
		button.accessibility_description = "Selected camera" if selected else "Switch camera"

func _toggle() -> void:
	route.toggle_playback()
	_sync()

func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	route.speed = SPEEDS[speed_index]
	speed_button.text = "%d×" % int(route.speed)

func _seek(seconds: float) -> void:
	route.seek(seconds)
	stage.frame_vehicle(vehicle.global_position, true)
	_sync()

func _process(_delta: float) -> void:
	stage.frame_vehicle(vehicle.global_position)
	if map_notes.visible:
		map_notes.queue_redraw()
	_sync()

func _sync() -> void:
	var now := float(route.current_time)
	var whole := floori(now)
	if whole != last_clock:
		clock_label.text = _format_time(whole)
		last_clock = whole
	slider.set_value_no_signal(now)
	var symbol := "pause" if route.playing else ("replay" if now >= route.departures[-1] else "play")
	if symbol != last_play_icon:
		play_icon.symbol = symbol
		play_icon.queue_redraw()
		play_button.tooltip_text = symbol.capitalize() + " (Space)"
		play_button.accessibility_name = symbol.capitalize()
		last_play_icon = symbol
	var station := -1
	for i in route.arrivals.size():
		if now >= route.arrivals[i] and now <= route.departures[i] + 0.5:
			station = i
	if station != last_station:
		for i in station_buttons.size():
			station_buttons[i].add_theme_color_override("font_color", VERMILION if i == station else INK)
		last_station = station

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: _toggle()
			KEY_V: _change_view(not near_view)
			KEY_S: _cycle_speed()
			KEY_LEFT: _seek(route.current_time - 5.0)
			KEY_RIGHT: _seek(route.current_time + 5.0)
			KEY_HOME: _seek(route.arrivals[0])
			KEY_END: _seek(route.departures[-1])
			_: return
		get_viewport().set_input_as_handled()
