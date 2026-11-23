extends RefCounted
## Original architectural miniatures. Facades face local +Z.

const Brush = preload("res://demo/art/model_mesh.gd")
const STUCCO := Color("#f3ddad")
const SILL := Color("#f4e7c7")
const WINDOW := Color("#506970")
const WINDOW_LIT := Color("#adc0b7")
const SHADOW := Color("#837d6e")
const SLATE := Color("#475e65")
const COPPER := Color("#618d82")
const GOLD := Color("#eebf56")
const WALLS := [Color("#e9bfa5"), Color("#efd49b"), Color("#c2cfba"), Color("#e0ac8e"), Color("#dbc3ad"), Color("#efdcba")]
const ROOFS := [Color("#ad5943"),Color("#bf6549"),Color("#985344"),Color("#bb7356"),Color("#707a79")]


static func house(b: Brush, p: Vector3, width: float, depth: float, floors: int, style: int, turn := 0.0) -> void:
	var old := b.pose
	b.pose = old * Transform3D(Basis(Vector3.UP, turn), p)
	var h := floors*3.45 + 1.25
	var wall: Color = WALLS[style%WALLS.size()]
	var roof: Color = ROOFS[style%ROOFS.size()]
	b.box(Vector3(0,h*0.5,0),Vector3(width,h,depth),wall)
	b.box(Vector3(0,0.54,0),Vector3(width+0.25,1.08,depth+0.25),SHADOW.lightened(0.2))
	b.box(Vector3(0,3.44,0),Vector3(width+0.48,0.37,depth+0.45),SILL)
	b.box(Vector3(0,h-0.40,0),Vector3(width+0.5,0.49,depth+0.5),SILL)
	b.box(Vector3(0,h+0.05,0),Vector3(width+0.95,0.50,depth+0.95),wall.darkened(0.16))
	_hip(b,Vector3(0,h+0.23,0),width+0.95,depth+1.0,depth*0.31,roof)
	var bays := maxi(2,roundi(width/3.4))
	for side: int in [-1,1]:
		var z := side*(depth*0.5+0.05)
		for i in bays:
			var x := width*((i+0.5)/bays-0.5)
			for level in floors:
				var y := 2.1 + level*3.43
				var ht := 2.28 if level==0 else 1.75
				var shade := WINDOW_LIT if (i+level+style)%6==0 else WINDOW
				b.box(Vector3(x,y,z),Vector3(1.38,ht,0.16),shade)
				b.box(Vector3(x,y-ht*0.5,z+side*0.08),Vector3(1.76,0.19,0.35),SILL)
				if level>0 and (style+i)%3!=0:
					b.box(Vector3(x,y+0.21,z+side*0.11),Vector3(1.32,0.12,0.16),SILL)
	# End wall details are important at the cut edges of each block.
	for side: int in [-1,1]:
		for k in maxi(2,int(depth/4.2)):
			var z := -depth*0.5+2.18+k*4.1
			for f in floors:
				b.box(Vector3(side*(width*0.5+0.06),2.0+f*3.43,z),Vector3(0.16,1.75,1.24),WINDOW)
	var eave := h+depth*0.31
	for n in 1+int(width>18):
		var x := (n-0.5)*width*0.45
		b.box(Vector3(x,eave+0.43,-0.65),Vector3(0.97,2.25,1.15),wall.darkened(0.09))
		b.box(Vector3(x,eave+1.62,-0.65),Vector3(1.27,0.25,1.4),roof.darkened(0.22))
	for n in maxi(1,int(width/8.5)):
		var x := -width*0.30+n*7.0
		b.box(Vector3(x,h+1.48,depth*0.29),Vector3(1.72,2.1,1.91),wall)
		b.box(Vector3(x,h+1.52,depth*0.29+0.99),Vector3(0.95,1.18,0.12),WINDOW)
		_hip(b, Vector3(x,h+2.54,depth*0.29),2.4,2.54,0.79,roof.darkened(0.12))
	if style%7==2:
		# A projecting bay with a faceted copper cap breaks the cornice line.
		var bay := Vector3(width*0.32,0,depth*0.49)
		b.frustum(bay+Vector3.UP*(h*0.57),2.12,2.06,h*0.85,8,wall,Vector2(0.88,1))
		for f in range(1,floors):
			b.box(bay+Vector3(0,2.1+f*3.43,1.91),Vector3(1.13,1.72,0.18),WINDOW)
		b.frustum(bay+Vector3.UP*(h+0.78),2.28,1.89,1.8,8,COPPER)
		b.frustum(bay+Vector3.UP*(h+2.96),1.89,0.36,2.58,8,COPPER.darkened(0.12))
		b.frustum(bay+Vector3.UP*(h+4.82),0.29,0.0,1.34,8,GOLD)
	if style%3==1:
		var canopy: Color = [Color("#a95746"),Color("#589184"),Color("#ac8555")][floori(style/3.0)%3]
		for k in 4:
			var dx := width*((k+0.5)/4.0-0.5)*0.75
			b.box(Vector3(dx,3.03,depth*0.5+0.77),Vector3(width*0.185,0.23,1.53),canopy if k%2==0 else SILL)
	b.pose = old


static func _hip(b: Brush, base: Vector3, width: float, depth: float, height: float, colour: Color) -> void:
	var x := width*0.5
	var z := depth*0.5
	var ridge := maxf(0.2,x-minf(z*0.74,x*0.7))
	var a := base+Vector3(-x,0,-z)
	var c := base+Vector3(x,0,-z)
	var d := base+Vector3(x,0,z)
	var e := base+Vector3(-x,0,z)
	var l := base+Vector3(-ridge,height,0)
	var r := base+Vector3(ridge,height,0)
	b.quad(e,d,r,l,colour)
	b.quad(c,a,l,r,colour)
	b.tri(a,e,l,colour)
	b.tri(d,c,r,colour)


static func theatre(b: Brush, p: Vector3) -> void:
	var old := b.pose
	b.pose = old.translated_local(p)
	# Pale limestone base, rusticated lower floors and the recessed loggia.
	b.box(Vector3(0,1.0,0),Vector3(49,2.0,60),Color("#a79c83"))
	b.box(Vector3(0,13.1,-1.2),Vector3(47.0,25.0,54.5),STUCCO)
	b.box(Vector3(0,5.6,0),Vector3(47.6,8.0,56.4),Color("#dec9a3"))
	for x in [-23.5,23.5]:
		for z in [-26,0,25]:
			b.box(Vector3(x,14.1,z),Vector3(1.25,26,3.3),SILL)
	for y in [3.15,6.0,9.25,21.7,25.5,27.1]:
		b.box(Vector3(0,y,0),Vector3(48.5,0.62,56.6),SILL)
	b.box(Vector3(0,13.5,26.2),Vector3(38,15.5,4.4),Color("#a99779"))
	# Three-tier façade; the arches are extruded voussoirs over recessed glass.
	for i in 7:
		var x := (i-3)*5.65
		b.box(Vector3(x,5.3,28.5),Vector3(3.4,5.4,0.58),WINDOW)
		b.box(Vector3(x,14.1,28.5),Vector3(3.7,5.4,0.4),Color("#707c77"))
		_arch_trim(b, Vector3(x,16.8,28.95),2.0,0.57,SILL)
		for j in [-1,1]:
			b.frustum(Vector3(x+j*2.28,14.75,29.45),0.41,0.36,9,8,SILL)
			b.box(Vector3(x+j*2.28,19.15,29.45),Vector3(1.12,0.6,1.22),STUCCO)
		b.box(Vector3(x,22.75,28.2),Vector3(2.5,1.35,0.54),Color("#978d77"))
	for side: int in [-1,1]:
		for row in 8:
			var z := (row-3.5)*6.6
			for y in [5.6,14.8,23.2]:
				b.box(Vector3(side*23.55,y,z),Vector3(0.24,4.5 if y<20 else 1.65,2.95),WINDOW)
				b.box(Vector3(side*23.74,y+0.31,z),Vector3(0.28,0.25,2.99),SILL)
	# The National Theatre's dark, convex hipped crown with gold ribs
	# is its most recognisable detail from across the river.
	var dims := [Vector3(24.4,27.5,29),Vector3(22.9,32.4,27.4),Vector3(19.1,38.5,24.1),Vector3(14,42.4,19.4),Vector3(8.7,44.1,15.0)]
	for i in dims.size()-1:
		var a: Vector3 = dims[i]
		var e: Vector3 = dims[i+1]
		for s in [-1,1]:
			var aa := Vector3(-a.x,a.y,s*a.z)
			var ab := Vector3(a.x,a.y,s*a.z)
			var ea := Vector3(-e.x,e.y,s*e.z)
			var eb := Vector3(e.x,e.y,s*e.z)
			if s==1:
				b.quad(aa,ab,eb,ea,SLATE)
			else:
				b.quad(ab,aa,ea,eb,SLATE)
			for k in range(-4,5):
				b.beam(Vector3(a.x*k/4.0,a.y+0.08,s*a.z),Vector3(e.x*k/4.0,e.y+0.08,s*e.z),0.34,0.31,GOLD)
			var ca := Vector3(s*a.x,a.y,-a.z)
			var cb := Vector3(s*a.x,a.y,a.z)
			var da := Vector3(s*e.x,e.y,-e.z)
			var db := Vector3(s*e.x,e.y,e.z)
			if s==1:
				b.quad(cb,ca,da,db,SLATE)
			else:
				b.quad(ca,cb,db,da,SLATE)
			for k in range(-3,4):
				b.beam(Vector3(s*a.x,a.y+0.07,a.z*k/4.0),Vector3(s*e.x,e.y+0.07,e.z*k/4.0),0.30,0.29,GOLD)
	b.box(Vector3(0,44.15,0),Vector3(17.5,0.48,30.2),GOLD)
	b.box(Vector3(0,44.43,0),Vector3(16.5,0.45,29.2),SLATE)
	for z in [-14.0,14.0]:
		for x in [-8.0,8.0]:
			b.frustum(Vector3(x,45.3,z),0.54,0.22,1.5,8,GOLD)
	for x in [-20.2,20.2]:
		var q := Vector3(x,28.0,27)
		b.box(q+Vector3.UP*0.75,Vector3(5.0,1.5,4.2),STUCCO)
		# Paired bronze horses drawing the corner chariots.
		for k in [-1,1]:
			b.box(q+Vector3(k,2.8,1),Vector3(0.88,1.12,2.55),COPPER)
			b.beam(q+Vector3(k,2.8,1.72),q+Vector3(k,4.22,2.35),0.72,0.78,COPPER)
			b.box(q+Vector3(k,4.14,2.7),Vector3(0.72,0.66,1.2),COPPER)
			b.beam(q+Vector3(k,2.55,1.65),q+Vector3(k,1.46,2.32),0.35,0.38,COPPER)
		b.frustum(q+Vector3(0,3.25,-0.88),0.80,0.35,2.85,7,COPPER)
		b.frustum(q+Vector3(0,5.07,-0.88),0.43,0.34,0.73,7,GOLD)
	b.pose = old


static func _arch_trim(b: Brush, center: Vector3, radius: float, width: float, colour: Color) -> void:
	for j in 10:
		var v := Vector2.from_angle(PI*j/10)
		var w := Vector2.from_angle(PI*(j+1)/10)
		var p := Vector3(v.x,v.y,0)
		var q := Vector3(w.x,w.y,0)
		b.quad(center+p*radius,center+p*(radius+width),center+q*(radius+width),center+q*radius,colour)


