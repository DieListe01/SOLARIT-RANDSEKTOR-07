extends SceneTree

var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("BATTLEFIELD FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var terrain_shader := FileAccess.get_file_as_string("res://assets/terrain.gdshader")
	check(terrain_shader.contains("terrain_cell=(world+warp*1.38*27.0)/32.0") and terrain_shader.contains("kind_at(TEXTURE,world,warp*1.38)") and terrain_shader.contains("world+vec2(0,7),warp*1.38") and terrain_shader.contains("world-vec2(0,5),warp*1.38"),"Terrain material sampling, edge mask and relief probes share the same domain warp")
	var db := Catalog.new()
	for count in [1,5,10,20,40]:
		var model := Simulation.new(db)
		model.entities.clear()
		var ids: Array = []
		for i in count:
			ids.append(model.spawn(["scout","tank","harvester","siege"][i%4],0,Vector2(500+i*2,1400),false))
		model.command(ids,Vector2(550,1550))
		var destinations: Dictionary = {}
		for id in ids:
			var cell := model.grid.cell(model.entities[id].destination)
			check(not destinations.has(cell),"Unique target cell for group of %d"%count)
			destinations[cell]=true
		check(model.path_requests.size()==count,"Every mobile retains path request")
		if count==1: check(model.entities[ids[0]].destination==Vector2(550,1550),"Single move destination unchanged")
		model.command(ids,Vector2.ZERO,"hold")
		for frame in 240:
			model.rebuild_movement_buckets()
			for id in ids: model.move_unit(model.entities[id],1.0/30.0)
		var minimum := INF
		for i in ids.size():
			for j in range(i+1,ids.size()): minimum=minf(minimum,model.entities[ids[i]].pos.distance_to(model.entities[ids[j]].pos))
		if count>1: check(minimum>18,"Coincident crowd resolves without paths: %d / %.1f"%[count,minimum])
		check(model.unit_radius("harvester")>model.unit_radius("scout"),"Collector uses larger spacing")
	var steering_model:=Simulation.new(db)
	var steering_id:int=steering_model.spawn("tank",0,Vector2(640,1400),false)
	var steering_unit:Dictionary=steering_model.entities[steering_id]
	steering_unit.path=[steering_unit.pos+Vector2(160,0)]
	steering_unit.velocity=Vector2(0,100)
	steering_unit.angle=0.0
	steering_model.rebuild_movement_buckets()
	steering_model.move_unit(steering_unit,1.0/30.0)
	check(steering_unit.angle>0.02,"Vehicle body turns toward its actual diagonal drift while steering onto a new path")
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.skip_intro(); game.set_classic(false); game.start_game(); game.paused=true
	game.sim.ai_timer=99999
	game.renderer.camera=Vector2(680,1430); game.renderer.zoom=1.55
	var hover_id: int = game.sim.spawn("tank",0,game.renderer.camera,false)
	game.paused=false
	await process_frame
	check(game.show_world_entity_hover(hover_id,Vector2(300,300)),"Live entity hover displays text with its panel")
	check(game.hover_label.text.contains("Panzer") and game.hover_panel.visible,"Entity hover contains readable name and panel")
	check(not game.show_world_entity_hover(-999,Vector2(300,300)) and not game.hover_panel.visible and game.hover_label.text.is_empty(),"Stale or missing entity never leaves an empty black panel")
	check(not game.show_world_entity_hover(hover_id,Vector2(-100,-100)) and not game.hover_panel.visible,"Hover panel stays inside the battlefield")
	game.paused=true
	await process_frame
	game.sim.explored[0].fill(1)
	game.sim.fog[0].fill(0)
	var fog_center:Vector2i=game.sim.grid.cell(game.renderer.camera)
	for y in range(fog_center.y-2,fog_center.y+3):
		for x in range(fog_center.x-2,fog_center.x+3): game.sim.fog[0][y*game.sim.grid.width+x]=1
	game.renderer._update_fog_texture()
	var fog_near_alpha:float=game.renderer.fog_image.get_pixel((fog_center.x+3)*4+2,fog_center.y*4+2).a
	var fog_far_alpha:float=game.renderer.fog_image.get_pixel((fog_center.x+8)*4+2,fog_center.y*4+2).a
	var fog_edge_a:float=game.renderer.fog_image.get_pixel((fog_center.x+3)*4+3,fog_center.y*4+2).a
	var fog_edge_b:float=game.renderer.fog_image.get_pixel((fog_center.x+4)*4,fog_center.y*4+2).a
	check(fog_near_alpha>0.0 and fog_near_alpha<fog_far_alpha and fog_far_alpha>0.6 and absf(fog_edge_a-fog_edge_b)<0.1,"Explored fog feathers smoothly away from current vision and across tile edges")
	game.sim.explored[0].fill(0)
	game.sim.fog[0].fill(0)
	for y in range(fog_center.y-2,fog_center.y+3):
		for x in range(fog_center.x-2,fog_center.x+3): game.sim.explored[0][y*game.sim.grid.width+x]=1
	game.renderer._update_fog_texture()
	var discovery_edge_alpha:float=game.renderer.fog_image.get_pixel((fog_center.x+3)*4+2,fog_center.y*4+2).a
	var discovery_far_alpha:float=game.renderer.fog_image.get_pixel((fog_center.x+8)*4+2,fog_center.y*4+2).a
	check(discovery_edge_alpha>0.62 and discovery_edge_alpha<discovery_far_alpha and discovery_far_alpha>0.99,"Unknown-terrain boundary fades outward without changing simulation visibility")
	await process_frame
	var visible_before: int=game.renderer.visible_mobile_count
	var hidden_pos: Vector2=game.renderer.camera+Vector2(450,300)
	for i in 200:
		game.sim.spawn("tank",1,hidden_pos+Vector2(i%5,i/5),false)
	for i in 200:
		game.sim.spawn("tank",0,game.renderer.camera+Vector2(1000+i%8, i/8),false)
	await process_frame
	check(game.renderer.visible_mobile_count==visible_before,"Hidden and off-screen units do not enter the render list")
	check(game.renderer.culled_mobile_fog_count>=200,"Fog-hidden enemies are counted as render-culled")
	check(game.renderer.culled_mobile_offscreen_count>=200,"Off-screen friendly units are counted as render-culled")
	game.paused=false
	for count in [1,5,10,40]:
		for e in game.sim.entities.values():
			if not e.building: game.sim.entities.erase(e.id)
		var ids: Array = []
		for i in count:
			ids.append(game.sim.spawn(game.db.units.keys()[i%game.db.units.size()],0,Vector2(470+(i%8)*80,1310+(i/8)*82),false))
		game.sim.rebuild_movement_buckets()
		game.sim.fog[0].fill(1); game.sim.explored[0].fill(1); game.renderer._update_fog_texture()
		game.selected=ids; game.update_hud()
		await process_frame; await process_frame
		root.get_texture().get_image().save_png("res://test-output/battlefield-group-%d.png"%count)
	game.music.shutdown(); game.queue_free()
	await process_frame
	print("BATTLEFIELD: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
