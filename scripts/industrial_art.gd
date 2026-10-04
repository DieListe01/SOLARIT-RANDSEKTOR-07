extends RefCounted
class_name IndustrialArt

# Original model-like vector artwork, independent of the simulation and Classic sprites.
var canvas: CanvasItem
var origin := Vector2.ZERO
var axis := Vector2.RIGHT
var lateral := Vector2.DOWN
var clock := 0.0
var opacity := 1.0
const STEEL = Color("a59882")
const DARK = Color("3b3029")
const EDGE = Color("ecce9e")
const RUBBER = Color("261e1b")
var metal_texture: Texture2D
var machinery_running := true
var simplified := false

func _init() -> void:
	var noise := FastNoiseLite.new()
	noise.seed=2186; noise.frequency=0.45
	var image_value := noise.get_image(64,64)
	for y in 64:
		for x in 64:
			var gray := 0.91+image_value.get_pixel(x,y).r*0.09
			image_value.set_pixel(x,y,Color(gray,gray,gray))
	metal_texture=ImageTexture.create_from_image(image_value)

func point(v: Vector2) -> Vector2:
	return origin+axis*v.x+lateral*v.y

func poly(vertices: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for v in vertices: points.append(point(v))
	canvas.draw_colored_polygon(points,Color(color,color.a*opacity))
	points.append(points[0])
	canvas.draw_polyline(points,Color(color,color.a*opacity),0.7,true)

func line(a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	canvas.draw_line(point(a),point(b),Color(color,color.a*opacity),width,true)

func rect(r: Rect2, color: Color) -> void:
	poly([r.position,r.position+Vector2(r.size.x,0),r.end,r.position+Vector2(0,r.size.y)],color)

func ellipse(p: Vector2, radius: Vector2, color: Color) -> void:
	var vertices: Array = []
	for i in 40: vertices.append(p+Vector2(cos(i*TAU/40),sin(i*TAU/40))*radius)
	poly(vertices,color)

func flame(p: Vector2, height: float, phase: float) -> void:
	# Layered, curling lobes replace rigid triangular damage markers.
	for layer in 5:
		var t := float(layer)/5.0
		var sway := sin(clock*8+phase+t*3)*height*0.18*t
		var q := p+Vector2(sway,-height*t)
		ellipse(q,Vector2(height*(0.28-t*0.19),height*0.24),Color(1,0.24+t*0.36,0.035,0.52*(1-t*0.6)))
		ellipse(q+Vector2(0,height*0.05),Vector2(height*(0.14-t*0.08),height*0.15),Color(1,0.84,0.36,0.62*(1-t)))
	for i in 3:
		var age := fposmod(clock*0.9+phase+i*0.31,1.0)
		ellipse(p+Vector2(sin(phase+i+age*4)*5,-height-age*height*1.4),Vector2(0.55,1.1),Color(1,0.66,0.18,(1-age)*0.65))

func box(r: Rect2, height: float, color: Color) -> void:
	var a := r.position
	var b := a+Vector2(r.size.x,0)
	var c := r.end
	var d := a+Vector2(0,r.size.y)
	var lift := Vector2(-height*0.28,-height)
	poly([b,c,c+lift,b+lift],color.darkened(0.52))
	poly([d,c,c+lift,d+lift],color.darkened(0.31))
	poly([a+lift,b+lift,c+lift,d+lift],color)
	# A brushed surface and a shallow lighting gradient keep large roofs from looking flat.
	var points := PackedVector2Array([point(a+lift),point(b+lift),point(c+lift),point(d+lift)])
	var colors := PackedColorArray([color.lightened(0.13),color.lightened(0.07),color.darkened(0.07),color.darkened(0.02)])
	for i in colors.size(): colors[i].a*=opacity
	canvas.draw_polygon(points,colors,PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]),metal_texture)
	if r.size.x>8 and r.size.y>6:
		var bevel := minf(2.2,minf(r.size.x,r.size.y)*0.09)
		poly([a+lift,b+lift,b+lift+Vector2(-bevel,bevel),a+lift+Vector2(bevel,bevel)],color.lightened(0.22))
		poly([b+lift,c+lift,c+lift-Vector2(bevel,bevel),b+lift+Vector2(-bevel,bevel)],color.darkened(0.22))
		poly([d+lift,c+lift,c+lift-Vector2(bevel,bevel),d+lift+Vector2(bevel,-bevel)],color.darkened(0.15))
	line(a+lift,b+lift,color.lightened(0.42),1)
	line(a+lift,d+lift,color.lightened(0.18),0.7)
	line(d+Vector2(0,-1),c+Vector2(0,-1),color.darkened(0.1),0.7)
	if r.size.x>20 and r.size.y>16:
		for row in range(5,int(r.size.y)-3,7):
			var q := a+lift+Vector2(4,row)
			line(q,q+Vector2(r.size.x-8,0),Color(color.lightened(0.25),0.13),0.5)
		for row in 3:
			var q := a+lift+Vector2(4,r.size.y*float(row+1)/4)
			line(q,q+Vector2(r.size.x*0.18,1),Color("62442b"),0.55)
		# Recessed service panel seams, abrasion and rust collect on broad metal plates.
		var middle := (a+c)*0.5+lift
		line(middle-Vector2(r.size.x*0.34,0),middle+Vector2(r.size.x*0.34,0),Color(0.23,0.16,0.11,0.24),0.6)
		for i in 7:
			var q := a+lift+Vector2(3+fposmod(i*11.7,r.size.x-6),3+fposmod(i*7.9,r.size.y-6))
			line(q,q+Vector2(1.5+float(i%3),0.3),Color(0.96,0.80,0.55,0.20),0.6)
			if i%3==0: ellipse(q+Vector2(1,1),Vector2(1.8,0.7),Color(0.58,0.27,0.10,0.25))
		for q in [a+lift+Vector2(2,2),b+lift+Vector2(-2,2),c+lift-Vector2(2,2),d+lift+Vector2(2,-2)]:
			ellipse(q,Vector2.ONE*0.8,EDGE.darkened(0.12))

func vent(r: Rect2) -> void:
	box(r,1.5,DARK)
	for x in range(2,int(r.size.x)-1,3):
		line(r.position+Vector2(x,1),r.position+Vector2(x,r.size.y-2),STEEL.darkened(0.2),0.8)

func fan(p: Vector2, radius: float, running: bool = true) -> void:
	ellipse(p,Vector2.ONE*(radius+1.5),RUBBER)
	ellipse(p,Vector2.ONE*radius,STEEL.darkened(0.45))
	for i in 5:
		var angle: float = i*TAU/5+(clock*1.7 if running and machinery_running else 0)
		var d := Vector2.from_angle(angle)
		poly([p+d*2,p+d.orthogonal()*2+d*radius*0.65,p+d*radius*0.88+d.orthogonal()*1.5],STEEL)
	for i in 8:
		var x := -radius+1+i*(radius*2-2)/7
		var height := sqrt(maxf(0,radius*radius-x*x))
		line(p+Vector2(x,-height),p+Vector2(x,height),Color(0.08,0.13,0.16,0.55),0.5)
	ellipse(p,Vector2.ONE*1.8,EDGE)

func pipe(points: Array, width: float = 3.0) -> void:
	for i in range(1,points.size()):
		line(points[i-1]+Vector2(1,2),points[i]+Vector2(1,2),RUBBER,width+2)
		line(points[i-1],points[i],STEEL.darkened(0.16),width)
		line(points[i-1]-Vector2(0,0.6),points[i]-Vector2(0,0.6),EDGE,width*0.24)
	for q in points: ellipse(q,Vector2.ONE*(width*0.65),STEEL.lightened(0.12))

func light(p: Vector2, color: Color, radius: float = 1.3) -> void:
	ellipse(p,Vector2.ONE*radius*3,Color(color,0.07))
	ellipse(p,Vector2.ONE*radius,color)

func hazard(a: Vector2, width: float) -> void:
	line(a,a+Vector2(width,0),RUBBER,4)
	for x in range(0,int(width)-2,6): line(a+Vector2(x,-1.6),a+Vector2(x+3,1.6),Color("eac174"),1.7)

func building(target: CanvasItem, e: Dictionary, size_value: Vector2, team: Color, elapsed: float) -> void:
	canvas=target; origin=e.pos; axis=Vector2.from_angle(float(e.get("rotation",0))*PI/2); lateral=Vector2.DOWN.rotated(float(e.get("rotation",0))*PI/2); clock=elapsed
	machinery_running=float(e.hp)/float(e.max_hp)>=0.4
	var size := size_value-Vector2(5,5)
	var base := Rect2(-size*0.5,size)
	var w := size.x; var h := size.y
	building_shadow(e,w,h)
	# Chamfered foundations and a dark contact edge separate silhouettes from terrain.
	var cut := minf(w,h)*(0.21 if e.kind in ["radar","tower"] else 0.10)
	var floor_points := [Vector2(-w*0.5+cut,-h*0.5),Vector2(w*0.5-cut,-h*0.5),Vector2(w*0.5,-h*0.5+cut),Vector2(w*0.5,h*0.5-cut),Vector2(w*0.5-cut,h*0.5),Vector2(-w*0.5+cut,h*0.5),Vector2(-w*0.5,h*0.5-cut),Vector2(-w*0.5,-h*0.5+cut)]
	var ground_shadow: Array = []
	for v in floor_points: ground_shadow.append(v+Vector2(2,5))
	poly(ground_shadow,Color("33241b"))
	poly(floor_points,Color("957c5e"))
	line(Vector2(-w*0.5+cut,-h*0.5),Vector2(w*0.5-cut,-h*0.5),EDGE,1.4)
	for x in range(8,int(w)-4,12):
		line(base.position+Vector2(x,0),base.position+Vector2(x,h-4),Color(0.17,0.23,0.26,0.27),0.7)
	hazard(Vector2(-w*0.5+5,h*0.5-5),w-10)
	# Dust collects around foundations, while broad corner panels identify ownership.
	for i in 8:
		var grit := Vector2(-w*0.5+float(i)*w/7,h*0.5+3+sin(i*2.3)*2)
		ellipse(grit,Vector2(4,1.4),Color(0.68,0.42,0.21,0.28))
	for side in [-1,1]:
		box(Rect2(side*w*0.38-w*0.055,-h*0.32,w*0.11,h*0.62),4,team.darkened(0.08))
	var faction: String = target.sim.factions[e.get("owner",0)]
	if faction=="drift":
		poly([Vector2(w*0.35,-h*0.35),Vector2(w*0.54,-h*0.51),Vector2(w*0.47,h*0.28),Vector2(w*0.34,h*0.32)],team.darkened(0.12))
		line(Vector2(w*0.43,-h*0.32),Vector2(w*0.41,h*0.2),EDGE,1.3)
	elif faction=="lumen":
		for side in [-1,1]:
			ellipse(Vector2(side*w*0.4,-h*0.2),Vector2(5,12),team.darkened(0.1))
			light(Vector2(side*w*0.4,-h*0.2-2),team.lightened(0.7),2)
	for x in [-w*0.5+4,w*0.5-4]:
		for y in [-h*0.5+2,h*0.5-10]:
			box(Rect2(x-2,y-2,4,4),1,EDGE.darkened(0.2))
	if not e.complete:
		var progress: float = clampf(e.build_progress/float(target.sim.definition(e).time),0,1)
		for i in 3:
			var projector := Vector2(-w*0.4+i*w*0.4,h*0.35)
			poly([projector,projector+Vector2(-8,-h*0.7-14),projector+Vector2(8,-h*0.7-14)],Color(team,0.07))
			light(projector,team.lightened(0.7),2)
		for i in 8:
			var age := fposmod(clock*0.5+i*0.13,1.0)
			ellipse(Vector2(-w*0.5+i*w/7,h*0.43+age*5),Vector2(2+age*5,1+age*2),Color(0.72,0.43,0.20,(1-age)*0.15))
		if progress>0.2:
			box(Rect2(-w*0.32,-h*0.25,w*0.64,h*0.55),4+progress*14,STEEL.darkened(0.3))
		if progress>0.55:
			vent(Rect2(-w*0.2,-h*0.15-12,w*0.4,h*0.2))
			pipe([Vector2(-w*0.4,h*0.3),Vector2(-w*0.4,-h*0.2),Vector2(-w*0.25,-h*0.2)])
		if progress>0.8:
			light(Vector2(w*0.25,-h*0.2-18),team.lightened(0.5),2)
		for x in [-w*0.35,w*0.35]:
			line(Vector2(x,h*0.35),Vector2(x,-h*0.3-18),STEEL,2)
		line(Vector2(-w*0.35,-h*0.3-18),Vector2(w*0.35,-h*0.3-18),team,3)
		for i in 4: line(Vector2(-w*0.35+i*w*0.18,h*0.35),Vector2(-w*0.17+i*w*0.18,-h*0.3-18),STEEL.darkened(0.3),1)
		var welder := Vector2(sin(clock*1.8)*w*0.3,-h*0.15-10)
		light(welder,Color("c9f8ff"),1.5)
		for i in 6:
			var age := fposmod(clock*2+i*0.17,1.0)
			line(welder+Vector2(i-3,age*14),welder+Vector2(i-3,age*14+2),Color(1,0.75,0.35,1-age),0.8)
		# A moving assembly scan and recognizable systems precede the online pulse.
		var scan_y := h*0.32-fposmod(clock*14,h*0.62+24)
		line(Vector2(-w*0.35,scan_y),Vector2(w*0.35,scan_y),Color(team,0.35),1.4)
		if progress>0.80:
			var saved_opacity := opacity
			opacity*=0.50+(progress-0.80)*2
			role_details(e,w,h,team,faction)
			opacity=saved_opacity
		rect(Rect2(-w*0.3,0,w*0.6,5),RUBBER)
		rect(Rect2(-w*0.3,0,w*0.6*progress,5),team)
		return
	match e.kind:
		"core":
			for side in [-1,1]:
				box(Rect2(side*w*0.3-5,-h*0.32,10,10),27,DARK)
				light(Vector2(side*w*0.3-7,-h*0.32-28),team,2)
			box(Rect2(-w*0.37,-h*0.32,w*0.65,h*0.55),12,STEEL.darkened(0.12))
			box(Rect2(-w*0.25,-h*0.25,w*0.46,h*0.37),22,STEEL)
			poly([Vector2(-w*0.25-6,-h*0.25-22),Vector2(w*0.21-6,-h*0.25-22),Vector2(w*0.25-6,-h*0.12-22),Vector2(-w*0.3-6,-h*0.12-22)],team.darkened(0.2))
			for i in 6: rect(Rect2(-w*0.23+i*w*0.07,-h*0.12-20,w*0.045,6),Color("9cdce0"))
			box(Rect2(-w*0.12,h*0.03,w*0.3,h*0.27),8,DARK)
			for i in 5: line(Vector2(-w*0.11,h*0.08+i*3),Vector2(w*0.17,h*0.08+i*3),STEEL.darkened(0.2),1)
			vent(Rect2(-w*0.4,-h*0.1,10,20))
			fan(Vector2(w*0.25,-h*0.23),7)
			box(Rect2(-w*0.08,-h*0.17,15,12),24,STEEL.darkened(0.06))
			ellipse(Vector2(w*0.01-6,-h*0.12-24),Vector2(5,3),DARK)
			ellipse(Vector2(w*0.01-6,-h*0.12-25),Vector2(3.5,2),EDGE)
			for i in 4:
				line(Vector2(-w*0.35,-h*0.32+i*3),Vector2(-w*0.22,-h*0.32+i*3),STEEL.darkened(0.5),1)
			for i in 5:
				var q := Vector2(w*0.28-3,h*0.03+i*4)
				line(q,q+Vector2(5,0),STEEL.darkened(0.55),1)
			pipe([Vector2(-w*0.3,h*0.3),Vector2(-w*0.35,h*0.15),Vector2(-w*0.35,-h*0.07)])
			var mast := Vector2(w*0.34,-h*0.25)
			line(mast,mast-Vector2(0,32),EDGE,1.5)
			line(mast-Vector2(7,22),mast+Vector2(7,-22),STEEL,1)
			light(mast-Vector2(0,32),team.lightened(0.6))
		"power":
			for i in 3:
				var q := Vector2(-w*0.1+float(i)*w*0.1,-h*0.2-25)
				line(q+Vector2(0,20),q,STEEL,3)
				ellipse(q,Vector2(3,2),Color(team,0.5+sin(clock*3+i)*0.3))
			for sign_value in [-1,1]:
				var p := Vector2(sign_value*w*0.22,-h*0.06)
				box(Rect2(p-Vector2(w*0.14,h*0.27),Vector2(w*0.28,h*0.54)),13,STEEL.darkened(0.1))
				fan(p+Vector2(-4,-h*0.15-13),w*0.1)
				for i in 5:
					line(p+Vector2(-w*0.12,-3+i*4),p+Vector2(w*0.1,-3+i*4),DARK,2)
					line(p+Vector2(-w*0.08,-3+i*4),p+Vector2(w*0.08,-3+i*4),team,0.9)
				pipe([p+Vector2(0,h*0.27),p+Vector2(0,h*0.34),Vector2(0,h*0.34)],2.5)
			box(Rect2(-6,-h*0.34,12,10),8,DARK)
			for sign_value in [-1,1]:
				var q := Vector2(sign_value*w*0.22,-h*0.34)
				line(q,q-Vector2(0,11),STEEL,4)
				ellipse(q-Vector2(0,11),Vector2(3,2),EDGE)
				ellipse(q-Vector2(0,12),Vector2(1.5,1),DARK)
			light(Vector2(0,-h*0.34-5),team)
		"refinery":
			box(Rect2(-w*0.22,h*0.26,w*0.44,h*0.55),1.5,DARK)
			for i in 7:
				var belt_y := h*0.28+fposmod(clock*6+i*h*0.07,h*0.49)
				line(Vector2(-w*0.19,belt_y),Vector2(w*0.19,belt_y),STEEL.darkened(0.15),1.2)
			for i in 4:
				var phase := fposmod(clock*0.3+i*0.23,1.0)
				ellipse(Vector2(w*0.3+phase*9,-h*0.3-18-phase*28),Vector2(2+phase*7,2+phase*5),Color(0.8,0.69,0.49,(1-phase)*0.14))
			for i in 3:
				var p := Vector2(-w*0.3+i*w*0.29,-h*0.1)
				var radius := w*0.105
				rect(Rect2(p-Vector2(radius,15),Vector2(radius*2,28)),STEEL.darkened(0.35))
				for strip in 9:
					var x := -radius+strip*radius*2/9
					var shade := 0.22+0.55*pow(sin((strip+0.5)*PI/9),0.7)
					rect(Rect2(p+Vector2(x,-14),Vector2(radius*2/9+0.2,26)),STEEL*Color(shade,shade,shade))
				ellipse(p+Vector2(0,12),Vector2(radius,5),STEEL.darkened(0.35))
				ellipse(p-Vector2(0,14),Vector2(radius,6),STEEL)
				ellipse(p-Vector2(0,15),Vector2(radius*0.7,4),STEEL.lightened(0.2))
				line(p+Vector2(-radius+3,-8),p+Vector2(-radius+3,9),EDGE,1)
				line(p+Vector2(-radius,3),p+Vector2(radius,3),team,3)
				pipe([p+Vector2(0,15),p+Vector2(0,h*0.28),Vector2(w*0.34,h*0.28)],2.5)
			box(Rect2(w*0.28,-h*0.3,w*0.13,h*0.45),16,DARK)
			vent(Rect2(w*0.27,-h*0.32-16,12,10))
			for i in 6:
				line(Vector2(w*0.35,-h*0.05+i*3),Vector2(w*0.42,-h*0.05+i*3),EDGE,0.8)
			line(Vector2(w*0.35,-h*0.05),Vector2(w*0.35,h*0.21),DARK,1)
			line(Vector2(w*0.42,-h*0.05),Vector2(w*0.42,h*0.21),DARK,1)
			hazard(Vector2(-w*0.15,h*0.32),w*0.3)
		"factory":
			for side in [-1,1]:
				line(Vector2(side*w*0.36,-h*0.05),Vector2(side*w*0.36,-h*0.28-31),DARK,4)
			line(Vector2(-w*0.36,-h*0.28-31),Vector2(w*0.36,-h*0.28-31),STEEL,4)
			var carriage := Vector2(sin(clock*0.45)*w*0.2,-h*0.28-31)
			box(Rect2(carriage-Vector2(4,3),Vector2(8,6)),2,team)
			line(carriage,carriage+Vector2(0,13+sin(clock*0.6)*4),EDGE,0.8)
			box(Rect2(-w*0.38,-h*0.36,w*0.76,h*0.6),16,STEEL.darkened(0.18))
			for i in 5:
				box(Rect2(-w*0.34,-h*0.32+i*h*0.1,w*0.65,h*0.07),18,STEEL.lightened(i*0.014))
			box(Rect2(-w*0.26,h*0.02,w*0.51,h*0.22),12,DARK)
			rect(Rect2(-w*0.23,h*0.1-12,w*0.46,h*0.2),RUBBER)
			for i in 6: line(Vector2(-w*0.21,h*0.12-10+i*2),Vector2(w*0.21,h*0.12-10+i*2),STEEL.darkened(0.42),1)
			for sign_value in [-1,1]:
				line(Vector2(sign_value*w*0.27,h*0.02-12),Vector2(sign_value*w*0.27,h*0.26),team,3)
				light(Vector2(sign_value*w*0.29,h*0.08-12),Color("ffe2a0"))
			fan(Vector2(-w*0.27,-h*0.34-18),5)
			fan(Vector2(w*0.19,-h*0.34-18),5)
			for i in 4:
				var q := Vector2(-w*0.18+i*w*0.11,-h*0.25-18)
				rect(Rect2(q,Vector2(w*0.08,h*0.055)),Color("83b6c1"))
				line(q,q+Vector2(w*0.08,0),EDGE,0.7)
			pipe([Vector2(w*0.35,-h*0.15),Vector2(w*0.35,h*0.15),Vector2(w*0.29,h*0.22)],2)
		"tower":
			box(Rect2(-11,-11,22,22),12,STEEL.darkened(0.3))
			ellipse(Vector2(-3,-13),Vector2(12,9),team.darkened(0.15))
			var barrel := Vector2.from_angle(e.turret)*25
			line(Vector2(-3,-13),Vector2(-3,-13)+barrel,DARK,7)
			line(Vector2(-3,-14),Vector2(-3,-14)+barrel,STEEL,4)
			ellipse(Vector2(-3,-13),Vector2(6,5),STEEL)
		"radar":
			var sweep := Vector2.from_angle(clock*0.8)*Vector2(w*0.45,h*0.3)
			line(Vector2(0,-20),sweep+Vector2(0,-20),Color(team,0.26),1.8)
			ellipse(Vector2(0,-20),Vector2(20,8),Color(team,0.04+0.03*sin(clock*2)))
			box(Rect2(-w*0.32,-h*0.1,w*0.6,h*0.35),9,STEEL.darkened(0.18))
			vent(Rect2(-w*0.28,h*0.01-9,14,10))
			line(Vector2(6,0),Vector2(6,-32),STEEL,5)
			for i in 5: line(Vector2(0,-i*5),Vector2(12,-i*5-5),EDGE,1)
			var dish := Vector2(6,-32)
			ellipse(dish,Vector2(18,9+sin((clock if machinery_running else 0.0)*0.4)*3),STEEL)
			ellipse(dish-Vector2(0,1),Vector2(14,6),STEEL.darkened(0.3))
			for i in 7: line(dish,dish+Vector2.from_angle(i*TAU/7)*Vector2(15,7),EDGE,0.7)
			line(dish,dish-Vector2(0,11),DARK,2)
			light(dish-Vector2(0,12),team)
		"repair":
			var joint := Vector2(-w*0.35,-h*0.1-14)
			var elbow := joint+Vector2(10+sin(clock*0.7)*4,-10)
			var tool := elbow+Vector2(10,sin(clock*0.8)*5+14)
			pipe([joint,elbow,tool],2.5)
			light(tool,Color("a8fff1"),1.2)
			for sign_value in [-1,1]:
				box(Rect2(sign_value*w*0.31-6,-h*0.27,12,h*0.53),8,DARK)
				box(Rect2(sign_value*w*0.31-3,-h*0.25,6,9),22,team.darkened(0.1))
				line(Vector2(sign_value*w*0.31-5,-h*0.25-22),Vector2(sign_value*4,-h*0.25-22),STEEL,3)
			for i in 5: line(Vector2(-w*0.22,-h*0.18+i*7),Vector2(w*0.22,-h*0.18+i*7),STEEL.darkened(0.1),2)
			line(Vector2(-8,1),Vector2(8,1),team,4)
			line(Vector2(0,-7),Vector2(0,9),team,4)
	role_details(e,w,h,team,faction)
	# Animated service lamps and weathered seams belong to every building type.
	box(Rect2(-w*0.23,h*0.28,w*0.46,h*0.10),4,team)
	for i in 9:
		var scratch := Vector2(-w*0.20+float(i)*w*0.05,h*0.29-3+sin(i*7.1)*1.2)
		line(scratch,scratch+Vector2(3,1),Color(0.93,0.76,0.48,0.28),0.6)
	for i in 4:
		var q := Vector2(w*0.3,h*0.15+i*3)
		line(q,q+Vector2(7,0),DARK,1.5)
		line(q,q+Vector2(5,0),Color(1,0.42,0.12,0.3+sin(clock*2+i)*0.1),0.7)
	# Coalition emblems remain distinct when color is unavailable.
	# Additional working hardware: instrument faces, protected wiring and access steps.
	for sign_value in [-1,1]:
		var console := Vector2(sign_value*w*0.33,h*0.20)
		box(Rect2(console-Vector2(5,6),Vector2(10,12)),4,DARK)
		rect(Rect2(console-Vector2(3,8),Vector2(6,4)),Color("37534d"))
		line(console-Vector2(2,6),console+Vector2(2,-6),Color("80c6ac"),0.7)
		for switch_index in 3: ellipse(console+Vector2(-2+switch_index*2,-1),Vector2.ONE*0.55,Color("dfb575"))
		for step_index in 3:
			var q := Vector2(sign_value*w*0.41,h*0.30-step_index*3)
			line(q-Vector2(3,0),q+Vector2(3,0),STEEL,1.2)
		line(Vector2(sign_value*w*0.41-3,h*0.31),Vector2(sign_value*w*0.41-3,h*0.19),EDGE,0.65)
		line(Vector2(sign_value*w*0.41+3,h*0.31),Vector2(sign_value*w*0.41+3,h*0.19),DARK,1)
	if e.kind=="refinery":
		for tank_index in 3:
			var q := Vector2(-w*0.28+tank_index*w*0.28,-h*0.14)
			ellipse(q,Vector2(3.5,3.2),DARK)
			ellipse(q-Vector2(0,0.6),Vector2(2.8,2.5),EDGE)
			line(q,q+Vector2.from_angle(-0.9+sin(clock*0.3+tank_index)*0.4)*2,Color("9c4030"),0.6)
			pipe([q+Vector2(5,3),q+Vector2(5,14),q+Vector2(11,14)],1.0)
	if e.kind in ["factory","repair"]:
		for rail_side in [-1,1]:
			var q := Vector2(rail_side*w*0.23,h*0.25)
			box(Rect2(q-Vector2(2,5),Vector2(4,17)),2,STEEL.darkened(0.3))
			for bolt in 4: ellipse(q+Vector2(0,-6+bolt*4),Vector2.ONE*0.65,EDGE)
			line(q,q+Vector2(0,9),DARK,0.8)
	# Service hatches, cable conduits and anchored roof hardware share the metal lighting.
	for sign_value in [-1,1]:
		var hatch := Vector2(sign_value*w*0.29,-h*0.15)
		box(Rect2(hatch-Vector2(7,4),Vector2(14,8)),2.2,STEEL.darkened(0.2))
		for rivet in [-1,1]: ellipse(hatch+Vector2(rivet*5,-5),Vector2.ONE*0.7,EDGE)
		line(hatch-Vector2(4,3),hatch+Vector2(4,-3),DARK,0.75)
		pipe([Vector2(sign_value*w*0.37,h*0.11),Vector2(sign_value*w*0.37,-h*0.12),hatch+Vector2(0,3)],1.6)
		for clamp_index in 3:
			var q := Vector2(sign_value*w*0.37,-h*0.09+clamp_index*h*0.06)
			line(q-Vector2(2,0),q+Vector2(2,0),EDGE.darkened(0.1),0.75)
	for i in 9:
		var q := Vector2(-w*0.31+i*w*0.073,h*0.28-5)
		line(q,q+Vector2(2,1),Color("d3ac73"),0.5)
	if e.get("repair",false) and e.hp<e.max_hp:
		var weld := Vector2(-w*0.22+sin(clock*0.8)*w*0.1,h*0.12)
		light(weld,Color("aeeaff"),1.6)
		for i in 4:
			var age := fposmod(clock*2+i*0.24,1.0)
			line(weld+Vector2(age*7,-age*6),weld+Vector2(age*7+2,-age*6+1),Color(1,0.76,0.36,1-age),0.8)
	var emblem := Vector2(-w*0.3,h*0.22)
	if e.get("owner",0)==1:
		poly([emblem+Vector2(0,-5),emblem+Vector2(5,0),emblem+Vector2(0,5),emblem+Vector2(-5,0)],team)
	elif e.get("owner",0)==2:
		ellipse(emblem,Vector2.ONE*4,team)
	else:
		rect(Rect2(emblem-Vector2(4,4),Vector2(8,8)),team)
	light(Vector2(-w*0.4,h*0.35-5),team.lightened(0.2),1.1+sin(clock*2.0)*0.25)
	for i in 5:
		var p := Vector2(-w*0.35+i*w*0.15,h*0.32-7)
		line(p,p+Vector2(4,-1),Color(0.12,0.16,0.17,0.45),0.8)
	var stage := 3 if e.hp/e.max_hp<0.15 else (2 if e.hp/e.max_hp<0.4 else (1 if e.hp/e.max_hp<0.7 else 0))
	if stage>0:
		for i in stage+1:
			var scar := Vector2(-w*0.25+i*w*0.19,h*0.06-i*6)
			poly([scar,scar+Vector2(12,-3),scar+Vector2(8,9),scar+Vector2(-5,5)],Color(0.15,0.09,0.05,0.72))
			line(scar,scar+Vector2(6,7),EDGE.darkened(0.4),1)
			var age := fposmod(clock*(0.35+stage*0.12)+i*0.23,1.0)
			ellipse(scar+Vector2(age*12,-15-age*(25+stage*15)),Vector2.ONE*(3+age*(7+stage*3)),Color(0.13,0.10,0.07,(1-age)*0.36))
			if sin(clock*19+i*7)>0.9:
				line(scar,scar+Vector2(9,-7),Color("ffe5aa"),1.5)
	if stage>=2:
		for i in stage*2:
			flame(Vector2(w*0.1+i*4,-h*0.05-8),9+sin(clock*11+i)*2,i)
		light(Vector2(w*0.2,-h*0.1-12),Color("ffa954"),3)
		light(Vector2(-w*0.38,h*0.30),Color("ff5b27"),1.0+maxf(0,sin(clock*9))*2)
		if sin(clock*23)>0.65:
			line(Vector2(-w*0.2,-h*0.15),Vector2(0,-h*0.2+4),Color("b9faff"),1)
			line(Vector2(0,-h*0.2+4),Vector2(w*0.15,-h*0.08),Color("b9faff"),1)

func simplified_vehicle(e: Dictionary, team: Color, faction: String, length: float, width: float) -> void:
	# Readable low-cost silhouette used only when crowds or zoom demand it.
	ellipse(Vector2(4,6),Vector2(length+5,width+5),Color(0.10,0.055,0.03,0.34))
	for side in [-1,1]:
		rect(Rect2(-length*0.82,side*(width-2.2),length*1.55,4.4),RUBBER)
		for i in 3:
			var x := -length*0.54+i*length*0.52
			line(Vector2(x,side*(width-4.5)),Vector2(x+2,side*(width-1)),STEEL.darkened(0.16),1.4)
	var hull := [Vector2(-length+2,-width+3),Vector2(length-5,-width+3),Vector2(length,0),Vector2(length-5,width-3),Vector2(-length+2,width-3),Vector2(-length,0)]
	poly(hull,team.darkened(0.34))
	poly([Vector2(-length*0.72,-width*0.55),Vector2(length*0.47,-width*0.55),Vector2(length*0.72,0),Vector2(length*0.47,width*0.55),Vector2(-length*0.72,width*0.55)],STEEL.darkened(0.18))
	line(Vector2(-length*0.46,-width*0.58),Vector2(length*0.35,-width*0.58),team.lightened(0.08),2.5)
	if faction=="drift": poly([Vector2(length-5,-width*0.65),Vector2(length+7,0),Vector2(length-5,width*0.65)],team.lightened(0.16))
	if e.kind=="scout":
		poly([Vector2(1,-5),Vector2(length+9,0),Vector2(1,5)],team.lightened(0.1))
	elif e.kind=="raider":
		var direction:=Vector2.from_angle(float(e.turret)-float(e.angle))
		for side in [-1,1]: line(Vector2(1,side*3),Vector2(1,side*3)+direction*21,Color("ffbd76"),2.8)
		poly([Vector2(-length*0.45,-width),Vector2(length*0.35,-width*0.7),Vector2(length+4,0),Vector2(length*0.35,width*0.7),Vector2(-length*0.45,width)],team.lightened(0.08))
	elif e.kind=="lancer":
		var direction:=Vector2.from_angle(float(e.turret)-float(e.angle))
		line(Vector2.ZERO,Vector2.ZERO+direction*37,Color("b9a7ff"),4)
		line(Vector2.ZERO+direction*7+direction.orthogonal()*4,Vector2.ZERO+direction*34,Color("ded0ff"),1.5)
	elif e.kind=="scorcher":
		var direction:=Vector2.from_angle(float(e.turret)-float(e.angle))
		box(Rect2(-3,-5,12,10),3,STEEL.darkened(0.1))
		for side in [-1,1]:
			line(Vector2(6,side*3),Vector2(6,side*3)+direction*18,Color("7d4b32"),4)
			line(Vector2(7,side*3),Vector2(7,side*3)+direction*17,Color("ff9c45"),1.6)
		light(Vector2(8,0)+direction*15,Color("ff7136"),2)
	elif e.kind=="bulwark":
		var direction:=Vector2.from_angle(float(e.turret)-float(e.angle))
		var turret:=Vector2(1,-2)
		box(Rect2(-length*0.52,-width*0.73,length*0.84,width*1.46),5,team.darkened(0.04))
		for side in [-1,1]:
			poly([Vector2(-length*0.38,side*width*0.68),Vector2(length*0.38,side*width*0.68),Vector2(length*0.48,side*width*0.90),Vector2(-length*0.48,side*width*0.90)],STEEL.darkened(0.25))
			line(Vector2(-length*0.36,side*width*0.72),Vector2(length*0.35,side*width*0.72),EDGE,1.2)
		box(Rect2(turret-Vector2(9,7),Vector2(18,14)),5,STEEL.darkened(0.08))
		line(turret,turret+direction*27,DARK,8)
		line(turret+Vector2(0,-1),turret+direction*25,Color("ffd18a"),3.2)
		light(turret+direction*25,Color("ffd18a"),1.3)
	else:
		var direction := Vector2.from_angle(float(e.turret)-float(e.angle))
		var turret := Vector2(1,-2)
		ellipse(turret,Vector2(8,7),DARK)
		line(turret,turret+direction*(27 if e.kind=="siege" else 19),STEEL.darkened(0.12),4.2)
		line(turret+Vector2(0,-1),turret+direction*(24 if e.kind=="siege" else 16)+Vector2(0,-1),team.lightened(0.15),1.3)
	light(Vector2(length-3,-width*0.48),Color("ffe5b3"),1.1)
	light(Vector2(length-3,width*0.48),Color("ffe5b3"),1.1)

func vehicle(target: CanvasItem, e: Dictionary, team: Color, faction: String, elapsed: float) -> void:
	canvas=target; origin=e.pos; axis=Vector2.from_angle(e.angle); lateral=axis.orthogonal(); clock=elapsed
	var heavy: bool = e.kind in ["harvester","siege","lancer","bulwark"]
	var length := (35.0 if e.kind=="bulwark" else (28.0 if e.kind=="harvester" else (30.0 if e.kind=="lancer" else 25.0))) if heavy else (15.0 if e.kind=="scout" else (23.0 if e.kind in ["raider","scorcher"] else 22.0))
	var width := (20.0 if e.kind=="bulwark" else (16.0 if e.kind=="harvester" else (17.0 if e.kind=="lancer" else 14.0))) if heavy else (9.0 if e.kind=="scout" else (12.0 if e.kind=="raider" else (14.0 if e.kind=="scorcher" else 13.0)))
	var speed: float = e.get("velocity",Vector2.ZERO).length()
	if speed>5: origin+=lateral*sin(clock*speed*0.1)*minf(0.6,speed*0.006)
	if simplified:
		simplified_vehicle(e,team,faction,length,width)
		return
	ellipse(Vector2(5,7),Vector2(length+5,width+5),Color(0.10,0.055,0.03,0.30))
	ellipse(Vector2(1,3),Vector2(length+1,width+1),Color(0.10,0.055,0.03,0.32))
	if faction=="lumen":
		ellipse(Vector2(0,4),Vector2(length*1.1,width*1.35),Color(team,0.10+sin(clock*3)*0.025))
		for sign_value in [-1,1]:
			ellipse(Vector2(-3,sign_value*width),Vector2(length*0.75,3),DARK)
			line(Vector2(-length*0.7,sign_value*width),Vector2(length*0.7,sign_value*width),Color(team,0.6),2)
	elif faction=="drift":
		for sign_value in [-1,1]:
			for i in 3:
				var q := Vector2(-length*0.65+i*length*0.65,sign_value*width)
				ellipse(q,Vector2(4.5,3.7),RUBBER)
				ellipse(q,Vector2(2.6,2.3),STEEL.darkened(0.1))
				ellipse(q,Vector2.ONE,EDGE)
	else:
		for sign_value in [-1,1]:
			var y: float = sign_value*width
			rect(Rect2(-length,y-3,length*2,6),RUBBER)
			if not e.get("cache_treads",false):
				for i in range(-int(length)+1,int(length),4):
					var tread := float(i)+fposmod(clock*speed*0.22,4.0)
					line(Vector2(tread,y-2.8),Vector2(tread,y+2.8),STEEL.darkened(0.35),1.6)
			for i in range(-int(length)+4,int(length)-2,7):
				ellipse(Vector2(i,y),Vector2(2,1.7),STEEL.darkened(0.16))
	var hull := [Vector2(-length+2,-width+3),Vector2(length-4,-width+3),Vector2(length,-width*0.5),Vector2(length,width*0.5),Vector2(length-4,width-3),Vector2(-length+2,width-3),Vector2(-length,width*0.5),Vector2(-length,-width*0.5)]
	var contact: Array = []
	for v in hull: contact.append(v+Vector2(2,4))
	poly(contact,Color(0.11,0.065,0.04,0.78))
	poly(hull,team.darkened(0.40))
	var roof: Array = []
	for v in hull: roof.append(v*Vector2(0.85,0.82)-Vector2(1,2))
	poly(roof,STEEL.darkened(0.15))
	if e.kind in ["tank","harvester","siege","bulwark"]:
		for sign_value in [-1,1]:
			poly([Vector2(length-6,sign_value*width*0.6),Vector2(length+1,sign_value*width*0.45),Vector2(length-1,sign_value*width*0.78),Vector2(length-8,sign_value*width*0.82)],team.darkened(0.12))
			line(Vector2(length-7,sign_value*width*0.57),Vector2(length,sign_value*width*0.42),EDGE,1.2)
	box(Rect2(-length*0.48,-width*0.6,length*0.82,width*1.2),1.5,team.darkened(0.12))
	if faction=="drift":
		# Slanted prow and asymmetric armor distinguish the mobile faction.
		poly([Vector2(length-5,-width+2),Vector2(length+7,-width*0.1),Vector2(length-2,width*0.65)],team.darkened(0.12))
		box(Rect2(-length*0.8,-width+1,length*0.6,4),3,DARK)
	elif faction=="lumen":
		ellipse(Vector2(0,-2),Vector2(length*0.6,width*0.6),team.darkened(0.15))
		for i in 3: light(Vector2(-6+i*5,-width+3),team.lightened(0.6),1)
	else:
		for side_value in [-1,1]: box(Rect2(-length*0.65,side_value*(width-4)-2,length*0.95,4),2,team)
	# Small panels, fasteners, dust and a clear rear engine give every hull a front/back.
	for i in 4:
		line(Vector2(-length+4+i*2.3,-3),Vector2(-length+4+i*2.3,3),DARK,0.9)
	for sign_value in [-1,1]:
		for i in 4:
			var q := Vector2(-length*0.65+i*length*0.4,sign_value*(width-2))
			ellipse(q,Vector2.ONE*0.7,EDGE)
			line(q+Vector2(1,1),q+Vector2(3,1),Color(0.65,0.36,0.16,0.45),0.7)
	line(Vector2(-length+3,-width+4),Vector2(length-5,-width+4),EDGE,1)
	for sign_value in [-1,1]:
		box(Rect2(-length*0.6,sign_value*(width-4)-2,length*0.8,3),1.3,team)
		light(Vector2(length-3,sign_value*(width-5)),Color("ffe5b3"),1.3)
		light(Vector2(-length+1,sign_value*(width-5)),Color("e89869"),0.7)
	vent(Rect2(-length+3,-4,7,8))
	for side_value in [-1,1]:
		var canister := Vector2(-length*0.44,side_value*(width-5))
		box(Rect2(canister-Vector2(5,1.8),Vector2(10,3.6)),2.5,Color("84745d"))
		for strap in [-1,1]: line(canister+Vector2(strap*3,-4),canister+Vector2(strap*3,1),DARK,1.2)
		line(canister-Vector2(4,3),canister+Vector2(4,-3),EDGE,0.6)
		for vent_index in 5:
			var q := Vector2(-length*0.2+vent_index*2.2,side_value*(width-6))
			line(q,q+Vector2(0,side_value*2.6),DARK,0.65)
			line(q+Vector2(0.6,0),q+Vector2(0.6,side_value*2.6),EDGE.darkened(0.2),0.45)
	# Split armor plates, access latches, braided wiring, exhaust sleeves and tow eyes.
	for sign_value in [-1,1]:
		for plate in 3:
			var q := Vector2(-length*0.55+plate*length*0.48,sign_value*(width-4))
			line(q,q+Vector2(length*0.33,-sign_value),Color(0.12,0.09,0.065,0.65),0.8)
			rect(Rect2(q+Vector2(2,-1),Vector2(2,1.5)),EDGE.darkened(0.20))
		pipe([Vector2(-length+5,sign_value*5),Vector2(-length+2,sign_value*6),Vector2(-length-2,sign_value*6)],1.2)
		for sleeve in 3: line(Vector2(-length+2-sleeve,sign_value*6-1),Vector2(-length+2-sleeve,sign_value*6+1),EDGE.darkened(0.3),0.5)
		ellipse(Vector2(length-2,sign_value*(width-3)),Vector2(1.8,1.2),DARK)
		line(Vector2(length-3,sign_value*(width-3)-1),Vector2(length,sign_value*(width-3)-1),EDGE,0.65)
	line(Vector2(-length*0.35,-width+5),Vector2(length*0.3,-width+5),Color("7e6c52"),0.75)
	for wire in 2: line(Vector2(-length*0.4,-width+6+wire),Vector2(length*0.2,-width+6+wire),Color("d6b578").darkened(wire*0.2),0.45)
	var emblem := Vector2(-length*0.15,-2)
	if e.get("owner",0)==1:
		poly([emblem+Vector2(0,-3),emblem+Vector2(3,0),emblem+Vector2(0,3),emblem+Vector2(-3,0)],EDGE)
	else:
		rect(Rect2(emblem-Vector2(2,2),Vector2(4,4)),EDGE)
	for sign_value in [-1,1]:
		line(Vector2(-length+5,sign_value*(width-2)),Vector2(-length+9,sign_value*(width-2)),EDGE,0.6)
		for i in 3:
			ellipse(Vector2(-length*0.4+i*length*0.4,sign_value*(width-3)),Vector2.ONE*0.55,EDGE)
	if e.kind=="harvester":
		box(Rect2(-16,-9,27,18),5,Color("b5a787"))
		for side_value in [-1,1]:
			box(Rect2(-length*0.75,side_value*(width-2)-2,length*1.35,4),3,team)
			line(Vector2(-length*0.7,side_value*(width-2)-5),Vector2(length*0.5,side_value*(width-2)-5),EDGE,0.8)
		for i in 6: line(Vector2(-10+i*3,-9),Vector2(-10+i*3,5),STEEL.darkened(0.3),0.9)
		var cargo: float = e.cargo/float(target.sim.db.rules.harvest_capacity)
		rect(Rect2(-10,-6,19*cargo,9),team.lightened(0.2))
		box(Rect2(10,-6,8,12),4,DARK)
		for i in 4: rect(Rect2(11+i*1.5,-8,0.8,5),Color("9dd4d4"))
		line(Vector2(17,-11),Vector2(17,11),STEEL,3)
		pipe([Vector2(-15,-5),Vector2(-15,-9),Vector2(4,-9)],1)
		for i in 6:
			var x := 18.0+sin(clock*12+i)*1.3 if e.harvest_state=="HARVEST" else 18.0
			line(Vector2(x,-10+i*4),Vector2(x+3,-10+i*4),EDGE,1.6)
		if e.harvest_state=="HARVEST":
			line(Vector2(20,0),Vector2(33+sin(clock*9)*3,0),Color("83ffeb"),2)
			for i in 5:
				var phase := fposmod(clock+i*0.19,1.0)
				ellipse(Vector2(25+phase*14,3+sin(i)*6),Vector2(2+phase*3,1+phase*2),Color(0.74,0.43,0.18,(1-phase)*0.14))
			for i in 7:
				var age := fposmod(clock*2+i*0.17,1.0)
				light(Vector2(21+age*7,-8+i*2.5),Color(team,(1-age)*0.8),0.6)
	elif e.kind=="scout":
		poly([Vector2(4,-6),Vector2(length+4,0),Vector2(4,6)],team)
		line(Vector2(5,-5),Vector2(length+3,0),EDGE,1.1)
		box(Rect2(-3,-5,11,10),3,STEEL)
		rect(Rect2(3,-6,4,8),Color("7db4c0"))
		line(Vector2(-6,4),Vector2(-9,10),EDGE,0.8)
		light(Vector2(-9,10),team,0.8)
	elif e.kind in ["raider","lancer","scorcher","bulwark"]:
		var angle: float=e.turret-e.angle
		var direction:=Vector2.from_angle(angle)
		var side:=direction.orthogonal()
		var turret:=Vector2(1,-2)
		if e.kind=="raider":
			# Twin offset repeaters and exposed flank thrusters distinguish this fast skirmisher.
			for sign_value in [-1,1]:
				var mount: Vector2=turret+side*sign_value*4
				box(Rect2(mount-direction*3-Vector2(2,2),Vector2(8,4)),2,team.darkened(0.17))
				line(mount,mount+direction*17,DARK,3.2)
				line(mount+side*0.7,mount+direction*16+side*0.7,Color("d4c7a5"),1.0)
				light(mount+direction*16,Color("ffb36f"),0.85)
				box(Rect2(Vector2(-length*0.32,sign_value*(width+1))-Vector2(4,2),Vector2(8,4)),2,team.lightened(0.06))
				line(Vector2(-length*0.30,sign_value*(width+2)),Vector2(-length*0.30,sign_value*(width+7)),Color("ffad62"),1.4)
		elif e.kind=="lancer":
			# Long crystal focusing rails and a glowing emitter sell the slow precision lance.
			box(Rect2(turret-direction*8-Vector2(6,6),Vector2(16,12)),3,Color("443b57"))
			line(turret+side*4,turret+direction*32+side*2,Color("77708a"),5)
			line(turret-side*4,turret+direction*32-side*2,Color("d6c5ff"),2.2)
			line(turret,turret+direction*37,Color("b9a7ff"),2)
			poly([turret+direction*8+side*2,turret+direction*14,turret+direction*20-side*2,turret+direction*15-side*4],Color("aa98ec"))
			light(turret+direction*29,Color("b9a7ff"),2.4)
		elif e.kind=="scorcher":
			# Twin insulated fuel lances, amber pressure gauges and a broad flame nozzle.
			box(Rect2(-length*0.36,-width*0.78,length*0.60,width*1.56),4,Color("6d4630"))
			for sign_value in [-1,1]:
				var mount: Vector2=turret+side*sign_value*5
				box(Rect2(mount-direction*4-Vector2(4,3),Vector2(10,6)),3,Color("8b5734"))
				line(mount,mount+direction*17,DARK,5)
				line(mount+side,mount+direction*16+side,Color("ff9b48"),2.0)
				pipe([Vector2(-length*0.35,sign_value*width*0.62),Vector2(-length*0.2,sign_value*width*0.7),mount+side*sign_value*4],1.4)
				light(mount+direction*17,Color("ff7838"),1.5)
		elif e.kind=="bulwark":
			# Heavy layered glacis and a short, wide siege cannon make the breach tank read as a front-line anchor.
			poly([Vector2(-length*0.55,-width*0.68),Vector2(length*0.18,-width*0.82),Vector2(length*0.48,-width*0.40),Vector2(length*0.50,width*0.40),Vector2(length*0.18,width*0.82),Vector2(-length*0.55,width*0.68)],team.darkened(0.04))
			for side_value in [-1,1]:
				box(Rect2(-length*0.48,side_value*(width*0.70)-3,length*0.88,6),3,STEEL.darkened(0.22))
				for i in 5: line(Vector2(-length*0.39+i*length*0.16,side_value*(width*0.72)-2),Vector2(-length*0.34+i*length*0.16,side_value*(width*0.72)+2),EDGE,1.4)
			box(Rect2(turret-direction*5-Vector2(8,8),Vector2(18,16)),5,STEEL.darkened(0.04))
			line(turret,turret+direction*27,DARK,9)
			line(turret+Vector2(0,-1),turret+direction*25,Color("e0c99b"),3.2)
			for side_value in [-1,1]: line(turret+side*side_value*6,turret+direction*20+side*side_value*6,team,1.5)
	else:
		var angle: float = e.turret-e.angle
		var shadow_direction := Vector2.from_angle(angle)
		ellipse(Vector2(6,7),Vector2(11,9),Color(0.10,0.055,0.03,0.42))
		line(Vector2(6,7),Vector2(6,7)+shadow_direction*(31 if e.kind=="siege" else 24),Color(0.10,0.055,0.03,0.42),5)
		var direction := Vector2.from_angle(angle)
		var side := direction.orthogonal()
		var turret := Vector2(1,-2)
		if e.has("reload"):
			var weapon: Dictionary = target.sim.db.weapons[target.sim.definition(e).weapon]
			turret-=direction*maxf(0,1-(float(weapon.reload)-float(e.reload))/0.16)*(5.5 if e.kind=="siege" else 3.5)
		ellipse(turret,Vector2(10,8),DARK)
		var gun_length := 30.0 if e.kind=="siege" else 23.0
		line(turret,turret+direction*gun_length,DARK,6)
		line(turret-side,turret-side+direction*gun_length,STEEL,3)
		line(turret+direction*(gun_length-4)-side*2,turret+direction*(gun_length-4)+side*2,STEEL.darkened(0.25),4)
		poly([turret-direction*6+side*7,turret+direction*10+side*3,turret+direction*10+side*3+Vector2(0,3),turret-direction*6+side*7+Vector2(0,3)],team.darkened(0.42))
		poly([turret-direction*7-side*6,turret+direction*8-side*5,turret+direction*10+side*3,turret-direction*6+side*7],team.darkened(0.05))
		poly([turret-direction*7-side*6,turret+direction*8-side*5,turret+direction*6-side*3,turret-direction*5-side*4],team.lightened(0.15))
		line(turret-direction*6+side*6,turret+direction*7+side*4,team,3)
		ellipse(turret-direction*3,Vector2.ONE*3,DARK)
		ellipse(turret-direction*3-Vector2(0,0.7),Vector2.ONE*2.2,EDGE)
		light(turret+side*3+direction*4,Color("a4e0d5"),0.7)
		if e.kind=="siege":
			# Long stabilizer rails and squared breech give siege a distinct heavy silhouette.
			for sign_value in [-1,1]:
				box(Rect2(-length-2,sign_value*(width+2)-2,length*1.6,4),2,DARK)
				line(Vector2(-length,sign_value*(width+2)-3),Vector2(length*0.4,sign_value*(width+2)-3),team,2)
			box(Rect2(turret-direction*9-Vector2(5,4),Vector2(10,8)),3,team.darkened(0.15))
			for sign_value in [-1,1]:
				var rack := Vector2(-7,sign_value*7)
				box(Rect2(rack-Vector2(5,2),Vector2(10,4)),2,DARK)
				for i in 3: ellipse(rack+Vector2(-3+i*3,0),Vector2.ONE*1,Color("b8ad8d"))
			line(turret+direction*9-side*3,turret+direction*17-side*3,EDGE,1)
		line(Vector2(-length+5,4),Vector2(-length+2,10),STEEL,0.7)
	if e.hp/e.max_hp<0.65:
		for i in 3:
			var age := fposmod(clock*0.8+i*0.33,1.0)
			ellipse(Vector2(-length*0.6+age*4,-age*20),Vector2.ONE*(1.5+age*4),Color(0.18,0.105,0.07,(1-age)*0.3))

	if e.hp/e.max_hp<0.35:
		var fire := Vector2(-length*0.5,-3)
		flame(fire,12+sin(clock*12)*2,float(e.get("id",0)))
		light(fire,Color("ff9e38"),1.8)
		line(Vector2(-length*0.5,2),Vector2(-length*0.1,6),Color(0.12,0.07,0.03,0.8),3)
		if sin(clock*21+e.id)>0.85:
			for i in 4: line(fire,fire+Vector2(8+i*3,-6+i*4),Color("ffe2a0"),1)


func building_shadow(e: Dictionary, w: float, h: float) -> void:
	var shape: Array = []
	var cut := 0.20 if e.kind in ["radar","tower"] else 0.11
	for v in [Vector2(-0.5+cut,-0.5),Vector2(0.5-cut,-0.5),Vector2(0.5,-0.5+cut),Vector2(0.5,0.5-cut),Vector2(0.5-cut,0.5),Vector2(-0.5+cut,0.5),Vector2(-0.5,0.5-cut),Vector2(-0.5,-0.5+cut)]:
		shape.append(v*Vector2(w,h)+Vector2(9,12))
	poly(shape,Color(0.12,0.065,0.035,0.35))
	var height: float = {"core":58.0,"power":44.0,"radar":64.0,"factory":28.0,"repair":36.0,"refinery":40.0}.get(e.kind,30.0)
	var extension := Vector2(height*0.62,height*0.4)
	if e.kind=="power":
		for sign_value in [-1,1]:
			var q := Vector2(sign_value*w*0.21,-h*0.20)
			poly([q-Vector2(8,4),q+extension-Vector2(8,4),q+extension+Vector2(10,7),q+Vector2(10,7)],Color(0.12,0.065,0.035,0.36))
	elif e.kind=="radar":
		line(Vector2(6,0),Vector2(6,0)+extension,Color(0.12,0.065,0.035,0.4),5)
		ellipse(extension,Vector2(21,10),Color(0.12,0.065,0.035,0.35))
	else:
		poly([Vector2(-w*0.23,-h*0.18),Vector2(w*0.24,-h*0.18),Vector2(w*0.24,-h*0.18)+extension,Vector2(-w*0.23,-h*0.18)+extension],Color(0.12,0.065,0.035,0.35))

func role_details(e: Dictionary, w: float, h: float, team: Color, faction: String) -> void:
	match e.kind:
		"core":
			# Tall command crown; inset team roof with a clean central command emblem.
			box(Rect2(-w*0.23,-h*0.30,w*0.41,h*0.12),30,team.darkened(0.06))
			box(Rect2(-w*0.16,-h*0.27,w*0.26,h*0.06),36,STEEL.darkened(0.08))
			for side in [-1,1]:
				pipe([Vector2(side*w*0.25,h*0.15),Vector2(side*w*0.25,-h*0.06),Vector2(side*w*0.16,-h*0.1-21)],2)
			for i in 3: rect(Rect2(-w*0.17+i*w*0.11,-h*0.28-31,w*0.07,5),EDGE)
			for side in [-1,1]:
				poly([Vector2(side*w*0.32,h*0.18),Vector2(side*w*0.43,h*0.31),Vector2(side*w*0.38,-h*0.09),Vector2(side*w*0.30,-h*0.19)],team.darkened(0.16))
		"power":
			for side in [-1,1]:
				var p := Vector2(side*w*0.23,-h*0.19-20)
				ellipse(p,Vector2(w*0.14,h*0.09),DARK)
				ellipse(p-Vector2(0,3),Vector2(w*0.12,h*0.08),team.darkened(0.12))
				for i in 4: line(p+Vector2(-w*0.09+i*w*0.06,-5),p+Vector2(-w*0.09+i*w*0.06,1),EDGE,0.8)
				for i in 3:
					var phase := fposmod(clock*0.4+i*0.3,1)
					line(p+Vector2(-4+sin(clock*3+i)*2,-7-phase*23),p+Vector2(5+sin(clock*3+i+1)*2,-9-phase*23),Color(1,0.82,0.52,(1-phase)*0.14),0.8)
		"refinery":
			for i in 3:
				var p := Vector2(-w*0.3+i*w*0.29,-h*0.1-15)
				ellipse(p,Vector2(w*0.107,6),team.darkened(0.10))
				ellipse(p-Vector2(2,1),Vector2(w*0.072,3),STEEL.lightened(0.2))
				line(p+Vector2(-w*0.09,3),p+Vector2(w*0.09,3),EDGE,0.8)
				if int(e.get("upgrade_level",0))>0:
					line(p+Vector2(-w*0.06,-2),p+Vector2(w*0.06,-2),Color("ffd18a"),1.4)
					light(p,Color("ffd18a"),0.65)
			pipe([Vector2(w*0.30,-h*0.32),Vector2(w*0.30,-h*0.32-34),Vector2(w*0.20,-h*0.32-34)],3)
			if int(e.get("upgrade_level",0))>0: box(Rect2(-w*0.42,-h*0.34,w*0.12,6),2,Color("eac174"))
		"factory":
			for i in 4:
				var y := -h*0.28+i*h*0.12
				poly([Vector2(-w*0.32,y-20),Vector2(w*0.29,y-20),Vector2(w*0.29,y+h*0.06-23),Vector2(-w*0.32,y+h*0.06-23)],team.darkened(0.1))
				line(Vector2(-w*0.32,y-20),Vector2(w*0.29,y-20),EDGE,1)
			box(Rect2(-w*0.26,h*0.015,w*0.52,h*0.05),15,team)
			if int(e.get("upgrade_level",0))>0:
				for i in 3:
					var retrofit:=Vector2(-w*0.22+i*w*0.22,-h*0.39)
					box(Rect2(retrofit-Vector2(4,3),Vector2(8,6)),3,Color("eac174"))
					light(retrofit,Color("ffb267"),0.75)
			var active: bool = not e.get("queue",[]).is_empty()
			if active:
				light(Vector2(0,h*0.12-6),Color("ffd293"),3+sin(clock*5))
		"armory":
			# A distinct retrofit hall: modular armor racks around an active test cradle.
			box(Rect2(-w*0.31,-h*0.29,w*0.62,h*0.43),7,STEEL.darkened(0.26))
			for side in [-1,1]:
				var x: float=side*w*0.25
				box(Rect2(x-5,-h*0.32,10,h*0.48),4,team.darkened(0.13))
				for rack in 4:
					line(Vector2(x-4,-h*0.26+rack*8),Vector2(x+4,-h*0.26+rack*8),EDGE,1.3)
					light(Vector2(x,-h*0.26+rack*8),Color(team,0.34+sin(clock*2+rack)*0.12),0.75)
			box(Rect2(-w*0.12,-h*0.18,w*0.24,h*0.29),4,DARK)
			line(Vector2(-w*0.10,-h*0.08),Vector2(w*0.10,-h*0.08),Color("b9a7ff"),2.5)
			var level:=int(e.get("upgrade_level",0))
			for i in 2:
				var lit: bool=i<level or (e.get("upgrading",false) and i<int(e.get("upgrade_target",0)) and fposmod(clock*2,1.0)>0.4)
				box(Rect2(-w*0.08+i*w*0.16,-h*0.40, w*0.10,5),1,Color("b9a7ff") if lit else DARK)
		"radar":
			ellipse(Vector2(6,-34),Vector2(21,10),team.darkened(0.08))
			ellipse(Vector2(6,-35),Vector2(16,7),STEEL.lightened(0.15))
			for i in 8: line(Vector2(6,-35),Vector2(6,-35)+Vector2.from_angle((clock if machinery_running else 0.0)*0.5+i*TAU/8)*Vector2(18,8),DARK,0.6)
			line(Vector2(6,-35),Vector2(6,-51),EDGE,1.6)
			light(Vector2(6,-51),team.lightened(0.4),1.5)
			if int(e.get("upgrade_level",0))>0:
				for radius in [24.0,31.0]:
					var phase:=fposmod(clock*0.22+radius*0.03,1.0)
					var center:=Vector2(6,-35)
					var orbit:=Vector2(radius*(0.75+phase*0.25),radius*0.38)
					for i in 12:
						var start_angle:=float(i)*TAU/12.0
						var end_angle:=start_angle+TAU/24.0
						line(center+Vector2(cos(start_angle)*orbit.x,sin(start_angle)*orbit.y),center+Vector2(cos(end_angle)*orbit.x,sin(end_angle)*orbit.y),Color(team,0.12*(1.0-phase)),0.9)
		"repair":
			line(Vector2(-w*0.36,-h*0.24-27),Vector2(w*0.36,-h*0.24-27),team,4)
			hazard(Vector2(-w*0.36,-h*0.24-25),w*0.72)
			for side in [-1,1]: line(Vector2(side*w*0.36,-h*0.24-27),Vector2(side*w*0.36,h*0.3),DARK,3)
		"tower":
			for side in [-1,1]:
				poly([Vector2(side*8,0),Vector2(side*15,8),Vector2(side*12,-16),Vector2(side*6,-21)],team.darkened(0.12))
	# Faction morphology is independent of owner colors.
	if faction=="drift":
		for side in [-1,1]:
			poly([Vector2(side*w*0.39,-h*0.26),Vector2(side*w*0.51,-h*0.46-8),Vector2(side*w*0.46,h*0.12)],team.darkened(0.22))
	elif faction=="forge":
		for side in [-1,1]: box(Rect2(side*w*0.36-4,h*0.10,8,h*0.18),5,team.darkened(0.13))
