extends Node2D
class_name VehicleCachePainter

var art: IndustrialArt
var entity: Dictionary
var team := Color.WHITE
var faction := "forge"
var sim: Simulation

func _draw() -> void:
	draw_set_transform(Vector2(128,128),0,Vector2.ONE*4.0)
	art.vehicle(self,entity,team,faction,0.0)
