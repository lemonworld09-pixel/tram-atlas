extends RefCounted
## Flat-shaded, vertex-painted geometry for the Prague miniature.
## Emit one mesh per landmark/block, including individually coloured details.

var pose := Transform3D.IDENTITY
var _positions := PackedVector3Array()
var _normals := PackedVector3Array()
var _colours := PackedColorArray()


func tri(a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	point_triangle(a, b, c, normal, colour)


func point_triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, colour: Color) -> void:
	var n := (pose.basis * normal).normalized()
	for p: Vector3 in [a, c, b]:
		_positions.append(pose * p)
		_normals.append(n)
		_colours.append(colour)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	point_triangle(a, b, c, normal, colour)
	point_triangle(a, c, d, normal, colour)


func box(center: Vector3, size: Vector3, colour: Color) -> void:
	var lo := center - size * 0.5
	var hi := center + size * 0.5
	var a := Vector3(lo.x, lo.y, lo.z)
	var b := Vector3(hi.x, lo.y, lo.z)
	var c := Vector3(hi.x, lo.y, hi.z)
	var d := Vector3(lo.x, lo.y, hi.z)
	var e := Vector3(lo.x, hi.y, lo.z)
	var f := Vector3(hi.x, hi.y, lo.z)
	var g := Vector3(hi.x, hi.y, hi.z)
	var h := Vector3(lo.x, hi.y, hi.z)
	quad(a,b,c,d,colour)
	quad(e,h,g,f,colour)
	quad(a,e,f,b,colour)
	quad(d,c,g,h,colour)
	quad(a,d,h,e,colour)
	quad(b,f,g,c,colour)


func frustum(center: Vector3, bottom: float, top: float, height: float, sides: int, colour: Color, stretch := Vector2.ONE, twist := 0.0) -> void:
	var down := Vector3.DOWN * height * 0.5
	for i in sides:
		var a := Vector2.from_angle(TAU * i / sides + twist) * stretch
		var b := Vector2.from_angle(TAU * (i + 1) / sides + twist) * stretch
		var u := Vector3(a.x, 0, a.y)
		var v := Vector3(b.x, 0, b.y)
		quad(center + down + u * bottom, center - down + u * top,
			center - down + v * top, center + down + v * bottom, colour)
		if top > 0.0:
			tri(center - down, center - down + v * top, center - down + u * top, colour)
		if bottom > 0.0:
			tri(center + down, center + down + u * bottom, center + down + v * bottom, colour)


func beam(a: Vector3, b: Vector3, width: float, depth: float, colour: Color) -> void:
	var old := pose
	var y := (b-a).normalized()
	if y.length_squared() < 0.9:
		return
	var guide := Vector3.FORWARD if absf(y.z) < 0.95 else Vector3.UP
	var x := y.cross(guide).normalized()
	pose = old * Transform3D(Basis(x, y, x.cross(y)), (a+b)*0.5)
	box(Vector3.ZERO, Vector3(width, a.distance_to(b), depth), colour)
	pose = old


func finish(parent: Node3D, title: String, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = title
	if not _positions.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _positions
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_COLOR] = _colours
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		instance.mesh = mesh
	parent.add_child(instance)
	return instance


static func paint() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.92
	return material
