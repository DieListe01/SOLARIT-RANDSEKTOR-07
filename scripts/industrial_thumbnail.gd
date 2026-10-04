extends Control
class_name IndustrialThumbnail

var sim: Simulation
var kind := "core"
var team_owner := 0
var entity_id := 0
var art := IndustrialArt.new()

func _draw() -> void:
	if sim==null: return
	var building := sim.db.buildings.has(kind)
	var e := {"owner":0,"kind":kind,"pos":Vector2(48,57),"complete":true,"hp":1.0,"max_hp":1.0,"angle":-0.4,"turret":-0.7,"cargo":120.0,"harvest_state":"IDLE"}
	if entity_id>0 and sim.entities.has(entity_id):
		e=sim.entities[entity_id].duplicate()
		e.pos=Vector2(48,57)
	else: e.owner=team_owner
	var color := sim.team_color(e.owner)
	if building:
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*0.46)
		art.building(self,e,Vector2(72,66),color,0.4)
	else:
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*0.8)
		e.pos=Vector2(28,29)
		art.vehicle(self,e,color,sim.factions[e.owner],0.4)
