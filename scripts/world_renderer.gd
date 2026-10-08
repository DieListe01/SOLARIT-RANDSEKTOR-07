extends Node2D
class_name WorldRenderer
const CachePainterScript = preload("res://scripts/vehicle_cache_painter.gd")
const BuildingCachePainterScript = preload("res://scripts/building_cache_painter.gd")

var sim: Simulation
var camera := Vector2(400,1450)
var zoom := 1.0
var logical_size := Vector2(1560,960)
var selected: Array = []
var hovered_entity_id := 0
var placement := ""
var placement_rotation := 0
var placement_cell := Vector2i.ZERO
var debug := false
var profile_enabled := false
var health_mode := "damaged"
var selection_rect := Rect2()
var selecting := false
var command_marker := Vector2.ZERO
var marker_time := 0.0
var classic := false
var crt := 0
var elapsed := 0.0
const INK = Color("162b2e")
var fog_texture: ImageTexture
var fog_image: Image
var fog_base_colors := PackedColorArray()
var fog_timer := 0.0
var industrial_art := IndustrialArt.new()
var visual_bursts: Array[Dictionary] = []
var glow_texture: Texture2D
var terrain_sprite: Sprite2D
var material_grid: WorldGrid
var terrain_detail: Sprite2D
var terrain_detail_chunks: Dictionary = {}
var solarit_detail_chunks: Dictionary = {}
var resource_detail_values: Dictionary = {}
var resource_detail_timer := 0.0
const DETAIL_CHUNK_SIZE := 16
var visible_terrain_chunk_count := 0
var dirty_terrain_chunk_count := 0
var solarit_atlas: Texture2D
var tracks: Array[Dictionary] = []
var movement_vfx_enabled := true
var previous_positions: Dictionary = {}
var previous_speeds: Dictionary = {}
var track_timer := 0.0
var track_age_timer := 0.0
var heat_layer: ColorRect
var combat_fx := CombatEffects.new()
var visual_paused := false
var visual_offset := Vector2.ZERO
var preserve_loaded_visuals := false
var interpolation_previous: Dictionary = {}
var interpolation_current: Dictionary = {}
var interpolation_alpha := 1.0
var visible_mobile_count := 0
var visible_building_count := 0
var culled_mobile_fog_count := 0
var culled_mobile_offscreen_count := 0
var active_vfx_count := 0
var vfx_budget_tier := 0
var vehicle_texture_cache: Dictionary = {}
var vehicle_cache_pending: Dictionary = {}
var vehicle_cache_queue: Array[Dictionary] = []
var vehicle_cache_worker_active := false
var vehicle_cache_hits := 0
var vehicle_cache_misses := 0
var building_texture_cache: Dictionary = {}
var building_texture_times: Dictionary = {}
var building_cache_pending: Dictionary = {}
var building_cache_queue: Array[Dictionary] = []
var building_cache_worker_active := false
var building_cache_hits := 0
var building_cache_misses := 0
var profile_total_ms := 0.0
var profile_terrain_ms := 0.0
var profile_ground_fx_ms := 0.0
var profile_wrecks_ms := 0.0
var profile_buildings_ms := 0.0
var profile_vehicles_ms := 0.0
var profile_combat_fx_ms := 0.0
var profile_tracks_ms := 0.0
var profile_projectiles_ms := 0.0
var profile_impacts_ms := 0.0
var profile_explosions_ms := 0.0
var profile_smoke_ms := 0.0
var profile_fog_ms := 0.0
var profile_sim_ms := 0.0
var profile_ui_ms := 0.0
var profile_solarit_count := 0
var profile_ruin_count := 0
var profile_projectile_count := 0
var profile_impact_count := 0
var profile_particle_count := 0
var impact_disc_vertices := PackedVector3Array()
var impact_disc_colors := PackedColorArray()
var impact_disc_indices := PackedInt32Array()
var impact_glow_vertices := PackedVector3Array()
var impact_glow_uvs := PackedVector2Array()
var impact_glow_colors := PackedColorArray()
var impact_glow_indices := PackedInt32Array()
var impact_line_points := PackedVector2Array()
var impact_line_colors := PackedColorArray()
var impact_line_points_medium := PackedVector2Array()
var impact_line_colors_medium := PackedColorArray()
var impact_line_points_heavy := PackedVector2Array()
var impact_line_colors_heavy := PackedColorArray()
var impact_disc_mesh := ArrayMesh.new()
var impact_glow_mesh := ArrayMesh.new()

func set_interpolation(previous: Dictionary, current: Dictionary, alpha: float) -> void:
	interpolation_previous=previous
	interpolation_current=current
	interpolation_alpha=clampf(alpha,0.0,1.0)

func interpolated_entity(entity: Dictionary) -> Dictionary:
	if entity.building or not interpolation_current.has(entity.id): return entity
	var now: Array=interpolation_current[entity.id]
	var before: Array=interpolation_previous.get(entity.id,now)
	var visual := entity.duplicate()
	visual.pos=(before[0] as Vector2).lerp(now[0],interpolation_alpha)
	visual.angle=lerp_angle(float(before[1]),float(now[1]),interpolation_alpha)
	visual.turret=lerp_angle(float(before[2]),float(now[2]),interpolation_alpha)
	return visual

func nearest_vehicle_texture(key: String, requested_frame: int) -> Texture2D:
	var requested: PackedStringArray=key.split("|")
	var best: Texture2D
	var best_distance:=64
	for candidate in vehicle_texture_cache:
		var parts: PackedStringArray=str(candidate).split("|")
		if parts.size()!=8 or requested.size()!=8: continue
		if parts[0]!=requested[0] or parts[1]!=requested[1] or parts[2]!=requested[2] or parts[3]!=requested[3]: continue
		if parts[5]!=requested[5] or parts[6]!=requested[6] or parts[7]!=requested[7]: continue
		var difference:=absi(int(parts[4])-requested_frame)
		difference=mini(difference,64-difference)
		if difference<best_distance:
			best_distance=difference
			best=vehicle_texture_cache[candidate]
	return best

func draw_cached_vehicle(entity: Dictionary, output: Vector2, scale_value: float, ratio: float) -> bool:
	var relative := wrapf(entity.turret-entity.angle,-PI,PI)
	# Half as many turret snapshots keep continuously turning units from rebuilding
	# an unbounded set of nearly identical 256px textures during large fights.
	var turret_frame := posmod(roundi((relative+PI)*32.0/TAU)*2,64)
	var turret_angle := float(turret_frame)*TAU/64.0-PI
	var hp_ratio: float=entity.hp/entity.max_hp
	var damage_state := 2 if hp_ratio<0.35 else (1 if hp_ratio<0.65 else 0)
	var cargo_state := clampi(roundi(float(entity.get("cargo",0.0))/maxf(1.0,float(sim.db.rules.harvest_capacity))*8.0),0,8) if entity.kind=="harvester" else 0
	var harvest_state := 1 if entity.kind=="harvester" and entity.get("harvest_state","")=="HARVEST" else 0
	var color_key := sim.team_color(entity.owner).to_html(false)
	var key := "%s|%s|%d|%s|%d|%d|%d|%d" % [entity.kind,sim.factions[entity.owner],entity.owner,color_key,turret_frame,damage_state,cargo_state,harvest_state]
	var texture: Texture2D=vehicle_texture_cache.get(key)
	if texture==null:
		vehicle_cache_misses+=1
		if not vehicle_cache_pending.has(key) and vehicle_cache_queue.size()<16:
			vehicle_cache_pending[key]=true
			vehicle_cache_queue.append({"key":key,"entity":entity.duplicate(true),"team":sim.team_color(entity.owner),"faction":sim.factions[entity.owner],"turret":turret_angle})
			process_vehicle_cache_queue.call_deferred()
		texture=nearest_vehicle_texture(key,turret_frame)
		if texture==null: return false
	else:
		vehicle_cache_hits+=1
	var base := output*0.5-camera*scale_value+visual_offset*ratio
	var screen_pos: Vector2=base+(entity.pos+combat_fx.hit_offset(entity.id))*scale_value
	draw_set_transform(screen_pos,entity.angle,Vector2.ONE*(scale_value*0.25))
	draw_texture(texture,Vector2(-128,-128))
	draw_set_transform(base,0,Vector2.ONE*scale_value)
	return true

func process_vehicle_cache_queue() -> void:
	if vehicle_cache_worker_active or not is_inside_tree(): return
	vehicle_cache_worker_active=true
	while not vehicle_cache_queue.is_empty():
		var request: Dictionary=vehicle_cache_queue.pop_front()
		await _build_vehicle_texture(request.key,request.entity,request.team,request.faction,request.turret)
	vehicle_cache_worker_active=false

func building_cache_key(entity: Dictionary) -> String:
	var rotation := posmod(int(entity.get("rotation",0)),4)
	var damage_stage := 2 if entity.hp/entity.max_hp<0.35 else (1 if entity.hp/entity.max_hp<0.65 else 0)
	var turret_frame := posmod(roundi(float(entity.get("turret",0.0))*16.0/TAU),16) if entity.kind=="tower" else 0
	var faction: String=sim.factions[entity.owner]
	var active := 1 if entity.kind=="factory" and not entity.get("queue",[]).is_empty() else 0
	var upgrade_stage:=int(entity.get("upgrade_level",0))
	return "%s|%d|%s|%d|%d|%d|%d|%d" % [entity.kind,entity.owner,faction,rotation,damage_stage,turret_frame,active,upgrade_stage]

func draw_cached_building(entity: Dictionary) -> bool:
	# Construction, repairs and damaged structures keep their live sparks/flames.
	# Fully operational structures are rasterized once and reused as one texture draw.
	if not entity.complete or entity.repair or entity.get("upgrading",false) or entity.hp/entity.max_hp<0.65:
		building_cache_misses+=1
		return false
	var key := building_cache_key(entity)
	var texture: Texture2D=building_texture_cache.get(key)
	if texture==null:
		building_cache_misses+=1
		if not building_cache_pending.has(key):
			building_cache_pending[key]=true
			building_cache_queue.append({"key":key,"entity":entity.duplicate(true),"team":sim.team_color(entity.owner),"faction":sim.factions[entity.owner]})
			process_building_cache_queue.call_deferred()
		return false
	building_cache_hits+=1
	draw_texture_rect(texture,Rect2(entity.pos-Vector2(128,128),Vector2(256,256)),false)
	return true

func process_building_cache_queue() -> void:
	if building_cache_worker_active or not is_inside_tree(): return
	building_cache_worker_active=true
	while not building_cache_queue.is_empty():
		var request: Dictionary=building_cache_queue.pop_front()
		await _build_building_texture(request.key,request.entity,request.team,request.faction)
	building_cache_worker_active=false

func _build_building_texture(key: String, source: Dictionary, team: Color, faction: String) -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(512,512)
	viewport.transparent_bg=true
	viewport.gui_disable_input=true
	viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	var painter=BuildingCachePainterScript.new()
	painter.art=IndustrialArt.new()
	painter.entity=source.duplicate(true)
	painter.entity.pos=Vector2.ZERO
	painter.entity.erase("reload")
	painter.team=team
	painter.faction=faction
	painter.sim=sim
	viewport.add_child(painter)
	add_child(viewport)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(viewport): return
	var image := viewport.get_texture().get_image()
	if image!=null:
		if building_texture_cache.size()>=128: building_texture_cache.erase(building_texture_cache.keys()[0])
		building_texture_cache[key]=ImageTexture.create_from_image(image)
		building_texture_times[key]=elapsed
	building_cache_pending.erase(key)
	viewport.queue_free()

func _build_vehicle_texture(key: String, source: Dictionary, team: Color, faction: String, turret_angle: float) -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(256,256)
	viewport.transparent_bg=true
	viewport.gui_disable_input=true
	viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	var painter=CachePainterScript.new()
	painter.art=IndustrialArt.new()
	painter.entity=source.duplicate(true)
	painter.entity.pos=Vector2.ZERO
	painter.entity.angle=0.0
	painter.entity.turret=turret_angle
	painter.entity.velocity=Vector2.ZERO
	painter.entity.cache_treads=true
	painter.entity.id=0
	painter.entity.erase("reload")
	painter.team=team
	painter.faction=faction
	painter.sim=sim
	viewport.add_child(painter)
	add_child(viewport)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(viewport): return
	var image := viewport.get_texture().get_image()
	if image!=null:
		if vehicle_texture_cache.size()>=128: vehicle_texture_cache.erase(vehicle_texture_cache.keys()[0])
		vehicle_texture_cache[key]=ImageTexture.create_from_image(image)
	vehicle_cache_pending.erase(key)
	viewport.queue_free()

func seed_mission_ground_details() -> void:
	if sim==null: return
	for raw in sim.db.mission.get("ruins",[]):
		if not raw is Dictionary or not raw.has("kind") or not raw.has("cell"): continue
		var kind: String=str(raw.kind)
		if not sim.db.units.has(kind) and not sim.db.buildings.has(kind): continue
		var cell_data: Array=raw.cell
		if cell_data.size()!=2: continue
		var cell:=Vector2i(int(cell_data[0]),int(cell_data[1]))
		if not sim.grid.inside(cell): continue
		var building:=sim.db.buildings.has(kind)
		var footprint: Array=sim.building_footprint(kind,int(raw.get("rotation",0))) if building else [1,1]
		var radius: float = maxf(float(footprint[0]),float(footprint[1]))*18.0 if building else float({"scout":16.0,"tank":25.0,"siege":32.0,"harvester":29.0}.get(kind,22.0))
		combat_fx.ruins.append({"pos":sim.grid.center(cell),"building":building,"core":kind=="core","angle":float(raw.get("rotation",0))*PI/2.0,"age":120.0,"radius":radius,"variant":int(raw.get("variant",0))%4,"object_kind":kind,"footprint":footprint})
	for raw in sim.db.mission.get("craters",[]):
		if not raw is Dictionary or not raw.has("cell"): continue
		var cell_data: Array=raw.cell
		if cell_data.size()!=2: continue
		var cell:=Vector2i(int(cell_data[0]),int(cell_data[1]))
		if sim.grid.inside(cell): combat_fx.craters.append({"pos":sim.grid.center(cell),"radius":float(raw.get("radius",30.0)),"age":120.0})

func _ready() -> void:
	solarit_atlas=load("res://assets/solarit_atlas.png")
	terrain_sprite=Sprite2D.new()
	terrain_sprite.centered=false; terrain_sprite.z_index=-3
	terrain_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new()
	if DisplayServer.get_name() != "headless":
		material.shader=load("res://assets/terrain.gdshader")
	terrain_sprite.material=material
	add_child(terrain_sprite)
	terrain_detail=Sprite2D.new()
	terrain_detail.centered=false; terrain_detail.z_index=-1
	terrain_detail.z_index=-1
	terrain_detail.texture=load("res://assets/terrain_detail.png")
	add_child(terrain_detail)
	var glow := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var radius := Vector2(x-31.5,y-31.5).length()/31.5
			glow.set_pixel(x,y,Color(1,1,1,pow(maxf(0,1-radius),2.5)))
	glow_texture=ImageTexture.create_from_image(glow)
	heat_layer=ColorRect.new()
	heat_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	heat_layer.z_index=10
	var heat_material := ShaderMaterial.new()
	heat_material.shader=load("res://assets/desert_heat.gdshader")
	heat_layer.material=heat_material
	add_child(heat_layer)

func _process(dt: float) -> void:
	if visual_paused: dt=0.0
	if not visual_paused:
		elapsed+=dt
		combat_fx.update(dt)
	visual_offset=combat_fx.offset
	for index in range(visual_bursts.size()-1,-1,-1):
		visual_bursts[index].life-=dt
		if visual_bursts[index].life<=0: visual_bursts.remove_at(index)
	track_age_timer+=dt
	if track_age_timer>=0.2:
		var age_step:=track_age_timer
		track_age_timer=0.0
		age_ground_tracks(age_step)
	track_timer-=dt
	if not movement_vfx_enabled:
		tracks.clear(); previous_positions.clear(); previous_speeds.clear()
	elif sim!=null and not visual_paused and track_timer<=0:
		track_timer=0.2
		for e in visible_mobile_entities():
			if sim.factions[e.owner]=="lumen": continue
			var old: Vector2 = previous_positions.get(e.id,e.pos)
			if float(previous_speeds.get(e.id,0))>25 and e.velocity.length()<8:
				combat_fx.emit_effect("dust",{"pos":e.pos,"weapon":""})
			if float(previous_speeds.get(e.id,0))<8 and e.velocity.length()>25:
				combat_fx.emit_effect("dust",{"pos":e.pos,"weapon":""})
			previous_speeds[e.id]=e.velocity.length()
			if old.distance_to(e.pos)>3 and old.distance_to(e.pos)<40:
				tracks.append({"a":old,"b":e.pos,"angle":e.angle,"life":50.0})
			previous_positions[e.id]=e.pos
		while tracks.size()>1800: tracks.pop_front()
	if sim!=null and sim.grid!=material_grid:
		tracks.clear(); previous_positions.clear()
		previous_speeds.clear()
		if not preserve_loaded_visuals:
			combat_fx.reset()
			seed_mission_ground_details()
		preserve_loaded_visuals=false
		material_grid=sim.grid
		var types := Image.create(sim.grid.width,sim.grid.height,false,Image.FORMAT_RGB8)
		for y in sim.grid.height:
			for x in sim.grid.width:
				types.set_pixel(x,y,Color((sim.grid.type_at(Vector2i(x,y))+0.5)/8.0,0,0))
		terrain_sprite.texture=ImageTexture.create_from_image(types)
		terrain_sprite.material.set_shader_parameter("map_cells",Vector2(sim.grid.width,sim.grid.height))
		_build_terrain_detail_mesh()
	if sim!=null:
		resource_detail_timer-=dt
		if resource_detail_timer<=0.0:
			resource_detail_timer=0.25
			var dirty_chunks: Dictionary={}
			for entity in sim.entities.values():
				if entity.kind!="harvester" or entity.harvest_state!="HARVEST" or entity.resource=="": continue
				var current_amount:=float(sim.grid.resources.get(entity.resource,0.0))
				if absf(current_amount-float(resource_detail_values.get(entity.resource,current_amount)))<=0.1: continue
				resource_detail_values[entity.resource]=current_amount
				var cell:=sim.grid.cell(sim.grid.center(sim.grid.parse_key(entity.resource)))
				dirty_chunks[Vector2i(cell.x/DETAIL_CHUNK_SIZE,cell.y/DETAIL_CHUNK_SIZE)]=true
			for chunk in dirty_chunks: _build_solarit_detail_chunk(chunk)
	fog_timer-=dt
	if sim!=null and fog_timer<=0:
		fog_timer=0.25
		var fog_size:=Vector2i(sim.grid.width,sim.grid.height)
		if fog_image==null or fog_image.get_size()!=fog_size:
			fog_image=Image.create(fog_size.x,fog_size.y,false,Image.FORMAT_RGBA8)
			fog_base_colors.resize(fog_size.x*fog_size.y)
			for y in fog_size.y:
				for x in fog_size.x:
					var index:=y*fog_size.x+x
					var grain := sin(float(x*73+y*179))*0.0035
					var strata := sin(float(x)*0.37+sin(float(y)*0.23))*0.006
					fog_base_colors[index]=Color(0.09+grain+strata,0.075+grain+strata,0.066+grain+strata,1.0)
		for y in sim.grid.height:
			for x in sim.grid.width:
				var index := y*sim.grid.width+x
				var alpha := 1.0 if sim.explored[sim.view_owner][index]==0 else (0.62 if sim.fog[sim.view_owner][index]==0 else 0.0)
				var base_color: Color=fog_base_colors[index]
				fog_image.set_pixel(x,y,Color(base_color.r,base_color.g,base_color.b,alpha))
		if fog_texture==null: fog_texture=ImageTexture.create_from_image(fog_image)
		else: fog_texture.update(fog_image)
	marker_time=maxf(0,marker_time-dt)
	queue_redraw()

func age_ground_tracks(dt: float) -> void:
	for index in range(tracks.size()-1,-1,-1):
		tracks[index].life-=dt
		if tracks[index].life<=0: tracks.remove_at(index)

func _movement_bucket_has_visible_cell(bucket: Vector2i) -> bool:
	var tile_size:=sim.grid.tile
	var first:=Vector2i(floori(float(bucket.x*80)/tile_size),floori(float(bucket.y*80)/tile_size))
	var last:=Vector2i(floori(float((bucket.x+1)*80-1)/tile_size),floori(float((bucket.y+1)*80-1)/tile_size))
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var cell:=Vector2i(x,y)
			if sim.grid.inside(cell) and sim.fog[sim.view_owner][y*sim.grid.width+x]>0: return true
	return false

func visible_mobile_entities(margin: float = 120.0) -> Array[Dictionary]:
	var visible: Array[Dictionary]=[]
	if sim==null: return visible
	if not sim.movement_buckets_valid: sim.rebuild_movement_buckets()
	var half:=logical_size*0.5/zoom
	var render_min:=camera-half-Vector2.ONE*margin
	var render_max:=camera+half+Vector2.ONE*margin
	var bucket_min:=Vector2i(floori(render_min.x/80.0),floori(render_min.y/80.0))
	var bucket_max:=Vector2i(floori(render_max.x/80.0),floori(render_max.y/80.0))
	var seen: Dictionary={}
	for bucket_y in range(bucket_min.y,bucket_max.y+1):
		for bucket_x in range(bucket_min.x,bucket_max.x+1):
			var bucket:=Vector2i(bucket_x,bucket_y)
			var bucket_units: Array=sim.movement_buckets.get(bucket,[])
			if bucket_units.is_empty(): continue
			var active_count:=0
			var contains_owned:=false
			for unit in bucket_units:
				if not sim.entities.has(int(unit.id)): continue
				active_count+=1
				if int(unit.owner)==sim.view_owner: contains_owned=true
			if active_count==0 or (not contains_owned and not _movement_bucket_has_visible_cell(bucket)): continue
			for entity in bucket_units:
				var id:=int(entity.id)
				if seen.has(id) or not sim.entities.has(id): continue
				seen[id]=true
				if entity.owner!=sim.view_owner and not sim.is_visible(entity,sim.view_owner): continue
				if absf(entity.pos.x-camera.x)>half.x+margin or absf(entity.pos.y-camera.y)>half.y+margin: continue
				visible.append(entity)
	return visible

func _draw() -> void:
	if sim==null: return
	var profile_started := Time.get_ticks_usec() if profile_enabled else 0
	profile_total_ms=0.0; profile_terrain_ms=0.0; profile_ground_fx_ms=0.0
	profile_wrecks_ms=0.0
	profile_buildings_ms=0.0; profile_vehicles_ms=0.0; profile_combat_fx_ms=0.0
	profile_tracks_ms=0.0; profile_projectiles_ms=0.0; profile_impacts_ms=0.0
	profile_explosions_ms=0.0; profile_smoke_ms=0.0; profile_fog_ms=0.0
	profile_solarit_count=0; profile_ruin_count=0; profile_projectile_count=0; profile_impact_count=0; profile_particle_count=0
	impact_disc_vertices.clear(); impact_disc_colors.clear(); impact_disc_indices.clear()
	impact_glow_vertices.clear(); impact_glow_uvs.clear(); impact_glow_colors.clear(); impact_glow_indices.clear()
	impact_line_points.clear(); impact_line_colors.clear()
	impact_line_points_medium.clear(); impact_line_colors_medium.clear()
	impact_line_points_heavy.clear(); impact_line_colors_heavy.clear()
	vehicle_cache_hits=0; vehicle_cache_misses=0
	building_cache_hits=0; building_cache_misses=0
	var output := get_viewport_rect().size
	heat_layer.size=output
	var ratio := output.x/logical_size.x
	var scale_value := zoom*ratio
	terrain_sprite.visible=true
	terrain_sprite.position=output*0.5-camera*scale_value+visual_offset*ratio
	terrain_sprite.scale=Vector2.ONE*scale_value*sim.grid.tile
	terrain_detail.position=terrain_sprite.position
	terrain_detail.scale=Vector2.ONE*scale_value*0.5
	draw_set_transform(output*0.5-camera*scale_value+visual_offset*ratio,0,Vector2.ONE*scale_value)
	var g := sim.grid
	var half := logical_size*0.5/zoom
	var from := g.cell(camera-half)-Vector2i.ONE
	var to := g.cell(camera+half)+Vector2i.ONE
	var terrain_started := Time.get_ticks_usec() if profile_enabled else 0
	vfx_budget_tier=0
	var combat_load:=sim.projectiles.size()+sim.effects.size()+combat_fx.particles.size()+visual_bursts.size()
	if combat_load>160: vfx_budget_tier=2
	elif combat_load>80: vfx_budget_tier=1
	# React to real frame pressure as well as effect count. A dense battle can be
	# expensive even with a modest number of logical effects because each effect
	# expands into many submitted primitives. This adaptive tier preserves the
	# important flash/projectile silhouettes while trimming secondary dust/smoke.
	var live_fps:=Engine.get_frames_per_second()
	if live_fps>0 and live_fps<46: vfx_budget_tier=maxi(vfx_budget_tier,3)
	elif live_fps>0 and live_fps<58: vfx_budget_tier=maxi(vfx_budget_tier,2)
	elif live_fps>0 and live_fps<82: vfx_budget_tier=maxi(vfx_budget_tier,1)
	visible_terrain_chunk_count=0
	for chunk_y in range(maxi(0,floori(float(from.y)/DETAIL_CHUNK_SIZE)),mini(ceili(float(g.height)/DETAIL_CHUNK_SIZE),floori(float(to.y)/DETAIL_CHUNK_SIZE)+1)):
		for chunk_x in range(maxi(0,floori(float(from.x)/DETAIL_CHUNK_SIZE)),mini(ceili(float(g.width)/DETAIL_CHUNK_SIZE),floori(float(to.x)/DETAIL_CHUNK_SIZE)+1)):
			var chunk_key:=Vector2i(chunk_x,chunk_y)
			var chunk_mesh: ArrayMesh=terrain_detail_chunks.get(chunk_key)
			if chunk_mesh!=null:
				draw_mesh(chunk_mesh,null)
			var solarit_mesh: ArrayMesh=solarit_detail_chunks.get(chunk_key)
			if solarit_mesh!=null: draw_mesh(solarit_mesh,solarit_atlas)
			if chunk_mesh!=null: visible_terrain_chunk_count+=1
	for y in range(maxi(0,from.y),mini(g.height,to.y+1)):
		for x in range(maxi(0,from.x),mini(g.width,to.x+1)):
			var c := Vector2i(x,y)
			var index := y*g.width+x
			var rect := Rect2(Vector2(c*g.tile),Vector2.ONE*g.tile)
			if sim.explored[sim.view_owner][index]==0: continue
			var remaining := float(sim.grid.resources.get(sim.grid.key(c),0))
			if remaining>0 and g.type_at(c)==3 and profile_enabled: profile_solarit_count+=1
			if debug: draw_rect(rect,Color(0.1,0.8,0.65,0.15),false,1)
	if profile_enabled: profile_terrain_ms=float(Time.get_ticks_usec()-terrain_started)/1000.0
	var tracks_started := Time.get_ticks_usec() if profile_enabled else 0
	var track_points := PackedVector2Array()
	var track_colors := PackedColorArray()
	var track_step:=1 if vfx_budget_tier==0 else (2 if vfx_budget_tier==1 else (3 if vfx_budget_tier==2 else 5))
	for track_index in range(0,tracks.size(),track_step):
		var track: Dictionary=tracks[track_index]
		var offset := Vector2.from_angle(track.angle).orthogonal()*9
		var shade := Color(0.10,0.12,0.10,0.18*track.life/50.0)
		for sign_value in [-1,1]:
			track_points.append(track.a+offset*sign_value); track_points.append(track.b+offset*sign_value)
			track_colors.append(shade)
	if not track_points.is_empty(): draw_multiline_colors(track_points,track_colors,2.3,true)
	if profile_enabled: profile_tracks_ms=float(Time.get_ticks_usec()-tracks_started)/1000.0
	var ground_fx_started := Time.get_ticks_usec() if profile_enabled else 0
	combat_fx.draw_ground(self)
	var ground_batch_started:=Time.get_ticks_usec() if profile_enabled else 0
	flush_impact_batch()
	if profile_enabled:
		profile_ground_fx_ms=float(Time.get_ticks_usec()-ground_fx_started)/1000.0
		profile_wrecks_ms=combat_fx.profile_wrecks_ms+float(Time.get_ticks_usec()-ground_batch_started)/1000.0
		profile_ruin_count=combat_fx.ruins.size()
	for memory in sim.known[sim.view_owner].values():
		if memory.building:
			var c := g.cell(memory.pos)
			if g.inside(c) and sim.fog[sim.view_owner][c.y*g.width+c.x]==0:
				var d: Dictionary = sim.db.buildings[memory.kind]
				draw_rect(Rect2(memory.pos-Vector2(sim.building_footprint(memory.kind,int(memory.get("rotation",0)))[0],sim.building_footprint(memory.kind,int(memory.get("rotation",0)))[1])*g.tile*0.5,Vector2(sim.building_footprint(memory.kind,int(memory.get("rotation",0)))[0],sim.building_footprint(memory.kind,int(memory.get("rotation",0)))[1])*g.tile),Color("3c3023"))
	# Cull hidden and off-screen entities before sorting or rendering any per-unit
	# effects. They still simulate normally; they simply have no drawing cost here.
	var sorted: Array[Dictionary]=[]
	culled_mobile_fog_count=0; culled_mobile_offscreen_count=0
	if not sim.movement_buckets_valid: sim.rebuild_movement_buckets()
	var render_min:=camera-half-Vector2(120,120)
	var render_max:=camera+half+Vector2(120,120)
	var bucket_min:=Vector2i(floori(render_min.x/80.0),floori(render_min.y/80.0))
	var bucket_max:=Vector2i(floori(render_max.x/80.0),floori(render_max.y/80.0))
	var indexed_mobile_ids: Dictionary={}
	for bucket_y in range(bucket_min.y,bucket_max.y+1):
		for bucket_x in range(bucket_min.x,bucket_max.x+1):
			var bucket_cell:=Vector2i(bucket_x,bucket_y)
			var bucket_units: Array=sim.movement_buckets.get(bucket_cell,[])
			if bucket_units.is_empty(): continue
			var has_owned_units:=false
			var active_bucket_count:=0
			for bucket_unit in bucket_units:
				if not sim.entities.has(int(bucket_unit.id)): continue
				active_bucket_count+=1
				if int(bucket_unit.owner)==sim.view_owner: has_owned_units=true
			if active_bucket_count==0: continue
			if not has_owned_units and not _movement_bucket_has_visible_cell(bucket_cell):
				culled_mobile_fog_count+=active_bucket_count
				continue
			for e in bucket_units:
				var entity_id:=int(e.id)
				if indexed_mobile_ids.has(entity_id) or not sim.entities.has(entity_id): continue
				indexed_mobile_ids[entity_id]=true
				if e.owner!=sim.view_owner and not sim.is_visible(e,sim.view_owner):
					culled_mobile_fog_count+=1
					continue
				var visual:=interpolated_entity(e)
				if absf(visual.pos.x-camera.x)>half.x+120 or absf(visual.pos.y-camera.y)>half.y+120: continue
				sorted.append({"entity":e,"visual":visual})
	for entity_id in sim.building_ids:
		if not sim.entities.has(entity_id): continue
		var e: Dictionary=sim.entities[entity_id]
		if e.owner!=sim.view_owner and not sim.is_visible(e,sim.view_owner): continue
		var visual:=interpolated_entity(e)
		if absf(visual.pos.x-camera.x)>half.x+120 or absf(visual.pos.y-camera.y)>half.y+120: continue
		sorted.append({"entity":e,"visual":visual})
	sorted.sort_custom(func(a,b):return a.visual.pos.y<b.visual.pos.y)
	if movement_vfx_enabled and vfx_budget_tier<3:
		var tread_points := PackedVector2Array()
		var tread_colors := PackedColorArray()
		for render_item in sorted:
			var e: Dictionary=render_item.entity
			var visual: Dictionary=render_item.visual
			if e.building: continue
			if visual.velocity.length()<=5 or sim.factions[visual.owner] in ["drift","lumen"]: continue
			var length := 28.0 if visual.kind=="harvester" else (30.0 if visual.kind=="lancer" else (25.0 if visual.kind=="siege" else 22.0))
			var width := 16.0 if visual.kind=="harvester" else (17.0 if visual.kind=="lancer" else (14.0 if visual.kind=="siege" else 13.0))
			var phase := fposmod(elapsed*visual.velocity.length()*0.22,4.0)
			for side in [-1,1]:
				var tread_step:=4 if vfx_budget_tier==0 else (6 if vfx_budget_tier==1 else 8)
				for i in range(-int(length)+1,int(length),tread_step):
					var tread := float(i)+phase
					tread_points.append(visual.pos+Vector2(tread,side*width-2.8).rotated(visual.angle))
					tread_points.append(visual.pos+Vector2(tread,side*width+2.8).rotated(visual.angle))
					tread_colors.append(Color("68645a"))
		if not tread_points.is_empty(): draw_multiline_colors(tread_points,tread_colors,1.6,true)
	var object_profile_started := 0
	visible_mobile_count=0; visible_building_count=0
	for render_item in sorted:
		if render_item.entity.building: visible_building_count+=1
		else: visible_mobile_count+=1
	culled_mobile_offscreen_count=maxi(0,sim.mobile_entity_count-visible_mobile_count-culled_mobile_fog_count)
	for render_item in sorted:
		var e: Dictionary=render_item.entity
		var visual: Dictionary=render_item.visual
		if movement_vfx_enabled and not e.building and e.velocity.length()>8 and vfx_budget_tier<2:
			var heavy: bool = e.kind in ["harvester","siege","tank"]
			var dust_count: int=(7 if heavy else 4) if vfx_budget_tier==0 else (3 if heavy else 2)
			for i in dust_count:
				var age := fposmod(elapsed*0.65+i*0.19,1.0)
				var pos: Vector2 = visual.pos-Vector2.from_angle(visual.angle)*(16+age*23)+Vector2(sin(i*3.1)*age*8,4)
				paint_circle(pos,2+age*(10 if heavy else 5),Color(0.76,0.49,0.24,(1-age)*(0.14 if heavy else 0.09)))
		if e.building:
			if profile_enabled: object_profile_started=Time.get_ticks_usec()
			if not draw_cached_building(e): draw_building(e)
			if profile_enabled: profile_buildings_ms+=float(Time.get_ticks_usec()-object_profile_started)/1000.0
		else:
			if profile_enabled: object_profile_started=Time.get_ticks_usec()
			if not draw_cached_vehicle(visual,output,scale_value,ratio):
				industrial_art.simplified=zoom<0.68
				draw_unit(visual)
			if profile_enabled: profile_vehicles_ms+=float(Time.get_ticks_usec()-object_profile_started)/1000.0
		if combat_fx.flashes.has(e.id):
			glow_at(visual.pos,45 if e.building else 22,Color(1,0.82,0.48,float(combat_fx.flashes[e.id])*2.8))
		if debug:
			if not e.building:
				var last: Vector2 = visual.pos
				for point in e.path: draw_line(last,point,Color("a2e48a"),1); last=point
			elif e.owner==sim.view_owner:
				draw_arc(e.pos,float(sim.db.rules.build_radius)*g.tile,0,TAU,64,Color(0.5,0.9,0.8,0.15),1)
	var combat_fx_started := Time.get_ticks_usec() if profile_enabled else 0
	var projectile_started := Time.get_ticks_usec() if profile_enabled else 0
	for p in sim.projectiles:
		var c := g.cell(p.pos)
		if not g.inside(c) or sim.fog[sim.view_owner][c.y*g.width+c.x]==0: continue
		if profile_enabled: profile_projectile_count+=1
		combat_fx.draw_projectile(self,p,vfx_budget_tier)
	if profile_enabled: profile_projectiles_ms=float(Time.get_ticks_usec()-projectile_started)/1000.0
	var impacts_started := Time.get_ticks_usec() if profile_enabled else 0
	for fx in sim.effects:
		if fx.get("event_backed",false): continue
		var c := g.cell(fx.pos)
		if not g.inside(c) or sim.fog[sim.view_owner][c.y*g.width+c.x]==0: continue
		if profile_enabled: profile_impact_count+=1
		var age: float = 1-fx.life/fx.max_life
		draw_modern_explosion(fx.pos,fx.radius,age,vfx_budget_tier)
	if profile_enabled: profile_impacts_ms=float(Time.get_ticks_usec()-impacts_started)/1000.0
	flush_impact_batch()
	for burst in visual_bursts:
		if profile_enabled: profile_particle_count+=1
		# At the emergency budget, keep completed-building pulses but drop the short-lived
		# per-shot muzzle decoration. The projectile and hit effects remain untouched.
		if vfx_budget_tier>=3 and burst.get("kind","shot")!="complete": continue
		var age: float = 1.0-burst.life/burst.duration
		if burst.get("kind","shot")=="complete":
			glow_at(burst.pos,55,Color(0.3,0.95,0.8,(1-age)*0.32))
			draw_arc(burst.pos,30+age*35,0,TAU,48,Color(0.6,1,0.85,(1-age)*0.6),1.5,true)
			continue
		append_impact_glow(burst.pos,28*(1-age),Color(1,0.75,0.34,(1-age)*0.65))
		for i in 5:
			var direction := Vector2.from_angle(burst.angle+(i-2)*0.2)
			var q: Vector2 = burst.pos+direction*age*16
			append_impact_line(q,q-direction*4,Color(1,0.91,0.62,(1-age)),1.2)
	flush_impact_batch()
	combat_fx.draw_effects(self)
	flush_impact_batch()
	if profile_enabled:
		profile_combat_fx_ms=float(Time.get_ticks_usec()-combat_fx_started)/1000.0
		profile_explosions_ms=combat_fx.profile_destroy_ms
		profile_impacts_ms+=combat_fx.profile_hit_ms+combat_fx.profile_impact_ms
		profile_projectiles_ms+=combat_fx.profile_shot_ms
		profile_smoke_ms=combat_fx.profile_smoke_ms+combat_fx.profile_dust_ms
	if profile_enabled: profile_particle_count+=combat_fx.particles.size()
	var wind_count:=18 if vfx_budget_tier==0 else (10 if vfx_budget_tier==1 else (5 if vfx_budget_tier==2 else 2))
	for i in wind_count:
		var wind := camera+Vector2(fposmod(elapsed*13+i*79,half.x*2)-half.x,fposmod(i*143.0,half.y*2)-half.y)
		if combat_fx.visible(self,wind): draw_line(wind,wind+Vector2(18+i%4*5,2),Color(0.95,0.73,0.38,0.055),0.8,true)
	var fog_started := Time.get_ticks_usec() if profile_enabled else 0
	if fog_texture!=null:
		draw_texture_rect(fog_texture,Rect2(Vector2.ZERO,Vector2(g.width,g.height)*g.tile),false)
		draw_fog_dust(from,to)
	if profile_enabled: profile_fog_ms=float(Time.get_ticks_usec()-fog_started)/1000.0
	active_vfx_count=sim.effects.size()+sim.projectiles.size()+combat_fx.particles.size()+tracks.size()
	# World status is deliberately above explosions, smoke and fog.
	var occupied_bars: Array[Rect2] = []
	for render_item in sorted:
		var e: Dictionary=render_item.entity
		var visual: Dictionary=render_item.visual
		if selected.has(e.id) or health_mode=="always" or (health_mode=="damaged" and (e.hp<e.max_hp or int(e.id)==hovered_entity_id)):
			if health_mode!="off" or selected.has(e.id):
				var w := 42.0 if e.building else 24.0
				var elevation := float({"core":88,"power":74,"radar":80,"refinery":68,"factory":66,"repair":65,"armory":70}.get(e.kind,58)) if e.building else sim.unit_radius(e.kind)+11.0
				var p: Vector2 = visual.pos-Vector2(w/2,elevation)
				var anchor := p
				for attempt in 3:
					var overlaps := false
					for used in occupied_bars:
						if used.intersects(Rect2(p-Vector2(1,1),Vector2(w+2,5))): overlaps=true; break
					if not overlaps: break
					p=anchor-Vector2(0,(attempt+1)*4)
				occupied_bars.append(Rect2(p-Vector2(1,1),Vector2(w+2,5)))
				draw_rect(Rect2(p-Vector2.ONE,Vector2(w+2,5)),INK)
				draw_rect(Rect2(p,Vector2(w*clampf(e.hp/e.max_hp,0,1),3)),Color(TeamIdentity.health(e.hp/e.max_hp),0.85))
		if e.owner==sim.view_owner and e.building:
			draw_world_progress(e,visual)
		if selected.has(e.id):
			draw_selection(visual)
			if e.owner==sim.view_owner and e.kind=="repair" and e.complete:
				draw_arc(visual.pos,100,0,TAU,64,Color(sim.team_color(sim.view_owner),0.2),0.8,true)
			if e.owner==sim.view_owner and e.building and e.kind=="factory":
				draw_line(e.pos,e.rally,Color(0.5,0.95,0.75,0.45),1)
				draw_line(e.rally,e.rally-Vector2(0,24),sim.team_color(e.owner),2)
				smooth_polygon(PackedVector2Array([e.rally-Vector2(0,24),e.rally+Vector2(16,-19),e.rally-Vector2(0,14)]),sim.team_color(e.owner))
		elif int(e.id)==hovered_entity_id:
			draw_selection(visual,true)
	if placement!="":
		var d: Dictionary = sim.db.buildings[placement]
		var footprint := sim.building_footprint(placement,placement_rotation)
		var rect := Rect2(Vector2(placement_cell*g.tile),Vector2(footprint[0],footprint[1])*g.tile)
		var valid := sim.build_reason(placement,sim.view_owner,placement_cell,placement_rotation)==""
		var color := Color(0.3,0.95,0.7,0.5) if valid else Color(1,0.3,0.23,0.5)
		var ghost := {"owner":sim.view_owner,"pos":rect.get_center(),"kind":placement,"complete":true,"hp":1.0,"max_hp":1.0,"turret":0.0,"rotation":placement_rotation}
		industrial_art.opacity=0.35
		industrial_art.building(self,ghost,Vector2(d.footprint[0],d.footprint[1])*g.tile,color,elapsed)
		industrial_art.opacity=1.0
		draw_rect(rect,Color(color,0.08))
		for y in range(0,int(rect.size.y),6): draw_line(rect.position+Vector2(0,y),rect.position+Vector2(rect.size.x,y),Color(color,0.2),0.8,true)
		draw_rect(rect,color.lightened(0.3),false,2)
	if selecting: draw_rect(selection_rect,Color(0.4,0.9,0.75,0.13)); draw_rect(selection_rect,Color("8ee9c5"),false,1)
	if marker_time>0:
		draw_arc(command_marker,12+marker_time*12,0,TAU,16,Color(0.65,1,0.8,marker_time),2)
	draw_set_transform(Vector2.ZERO)
	if classic and crt>0:
		for y in range(0,int(output.y),3): draw_line(Vector2(0,y),Vector2(output.x,y),Color(0,0,0,0.1 if crt==1 else 0.22),1)
	if profile_enabled: profile_total_ms=float(Time.get_ticks_usec()-profile_started)/1000.0


func _construction_phase(progress: float) -> String:
	if progress < 0.25: return "FUNDAMENT"
	if progress < 0.50: return "RAHMEN"
	if progress < 0.85: return "MONTAGE"
	if progress < 1.0: return "INBETRIEBNAHME"
	return "BETRIEBSBEREIT"

func _world_progress_data(e: Dictionary) -> Dictionary:
	if sim==null or e.owner!=sim.view_owner or not e.building: return {}
	if not e.complete:
		var total: float=maxf(0.01,float(sim.definition(e).time))
		var ratio: float=clampf(float(e.get("build_progress",0.0))/total,0.0,1.0)
		return {"ratio":ratio,"title":str(sim.definition(e).name),"detail":_construction_phase(ratio),"queue":0,"kind":"build"}
	if e.get("upgrading",false):
		var upgrade_total: float=maxf(0.01,float(e.get("upgrade_time",1.0)))
		var upgrade_ratio: float=clampf(float(e.get("upgrade_progress",0.0))/upgrade_total,0.0,1.0)
		return {"ratio":upgrade_ratio,"title":str(sim.definition(e).name),"detail":"AUSBAU STUFE %d"%int(e.get("upgrade_target",1)),"queue":0,"kind":"upgrade"}
	if e.kind=="factory" and not e.get("queue",[]).is_empty():
		var job: Dictionary=e.queue[0]
		var unit_def: Dictionary=sim.db.units.get(str(job.kind),{})
		var production_time: float=maxf(0.01,float(unit_def.get("time",1.0))*(0.85 if int(e.get("upgrade_level",0))>0 else 1.0))
		var production_ratio: float=clampf(float(e.get("progress",0.0))/production_time,0.0,1.0)
		return {"ratio":production_ratio,"title":str(unit_def.get("name",job.kind)),"detail":"MONTAGE","queue":e.queue.size(),"kind":"production"}
	return {}

func draw_world_progress(e: Dictionary, visual: Dictionary) -> void:
	var data: Dictionary=_world_progress_data(e)
	if data.is_empty(): return
	var focused: bool=selected.has(e.id) or int(e.id)==hovered_entity_id
	var ratio: float=float(data.ratio)
	var building_height: float=float({"core":88,"power":74,"radar":80,"refinery":68,"factory":66,"repair":65,"armory":70}.get(e.kind,58))
	# Construction stays readable in-world. Running factories show their active product at
	# normal zoom, but collapse to a tiny progress bar when the camera is far away.
	var show_label: bool=str(data.kind)!="production" or focused or zoom>=0.90
	var bar_width: float=72.0 if show_label else 42.0
	var y_offset: float=building_height+(8.0 if show_label else 6.0)
	var top_left: Vector2=visual.pos-Vector2(bar_width*0.5,y_offset)
	var fill_color: Color=Color("78e3c5") if str(data.kind)!="production" else Color("e7bd78")
	if show_label:
		var plate_width: float=maxf(116.0,bar_width)
		top_left.x=visual.pos.x-plate_width*0.5
		draw_rect(Rect2(top_left-Vector2(6,24),Vector2(plate_width+12,41)),Color("130f0c",0.88))
		draw_rect(Rect2(top_left-Vector2(6,24),Vector2(plate_width+12,41)),Color("8f6b3f",0.8),false,1.0)
		var short_title: String=str(data.title)
		if str(data.kind)=="production" and short_title.contains("·"):
			short_title=short_title.get_slice("·",1).strip_edges()
		if short_title.length()>22: short_title=short_title.left(21)+"…"
		var detail_text: String="%s · %d%%"%[str(data.detail),int(ratio*100.0)]
		if int(data.queue)>1: detail_text+=" · +%d"%[int(data.queue)-1]
		draw_string(ThemeDB.fallback_font,top_left-Vector2(0,8),short_title,HORIZONTAL_ALIGNMENT_CENTER,plate_width,11,Color("e8dfcf"))
		draw_string(ThemeDB.fallback_font,top_left+Vector2(0,7),detail_text,HORIZONTAL_ALIGNMENT_CENTER,plate_width,10,fill_color)
		top_left=Vector2(visual.pos.x-bar_width*0.5,top_left.y+15)
	draw_rect(Rect2(top_left,Vector2(bar_width,4)),Color("16110d",0.95))
	draw_rect(Rect2(top_left,Vector2(bar_width*ratio,4)),fill_color)

func draw_selection(e: Dictionary, hover: bool = false) -> void:
	var color := Color("e7bd78") if hover else sim.team_color(e.owner)
	var focused: bool = not hover and (selected.size()==1 or (not selected.is_empty() and e.id==selected[0]))
	var emphasis := 0.3 if hover else (0.86 if focused else 0.42)
	if e.building:
		var footprint: Array = sim.footprint(e)
		var extent := Vector2(footprint[0],footprint[1])*sim.grid.tile*0.5+Vector2(4,5)
		for x in [-1,1]:
			for y in [-1,1]:
				var corner: Vector2 = e.pos+extent*Vector2(x,y)
				var points := PackedVector2Array([corner-Vector2(x*12,0),corner,corner-Vector2(0,y*12)])
				draw_polyline(points,Color(0.12,0.08,0.05,0.65),3,true)
				draw_polyline(points,Color(color,emphasis),1.1,true)
	else:
		var length: float = {"scout":19.0,"tank":26.0,"siege":31.0,"harvester":33.0,"raider":27.0,"lancer":35.0,"scorcher":27.0,"bulwark":40.0}.get(e.kind,25.0)
		var width: float = {"scout":12.0,"tank":17.0,"siege":18.0,"harvester":21.0,"raider":16.0,"lancer":21.0,"scorcher":18.0,"bulwark":25.0}.get(e.kind,20.0)
		var forward := Vector2.from_angle(e.angle)
		var side := forward.orthogonal()
		for x in [-1,1]:
			for y in [-1,1]:
				var corner: Vector2 = e.pos+forward*length*x+side*width*y
				var points := PackedVector2Array([corner-forward*x*(6 if focused else 4),corner,corner-side*y*4])
				draw_polyline(points,Color(0.12,0.08,0.05,0.6),2.4,true)
				draw_polyline(points,Color(color,emphasis),0.9,true)

func draw_building(e: Dictionary) -> void:
	var d: Dictionary = sim.definition(e)
	var size_value := Vector2(d.footprint[0],d.footprint[1])*sim.grid.tile
	industrial_art.building(self,e,size_value,sim.team_color(e.owner),elapsed)

func draw_unit(e: Dictionary) -> void:
	var visual := e.duplicate()
	visual.pos+=combat_fx.hit_offset(e.id)
	industrial_art.vehicle(self,visual,sim.team_color(e.owner),sim.factions[e.owner],elapsed)

func _build_terrain_detail_mesh() -> void:
	terrain_detail_chunks.clear()
	solarit_detail_chunks.clear(); resource_detail_values.clear()
	var grid := sim.grid
	var chunks_x := ceili(float(grid.width)/DETAIL_CHUNK_SIZE)
	var chunks_y := ceili(float(grid.height)/DETAIL_CHUNK_SIZE)
	dirty_terrain_chunk_count=chunks_x*chunks_y
	for chunk_y in chunks_y:
		for chunk_x in chunks_x:
			var vertices := PackedVector3Array()
			var colors := PackedColorArray()
			var indices := PackedInt32Array()
			for y in range(chunk_y*DETAIL_CHUNK_SIZE,mini(grid.height,(chunk_y+1)*DETAIL_CHUNK_SIZE)):
				for x in range(chunk_x*DETAIL_CHUNK_SIZE,mini(grid.width,(chunk_x+1)*DETAIL_CHUNK_SIZE)):
					var cell := Vector2i(x,y)
					var terrain := grid.type_at(cell)
					var seed_value := x*37+y*71
					var region := Vector2i(x/8,y/8)
					# Sparse regional seams and old hardstand panels share the terrain mesh.
					if terrain in [1,4] and posmod(region.x*7+region.y*13,5)==0:
						var origin := Vector2(cell*grid.tile)
						if x%3==0:
							_append_detail_line(vertices,colors,indices,origin+Vector2(9,0),origin+Vector2(11,32),0.9,Color(0.12,0.09,0.06,0.26))
						if y%4==0:
							_append_detail_line(vertices,colors,indices,origin+Vector2(0,8),origin+Vector2(32,8),0.8,Color(0.63,0.51,0.36,0.16))
					if terrain==2:
						if seed_value%5==0:
							var grass_start := Vector2(cell*grid.tile)+Vector2(seed_value%28,(seed_value*17)%30)
							_append_detail_line(vertices,colors,indices,grass_start,grass_start+Vector2(8,1.4),0.7,Color(0.9,0.75,0.5,0.13))
						continue
					if terrain!=1 and terrain!=6: continue
					if terrain==1 and seed_value%5!=0: continue
					for i in (2 if terrain==6 else 1):
						var p := Vector2(cell*grid.tile)+Vector2((seed_value+i*13)%23,8+(seed_value+i*7)%20)
						var rock := PackedVector2Array([p,p+Vector2(4,-6),p+Vector2(11,-4),p+Vector2(14,2),p+Vector2(7,5)])
						var color := Color("77604a") if terrain==1 else Color("8f7352")
						for point_index in 5:
							_append_detail_triangle(vertices,colors,indices,p+Vector2(7,0),rock[point_index],rock[(point_index+1)%5],color)
						var highlight := p+Vector2(1,-1)
						_append_detail_line(vertices,colors,indices,highlight,highlight+Vector2(4,-4),0.8,Color("c8a372"))
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=vertices
			arrays[Mesh.ARRAY_COLOR]=colors
			arrays[Mesh.ARRAY_INDEX]=indices
			var mesh := ArrayMesh.new()
			if not vertices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			terrain_detail_chunks[Vector2i(chunk_x,chunk_y)]=mesh
			_build_solarit_detail_chunk(Vector2i(chunk_x,chunk_y))
	dirty_terrain_chunk_count=0

func _build_solarit_detail_chunk(chunk: Vector2i) -> void:
	var grid:=sim.grid
	var vertices:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	for y in range(chunk.y*DETAIL_CHUNK_SIZE,mini(grid.height,(chunk.y+1)*DETAIL_CHUNK_SIZE)):
		for x in range(chunk.x*DETAIL_CHUNK_SIZE,mini(grid.width,(chunk.x+1)*DETAIL_CHUNK_SIZE)):
			var cell:=Vector2i(x,y)
			if grid.type_at(cell)!=3: continue
			var key:=grid.key(cell)
			var remaining:=float(grid.resources.get(key,0.0))
			resource_detail_values[key]=remaining
			if remaining<=0.0: continue
			var seed_value:=x*37+y*71
			var depletion:=clampf(remaining/100.0,0.45,1.0)
			var tier:=0 if depletion<0.60 else (1 if depletion<0.88 else 2)
			var variation:=posmod(seed_value*17+x*y,4)
			var atlas_origin:=Vector2(variation*32,tier*32)
			var cell_origin:=Vector2(cell*grid.tile)
			var center := cell_origin+Vector2(16+sin(seed_value*1.7)*4.0,16+cos(seed_value*2.3)*4.0)
			var radius := 12.0+float(posmod(seed_value*13+x*y,9))*0.65
			var rotation := sin(seed_value*0.71)*0.32
			var first:=vertices.size()
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var p: Vector2=center+(corner*radius*Vector2(1.0,0.88+float(posmod(seed_value,4))*0.08)).rotated(rotation)
				vertices.append(Vector3(p.x,p.y,0))
			var atlas_size:=Vector2(solarit_atlas.get_width(),solarit_atlas.get_height())
			for uv in [atlas_origin,atlas_origin+Vector2(32,0),atlas_origin+Vector2(32,32),atlas_origin+Vector2(0,32)]: uvs.append(uv/atlas_size)
			var brightness := 0.88+float(posmod(seed_value*3,7))*0.025
			var tint:=Color(brightness,brightness,brightness,0.68+0.32*depletion)
			for _i in 4: colors.append(tint)
			indices.append_array(PackedInt32Array([first,first+1,first+2,first,first+2,first+3]))
	if vertices.is_empty():
		solarit_detail_chunks.erase(chunk)
		return
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	solarit_detail_chunks[chunk]=mesh

func _append_detail_triangle(vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var start := vertices.size()
	vertices.append(Vector3(a.x,a.y,0)); vertices.append(Vector3(b.x,b.y,0)); vertices.append(Vector3(c.x,c.y,0))
	colors.append(color); colors.append(color); colors.append(color)
	indices.append(start); indices.append(start+1); indices.append(start+2)

func _append_detail_line(vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var side := (b-a).orthogonal().normalized()*width*0.5
	var start := vertices.size()
	for point in [a-side,b-side,b+side,a+side]:
		vertices.append(Vector3(point.x,point.y,0)); colors.append(color)
	indices.append(start); indices.append(start+1); indices.append(start+2)
	indices.append(start); indices.append(start+2); indices.append(start+3)

func draw_fog_dust(from: Vector2i, to: Vector2i) -> void:
	# Atmospheric motion is visual only and never reveals hidden entities.
	for i in 24:
		var cell := Vector2i(maxi(0,from.x)+(i*17)%maxi(1,to.x-from.x),maxi(0,from.y)+(i*11)%maxi(1,to.y-from.y))
		if not sim.grid.inside(cell): continue
		var index := cell.y*sim.grid.width+cell.x
		if sim.explored[sim.view_owner][index]==0 or sim.fog[sim.view_owner][index]!=0: continue
		var p := Vector2(cell*sim.grid.tile)+Vector2(fposmod(elapsed*3+i*7,32),12)
		draw_line(p,p+Vector2(20,3),Color(0.69,0.47,0.29,0.045),2,true)

func smooth_polygon(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points,color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline,color,0.7,true)

func paint_circle(center: Vector2, radius: float, color: Color, filled: bool = true, point_count: int = -1, antialiased: bool = true) -> void:
	var segments:=clampi(point_count if point_count>0 else ceili(radius*2.0),12,48)
	if filled:
		var points:=PackedVector2Array()
		points.resize(segments)
		for i in segments:
			var angle:=TAU*float(i)/float(segments)
			points[i]=center+Vector2(cos(angle),sin(angle))*radius
		draw_colored_polygon(points,color)
	else:
		draw_arc(center,radius,0.0,TAU,segments,color,1.0,antialiased)

func glow_at(pos: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect(glow_texture,Rect2(pos-Vector2.ONE*radius,Vector2.ONE*radius*2),false,color)

func visual_event(kind: String, pos: Vector2) -> void:
	if kind=="complete":
		visual_bursts.append({"kind":"complete","pos":pos,"life":1.0,"duration":1.0})
		return
	if kind!="shot" or sim==null: return
	var angle := 0.0
	for e in sim.entities.values():
		if e.pos.distance_to(pos)<2:
			angle=e.turret
			break
	visual_bursts.append({"pos":pos+Vector2.from_angle(angle)*23,"angle":angle,"life":0.16,"duration":0.16})

func draw_modern_explosion(pos: Vector2, radius: float, age: float, detail_tier: int=0) -> void:
	var fade := 1.0-age
	append_impact_glow(pos,radius*(0.7+age),Color(1,0.48,0.13,fade*0.6))
	if age<0.25: append_impact_glow(pos,radius*0.7,Color(1,0.94,0.7,(1-age*4)*0.8))
	var spokes:=9 if detail_tier==0 else (7 if detail_tier==1 else 5)
	for i in spokes:
		var direction := Vector2.from_angle(i*2.39996+pos.x*0.01)
		var q := pos+direction*radius*age*(0.5+float(i%3)*0.3)
		var heat := Color("ffc275").lerp(Color("8a4a27"),age)
		append_impact_disc(q,radius*0.13*(1-age)+1,Color(heat,fade*0.85))
		if i%2==0:
			var smoke := q+Vector2(age*10,-age*radius*0.6)
			append_impact_disc(smoke,radius*(0.09+age*0.18),Color(0.13,0.15,0.17,sin(age*PI)*0.3))
		var spark := pos+direction*radius*age*1.4
		append_impact_line(spark,spark-direction*(2+radius*0.12*fade),Color(1,0.83,0.42,fade*fade))
	append_impact_arc(pos,radius*age*1.1,0,TAU,64 if detail_tier==0 else (48 if detail_tier==1 else 32),Color(0.9,0.8,0.6,fade*0.18))

func append_impact_disc(center: Vector2, radius: float, color: Color) -> void:
	var segments:=clampi(ceili(radius*1.5),12,32)
	var first:=impact_disc_vertices.size()
	impact_disc_vertices.append(Vector3(center.x,center.y,0)); impact_disc_colors.append(color)
	for i in segments:
		var angle:=TAU*float(i)/float(segments)
		var p:=center+Vector2(cos(angle),sin(angle))*radius
		impact_disc_vertices.append(Vector3(p.x,p.y,0)); impact_disc_colors.append(color)
	for i in segments: impact_disc_indices.append_array(PackedInt32Array([first,first+i+1,first+(i+1)%segments+1]))

func append_pixel_puff(center: Vector2, radius: float, color: Color, seed_value: float = 0.0) -> void:
	# Three stepped lobes share the existing colour mesh; no nodes or extra draw calls.
	var step := maxf(1.0,radius*0.24)
	var origin := (center/step).floor()*step
	for lobe in 3:
		var offset := Vector2(sin(seed_value+lobe*2.4),cos(seed_value*0.7+lobe*2.1))*radius*0.42
		var extent := Vector2(radius*(0.50+float(lobe%2)*0.18),radius*(0.38+float((lobe+1)%2)*0.20))
		var first := impact_disc_vertices.size()
		var tint := Color(color, color.a*(0.7 if lobe==2 else 1.0))
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var p: Vector2 = origin+offset+corner*extent
			p=(p/step).round()*step
			impact_disc_vertices.append(Vector3(p.x,p.y,0)); impact_disc_colors.append(tint)
		impact_disc_indices.append_array(PackedInt32Array([first,first+1,first+2,first,first+2,first+3]))

func append_impact_glow(center: Vector2, radius: float, color: Color) -> void:
	var first:=impact_glow_vertices.size()
	for p in [center+Vector2(-radius,-radius),center+Vector2(radius,-radius),center+Vector2(radius,radius),center+Vector2(-radius,radius)]:
		impact_glow_vertices.append(Vector3(p.x,p.y,0)); impact_glow_colors.append(color)
	impact_glow_uvs.append_array(PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]))
	impact_glow_indices.append_array(PackedInt32Array([first,first+1,first+2,first,first+2,first+3]))

func append_impact_line(from: Vector2, to: Vector2, color: Color, width: float=1.2) -> void:
	if width>2.5:
		impact_line_points_heavy.append(from); impact_line_points_heavy.append(to); impact_line_colors_heavy.append(color)
	elif width>1.3:
		impact_line_points_medium.append(from); impact_line_points_medium.append(to); impact_line_colors_medium.append(color)
	else:
		impact_line_points.append(from); impact_line_points.append(to); impact_line_colors.append(color)
func append_impact_polyline(points: PackedVector2Array, color: Color, width: float=1.2) -> void:
	for i in range(points.size()-1): append_impact_line(points[i],points[i+1],color,width)

func append_impact_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, segments: int, color: Color) -> void:
	var previous:=center+Vector2.from_angle(start_angle)*radius
	for i in range(1,segments+1):
		var angle:=lerpf(start_angle,end_angle,float(i)/float(segments))
		var current:=center+Vector2.from_angle(angle)*radius
		append_impact_line(previous,current,color); previous=current

func flush_impact_batch() -> void:
	if not impact_glow_vertices.is_empty():
		var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=impact_glow_vertices; arrays[Mesh.ARRAY_TEX_UV]=impact_glow_uvs
		arrays[Mesh.ARRAY_COLOR]=impact_glow_colors; arrays[Mesh.ARRAY_INDEX]=impact_glow_indices
		impact_glow_mesh.clear_surfaces(); impact_glow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		draw_mesh(impact_glow_mesh,glow_texture)
	if not impact_disc_vertices.is_empty():
		var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=impact_disc_vertices; arrays[Mesh.ARRAY_COLOR]=impact_disc_colors; arrays[Mesh.ARRAY_INDEX]=impact_disc_indices
		impact_disc_mesh.clear_surfaces(); impact_disc_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		draw_mesh(impact_disc_mesh,null)
	if not impact_line_points.is_empty(): draw_multiline_colors(impact_line_points,impact_line_colors,1.2,true)
	if not impact_line_points_medium.is_empty(): draw_multiline_colors(impact_line_points_medium,impact_line_colors_medium,2.0,true)
	if not impact_line_points_heavy.is_empty(): draw_multiline_colors(impact_line_points_heavy,impact_line_colors_heavy,4.0,true)
	impact_glow_vertices.clear(); impact_glow_uvs.clear(); impact_glow_colors.clear(); impact_glow_indices.clear()
	impact_disc_vertices.clear(); impact_disc_colors.clear(); impact_disc_indices.clear()
	impact_line_points.clear(); impact_line_colors.clear()
	impact_line_points_medium.clear(); impact_line_colors_medium.clear()
	impact_line_points_heavy.clear(); impact_line_colors_heavy.clear()


