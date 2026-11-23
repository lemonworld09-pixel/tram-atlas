extends Control
## A small line drawing used for the atlas mark and playback controls.

var symbol := "atlas"
var ink := Color.WHITE

func _draw() -> void:
	var center := size * 0.5
	if symbol == "atlas":
		var badge := Rect2(center - Vector2(18, 18), Vector2(36, 36))
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("#eeaf63")
		fill.set_corner_radius_all(9)
		draw_style_box(fill, badge)
		var points := PackedVector2Array([Vector2(-9, 9), Vector2(-9, 4), Vector2(5, -5), Vector2(5,-10)])
		for dx in [0, 5]:
			var line := PackedVector2Array()
			for pt in points:
				line.append(center + pt + Vector2(dx, 0))
			draw_polyline(line, Color("#213831"), 2.3, true)
	elif symbol == "pause":
		for offset in [-5, 3]:
			draw_rect(Rect2(center + Vector2(offset, -7), Vector2(3, 14)), ink)
	elif symbol == "play":
		draw_colored_polygon(PackedVector2Array([center + Vector2(-4,-8),center + Vector2(8,0),center + Vector2(-4,8)]), ink)
	elif symbol == "replay":
		draw_arc(center + Vector2(0,1), 7, -PI * .95, PI * .7, 24, ink, 2, true)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-10,-6),center+Vector2(-3,-5),center+Vector2(-9,1)]), ink)
