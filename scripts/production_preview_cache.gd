extends Node
class_name ProductionPreviewCache

const VehiclePainter := preload("res://scripts/vehicle_cache_painter.gd")

var sim: Simulation
var viewports: Dictionary = {}
var created_view_count := 0
var readback_count := 0
var warmed := false

## Requests are lookup-only during play. Missing views are never rendered on a
## production or combat frame; prewarm_all() fills the finite catalog at load.
func texture_for(kind: String, owner: int, angle: float) -> Texture2D:
	if sim == null or not sim.db.units.has(kind) or owner<0 or owner>=sim.factions.size(): return null
	var key := _cache_key(kind,owner,angle)
	var viewport := viewports.get(key) as SubViewport
	if viewport == null or not is_instance_valid(viewport): return null
	return viewport.get_texture()

## Bake the bounded production catalog while mission loading is still paused.
## Four chassis headings cover every factory rotation; all vehicle roles and
## active player factions are included. Viewports render once and remain GPU
## resident. No readback is used at any stage.
func prewarm_all() -> void:
	if sim == null: return
	var batch := 0
	for owner in sim.factions.size():
		for kind_value in sim.db.units.keys():
			var kind := str(kind_value)
			for direction in 4:
				var heading_angle := float(direction)*TAU/4.0
				var key := _cache_key(kind,owner,heading_angle)
				if not viewports.has(key):
					var viewport := _create_view(kind,owner,heading_angle)
					if viewport != null:
						viewports[key] = viewport
						created_view_count += 1
				batch += 1
				if batch >= 4:
					batch = 0
					await get_tree().process_frame
	await get_tree().process_frame
	warmed = true

func _cache_key(kind: String, owner: int, angle: float) -> String:
	var faction := str(sim.factions[owner])
	var heading := posmod(roundi(angle*4.0/TAU),4)
	var color_key := sim.team_color(owner).to_html(false)
	return "%s|%s|%d|%s|%d" % [kind,faction,owner,color_key,heading]

func _create_view(kind: String, owner: int, angle: float) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "Production preview %s %d" % [kind,owner]
	viewport.size = Vector2i(256,256)
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var definition: Dictionary = sim.db.units[kind]
	var snapshot := {"id":-80000-owner,"kind":kind,"owner":owner,"building":false,"pos":Vector2.ZERO,"hp":float(definition.health)*float(sim.db.factions[sim.factions[owner]].health),"max_hp":float(definition.health)*float(sim.db.factions[sim.factions[owner]].health),"angle":angle,"turret":angle,"path":[],"destination":Vector2.ZERO,"order":"guard","target":0,"reload":0.0,"queue":[],"progress":0.0,"complete":true,"build_progress":0.0,"rally":Vector2.ZERO,"cargo":0.0,"harvest_state":"IDLE","resource":"","repair":false,"stuck":0.0,"last_pos":Vector2.ZERO,"path_pending":false,"velocity":Vector2.ZERO,"drive_frame":0,"animation_frame_count":4,"visual_animation_state":0,"visual_cargo_state":0,"visual_damage_state":0}
	var painter := VehiclePainter.new()
	painter.art = IndustrialArt.new()
	painter.entity = snapshot
	painter.team = sim.team_color(owner)
	painter.faction = str(sim.factions[owner])
	painter.sim = sim
	viewport.add_child(painter)
	add_child(viewport)
	return viewport
