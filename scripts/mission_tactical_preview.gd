class_name MissionTacticalPreview
extends Control

const INK := Color("101917")
const TERRAIN_COLORS := [Color("93653e"),Color("56584e"),Color("b1804a"),Color("7bd8c3"),Color("807764"),Color("49433c"),Color("292b29")]
const MINT := Color("74d7b5")
const GOLD := Color("e8b963")
const FOE := Color("e06d4e")

var mission_data: Dictionary = {}
var elapsed := 0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	set_process(true)

func _process(delta: float) -> void:
	elapsed+=delta
	queue_redraw()

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO,size)
	draw_rect(bounds,Color("0a1417"))
	# Quiet technical underlay gives the tactical panel depth without obscuring terrain.
	for i in range(0,int(size.x),24):
		draw_line(Vector2(i,0),Vector2(i,size.y),Color(0.82,0.88,0.78,0.025),1.0)
	for i in range(0,int(size.y),24):
		draw_line(Vector2(0,i),Vector2(size.x,i),Color(0.82,0.88,0.78,0.025),1.0)
	var w:=size.x
	var h:=size.y
	var map_width:=maxi(1,int(mission_data.get("width",64)))
	var map_height:=maxi(1,int(mission_data.get("height",64)))
	var tile_w:=w/float(map_width)
	var tile_h:=h/float(map_height)
	var terrain:=PackedInt32Array()
	terrain.resize(map_width*map_height)
	terrain.fill(0)
	var terrain_types: Dictionary={"sand":0,"rock":1,"dunes":2,"resource":3,"hard_ground":4,"crater":5,"cliff":6}
	for region_variant in mission_data.get("terrain_regions",[]):
		var region: Dictionary=region_variant
		var rect: Array=region.get("rect",[])
		if rect.size()<4: continue
		var type_index:=int(terrain_types.get(str(region.get("type","sand")),0))
		for y_cell in range(maxi(0,int(rect[1])),mini(map_height,int(rect[1])+int(rect[3]))):
			for x_cell in range(maxi(0,int(rect[0])),mini(map_width,int(rect[0])+int(rect[2]))): terrain[y_cell*map_width+x_cell]=type_index
	for y_cell in range(map_height):
		for x_cell in range(map_width):
			var color_index:=terrain[y_cell*map_width+x_cell]
			draw_rect(Rect2(x_cell*tile_w,y_cell*tile_h,tile_w+0.35,tile_h+0.35),TERRAIN_COLORS[color_index])
	# Resource fields use the authored mission coordinates and radii.
	for patch_variant in mission_data.get("resources",[]):
		var patch: Dictionary=patch_variant
		var cell: Array=patch.get("cell",[])
		if cell.size()<2: continue
		var center:=Vector2((float(cell[0])+0.5)*tile_w,(float(cell[1])+0.5)*tile_h)
		var radius:=maxf(3.0,float(patch.get("radius",2))*minf(tile_w,tile_h))
		draw_circle(center,radius,Color("48d5bd",0.13))
		draw_arc(center,radius,0,TAU,32,Color("81e7d1",0.42),1.0)
		draw_circle(center,radius*0.48,Color("81e7d1",0.20))
	# Coordinates mirror the map grid for quick orientation without obscuring terrain.
	for i in range(1,8):
		draw_line(Vector2(w*float(i)/8.0,0),Vector2(w*float(i)/8.0,h),Color(0.9,0.84,0.69,0.08),0.8)
		draw_line(Vector2(0,h*float(i)/8.0),Vector2(w,h*float(i)/8.0),Color(0.9,0.84,0.69,0.08),0.8)
	var starts: Array=mission_data.get("player_starts",[])
	var friendly:=Vector2.ZERO
	if not starts.is_empty() and starts[0] is Array and starts[0].size()>=2:
		friendly=Vector2((float(starts[0][0])+0.5)*tile_w,(float(starts[0][1])+0.5)*tile_h)
	var target:=friendly
	var target_found:=false
	for objective_variant in mission_data.get("objectives",[]):
		var objective: Dictionary=objective_variant
		if not bool(objective.get("primary",false)): continue
		var owner:=int(objective.get("owner",1))
		var source: Array=mission_data.get("structures",[])
		for structure_variant in source:
			var structure: Dictionary=structure_variant
			var cell: Array=structure.get("cell",[])
			if int(structure.get("owner",-1))==owner and str(structure.get("kind",""))==str(objective.get("kind","core")) and cell.size()>=2:
				target=Vector2((float(cell[0])+0.5)*tile_w,(float(cell[1])+0.5)*tile_h)
				target_found=true
				break
		if target_found: break
	if not target_found and starts.size()>1 and starts[1] is Array and starts[1].size()>=2:
		target=Vector2((float(starts[1][0])+0.5)*tile_w,(float(starts[1][1])+0.5)*tile_h)
	draw_line(friendly,target,Color(MINT,0.52),1.4)
	for dash in range(1,12):
		var point:=friendly.lerp(target,float(dash)/12.0)
		if dash%2==0: draw_circle(point,1.1,Color(0.72,0.9,0.77,0.6))
	# Enemy structures and known units are shown at their authored map positions.
	for structure_variant in mission_data.get("structures",[]):
		var structure: Dictionary=structure_variant
		if int(structure.get("owner",0))==0: continue
		var cell: Array=structure.get("cell",[])
		if cell.size()<2: continue
		var point:=Vector2((float(cell[0])+0.5)*tile_w,(float(cell[1])+0.5)*tile_h)
		var marker_size:=Vector2(maxf(3.0,tile_w*1.2),maxf(3.0,tile_h*1.5))
		draw_rect(Rect2(point-marker_size*0.5,marker_size),FOE if str(structure.get("kind",""))=="core" else Color("c27b5a"))
	for unit_variant in mission_data.get("units",[]):
		var unit: Dictionary=unit_variant
		if int(unit.get("owner",0))==0: continue
		var cell: Array=unit.get("cell",[])
		if cell.size()<2: continue
		draw_circle(Vector2((float(cell[0])+0.5)*tile_w,(float(cell[1])+0.5)*tile_h),maxf(2.3,minf(tile_w,tile_h)*0.65),FOE)
	var pulse:=0.5+0.5*sin(elapsed*2.0)
	draw_arc(friendly,8.0+pulse*3.0,0,TAU,32,Color(MINT,0.52-pulse*0.18),1.2)
	draw_circle(friendly,7.0,Color(INK,0.82)); draw_circle(friendly,4.5,MINT)
	draw_arc(target,10.0+pulse*4.0,0,TAU,32,Color(GOLD,0.48-pulse*0.16),1.4)
	draw_circle(target,8.0,Color(GOLD,0.14)); draw_circle(target,4.0,GOLD)
	# Slow scan sweep and corner brackets animate the live tactical picture.
	var scan_x:=fposmod(elapsed*45.0,size.x)
	draw_rect(Rect2(scan_x-18,0,36,size.y),Color(MINT.r,MINT.g,MINT.b,0.035))
	draw_line(Vector2(scan_x,0),Vector2(scan_x,size.y),Color(MINT.r,MINT.g,MINT.b,0.16),1.0)
	var corner:=Color("d8b36f",0.75)
	for point in [Vector2(7,7),Vector2(size.x-7,7),Vector2(7,size.y-7),Vector2(size.x-7,size.y-7)]:
		var sx:=1.0 if point.x< size.x*0.5 else -1.0
		var sy:=1.0 if point.y< size.y*0.5 else -1.0
		draw_line(point,point+Vector2(sx*13,0),corner,1.4)
		draw_line(point,point+Vector2(0,sy*13),corner,1.4)
	draw_rect(bounds,Color("b39461",0.62),false,1.0)
