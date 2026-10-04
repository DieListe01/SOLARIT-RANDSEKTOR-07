extends Node2D
class_name BuildingCachePainter

var art: IndustrialArt
var entity: Dictionary
var team := Color.WHITE
var faction := "forge"
var sim: Simulation

func _draw() -> void:
	# Keep the building pivot at the center of the 256px cache. This leaves room
	# for tall machinery and its directional shadow without clipping the artwork.
	draw_set_transform(Vector2(256,256),0,Vector2.ONE*2.0)
	var footprint: Array=sim.definition(entity).footprint
	art.building(self,entity,Vector2(footprint[0],footprint[1])*sim.grid.tile,team,0.0)
