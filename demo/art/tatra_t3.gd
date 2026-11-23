@tool
extends Node3D
## Original scale model, 14 metres long. The local railhead is y=0; front is -Z.

const Brush = preload("res://demo/art/model_mesh.gd")
const CREAM := Color("#ffe5ae")
const RED := Color("#cb322a")
const RED_DARK := Color("#9a2b27")
const IRON := Color("#343e46")
const GLASS := Color("#285161")
const GLEAM := Color("#779798")
const LAMP := Color("#fff2ca")

## Prague T3s can run as a coupled pair. Both bodies independently sample the
## path so their bogies follow the Újezd curve when the timetable is scrubbed.
@export var coupled_pair := true
var _trailer: MeshInstance3D
var _follower: PathFollow3D
var _track: Path3D
const COUPLING_DISTANCE := 14.72


func _ready() -> void:
	var b := Brush.new()
	b.box(Vector3(0,0.65,0), Vector3(1.9,0.5,10.3), IRON)
	for z in [-4.95, -3.3, 3.3, 4.95]:
		for side in [-1,1]:
			b.pose = Transform3D(Basis(Vector3.FORWARD, PI*0.5), Vector3(side*0.78,0.36,z))
			b.frustum(Vector3.ZERO,0.36,0.36,0.28,12,IRON)
			b.frustum(Vector3(0,0.14*side,0),0.19,0.19,0.04,10,GLEAM)
	b.pose = Transform3D.IDENTITY
	_band(b,0.68,0.9,1.1,1.24,6.76,6.95,RED_DARK)
	_band(b,0.9,1.58,1.24,1.25,6.95,7.0,RED)
	_band(b,1.58,1.83,1.25,1.25,7.0,7.0,CREAM)
	_band(b,1.83,2.83,1.25,1.18,7.0,6.72,CREAM)
	_band(b,2.83,3.08,1.18,1.18,6.72,6.72,CREAM)
	_band(b,3.08,3.22,1.21,1.03,6.79,6.60,Color("#a4aaa3"))
	_band(b,3.22,3.32,1.03,0.84,6.60,6.42,Color("#c9c5ae"))
	# Wraparound windshields, divided by a narrow cream centre post.
	for end in [-1,1]:
		b.box(Vector3(0,2.31,6.88*end),Vector3(1.72,0.82,0.13),GLASS)
		b.box(Vector3(0,2.31,6.96*end),Vector3(0.085,0.82,0.02),CREAM)
		b.box(Vector3(0,2.95,6.78*end),Vector3(1.32,0.235,0.1),IRON)
		_digits(b,Vector3(-0.12,2.95,6.84*end),end)
		for x in [-0.66,0.66]:
			b.box(Vector3(x,1.44,6.996*end),Vector3(0.21,0.17,0.08),LAMP)
		b.box(Vector3(0,1.12,7.02*end),Vector3(1.75,0.13,0.13),IRON)
	for side in [-1,1]:
		for i in 10:
			var z := -5.85 + i*1.30
			b.box(Vector3(side*1.24,2.30,z),Vector3(0.05,0.83,1.19),GLASS)
			b.box(Vector3(side*1.27,2.5,z),Vector3(0.025,0.075,1.18),GLEAM)
		if side == 1:
			for z in [-5.35,0.0,4.93]:
				b.box(Vector3(1.28,1.81,z),Vector3(0.06,1.92,1.00),RED_DARK)
				for leaf in [-0.25,0.25]:
					b.box(Vector3(1.32,1.84,z+leaf),Vector3(0.04,1.76,0.425),CREAM)
					b.box(Vector3(1.35,2.26,z+leaf),Vector3(0.02,0.82,0.34),GLASS)
		b.box(Vector3(side*1.26,1.66,0),Vector3(0.045,0.065,12.5),CREAM)
	for z in [-4.45, -2.55, 3.92]:
		b.box(Vector3(0,3.37,z),Vector3(1.14,0.18,0.81),Color("#84938c"))
		for slat in 4:
			b.box(Vector3(0,3.466,z-0.27+slat*0.18),Vector3(0.96,0.022,0.04),IRON)
	# Scissor pantograph has two articulated frames and a contact shoe.
	b.box(Vector3(0,3.45,1.1),Vector3(0.98,0.25,1.2),IRON)
	for x in [-0.37,0.37]:
		var a := Vector3(x,3.54,0.95)
		var c := Vector3(x,4.66,0.81)
		for z in [-0.22,1.88]:
			var joint := Vector3(x,4.11,z)
			b.beam(a,joint,0.065,0.065,RED_DARK)
			b.beam(joint,c,0.065,0.065,IRON)
	b.box(Vector3(0,4.69,0.81),Vector3(1.66,0.09,0.14),IRON)
	b.box(Vector3(0,0.8,7.19),Vector3(0.36,0.22,0.38),IRON)
	b.box(Vector3(0,0.8,-7.19),Vector3(0.36,0.22,0.38),IRON)
	var lead := b.finish(self,"EnamelBodyAndRunningGear",Brush.paint())
	_follower = get_parent() as PathFollow3D
	if coupled_pair and _follower:
		_track = _follower.get_parent() as Path3D
		if _track and _track.curve:
			_trailer = MeshInstance3D.new()
			_trailer.name = "CoupledMotorCar"
			_trailer.mesh = lead.mesh
			add_child(_trailer)
			_trailer.top_level = true
			process_priority = 3
			_position_trailer()


func _process(_delta: float) -> void:
	if is_instance_valid(_trailer):
		_position_trailer()


func _track_at(distance: float) -> Vector3:
	var line := _track.curve
	if distance < 0.0:
		var start := line.sample_baked(0.0)
		return _track.to_global(start+start.direction_to(line.sample_baked(1.0))*distance)
	return _track.to_global(line.sample_baked(distance))


func _position_trailer() -> void:
	var distance := _follower.progress - COUPLING_DISTANCE
	# Use both bogies for the rigid body's bearing through the corner.
	var rear := _track_at(distance-4.1)
	var front := _track_at(distance+4.1)
	_trailer.global_transform = Transform3D(Basis.looking_at(rear.direction_to(front),Vector3.UP),(rear+front)*0.5)


func _ring(y: float, half_width: float, length: float) -> PackedVector3Array:
	var w := half_width
	var e := w*0.68
	var l := length
	return PackedVector3Array([Vector3(-e,y,-l),Vector3(e,y,-l),
		Vector3(w,y,-l+0.63),Vector3(w,y,l-0.63),Vector3(e,y,l),
		Vector3(-e,y,l),Vector3(-w,y,l-0.63),Vector3(-w,y,-l+0.63)])


func _band(b: Brush, low: float, high: float, w1: float, w2: float, l1: float, l2: float, colour: Color) -> void:
	var a := _ring(low,w1,l1)
	var c := _ring(high,w2,l2)
	for i in 8:
		var j := (i+1)%8
		b.quad(a[i],c[i],c[j],a[j],colour)
		b.tri(Vector3(0,high,0),c[j],c[i],colour)


func _digits(b: Brush, origin: Vector3, end: int) -> void:
	for digit in 2:
		var x := origin.x+digit*0.25
		for y in [-0.068,0.0,0.068]:
			b.box(Vector3(x,origin.y+y,origin.z),Vector3(0.12,0.026,0.012),LAMP)
		for sign_y in [-1,1]:
			b.box(Vector3(x+sign_y*end*0.047,origin.y+0.033*sign_y,origin.z),
				Vector3(0.026,0.07,0.012),LAMP)
