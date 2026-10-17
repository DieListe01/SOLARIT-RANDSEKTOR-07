extends SceneTree

const CatalogScript := preload("res://scripts/catalog.gd")
const SimulationScript := preload("res://scripts/simulation.gd")
const WorldRendererScript := preload("res://scripts/world_renderer.gd")
const ProductionPreviewCacheScript := preload("res://scripts/production_preview_cache.gd")
const FACTIONS := ["forge", "drift", "lumen"]
const FRAME_COUNT := 600

var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("BUILDING STABILITY FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func _construction_stage(renderer: WorldRenderer, factory: Dictionary) -> int:
	var total := maxf(0.01, float(renderer.sim.definition(factory).time))
	var ratio := clampf(float(factory.get("build_progress", 0.0)) / total, 0.0, 1.0)
	return renderer._construction_stage_index(ratio)

func _cache_snapshot(renderer: WorldRenderer, factory: Dictionary) -> Dictionary:
	var snapshot: Dictionary = factory.duplicate(true)
	snapshot.unloading = false
	snapshot.building_animation_frame = renderer._building_animation_frame(factory)
	snapshot.construction_stage = 5 if bool(factory.get("complete", true)) else _construction_stage(renderer, factory)
	return snapshot

func _visible_pixel_difference(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size(): return 0
	var changed := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if maxf(maxf(absf(ca.r-cb.r), absf(ca.g-cb.g)), absf(ca.b-cb.b)) > 0.06:
				changed += 1
	return changed

func _normal_zoom_pose(texture: Texture2D) -> Image:
	# A 640 px factory cache is drawn as a 256-world-unit sprite. At the fixture's
	# 1.25 RTS zoom in a 1920 px viewport, this is the corresponding screen scale.
	# Crop to the authored model alpha bounds before downsampling so unrelated
	# transparent pixels cannot inflate the animation score.
	if texture == null: return null
	var image := texture.get_image()
	if image == null: return null
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0: return null
	var cropped := image.get_region(used)
	var target_size := Vector2i(maxi(1,roundi(float(used.size.x)*0.4923)),maxi(1,roundi(float(used.size.y)*0.4923)))
	cropped.resize(target_size.x,target_size.y,Image.INTERPOLATE_LANCZOS)
	return cropped

func _warm_pose(renderer: WorldRenderer, factory: Dictionary, faction: String) -> String:
	var snapshot := _cache_snapshot(renderer, factory)
	var key := renderer.building_cache_key(factory)
	var reconstructed := renderer._building_snapshot_cache_key(snapshot, faction)
	check(reconstructed == key, "%s prewarm snapshot reconstructs its exact pose key" % faction)
	if reconstructed != key: return ""
	renderer.building_cache_pending[key] = true
	await renderer._build_building_texture(key, snapshot, renderer.sim.team_color(int(factory.owner)), faction)
	var texture: Texture2D = renderer.building_texture_cache.get(key)
	check(texture != null, "%s authored factory pose was rendered before the 600-frame measurement" % faction)
	check(texture != null and renderer._building_cache_entry_valid(key, texture, "factory", int(factory.owner), faction), "%s cached factory pose retains its model/faction identity" % faction)
	if texture != null and faction not in ["forge", "drift", "lumen"]:
		check(false, "Unexpected factory faction in visual capture: %s" % faction)
	var is_completed_idle: bool=bool(factory.get("complete", false)) and (factory.get("queue", []) as Array).is_empty() and not factory.has("production_exit_unit")
	if texture != null and is_completed_idle and not renderer.get_meta("building_stability_texture_checked", false):
		var baked_image := texture.get_image()
		var used := baked_image.get_used_rect() if baked_image != null else Rect2i()
		var sampled_colors: Dictionary={}
		if baked_image != null:
			for y in range(0,baked_image.get_height(),8):
				for x in range(0,baked_image.get_width(),8):
					var color:=baked_image.get_pixel(x,y)
					if color.a>0.05: sampled_colors[color]=true
		check(baked_image != null and used.get_area() > 256 and sampled_colors.size() > 20, "%s idle factory image contains a detailed rendered model; used rect %s, sampled colors %d" % [faction, str(used), sampled_colors.size()])
		if baked_image != null:
			var capture_path := "res://test-output/building_cache_idle_%s.png" % faction
			baked_image.save_png(ProjectSettings.globalize_path(capture_path))
		renderer.set_meta("building_stability_texture_checked", true)
	return key

func _save_capture(path: String) -> void:
	var texture := get_root().get_texture()
	if texture == null:
		check(false, "Full-HD review frame is available")
		return
	var image := texture.get_image()
	check(image != null and image.get_width() == 1920 and image.get_height() == 1080, "Factory review image is rendered at 1920x1080")
	if image != null:
		var absolute_path := ProjectSettings.globalize_path(path)
		image.save_png(absolute_path)

func _save_factory_sequence_frame(renderer: WorldRenderer, factory: Dictionary, faction: String, state: String, frame: int) -> void:
	var key := renderer.building_cache_key(factory)
	var texture: Texture2D = renderer.building_texture_cache.get(key)
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.get_width() != 640 or image.get_height() != 640:
		check(false,"%s %s adjacent factory frame %d resolves exact 640x640 pose (key=%s texture=%s size=%s)"%[faction,state,frame,key,str(texture),str(image.get_size() if image!=null else Vector2i.ZERO)])
		return
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		check(false,"%s %s factory pose has visible authored pixels"%[faction,state,frame])
		return
	image=image.get_region(used)
	image.resize(maxi(1,roundi(float(used.size.x)*0.4923)),maxi(1,roundi(float(used.size.y)*0.4923)),Image.INTERPOLATE_LANCZOS)
	var sequence_dir := "res://test-output/factory_gameplay_review/%s" % faction
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sequence_dir))
	var path := ProjectSettings.globalize_path(sequence_dir.path_join("%s_%04d.png" % [state,frame]))
	check(image.save_png(path)==OK,"%s %s normal-zoom-equivalent adjacent factory frame %d is saved" % [faction,state,frame])

func _save_pose_capture(renderer: WorldRenderer, factory: Dictionary, path: String) -> void:
	var key:=renderer.building_cache_key(factory)
	var texture:Texture2D=renderer.building_texture_cache.get(key)
	check(texture!=null,"Pose contact-sheet entry exists for %s" % path)
	if texture==null: return
	var image:=texture.get_image()
	check(image!=null and image.get_width()==640 and image.get_height()==640,"Pose contact-sheet entry is a complete 640x640 baked building pose")
	if image!=null: image.save_png(ProjectSettings.globalize_path(path))

func _warm_core_poses(renderer: WorldRenderer, core: Dictionary, faction: String) -> Dictionary:
	var allowed: Dictionary={}
	var saved_elapsed:=renderer.elapsed
	for animation_frame in 8:
		renderer.elapsed=float(animation_frame)+0.01
		var snapshot:=_cache_snapshot(renderer,core)
		var key:=renderer.building_cache_key(core)
		check(renderer._building_snapshot_cache_key(snapshot,faction)==key,"%s core prewarm snapshot reconstructs animation pose %d" % [faction,animation_frame])
		renderer.building_cache_pending[key]=true
		await renderer._build_building_texture(key,snapshot,renderer.sim.team_color(int(core.owner)),faction)
		var texture:Texture2D=renderer.building_texture_cache.get(key)
		check(texture!=null and renderer._building_cache_entry_valid(key,texture,"core",int(core.owner),faction),"%s core animation pose %d was rendered and retained with exact identity" % [faction,animation_frame])
		allowed[key]=true
	renderer.elapsed=saved_elapsed
	return allowed

func _core_render_signature(renderer: WorldRenderer, core: Dictionary) -> PackedByteArray:
	var image:=get_root().get_texture().get_image()
	check(image!=null and image.get_width()==1920 and image.get_height()==1080,"Placement-overlap capture uses the Full-HD root viewport")
	if image==null: return PackedByteArray()
	var ratio:=float(image.get_width())/1560.0
	var scale_value:=1.25*ratio
	var center:Vector2=Vector2(image.get_width(),image.get_height())*0.5+(core.pos-renderer.camera)*scale_value
	var rect:Rect2i=Rect2i(Vector2i(roundi(center.x)-190,roundi(center.y)-190),Vector2i(380,380))
	rect=rect.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	check(rect.size.x>0 and rect.size.y>0,"Core model lies inside the placement stability capture")
	return image.get_region(rect).get_data() if rect.size.x>0 and rect.size.y>0 else PackedByteArray()

func _placement_render_region(renderer: WorldRenderer, sim: Simulation, cell: Vector2i, rotation: int, label: String) -> Dictionary:
	var image:=get_root().get_texture().get_image()
	check(image!=null and image.get_width()==1920 and image.get_height()==1080,"%s placement preview is captured in Full HD" % label)
	if image==null: return {}
	var footprint:=sim.building_footprint("factory",rotation)
	var world_center:=Vector2(cell*sim.grid.tile)+Vector2(footprint[0],footprint[1])*sim.grid.tile*0.5
	var scale_value:=renderer.zoom*float(image.get_width())/1560.0
	var screen_center:=Vector2(image.get_width(),image.get_height())*0.5+(world_center-renderer.camera)*scale_value
	var region:=Rect2i(Vector2i(roundi(screen_center.x)-250,roundi(screen_center.y)-280),Vector2i(500,560))
	region=region.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	check(region.size==Vector2i(500,560),"%s placement preview crop remains fully inside the Full-HD image" % label)
	if region.size!=Vector2i(500,560): return {}
	return {"pixels":image.get_region(region).get_data(),"image":image.get_region(region),"rect":region}

func _check_placement_ghost_stability(renderer: WorldRenderer, sim: Simulation, faction: String) -> void:
	# Keep a valid preview near the center of the camera, distinct from both
	# already placed structures. With simulation and visual time held, the same
	# ghost must remain the same image on every adjacent rendered frame.
	var cell:=Vector2i(40,36)
	var rotation:=0
	var footprint:=sim.building_footprint("factory",rotation)
	var ghost_rect:=Rect2(Vector2(cell*sim.grid.tile),Vector2(footprint[0],footprint[1])*sim.grid.tile)
	for entity in sim.entities.values():
		if entity.building:
			var existing_rect:=Rect2(entity.pos-Vector2(48,48),Vector2(96,96))
			check(not ghost_rect.intersects(existing_rect),"%s dedicated stable-preview cell is separate from placed buildings" % faction)
	renderer.visual_paused=true
	renderer.elapsed=0.01
	var heat_was_visible:=renderer.heat_layer.visible
	renderer.heat_layer.visible=false
	renderer.placement=""
	renderer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var baseline:=_placement_render_region(renderer,sim,cell,rotation,"%s no-preview baseline" % faction)
	renderer.placement="factory"
	renderer.placement_rotation=rotation
	renderer.placement_cell=cell
	renderer.placement_cell_valid=true
	renderer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var first:=_placement_render_region(renderer,sim,cell,rotation,"%s first placement frame" % faction)
	check(not baseline.is_empty() and not first.is_empty(),"%s has valid baseline and preview image crops" % faction)
	if not baseline.is_empty() and not first.is_empty():
		check(baseline.pixels!=first.pixels,"%s placement preview visibly changes its own world region" % faction)
		(first.image as Image).save_png(ProjectSettings.globalize_path("res://test-output/building_preview_%s.png" % faction))
		var stable_pixels: PackedByteArray=first.pixels
		for sample in 5:
			renderer.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var adjacent:=_placement_render_region(renderer,sim,cell,rotation,"%s adjacent preview frame %d" % [faction,sample+1])
			check(not adjacent.is_empty() and adjacent.pixels==stable_pixels,"%s placement preview frame %d is pixel-stable with unchanged input" % [faction,sample+1])
	renderer.placement=""
	renderer.placement_cell_valid=false
	renderer.heat_layer.visible=heat_was_visible

func _check_placement_overlay_stability(renderer: WorldRenderer, sim: Simulation, core: Dictionary, core_id: int, factory: Dictionary, allowed_core_keys: Dictionary, faction: String) -> void:
	var idle_factory:=renderer.building_cache_key(factory)
	check(renderer.building_texture_cache.has(idle_factory),"%s factory pose is warm before placement preview sampling" % faction)
	renderer.visual_paused=true
	renderer.elapsed=0.01
	# The full-screen heat shimmer uses shader TIME and changes unrelated pixels
	# between captures; keep it out of this building-only pixel comparison.
	var heat_was_visible:=renderer.heat_layer.visible
	renderer.heat_layer.visible=false
	renderer.placement=""
	renderer.building_visual_event_log.clear()
	renderer.visible=true
	renderer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var baseline:=_core_render_signature(renderer,core)
	check(not baseline.is_empty(),"%s core baseline frame was captured" % faction)
	# A newly selected build item must not draw its previous hover cell while
	# the pointer has not yet supplied a valid battlefield coordinate.
	renderer.placement="factory"
	renderer.placement_cell=sim.grid.cell(core.pos)
	renderer.placement_cell_valid=false
	var stale_event_start:=renderer.building_visual_event_log.size()
	renderer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var stale_signature:=_core_render_signature(renderer,core)
	check(stale_signature==baseline,"%s newly selected placement does not draw its stale previous cell over the core" % faction)
	var stale_suppressed:=false
	for event_index in range(stale_event_start,renderer.building_visual_event_log.size()):
		var event:Dictionary=renderer.building_visual_event_log[event_index]
		if str(event.get("event",""))=="placement_preview_suppressed_invalid_cell" and str(event.get("kind",""))=="factory": stale_suppressed=true
	check(stale_suppressed,"%s placement diagnostics explain that the stale-cell preview was suppressed" % faction)
	var placement_cells: Array[Vector2i]=[Vector2i(45,30),Vector2i(45,46),Vector2i(19,30),Vector2i(19,46)]
	for index in placement_cells.size():
		renderer.placement="factory"
		renderer.placement_rotation=index%4
		renderer.placement_cell=placement_cells[index]
		renderer.placement_cell_valid=true
		var core_rect:=Rect2(core.pos-Vector2(48,48),Vector2(96,96))
		var footprint:=sim.building_footprint("factory",renderer.placement_rotation)
		var placement_rect:=Rect2(Vector2(renderer.placement_cell*sim.grid.tile),Vector2(footprint[0],footprint[1])*sim.grid.tile)
		check(not core_rect.intersects(placement_rect),"%s placement sample %d is physically separate from the core" % [faction,index])
		renderer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var signature:=_core_render_signature(renderer,core)
		check(signature==baseline,"%s placement preview at cell %s does not change core-region pixels" % [faction,str(renderer.placement_cell)])
		var observed: Dictionary={}
		for event in renderer.building_visual_event_log:
			if int(event.get("entity_id",0))==core_id: observed=event
		check(not observed.is_empty(),"%s core diagnostic exists while factory placement preview is visible" % faction)
		if not observed.is_empty():
			var key:=str(observed.get("cache_key",""))
			check(bool(observed.get("cache_hit",false)) and str(observed.get("fallback_reason",""))=="exact_cache_hit","%s placement sample %d keeps the core on its exact warmed cache pose" % [faction,index])
			check(allowed_core_keys.has(key) and str(observed.get("chosen_cache_key",""))==key,"%s placement sample %d cannot substitute the factory pose for the core" % [faction,index])
	renderer.placement=""
	renderer.placement_cell_valid=false
	renderer.heat_layer.visible=heat_was_visible

func run() -> void:
	var viewport_size := get_root().size
	check(viewport_size == Vector2i(1920, 1080), "Building stability scene runs in Full HD; got %s" % str(viewport_size))
	var base_catalog := CatalogScript.new("res://data/veyra.json")
	var image_root := ProjectSettings.globalize_path("res://test-output")
	DirAccess.make_dir_recursive_absolute(image_root)
	var captures := {0: "idle", 60: "production_start", 180: "assembly_55", 300: "assembly_86", 420: "assembly_95", 480: "gate_release", 481: "vehicle_exit_started", 500: "vehicle_exit_motion", 540: "next_queue", 560: "foundation", 570: "frame", 580: "mounting", 590: "commissioning"}

	for faction_value in FACTIONS:
		var faction := str(faction_value)
		var sim := SimulationScript.new(base_catalog, faction)
		sim.view_owner = 0
		var origin := sim.grid.center(Vector2i(32, 38))
		var core_id: int=sim.spawn("core",0,origin-Vector2(192.0,0.0),true)
		var core: Dictionary=sim.entities[core_id]
		var factory_id: int = sim.spawn("factory", 0, origin, true)
		var factory: Dictionary = sim.entities[factory_id]
		var renderer: WorldRenderer = WorldRendererScript.new()
		renderer.sim = sim
		renderer.logical_size = Vector2(1560, 960)
		renderer.camera = factory.pos
		renderer.zoom = 1.25
		renderer.visual_paused = true
		renderer.visible = false
		root.add_child(renderer)
		await process_frame
		# The production exit uses the mission-warmed, GPU-resident preview texture.
		# Warm the four cardinal tank headings used by factory rotations only.
		var preview_cache = ProductionPreviewCacheScript.new()
		preview_cache.sim = sim
		renderer.add_child(preview_cache)
		renderer.production_preview_cache = preview_cache
		for heading in 4:
			var angle := float(heading) * TAU / 4.0
			var preview_key := preview_cache._cache_key("tank",0,angle)
			preview_cache.viewports[preview_key] = preview_cache._create_view("tank",0,angle)
			await RenderingServer.frame_post_draw
		sim.update_fog()
		# This isolated renderer scene has no moving scouts or core placed near the
		# test factory. Reveal the map so fog does not hide the very building whose
		# cache identity and rendered appearance are under inspection.
		sim.explored[0].fill(1)
		sim.fog[0].fill(1)
		var allowed_core_keys:=await _warm_core_poses(renderer,core,faction)
		check(allowed_core_keys.size()==8,"%s build core uses eight explicit, reusable illumination/animation poses" % faction)

		# Pre-render the exact construction and working poses used in the run. A
		# cache miss during the sampled frames therefore indicates a key/state bug,
		# not normal cold-cache setup.
		var allowed_keys: Dictionary = {}
		factory.complete = false
		factory.queue.clear()
		var building_time := maxf(0.01, float(sim.definition(factory).time))
		for ratio in [0.20, 0.50, 0.80, 0.95]:
			factory.build_progress = building_time * float(ratio)
			var stage_key := await _warm_pose(renderer, factory, faction)
			allowed_keys[stage_key] = true
		factory.complete = true
		factory.queue = [{"kind": "tank", "paid": 0}]
		var unit_time := maxf(0.01, float(sim.db.units.tank.time))
		var active_factory_keys: Array[String] = []
		for animation_frame in 4:
			renderer.elapsed = float(animation_frame) * 0.5 + 0.05
			factory.progress = unit_time * [0.10, 0.55, 0.86, 0.95][animation_frame]
			var production_key := await _warm_pose(renderer, factory, faction)
			active_factory_keys.append(production_key)
			allowed_keys[production_key] = true
		factory.queue.clear()
		factory.progress = 0.0
		renderer.elapsed = 0.0
		var idle_key := await _warm_pose(renderer, factory, faction)
		allowed_keys[idle_key] = true
		check(allowed_keys.size() == 9, "%s factory has cached poses for four construction, four working and idle phases" % faction)
		var idle_image := (renderer.building_texture_cache[idle_key] as Texture2D).get_image()
		var idle_screen_scale_pose := _normal_zoom_pose(renderer.building_texture_cache[idle_key] as Texture2D)
		var previous_active_image: Image
		for animation_frame in active_factory_keys.size():
			var active_image := (renderer.building_texture_cache[active_factory_keys[animation_frame]] as Texture2D).get_image()
			var visible_motion := _visible_pixel_difference(idle_image, active_image)
			check(visible_motion > 600, "%s factory production pose %d visibly moves its machinery at cache scale (%d changed samples)" % [faction, animation_frame, visible_motion])
			if previous_active_image != null:
				var phase_motion := _visible_pixel_difference(previous_active_image, active_image)
				check(phase_motion > 250, "%s factory production phase %d visibly progresses from the prior pose (%d changed samples)" % [faction, animation_frame, phase_motion])
			previous_active_image = active_image
		check(renderer.building_cache_queue.is_empty() and renderer.building_cache_pending.is_empty(), "%s factory has no pending cache work before measurement" % faction)

		factory.queue.clear()
		factory.progress = 0.0
		factory.erase("production_exit_unit")
		factory.hp = factory.max_hp
		renderer.elapsed = 0.0
		var exit_unit_id := 0
		var exit_started_position := Vector2.ZERO
		var exit_moved := false
		var exit_completed := false
		renderer.building_visual_diagnostics_enabled = true
		renderer.building_visual_event_log.clear()
		renderer.visible = true
		for local_frame in FRAME_COUNT:
			var frame := int(local_frame)
			if frame < 60:
				factory.complete = true
				factory.queue.clear()
				factory.progress = 0.0
				factory.erase("production_exit_unit")
			elif frame < 120:
				factory.complete = true
				factory.queue = [{"kind": "tank", "paid": 0}]
				factory.progress = unit_time * 0.10
				factory.erase("production_exit_unit")
			elif frame < 240:
				factory.complete = true
				factory.queue = [{"kind": "tank", "paid": 0}]
				factory.progress = unit_time * 0.55
				factory.erase("production_exit_unit")
			elif frame < 360:
				factory.complete = true
				factory.queue = [{"kind": "tank", "paid": 0}]
				factory.progress = unit_time * 0.86
				factory.erase("production_exit_unit")
			elif frame < 480:
				factory.complete = true
				factory.queue = [{"kind": "tank", "paid": 0}]
				factory.progress = unit_time * 0.95
				factory.erase("production_exit_unit")
			elif frame == 480:
				factory.complete = true
				factory.queue = [{"kind":"tank","paid":0}]
				factory.progress = unit_time * 0.95
				sim.process_building(factory,maxf(0.2,unit_time*0.2))
				exit_unit_id = int(factory.get("production_exit_unit",0))
				if sim.entities.has(exit_unit_id): exit_started_position = sim.entities[exit_unit_id].pos
				check(exit_unit_id > 0 and sim.entities.has(exit_unit_id) and bool(sim.entities[exit_unit_id].get("production_exit_active",false)), "%s actual factory completion creates a live unit in its visible exit sequence" % faction)
			elif frame < 540:
				if exit_unit_id > 0 and sim.entities.has(exit_unit_id):
					var exit_unit: Dictionary = sim.entities[exit_unit_id]
					var old_position: Vector2 = exit_unit.pos
					if bool(exit_unit.get("production_exit_active",false)): sim.move_unit(exit_unit,1.0/60.0)
					if exit_unit.pos.distance_to(old_position) > 0.1: exit_moved = true
					if not bool(exit_unit.get("production_exit_active",false)): exit_completed = true
					sim.process_building(factory,0.0)
			else:
				factory.complete = true
				factory.erase("production_exit_unit")
				factory.queue = [{"kind": "scout", "paid": 0}]
				factory.progress = float(sim.db.units.scout.time) * 0.10
			if frame >= 300 and frame < 360:
				factory.hp = factory.max_hp * 0.40
			elif frame >= 360 and frame < 420:
				factory.hp = factory.max_hp * 0.20
			else:
				factory.hp = factory.max_hp
			# During the final sample window, force the four construction poses in
			# turn; each one was warmed and validated before gameplay frames began.
			if frame >= 560:
				factory.complete = false
				factory.queue.clear()
				factory.erase("production_exit_unit")
				factory.build_progress = building_time * [0.20, 0.50, 0.80, 0.95][(frame - 560) / 10 % 4]
			if frame >= 120 and frame < 144:
				renderer.elapsed=float(frame-120)/12.0
			elif frame >= 360 and frame < 384:
				renderer.elapsed=float(frame-360)/12.0
			elif frame >= 480 and frame < 504:
				renderer.elapsed=float(frame-480)/12.0
			else:
				renderer.elapsed = float(frame) / 60.0
			renderer.camera = factory.pos
			var event_start := renderer.building_visual_event_log.size()
			renderer.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var observed: Dictionary = {}
			for event_index in range(event_start, renderer.building_visual_event_log.size()):
				var event: Dictionary = renderer.building_visual_event_log[event_index]
				if int(event.get("entity_id", 0)) == factory_id:
					observed = event
			check(not observed.is_empty(), "%s rendered a factory diagnostic event on sample frame %d" % [faction, frame])
			if not observed.is_empty():
				var key := str(observed.get("cache_key", ""))
				check(bool(observed.get("cache_hit", false)) and str(observed.get("fallback_reason", "")) == "exact_cache_hit", "%s frame %d uses its exact warmed pose, never an unrelated fallback" % [faction, frame])
				check(str(observed.get("chosen_cache_key", "")) == key and allowed_keys.has(key), "%s frame %d keeps a same-faction factory identity through state change" % [faction, frame])
				var texture: Texture2D = renderer.building_texture_cache.get(key)
				check(renderer._building_cache_entry_valid(key, texture, "factory", 0, faction), "%s frame %d texture metadata matches the requested factory/faction" % [faction, frame])
				check(str(observed.get("actual_model_path", "")).ends_with("factory.glb"), "%s frame %d draws an authored factory GLB" % [faction, frame])
			if captures.has(frame):
				await _save_capture("res://test-output/building_stability_%s_%s.png" % [faction, str(captures[frame])])
				await _save_pose_capture(renderer,factory,"res://test-output/building_pose_%s_%s.png" % [faction,str(captures[frame])])
			if frame < 24:
				await _save_factory_sequence_frame(renderer,factory,faction,"idle",frame)
			elif frame >= 120 and frame < 144:
				await _save_factory_sequence_frame(renderer,factory,faction,"production",frame-120)
			elif frame >= 360 and frame < 384:
				await _save_factory_sequence_frame(renderer,factory,faction,"near_complete",frame-360)
			elif frame >= 480 and frame < 504:
				await _save_factory_sequence_frame(renderer,factory,faction,"exit",frame-480)
		for animation_frame in active_factory_keys.size():
			var phase_image := _normal_zoom_pose(renderer.building_texture_cache[active_factory_keys[animation_frame]] as Texture2D)
			var scaled_difference := _visible_pixel_difference(idle_screen_scale_pose,phase_image)
			check(scaled_difference > 120, "%s production pose %d remains visibly distinct after normal RTS-zoom downsampling (%d changed samples)" % [faction,animation_frame,scaled_difference])
			print("FACTORY_NORMAL_ZOOM faction=%s phase=%d changed_samples=%d threshold=120" % [faction,animation_frame,scaled_difference])
		check(renderer.building_cache_queue.is_empty() and renderer.building_cache_pending.is_empty(), "%s has zero cold pose builds during its 600 sampled frames" % faction)
		check(exit_moved, "%s completed vehicle visibly moves from the factory door during the rendered exit window" % faction)
		check(exit_completed, "%s completed vehicle clears the door and leaves the production handoff state" % faction)
		check(renderer.building_visual_event_log.size() >= FRAME_COUNT - 1, "%s produced per-frame diagnostic coverage for its 600-frame run" % faction)
		await _check_placement_overlay_stability(renderer,sim,core,core_id,factory,allowed_core_keys,faction)
		await _check_placement_ghost_stability(renderer,sim,faction)
		renderer.building_visual_diagnostics_enabled = false
		renderer.queue_free()
		await process_frame

	if failures.is_empty():
		print("BUILDING VISUAL STABILITY: %d checks, 0 failures; three faction factories rendered for %d frames each at 1920x1080" % [checks, FRAME_COUNT])
		quit(0)
	else:
		printerr("BUILDING VISUAL STABILITY: %d checks, %d failures" % [checks, failures.size()])
		quit(1)
