extends Control
class_name FrontendBackdrop

signal completed
var intro := false
var elapsed := 0.0
var duration := 15.0
var finished := false
const SAND = Color("c49a65")
const LIGHT = Color("9cdcc5")
const DARK = Color("2a201b")
var font: Font

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=ThemeDB.fallback_font

func _process(dt: float) -> void:
	elapsed+=dt
	queue_redraw()
	if intro and elapsed>=duration and not finished:
		finished=true
		completed.emit()

func opacity(start: float, end: float, fade: float = 0.7) -> float:
	return clampf((elapsed-start)/fade,0,1)*clampf((end-elapsed)/fade,0,1)

func centered(text_value: String, center_x: float, baseline: float, point_size: int, color: Color) -> void:
	var extent := font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size)
	draw_string(font,Vector2(center_x-extent.x*0.5,baseline),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,color)

func _draw() -> void:
	if font==null: return
	var reveal := smoothstep(0.9,4.8,elapsed) if intro else 1.0
	# All artwork is drawn in the same logical coordinates in both render modes.
	for i in 54:
		var t := float(i)/53.0
		var color := Color("1b151c").lerp(Color("6f6256"),pow(t,2.5))
		draw_rect(Rect2(0,i*20,1920,21),color)
	for i in 100:
		var p := Vector2(31+(i*179)%1850,53+(i*97)%590)
		var glow := 0.25+0.3*(0.5+0.5*sin(elapsed*0.5+i*2.1))
		draw_rect(Rect2(p,Vector2.ONE*(2 if i%9 else 3)),Color(0.8,0.88,0.8,glow))
	var planet := Vector2(1442,245)
	for i in range(8,0,-1): paint_circle(planet,185+i*3,Color(0.93,0.71,0.4,0.011))
	paint_circle(planet,185,Color("bea17c"))
	for i in range(-176,177,8):
		var half_width := sqrt(185.0*185.0-float(i*i))
		var color := Color("bea17c").lerp(Color("d9bf8d"),0.5+0.3*sin(i*0.036))
		draw_line(planet+Vector2(-half_width,i),planet+Vector2(half_width,i),color,8)
	paint_circle(planet-Vector2(72,33),174,Color("2e2228"))
	draw_arc(planet,190,-0.9,1.6,90,Color(0.97,0.81,0.55,0.38),2)
	# A distant orbital beacon slowly travels over the basin.
	var beacon := Vector2(1100+sin(elapsed*0.06)*230,150+cos(elapsed*0.06)*48)
	draw_line(beacon-Vector2(15,0),beacon+Vector2(15,0),Color("769492"),2)
	draw_line(beacon-Vector2(0,5),beacon+Vector2(0,5),LIGHT,2)
	for layer in 4:
		var ridge := PackedVector2Array([Vector2(-50,1100)])
		for x in range(-50,2001,64):
			var y := 550+layer*92+sin(x*0.005+layer*1.7)*64+sin(x*0.013+layer)*32
			ridge.append(Vector2(x+sin(elapsed*0.04)*layer*4,y))
		ridge.append(Vector2(2000,1100))
		var colors := [Color("46352c"),Color("66503b"),Color("8a6747"),Color("ad793e")]
		smooth_polygon(ridge,colors[layer])
		if layer<3:
			for j in range(1,ridge.size()-2):
				draw_line(ridge[j]+Vector2(0,3),ridge[j+1]+Vector2(0,3),colors[layer].lightened(0.12),2)
	# Lit industrial outpost on the ridge. No existing franchise silhouettes.
	for i in 95:
		var x := 880.0+(i*97)%1040
		var y := 710.0+(i*53)%260
		var contour := PackedVector2Array()
		for j in 9: contour.append(Vector2(x+j*7,y+sin(j*0.35+i)*3))
		draw_polyline(contour,Color(0.9,0.76,0.52,0.07),1,true)
	draw_colony(Vector2(1340,628),0.92)
	for i in 22:
		var p := Vector2(1010+(i*83)%765,792+(i*47)%144)
		var height_value := 8+float((i*13)%19)
		smooth_polygon(PackedVector2Array([p+Vector2(-6,5),p+Vector2(-4,-height_value),p+Vector2(3,-height_value-5),p+Vector2(8,0)]),Color("6dada0"))
		draw_line(p+Vector2(2,-height_value),p+Vector2(3,-4),LIGHT,2)
		if i%4==0: paint_circle(p+Vector2(1,-height_value),3,Color(0.63,0.95,0.81,0.35+sin(elapsed*2+i)*0.15))
	# Foreground heavy survey vehicle, with separate hull, tracks and turret.
	draw_crawler(Vector2(1415,913),1.1)
	for i in 48:
		var x := fposmod(i*137.0+elapsed*(18+i%5*4),2070)-80
		var y := 730+(i*79)%333
		draw_line(Vector2(x,y),Vector2(x+12+i%6*4,y-2),Color(0.85,0.72,0.49,0.08),1)
	if intro:
		var landing := smoothstep(4.5,9.0,elapsed)
		if elapsed>4.5 and elapsed<10.3:
			draw_lander(Vector2(1800,170).lerp(Vector2(1460,596),landing),1.0-landing*0.45,opacity(4.5,10.3))
		# Gradual reveal and letterboxing make the sequence readable and skippable.
		draw_rect(Rect2(0,0,1920,1080),Color(0.025,0.055,0.075,1-reveal))
		draw_rect(Rect2(0,0,1920,94),Color("08131b"))
		draw_rect(Rect2(0,916,1920,164),Color("08131b"))
		var a := opacity(0.25,3.0)
		centered("ASHLINE",960,465,84,Color(SAND,a))
		centered("EIN SIGNAL AUS DER ASCHE",960,521,21,Color(LIGHT,a))
		a=opacity(3.0,6.8)
		centered("VEYRA",960,230,49,Color(SAND,a))
		centered("Randsektor 07  /  2186",960,272,21,Color(LIGHT,a))
		a=opacity(4.0,8.2)
		centered("Unter der Asche schläft die Energie einer verlorenen Sonne.",960,988,27,Color("d8dfcf",a))
		a=opacity(8.0,11.5)
		centered("Drei Bündnisse. Ein Becken. Deine erste Kolonie.",960,988,27,Color("d8dfcf",a))
		a=smoothstep(10.4,12.6,elapsed)
		draw_rect(Rect2(0,320,1920,205),Color(0.025,0.06,0.075,a*0.65))
		centered("ASHLINE",960,450,117,Color(SAND,a))
		centered("DAS VEYRA-BECKEN",960,500,26,Color(LIGHT,a))
		a=opacity(11.5,15.0)
		centered("Errichte deine Basis. Sichere das Solarit. Halte die Aschegrenze.",960,988,26,Color("d8dfcf",a))
		draw_line(Vector2(720,1037),Vector2(720+480*clampf(elapsed/duration,0,1),1037),Color(SAND,0.4),2)
	else:
		# Readability gradient for the menu, while preserving the uninterrupted vista.
		for i in 48: draw_rect(Rect2(i*20,0,20,1080),Color(0.025,0.055,0.073,0.91*pow(1-float(i)/48.0,0.48)))
		draw_rect(Rect2(0,1000,1920,80),Color(0.025,0.055,0.073,0.7))

func draw_colony(p: Vector2, scale_value: float) -> void:
	draw_set_transform(p,0,Vector2.ONE*scale_value)
	smooth_polygon(PackedVector2Array([Vector2(-260,75),Vector2(100,16),Vector2(295,82),Vector2(-92,155)]),Color("49574d"))
	for i in 7: draw_line(Vector2(-226+i*63,78),Vector2(-90+i*48,119),Color("637265"),1)
	for i in 3:
		var x := -151+i*46
		draw_rect(Rect2(x,10,33,80),DARK)
		draw_rect(Rect2(x+4,14,25,69),Color("617c73"))
		paint_ellipse(Rect2(x,0,33,22),Color("91a08a"))
		draw_rect(Rect2(x+5,66,23,5),LIGHT)
	draw_rect(Rect2(-6,-30,130,121),DARK)
	smooth_polygon(PackedVector2Array([Vector2(-16,-29),Vector2(72,-61),Vector2(141,-30),Vector2(39,1)]),Color("849385"))
	smooth_polygon(PackedVector2Array([Vector2(39,1),Vector2(141,-30),Vector2(141,77),Vector2(39,110)]),Color("31494b"))
	draw_rect(Rect2(1,-20,29,90),Color("415b58"))
	for i in 5: draw_rect(Rect2(5,-10+i*15,17,5),Color("9cdcc5") if i%2==0 else Color("689e8d"))
	for i in 4: draw_line(Vector2(55,20+i*17),Vector2(121,-1+i*17),Color("70877b"),3)
	smooth_polygon(PackedVector2Array([Vector2(60,53),Vector2(104,39),Vector2(104,89),Vector2(60,102)]),Color("102329"))
	draw_line(Vector2(60,57),Vector2(104,43),LIGHT,4)
	draw_line(Vector2(157,41),Vector2(157,-134),Color("61796f"),5)
	draw_line(Vector2(152,-30),Vector2(172,-94),Color("61796f"),2)
	var dish := Vector2(157,-126)
	draw_arc(dish,31,-0.3+sin(elapsed*0.15)*0.2,2.8+sin(elapsed*0.15)*0.2,20,Color("b2b697"),5)
	paint_circle(dish,4,LIGHT)
	if fmod(elapsed,3.0)<0.5: paint_circle(Vector2(157,-155),3,Color("dbb47b"))
	for i in 3:
		draw_rect(Rect2(187+i*20,46-i*5,15,35),DARK)
		draw_rect(Rect2(190+i*20,49-i*5,8,15),LIGHT.darkened(0.3))
	for i in 5:
		var smoke := Vector2(-83+sin(elapsed*0.3+i)*9,-15-i*13-fmod(elapsed*5,13))
		paint_circle(smoke,7+i*2,Color(0.53,0.56,0.51,0.06))
	for i in 3:
		var x := -151+i*46
		for y in range(20,64,9): draw_line(Vector2(x+5,y),Vector2(x+28,y),Color("415c59"),1,true)
		draw_line(Vector2(x+10,17),Vector2(x+10,62),Color("c0c5ab"),1,true)
		paint_circle(Vector2(x+17,12),4,DARK,true,-1,true)
		draw_line(Vector2(x+17,83),Vector2(x+17,98),Color("b1aa8a"),4,true)
	draw_line(Vector2(-134,98),Vector2(12,98),Color("b1aa8a"),3,true)
	for i in 8:
		var q := Vector2(48+i*11,-2-i*3.3)
		draw_line(q,q+Vector2(0,92),Color(0.6,0.7,0.6,0.14),1,true)
	for i in 7:
		var q := Vector2(67+i*9,63-i*3)
		draw_line(q,q+Vector2(0,28),Color("425a59"),1,true)
	for i in 12:
		var q := Vector2(-208+i*36,91+sin(i)*8)
		draw_line(q,q+Vector2(0,-8),Color("b5bc9c"),2,true)
		paint_circle(q+Vector2(0,-9),2,LIGHT,true,-1,true)
	for i in 5:
		var q := Vector2(5+i*18,-28-i*5)
		draw_rect(Rect2(q,Vector2(12,7)),DARK)
		draw_line(q+Vector2(2,2),q+Vector2(10,2),Color("b9c4a9"),1,true)
	draw_set_transform(Vector2.ZERO)

func paint_ellipse(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32: points.append(rect.get_center()+Vector2(cos(i*TAU/32),sin(i*TAU/32))*rect.size*0.5)
	smooth_polygon(points,color)

func draw_crawler(p: Vector2, scale_value: float) -> void:
	draw_set_transform(p,-0.15,Vector2.ONE*scale_value)
	paint_ellipse(Rect2(-143,-9,292,81),Color(0.05,0.09,0.09,0.35))
	for y in [-32,31]:
		draw_rect(Rect2(-122,y,244,29),Color("102329"))
		for i in 17: draw_line(Vector2(-112+i*14,y+3),Vector2(-116+i*14,y+24),Color("425751"),4)
	smooth_polygon(PackedVector2Array([Vector2(-118,-17),Vector2(95,-28),Vector2(126,0),Vector2(104,37),Vector2(-103,49)]),Color("34534f"))
	smooth_polygon(PackedVector2Array([Vector2(-118,-17),Vector2(-95,-42),Vector2(84,-51),Vector2(95,-28)]),Color("759182"))
	smooth_polygon(PackedVector2Array([Vector2(-95,-29),Vector2(76,-39),Vector2(95,-10),Vector2(-78,1)]),Color("59786b"))
	for i in 6: draw_line(Vector2(-90+i*12,-24),Vector2(-85+i*12,-5),Color("213d3d"),5)
	smooth_polygon(PackedVector2Array([Vector2(-10,-26),Vector2(23,-47),Vector2(63,-47),Vector2(78,-23),Vector2(59,-4),Vector2(10,-4)]),Color("92a38c"))
	draw_line(Vector2(49,-25),Vector2(145,-62),Color("1c3438"),12)
	draw_line(Vector2(49,-30),Vector2(145,-67),Color("b9bfa2"),7)
	draw_rect(Rect2(-68,5,58,7),Color("6cbba1"))
	paint_circle(Vector2(95,8),4,Color("e8cb8d"))
	paint_circle(Vector2(112,6),4,Color("e8cb8d"))
	draw_line(Vector2(-19,-42),Vector2(-23,-95),Color("65857c"),2)
	for i in 13:
		var q := Vector2(-100+i*17,32)
		paint_circle(q,8,Color("718576"),true,-1,true)
		paint_circle(q,4,DARK,true,-1,true)
		paint_circle(q,1.5,Color("b8bda1"),true,-1,true)
	for i in 10:
		var q := Vector2(-88+i*19,-34)
		paint_circle(q,1.8,Color("c0c5a9"),true,-1,true)
	for i in 5: draw_line(Vector2(-83+i*30,8),Vector2(-74+i*30,31),Color("203e3e"),1,true)
	draw_line(Vector2(16,-26),Vector2(55,-31),Color("d2ccb0"),1.5,true)
	draw_rect(Rect2(22,-21,23,8),Color("283f43"))
	for i in 4: draw_line(Vector2(24+i*5,-20),Vector2(24+i*5,-14),Color("89bfba"),1,true)
	draw_line(Vector2(133,-60),Vector2(149,-66),DARK,12,true)
	for i in 3: draw_line(Vector2(136+i*4,-66),Vector2(140+i*4,-57),Color("718a7c"),1,true)
	draw_set_transform(Vector2.ZERO)

func draw_lander(p: Vector2, scale_value: float, alpha: float) -> void:
	draw_set_transform(p,-0.12,Vector2.ONE*scale_value)
	for x in [-45,45]:
		smooth_polygon(PackedVector2Array([Vector2(x-10,15),Vector2(x,65+sin(elapsed*37)*8),Vector2(x+10,15)]),Color(0.95,0.76,0.46,alpha*0.7))
		draw_line(Vector2(x,15),Vector2(x,35),Color(LIGHT,alpha),7)
	smooth_polygon(PackedVector2Array([Vector2(-78,0),Vector2(-44,-18),Vector2(-15,-53),Vector2(31,-51),Vector2(52,-16),Vector2(87,3),Vector2(72,23),Vector2(-66,24)]),Color("82968a",alpha))
	smooth_polygon(PackedVector2Array([Vector2(-17,-34),Vector2(26,-36),Vector2(36,-15),Vector2(-27,-12)]),Color("213a40",alpha))
	draw_line(Vector2(-70,4),Vector2(72,4),Color(LIGHT,alpha),3)
	draw_set_transform(Vector2.ZERO)

func smooth_polygon(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points,color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline,color,0.7,true)

func paint_circle(center: Vector2, radius: float, color: Color, filled: bool = true, point_count: int = -1, antialiased: bool = true) -> void:
	draw_circle(center,radius,color,filled,point_count,antialiased)
