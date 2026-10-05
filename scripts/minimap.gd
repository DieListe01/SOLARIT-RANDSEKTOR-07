extends Control
class_name TacticalMap
signal navigate(point: Vector2)
var sim: Simulation
var camera := Vector2.ZERO
var world_view := Vector2(1560,960)
var timer := 0.0
var elapsed := 0.0
var pings: Array[Dictionary] = []
var terrain_texture: ImageTexture
var terrain_image: Image
var terrain_grid: WorldGrid

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func ping(pos: Vector2, color: Color) -> void:
	pings.append({"pos":pos,"color":color,"life":3.0})
	while pings.size()>12: pings.pop_front()

func _process(dt: float) -> void:
	elapsed+=dt
	for item in pings: item.life-=dt
	pings=pings.filter(func(item):return item.life>0)
	timer-=dt
	if timer<=0:
		_refresh_terrain_texture()
		queue_redraw(); timer=0.2

func _refresh_terrain_texture() -> void:
	if sim==null: return
	var g:=sim.grid
	if terrain_image==null or terrain_grid!=g:
		terrain_grid=g
		terrain_image=Image.create(g.width,g.height,false,Image.FORMAT_RGBA8)
		terrain_texture=ImageTexture.create_from_image(terrain_image)
	var radar:=false
	if sim.powered(sim.view_owner):
		for building_id in sim.building_ids:
			if not sim.entities.has(building_id): continue
			var building: Dictionary=sim.entities[building_id]
			if building.owner==sim.view_owner and building.kind=="radar" and building.complete:
				radar=true; break
	var background:=Color("211914")
	for y in g.height:
		for x in g.width:
			var index:=y*g.width+x
			var color:=background
			if sim.explored[sim.view_owner][index]>0:
				color=WorldGrid.COLORS[g.terrain[index]]
				if not radar: color=color.darkened(0.65)
				elif sim.fog[sim.view_owner][index]==0: color=color.darkened(0.5)
				if g.terrain[index]==3 and float(g.resources.get(g.key(Vector2i(x,y)),0))>0:
					var alpha:=0.65 if radar else 0.3
					var solarit:=Color(0.30,0.65,0.59)
					color=Color(solarit.r*alpha+color.r*(1.0-alpha),solarit.g*alpha+color.g*(1.0-alpha),solarit.b*alpha+color.b*(1.0-alpha),1.0)
			terrain_image.set_pixel(x,y,color)
	if terrain_texture==null or terrain_texture.get_width()!=g.width or terrain_texture.get_height()!=g.height:
		terrain_texture=ImageTexture.create_from_image(terrain_image)
	else:
		terrain_texture.update(terrain_image)

func _gui_input(event: InputEvent) -> void:
	if sim==null: return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		navigate.emit(event.position/size*Vector2(sim.grid.width,sim.grid.height)*sim.grid.tile)
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("211914"))
	if sim==null: return
	var g := sim.grid
	var radar := false
	if sim.powered(sim.view_owner):
		for building_id in sim.building_ids:
			if not sim.entities.has(building_id): continue
			var building: Dictionary=sim.entities[building_id]
			if building.owner==sim.view_owner and building.kind=="radar" and building.complete:
				radar=true; break
	var scale_value := size/Vector2(g.width,g.height)
	if terrain_texture!=null: draw_texture_rect(terrain_texture,Rect2(Vector2.ZERO,size),false)
	for e in sim.entities.values():
		if e.owner!=sim.view_owner and (not radar or not sim.is_visible(e,sim.view_owner)): continue
		var p: Vector2 = e.pos/(Vector2(g.width,g.height)*g.tile)*size
		var color := sim.team_color(e.owner)
		draw_rect(Rect2(p-Vector2.ONE*3,Vector2.ONE*6),Color(0.08,0.045,0.025,0.82))
		if e.owner!=sim.view_owner:
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-3),p+Vector2(3,0),p+Vector2(0,3),p+Vector2(-3,0)]),color)
		else:
			draw_rect(Rect2(p-Vector2.ONE*2,Vector2.ONE*(5 if e.building else 3)),color)
	var map_size := Vector2(g.width,g.height)*g.tile
	draw_rect(Rect2((camera-world_view*0.5)/map_size*size,world_view/map_size*size),Color("f0d6a2"),false,1)
	if radar:
		var y := fposmod(elapsed*size.y*0.25,size.y)
		draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.2,0.9,0.8,0.14),2,true)
	for item in pings:
		var p: Vector2 = item.pos/map_size*size
		var phase := fposmod(3-item.life,1.0)
		draw_arc(p,4+phase*15,0,TAU,32,Color(item.color,1-phase),2,true)
		draw_line(p-Vector2(4,0),p+Vector2(4,0),item.color,1,true)
		draw_line(p-Vector2(0,4),p+Vector2(0,4),item.color,1,true)
	draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color("ae8453"),false,2)
	for corner in [Vector2(1,1),Vector2(size.x-10,1),Vector2(1,size.y-3),Vector2(size.x-10,size.y-3)]:
		draw_line(corner,corner+Vector2(9,0),Color("f0c77e"),2,true)
