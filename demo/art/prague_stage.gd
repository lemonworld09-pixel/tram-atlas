extends Node3D
## A scale miniature around the PID track. X along Most Legií towards Újezd,
## +Z towards the northern tip of Střelecký ostrov. The origin is stop one.

const Brush = preload("res://demo/art/model_mesh.gd")
const Architecture = preload("res://demo/art/architecture.gd")
const WATER := Color("#569899")
const WAKE := Color("#a2c6bd")
const STONE := Color("#c7b597")
const PALE := Color("#efddbb")
const MORTAR := Color("#9d907c")
const LAND := Color("#d4cdb1")
const PAVING := Color("#b4aaa0")
const IRON := Color("#59696a")
const HEDGE := Color("#849d77")
const FOLIAGE := [Color("#809c74"),Color("#91ae7d"),Color("#91a76a"),Color("#719887"),Color("#abb875")]
const LEAVES := Color("#afbd88")
const WALK := Color("#e5d3ac")
const RNG_SEED := 220422
var _rng := RandomNumberGenerator.new()
var _paint := Brush.paint()
var _camera: Camera3D
var _close := false
var _focus := Vector3(270,0,0)
var _vehicle := Vector3.ZERO
var _built := false
var _water_y := -8.85
var _boats: Array[MeshInstance3D] = []
var _service_start := 0.0


func build_for_path(path: Path3D) -> void:
	if _built or not path or not path.curve or path.curve.point_count < 2:
		return
	_built = true
	_rng.seed = RNG_SEED
	var start := path.to_global(path.curve.get_point_position(0))
	var axis := start.direction_to(path.to_global(path.curve.sample_baked(210.0)))
	axis.y = 0
	axis = axis.normalized()
	global_transform = Transform3D(Basis(axis,Vector3.UP,axis.cross(Vector3.UP)),start)
	_landscape()
	_island()
	_bridge()
	_town()
	_rails(path)
	_river_life()
	var timetable := path.get_parent()
	if timetable.has_signal("sampled") and timetable.get("arrivals") != null:
		_service_start = timetable.get("arrivals")[0]
		timetable.connect("sampled",_move_boats)
	_lighting()
	frame_vehicle(start, true)


func set_tram_view(enabled: bool) -> void:
	_close = enabled
	if _camera:
		frame_vehicle(to_global(_vehicle),true)


func frame_vehicle(vehicle_global_position: Vector3, immediate := false) -> void:
	if not _camera:
		return
	_vehicle = to_local(vehicle_global_position)
	var target := _vehicle + Vector3(0,1.7,0)
	if not _close:
		# Show the river at the eastern stop, then glide into the western streets.
		target = Vector3(lerpf(222,563,smoothstep(325,675,_vehicle.x)),0,10+_vehicle.z*0.71)
	var weight := 1.0 if immediate else 1.0 - exp(-minf(get_process_delta_time(),0.1)*5)
	_focus = _focus.lerp(target,weight)
	_camera.position = _focus + Vector3(-0.61,0.73,1.0).normalized()*(150 if _close else 660)
	_camera.look_at(to_global(_focus),Vector3.UP)
	var view_size := get_viewport().get_visible_rect().size
	var aspect := maxf(1.0,view_size.x/maxf(view_size.y,1.0))
	_camera.size = maxf(42.0,117.0/aspect) if _close else maxf(226.0,604.0/aspect)


func _lighting() -> void:
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("#e9e9db")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("#e4ebe9")
	sky.ambient_light_energy = 0.49
	sky.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var world := WorldEnvironment.new()
	world.name = "StudioDaylight"
	world.environment = sky
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.light_color = Color("#fff2de")
	sun.light_energy = 0.34
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 1060
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.23
	sun.shadow_normal_bias = 1.8
	add_child(sun)
	sun.look_at_from_position(to_global(Vector3(-380,660,240)),global_position,Vector3.UP)
	_camera = Camera3D.new()
	_camera.name = "MiniatureCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 1.0
	_camera.far = 2200
	add_child(_camera)
	_camera.make_current()


func _poly(b: Brush, outline: PackedVector2Array, bottom: float, top: float, lid: Color, side: Color) -> void:
	if Geometry2D.is_polygon_clockwise(outline):
		outline = outline.duplicate()
		outline.reverse()
	var faces := Geometry2D.triangulate_polygon(outline)
	for i in range(0,faces.size(),3):
		b.tri(_v(outline[faces[i]],top),_v(outline[faces[i+2]],top),_v(outline[faces[i+1]],top),lid)
	for i in outline.size():
		var a := outline[i]
		var c := outline[(i+1)%outline.size()]
		b.quad(_v(a,bottom),_v(a,top),_v(c,top),_v(c,bottom),side)


func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x,y,p.y)


func _landscape() -> void:
	var b := Brush.new()
	var base := PackedVector2Array([Vector2(-110,-144),Vector2(-97,-157),Vector2(761,-157),Vector2(779,-140),
		Vector2(779,351),Vector2(768,363),Vector2(580,363),Vector2(565,347),Vector2(565,175),
		Vector2(-95,175),Vector2(-110,161)])
	_studio_shadow(base)
	_poly(b,base,-24,-14.1,STONE,Color("#879189"))
	_poly(b,base,-14.1,-12.3,PALE,Color("#dac7a6"))
	_poly(b,base,-12.3,_water_y,WATER,Color("#72a3a2"))
	var east := PackedVector2Array([Vector2(-110,-144),Vector2(-97,-157),Vector2(101,-157),
		Vector2(86,-74),Vector2(86,7),Vector2(79,74),Vector2(76,175),Vector2(-95,175),Vector2(-110,161)])
	var west := PackedVector2Array([Vector2(427,-157),Vector2(761,-157),Vector2(779,-140),Vector2(779,351),Vector2(768,363),
		Vector2(580,363),Vector2(565,347),Vector2(565,175),Vector2(463,175),Vector2(451,117),Vector2(448,26),Vector2(444,-44)])
	_poly(b,east,_water_y-0.1,-0.43,LAND,STONE)
	_poly(b,west,_water_y-0.1,-0.43,LAND,STONE)
	# Granite bands, cornices and rhythm along the river-facing retaining walls.
	for bank in [[Vector2(101,-157),Vector2(86,-74),Vector2(86,7),Vector2(79,74),Vector2(76,175)],
			[Vector2(427,-157),Vector2(444,-44),Vector2(448,26),Vector2(451,117),Vector2(463,175)]]:
		for i in bank.size()-1:
			var a := _v(bank[i],-0.31)
			var c := _v(bank[i+1],-0.31)
			_hstripe(b,a,c,1.0,0.7,PALE)
			_hstripe(b,a+Vector3.DOWN*6.9,c+Vector3.DOWN*6.9,0.7,0.60,MORTAR)
			for n in maxi(1,roundi(a.distance_to(c)/10.0)):
				var p := a.lerp(c,n/float(maxi(1,roundi(a.distance_to(c)/10.0))))
				b.box(p+Vector3.DOWN*3.98,Vector3(0.85,7.6,0.73),PALE.darkened(0.09))
	# Street paving is laid below the measured route.
	_hstripe(b,Vector3(-110,-0.31,-1.7),Vector3(86,-0.31,-1.7),14.3,0.19,PAVING)
	_hstripe(b,Vector3(448,-0.31,-1.7),Vector3(683,-0.31,-1.7),14.3,0.19,PAVING)
	_hstripe(b,Vector3(680,-0.31,-156),Vector3(675,-0.31,363),18.0,0.20,PAVING)
	for x in [-73,67,465,554,617,750]:
		_hstripe(b,Vector3(x,-0.32,-154),Vector3(x,-0.32,171),7.2,0.13,PAVING)
	for z in [-91,68,137,226,298]:
		if z<176:
			_hstripe(b,Vector3(-107,-0.33,z),Vector3(70,-0.33,z),6.7,0.11,PAVING)
		_hstripe(b,Vector3(465 if z<176 else 566,-0.33,z),Vector3(773,-0.33,z),7.2,0.11,PAVING)
	var banks := b.finish(self,"BanksAndCutawayBase",_paint)
	banks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A separately shaded water surface still receives the real arch and pier shadows.
	var water := Brush.new()
	_poly(water,PackedVector2Array([Vector2(101,-156.98),Vector2(427,-156.98),
		Vector2(444,-44),Vector2(448,26),Vector2(451,117),Vector2(463,174.98),
		Vector2(76,174.98),Vector2(79,74),Vector2(86,7),Vector2(86,-74)]),
		_water_y,_water_y+0.022,WATER,WATER)
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://demo/art/vltava.gdshader")
	var surface := water.finish(self,"RiverSurface",water_material)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _studio_shadow(base: PackedVector2Array) -> void:
	var b := Brush.new()
	var matte := Brush.paint()
	matte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 12:
		var softness := (12-i)/12.0
		var contours := Geometry2D.offset_polygon(base,softness*11+0.5)
		if contours.is_empty():
			continue
		var rim: PackedVector2Array = contours[0]
		for j in rim.size():
			rim[j]+=Vector2(4.5,-3.0)
		var shade := Color("#bac0b3").lerp(Color("#e9e9db"),smoothstep(0.0,1.0,softness))
		_poly(b,rim,-26.5,-26.45+i*0.055,shade,shade)
	var piece := b.finish(self,"StudioContactShadow",matte)
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _island() -> void:
	var b := Brush.new()
	var rim := PackedVector2Array([Vector2(272,-157),Vector2(316,-157),Vector2(325,-119),Vector2(331,-52),
		Vector2(333,14),Vector2(326,73),Vector2(312,119),Vector2(296,151),Vector2(289,155),
		Vector2(281,136),Vector2(275,104),Vector2(272,51),Vector2(266,-24),Vector2(262,-94)])
	_poly(b,rim,_water_y-0.1,-7.15,Color("#c5bd96"),Color("#a89c7f"))
	var lawn := rim.duplicate()
	for i in lawn.size():
		lawn[i].x = lerpf(296,lawn[i].x,0.96)
		lawn[i].y = lawn[i].y*0.987
	_poly(b,lawn,-7.15,-6.83,Color("#a1b58c"),HEDGE)
	var walk := [Vector2(288,-151),Vector2(296,-95),Vector2(301,-47),Vector2(300,12),Vector2(309,60),Vector2(298,112),Vector2(290,143)]
	for i in walk.size()-1:
		_hstripe(b,_v(walk[i],-6.77),_v(walk[i+1],-6.77),3.35,0.12,WALK)
	for i in 129:
		var z := _rng.randf_range(-150,129)
		if absf(z)<13:
			continue
		var x := _rng.randf_range(272,324)
		if not Geometry2D.is_point_in_polygon(Vector2(x,z), lawn) or absf(x-300)<3.7:
			continue
		_tree(b,Vector3(x,-6.81,z),_rng.randf_range(6.2,13.7),i)
	for i in 4:
		var p := Vector3(297+i*0.7,-6.7,65+i*12)
		_bench(b,p)
	b.finish(self,"StreleckyOstrov",_paint)


func _hstripe(b: Brush,a: Vector3,c: Vector3,width: float,height: float,colour: Color) -> void:
	var shift := Vector3(-(c.z-a.z),0,c.x-a.x).normalized()*width*0.5
	var down := Vector3.DOWN*height*0.5
	b.quad(a-shift-down,a+shift-down,c+shift-down,c-shift-down,colour)
	b.quad(a-shift+down,a-shift-down,c-shift-down,c-shift+down,colour)
	b.quad(c+shift+down,c+shift-down,a+shift-down,a+shift+down,colour)


func _tree(b: Brush,ground: Vector3,h: float,style: int) -> void:
	var foliage: Color = FOLIAGE[posmod(style,FOLIAGE.size())]
	b.frustum(ground+Vector3.UP*h*0.30,h*0.039,h*0.029,h*0.60,6,Color("#7f7462"))
	var tall := style%6==0
	var scale_x := 0.21 if tall else 0.36
	var r := h*scale_x
	b.frustum(ground+Vector3.UP*h*0.51,r*0.47,r,h*0.27,7,foliage.darkened(0.065),Vector2(0.92,1.0),style*0.6)
	b.frustum(ground+Vector3.UP*h*0.77,r,r*0.69,h*0.25,7,foliage,Vector2(0.92,1.0),style*0.6)
	b.frustum(ground+Vector3.UP*h*0.955,r*0.69,0.14,h*0.12,7,foliage.lightened(0.035),Vector2(0.92,1.0),style*0.6)
	if not tall and style%3==1:
		var east := Vector3(cos(style),0,sin(style))
		var branch := ground+east*r*0.71+Vector3.UP*h*0.55
		b.frustum(branch,r*0.48,r*0.7,h*0.19,6,foliage.darkened(0.045))
		b.frustum(branch+Vector3.UP*h*0.16,r*0.7,r*0.26,h*0.13,6,foliage)


func _bench(b: Brush, p: Vector3) -> void:
	b.box(p+Vector3(0,0.53,0),Vector3(2.3,0.2,0.68),Color("#a78058"))
	b.box(p+Vector3(0,1,0.35),Vector3(2.3,0.58,0.14),Color("#ae8b61"))
	for x in [-0.76,0.76]:
		b.box(p+Vector3(x,0.26,0),Vector3(0.23,0.52,0.60),IRON)


func _bridge() -> void:
	var b := Brush.new()
	const MID := -1.74
	const HALF_WIDTH := 8.90
	# Piers follow the stepped span widths of the real masonry arch bridge.
	var piers := [84.0,116.0,155.0,195.0,236.0,278.0,317.0,357.0,400.0,449.0]
	var deck_length: float = piers.back()-piers.front()
	var cx: float = (piers.front()+piers.back())*0.5
	b.box(Vector3(cx,-0.85,MID),Vector3(deck_length,1.34,HALF_WIDTH*2.0),STONE)
	b.box(Vector3(cx,-0.21,MID),Vector3(deck_length,0.14,12.4),PAVING)
	for j in piers.size()-1:
		var x0: float = piers[j]+2.1
		var x1: float = piers[j+1]-2.1
		var lower := -8.05
		var rise := 6.19 if j!=5 else 4.90
		for i in 16:
			var a: float = PI*i/16
			var c: float = PI*(i+1)/16
			var v := Vector2(lerpf(x0,x1,(1.0-cos(a))*0.5),lower+sin(a)*rise)
			var w := Vector2(lerpf(x0,x1,(1.0-cos(c))*0.5),lower+sin(c)*rise)
			for side: int in [-1,1]:
				var z := MID+side*(HALF_WIDTH-0.36)
				var p := Vector3(v.x,v.y,z)
				var q := Vector3(w.x,w.y,z)
				var pt := Vector3(v.x,-0.98,z)
				var qt := Vector3(w.x,-0.98,z)
				if side==1:
					b.quad(p,q,qt,pt,STONE)
				else:
					b.quad(q,p,pt,qt,STONE)
				var vv := Vector3(-cos(a)*0.78,sin(a)*0.95,0)
				var ww := Vector3(-cos(c)*0.78,sin(c)*0.95,0)
				p.z+=side*0.14
				q.z+=side*0.14
				var shade := PALE.darkened(0.09 if i%3==0 else 0.02)
				if side==1:
					b.quad(p,q,q+ww,p+vv,shade)
				else:
					b.quad(q,p,p+vv,q+ww,shade)
			b.quad(Vector3(v.x,v.y,MID-HALF_WIDTH+0.36),Vector3(w.x,w.y,MID-HALF_WIDTH+0.36),
				Vector3(w.x,w.y,MID+HALF_WIDTH-0.36),Vector3(v.x,v.y,MID+HALF_WIDTH-0.36),MORTAR)
	for x: float in piers:
		b.box(Vector3(x,-4.44,MID),Vector3(4.6,8.5,HALF_WIDTH*2),STONE)
		for side: int in [-1,1]:
			var z := MID+side*HALF_WIDTH
			b.frustum(Vector3(x,-6.02,z),2.55,2.0,6.2,4,MORTAR,Vector2(1.05,1.55))
			b.frustum(Vector3(x,-2.08,z),2.0,1.06,1.7,4,STONE,Vector2(1.05,1.55))
			b.box(Vector3(x,0.64,z),Vector3(2.6,2.0,1.68),STONE)
			b.box(Vector3(x,1.62,z),Vector3(2.78,0.42,1.86),PALE)
			_lamp(b,Vector3(x,1.79,z),4.5,true)
	for side: int in [-1,1]:
		var z := MID+side*HALF_WIDTH
		b.box(Vector3(cx,-0.20,z-side*1.18),Vector3(deck_length,0.38,2.66),PALE)
		b.box(Vector3(cx,0.16,z),Vector3(deck_length,0.39,0.60),STONE)
		b.box(Vector3(cx,1.17,z),Vector3(deck_length,0.34,0.67),PALE)
		for i in int(deck_length/2.15):
			b.box(Vector3(piers[0]+i*2.15,0.70,z),Vector3(0.78,1.05,0.46),STONE)
		# Thin edge course casts a readable shadow along the bridge nose.
		b.box(Vector3(cx,-1.18,z),Vector3(deck_length,0.46,0.88),PALE)
	for x in [101.0,137.3,169.0,208.0,246.0,311.0,353.0,381.0,409.0]:
		var z := -8.87 if int(x)%3==0 else 5.68
		_person(b,Vector3(x,0.0,z),int(x))
		if int(x)%2==1:
			_person(b,Vector3(x+0.88,0.0,z+0.31),int(x)+1)
	b.finish(self,"MostLegii",_paint)


func _lamp(b: Brush, p: Vector3, h: float, double: bool) -> void:
	b.frustum(p+Vector3.UP*0.37,0.34,0.22,0.74,7,IRON)
	b.frustum(p+Vector3.UP*(h*0.48),0.15,0.11,h*0.92,7,IRON)
	var offsets := [-0.65,0.65] if double else [0.0]
	for x: float in offsets:
		b.beam(p+Vector3(0,h-1.1,0),p+Vector3(x,h,0),0.13,0.13,IRON)
		b.frustum(p+Vector3(x,h+0.17,0),0.16,0.34,0.51,4,Color("#f9e5a9"),Vector2.ONE,PI/4)
		b.frustum(p+Vector3(x,h+0.48,0),0.43,0.09,0.21,4,IRON,Vector2.ONE,PI/4)


func _town() -> void:
	var theatre := Brush.new()
	Architecture.theatre(theatre,Vector3(31.3,-0.25,-42.5))
	# Courtyard wing and a slightly lower mansard on the south side of the theatre.
	Architecture.house(theatre,Vector3(31.0,-0.35,-89.0),42.0,23.0,5,4)
	theatre.finish(self,"NarodniDivadlo",_paint)
	var b := Brush.new()
	_block(b,-106,-11,-31,19,4)
	_block(b,-106,61,-117,20,4)
	_block(b,-95,49,87,16,3)
	_block(b,-93,-37,24,16,3)
	_block(b,-59,26,152,16,3)
	_block(b,-101,-70,-64,17,4)
	_block(b,-102,-70,113,13,3)
	_block(b,-9,50,116,13,3)
	Architecture.house(b,Vector3(-19,-0.35,-65),18.0,14.5,4,23,PI/2)
	Architecture.house(b,Vector3(61,-0.35,-117),20.4,14.2,4,9,PI/2)
	# Vítězná street, with an open riverside square in front of the western gates.
	_block(b,479,540,-26,19,4)
	_block(b,566,608,-25,19,4)
	_block(b,625,666,-24,20,3)
	_block(b,475,544,31,16,3)
	_block(b,572,602,31,17,3)
	_block(b,629,655,30,16,3)
	_block(b,467,541,-117,17,3)
	_block(b,580,657,-119,19,4)
	_block(b,701,763,-116,20,3)
	_block(b,471,536,96,15,3)
	_block(b,579,653,99,17,3)
	_block(b,485,553,151,15,3)
	_block(b,479,520,-57,15,3)
	_block(b,564,602,-58,16,4)
	_block(b,578,625,143,15,3)
	_block(b,576,621,201,16,3)
	Architecture.house(b,Vector3(533,-0.35,120),18.0,16.5,3,16,PI/2)
	# Perpendicular facades on Újezd face the actual last curve of the trip.
	for x in [649.0,709.0]:
		for z0 in [-66.0,52.0,149.0,233.0,308.0]:
			var height := 3 if x>680 else 4
			for k in 2:
				Architecture.house(b,Vector3(x,-0.31,z0+k*14.0),
					13.4+_rng.randf()*1.7,16.2,height+int(k==1),_rng.randi_range(1,31),PI/2)
	for z in [-95,-36,42,109,176,250,327]:
		Architecture.house(b,Vector3(742,-0.30,z),22.2,16.4,3,_rng.randi_range(1,31),PI/2)
	b.finish(self,"PragueTownhouses",_paint)
	var street := Brush.new()
	# Parks, waterside promenades, bridge entrance kiosks and tram shelters.
	_garden(street,Vector3(9,-0.37,22),Vector2(65,24),0)
	_garden(street,Vector3(509,-0.37,53),Vector2(59,17),1)
	_garden(street,Vector3(494,-0.37,-91),Vector2(45,22),2)
	_garden(street,Vector3(611,-0.37,270),Vector2(75,35),3)
	_garden(street,Vector3(-18,-0.37,-146),Vector2(105,13),4)
	for i in 19:
		var z := -146.0+i*16.6
		if absf(z)>11:
			_tree(street,Vector3(77.2-0.055*z,-0.42,z),_rng.randf_range(6.4,10.2),i)
			_tree(street,Vector3(454.7+0.091*z,-0.42,z),_rng.randf_range(7.0,10.7),i+7)
	for z in [-64,57,120]:
		for i in 12:
			var x := 478.0+i*16.0
			if x<660:
				_tree(street,Vector3(x,-0.42,z),_rng.randf_range(6.2,9.3),i+z)
	for i in 14:
		var x := -99+i*12.8
		if x>66:
			continue
		_tree(street,Vector3(x,-0.42,47),_rng.randf_range(6.3,9.3),i)
	for i in 14:
		var z := -140.0+i*36.0
		_tree(street,Vector3(694,-0.42,z),_rng.randf_range(5.3,7.4),i)
	for x in [-62.0,11.0,49.0,476.0,533.0,594.0,631.0]:
		for z in [-10.2,8.6]:
			_lamp(street,Vector3(x,-0.2,z),4.25,false)
	for x in [90.0,442.0]:
		for z in [-12.5,10.4]:
			street.box(Vector3(x,0.72,z),Vector3(2.7,1.8,2.65),STONE)
			street.box(Vector3(x,1.63,z),Vector3(3.15,0.38,3.05),PALE)
			_lamp(street,Vector3(x,1.84,z),3.25,true)
	for x in [81.0,450.0]:
		for z in [-14.5,11.7]:
			_tollhouse(street,Vector3(x,-0.39,z))
	for i in 12:
		var p := Vector3(473+_rng.randf()*141,-0.35,-9.8 if i%2==0 else 8.7)
		_car(street,p,0 if i%2==1 else PI,i)
	for i in 6:
		_car(street,Vector3(-94+i*23.3,-0.35,-8.8),0,i+6)
	for i in 11:
		_car(street,Vector3(687.5,-0.35,-96+i*39.2),PI/2,i+2)
	_kiosk(street,Vector3(45,-0.3,38))
	_kiosk(street,Vector3(465,-0.3,-29))
	street.finish(self,"PromenadesAndGardens",_paint)


func _garden(b: Brush,p: Vector3,size: Vector2,style: int) -> void:
	var grounds := Color("#a9b68e")
	b.box(p+Vector3.UP*0.14,Vector3(size.x,0.23,size.y),PALE.darkened(0.09))
	b.box(p+Vector3.UP*0.29,Vector3(size.x-1.15,0.14,size.y-1.15),grounds)
	b.box(p+Vector3.UP*0.39,Vector3(size.x-1.15,0.09,1.5),WALK)
	b.box(p+Vector3.UP*0.39,Vector3(1.6,0.09,size.y-1.1),WALK)
	for x in [-1,1]:
		for z in [-1,1]:
			var offset := Vector3(x*size.x*0.32,0.45,z*size.y*0.25)
			b.box(p+offset+Vector3.UP*0.37,Vector3(size.x*0.22,0.73,1.05),HEDGE)
			_tree(b,p+offset+Vector3(x*size.x*0.08,0.15,z*1.7),7.0+(style%3)*0.8,style+x+z)
		_bench(b,p+Vector3(x*3.7,0.37,2.15))
	if style%2==0:
		b.frustum(p+Vector3.UP*0.84,2.7,2.65,0.8,12,STONE)
		b.frustum(p+Vector3.UP*1.29,2.24,2.24,0.14,12,Color("#80aaa1"))
		b.frustum(p+Vector3.UP*2.01,0.51,0.24,1.7,8,PALE)


func _person(b: Brush,p: Vector3,style: int) -> void:
	var coat: Color = [Color("#9a4b3a"),Color("#587970"),Color("#c99751"),Color("#837485"),Color("#788a93")][style%5]
	var h := 0.91 if style%3==0 else 1.02
	b.frustum(p+Vector3.UP*(0.38*h),0.17,0.21,0.73*h,6,IRON)
	b.frustum(p+Vector3.UP*(1.00*h),0.27,0.22,0.68*h,7,coat)
	b.frustum(p+Vector3.UP*(1.55*h),0.185,0.17,0.34*h,7,Color("#bb9578"))
	if style%2:
		b.frustum(p+Vector3.UP*(1.76*h),0.21,0.13,0.16*h,6,IRON)


func _car(b: Brush,p: Vector3,yaw: float,style: int) -> void:
	var old := b.pose
	b.pose = old * Transform3D(Basis(Vector3.UP,yaw),p)
	var body: Color = [Color("#829b9c"),Color("#b36852"),Color("#d1c59f"),Color("#688079"),Color("#989c98")][style%5]
	b.box(Vector3(0,0.58,0),Vector3(3.9,0.73,1.62),body)
	b.box(Vector3(0.1,1.08,0),Vector3(2.1,0.66,1.41),Color("#667d7c"))
	b.box(Vector3(0.14,1.47,0),Vector3(1.88,0.18,1.47),body.lightened(0.13))
	for x in [-1.15,1.15]:
		for z in [-0.82,0.82]:
			b.box(Vector3(x,0.35,z),Vector3(0.62,0.52,0.15),IRON)
	b.pose = old


func _tollhouse(b: Brush, p: Vector3) -> void:
	b.frustum(p+Vector3.UP*0.40,3.38,3.38,0.8,8,STONE)
	b.frustum(p+Vector3.UP*2.30,2.96,2.88,3.7,8,Color("#cab894"))
	for side: int in [-1,1]:
		b.box(p+Vector3(0,2.45,side*2.73),Vector3(1.49,2.27,0.30),Architecture.WINDOW)
		b.box(p+Vector3(side*2.73,2.45,0),Vector3(0.30,2.27,1.49),Architecture.WINDOW)
	b.frustum(p+Vector3.UP*4.26,3.18,3.30,0.6,8,PALE)
	b.frustum(p+Vector3.UP*5.35,3.25,2.42,1.58,8,Architecture.SLATE)
	b.frustum(p+Vector3.UP*6.78,2.42,1.15,1.29,8,Architecture.SLATE)
	b.frustum(p+Vector3.UP*7.54,1.04,0.50,0.41,8,GOLD_SHADE)
	b.frustum(p+Vector3.UP*8.08,0.34,0.0,0.9,6,Architecture.SLATE)


func _block(b: Brush,x0: float,x1: float,z: float,depth: float,floors: int) -> void:
	var n := maxi(1,roundi((x1-x0)/13.7))
	var w := (x1-x0)/n
	for i in n:
		var d := depth+_rng.randf_range(-1.7,1.7)
		Architecture.house(b,Vector3(x0+w*(i+0.5),-0.37,z),w-0.34,d,
			floors+int(_rng.randf()>0.69),_rng.randi_range(0,49))


func _kiosk(b: Brush, p: Vector3) -> void:
	b.frustum(p+Vector3.UP*0.36,1.65,1.65,0.7,8,STONE)
	b.frustum(p+Vector3.UP*2.01,1.5,1.48,2.92,8,Color("#73a093"))
	b.frustum(p+Vector3.UP*3.67,2.0,2.05,0.38,8,PALE)
	b.frustum(p+Vector3.UP*4.51,2.08,0.56,1.3,8,Color("#64857c"))
	b.frustum(p+Vector3.UP*5.44,0.48,0.20,0.66,8,GOLD_SHADE)


const GOLD_SHADE := Color("#d1ac68")


func _rails(path: Path3D) -> void:
	var b := Brush.new()
	var curve := path.curve
	# Offsets measured perpendicular to the imported polyline, including the bend to Újezd.
	var centerline := PackedVector3Array()
	for i in curve.point_count:
		var p := to_local(path.to_global(curve.get_point_position(i)))
		if centerline.is_empty() or p.distance_squared_to(centerline[-1]) > 0.0001:
			centerline.append(p)
	var before := centerline[0]+centerline[1].direction_to(centerline[0])*34.0
	var after := centerline[-1]+centerline[-2].direction_to(centerline[-1])*19.0
	centerline.insert(0,before)
	centerline.append(after)
	for offset: float in [-4.1375,-2.7025,-0.7175,0.7175]:
		var rail := PackedVector3Array()
		for i in centerline.size():
			var prev := centerline[i]-centerline[maxi(i-1,0)]
			var next := centerline[mini(i+1,centerline.size()-1)]-centerline[i]
			var t := (prev.normalized()+next.normalized()).normalized()
			var lateral := Vector3(-t.z,0,t.x)
			rail.append(centerline[i]+lateral*offset)
		for i in rail.size()-1:
			_hstripe(b,rail[i]-Vector3.UP*0.067,rail[i+1]-Vector3.UP*0.067,0.19,0.13,Color("#676d69"))
			_hstripe(b,rail[i]-Vector3.UP*0.003,rail[i+1]-Vector3.UP*0.003,0.085,0.012,Color("#c5c8ba"))
	# An understated overhead contact wire, with pier-mounted masts.
	var length := curve.get_baked_length()
	var last_wire := Vector3.ZERO
	var spans := ceili(length/35)
	for i in spans+1:
		var d := length*i/spans
		var pos := to_local(path.to_global(curve.sample_baked(d)))
		var next := to_local(path.to_global(curve.sample_baked(clampf(d+0.5,0,length))))
		if i==spans:
			next = pos+pos-to_local(path.to_global(curve.sample_baked(d-0.5)))
		var t := (next-pos).normalized()
		var lateral := Vector3(-t.z,0,t.x)
		var wire := pos+Vector3.UP*4.70
		var pole := pos+lateral*6.8
		b.frustum(pole+Vector3.UP*2.82,0.13,0.10,5.65,6,IRON)
		b.beam(pole+Vector3.UP*5.50,wire+Vector3.UP*0.16,0.095,0.095,IRON)
		b.beam(pole+Vector3.UP*4.10,pole+Vector3.UP*5.06-lateral*3.15,0.085,0.085,IRON)
		if i>0:
			b.beam(last_wire,wire,0.055,0.055,IRON)
		last_wire = wire
	var distances := PackedFloat64Array([0.0,length])
	var timetable := path.get_parent()
	if timetable.has_signal("sampled") and timetable.get("distances") != null:
		distances = timetable.get("distances")
	for d: float in distances:
		var stop := to_local(path.to_global(curve.sample_baked(d)))
		var ahead := to_local(path.to_global(curve.sample_baked(minf(d+0.5,length))))
		var t := (ahead-stop).normalized()
		if t.length_squared()<0.9:
			t = (stop-to_local(path.to_global(curve.sample_baked(d-0.5)))).normalized()
		var side := Vector3(-t.z,0,t.x)
		var p := stop+side*3.4
		b.frustum(p+Vector3.UP*1.45,0.09,0.09,2.9,6,Color("#ac4538"))
		b.box(p+Vector3.UP*2.78,Vector3(0.82,0.72,0.22),Color("#af3e32"))
		b.box(p+Vector3(0,2.78,0.12),Vector3(0.55,0.43,0.08),PALE)
		_bench(b,p+side*1.5+t*3.0)
	b.finish(self,"RailsAndOverhead",_paint)


func _river_life() -> void:
	var b := Brush.new()
	# Flecks follow the river rather than the track. Keep large sheets of open water.
	for i in 310:
		var x := _rng.randf_range(89,444)
		var z := _rng.randf_range(-152,169)
		if x>260 and x<334:
			continue
		if x<maxf(88,88-z*0.08) or x>minf(444,443+z*0.11):
			continue
		var width := _rng.randf_range(1.0,4.5)
		var shade := Color("#70a9a6") if i%4 else Color("#94bcb2")
		var y := _water_y+0.045
		b.quad(Vector3(x-width,y,z),Vector3(x-0.4,y,z+0.37),Vector3(x+width,y,z+0.05),Vector3(x+0.60,y,z-0.33),shade)
	for i in 2:
		var boat := Brush.new()
		_boat(boat,Vector3.ZERO,0.0,1.0 if i==0 else 0.84)
		var actor := boat.finish(self,"ExcursionBoat%d"%(i+1),_paint)
		actor.rotation.y = 0.16 if i==0 else PI-0.12
		_boats.append(actor)
	_move_boats(0)
	# A small timber landing on the island and its moorings.
	b.box(Vector3(272,-7.15,77),Vector3(9.0,0.55,2.25),Color("#af916a"))
	b.box(Vector3(267.0,-7.16,77),Vector3(2.28,0.53,12.2),Color("#b59971"))
	for z in [72,82]:
		b.frustum(Vector3(267,-7.85,z),0.21,0.21,2.75,6,IRON)
	for i in 4:
		var a := Vector3(378+i*3.15,_water_y+0.16,91+i*4.8)
		var old := b.pose
		b.pose = Transform3D(Basis(Vector3.UP,i*0.31-0.74),a)
		b.frustum(Vector3.ZERO,0.56,0.72,0.35,6,Color("#af6c4a"),Vector2(0.66,2.6))
		b.box(Vector3(0,0.3,0),Vector3(0.74,0.25,0.36),PALE)
		b.pose = old
	b.finish(self,"RiverMarksAndLanding",_paint)


func _move_boats(service_seconds: float) -> void:
	if _boats.size()!=2:
		return
	var t := clampf((service_seconds-_service_start)/240.0,0.0,1.0)
	_boats[0].position = Vector3(lerpf(186.0,157.0,t),_water_y,lerpf(115.0,-125.0,t))
	_boats[1].position = Vector3(lerpf(390.0,366.0,t),_water_y,lerpf(-135.0,127.0,t))


func _boat(b: Brush, p: Vector3, yaw: float, size: float) -> void:
	var old := b.pose
	b.pose = Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),p)
	var hull := PackedVector2Array([Vector2(0,-12.5),Vector2(2.15,-9.0),Vector2(2.8,-5.3),
		Vector2(2.85,6.0),Vector2(2.35,10.1),Vector2(1.7,11.4),Vector2(-1.7,11.4),
		Vector2(-2.35,10.1),Vector2(-2.85,6.0),Vector2(-2.8,-5.3),Vector2(-2.15,-9.0)])
	_poly(b,hull,0.09,0.98,PALE,Color("#894e44"))
	b.box(Vector3(0,1.61,0.8),Vector3(4.33,1.42,14.2),Color("#eae3c7"))
	for side: int in [-1,1]:
		for i in 10:
			b.box(Vector3(side*2.18,1.72,-5.1+1.27*i),Vector3(0.06,0.75,0.92),Color("#4f777c"))
	b.box(Vector3(0,2.43,0.66),Vector3(4.72,0.36,14.7),Color("#e7e7ce"))
	b.box(Vector3(0,3.04,-4.1),Vector3(2.9,1.05,3.35),Color("#6f918d"))
	b.box(Vector3(0,3.64,-4.1),Vector3(3.30,0.24,3.73),PALE)
	b.frustum(Vector3(0,3.28,2.62),0.63,0.61,1.7,8,Color("#aa5a3f"))
	b.frustum(Vector3(0,4.20,2.62),0.65,0.64,0.26,8,IRON)
	for side: int in [-1,1]:
		var a := Vector3(side*2.25,0.07,9.1)
		var c := Vector3(side*6.75,0.07,22.8)
		_hstripe(b,a,c,0.55,0.03,WAKE)
		_hstripe(b,a+Vector3(side*1.0,0,2.1),c+Vector3(side*1.8,0,1.8),0.30,0.02,WAKE)
	b.pose = old


