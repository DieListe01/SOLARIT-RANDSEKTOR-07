extends SceneTree

const VehiclePainter=preload("res://scripts/vehicle_cache_painter.gd")

func _initialize() -> void:
	print("Starting authored harvester pose preview")
	call_deferred("run")

func capture_pose(name_value: String, state: int, frame: int, cargo: int, damage: int) -> Image:
	var painter=VehiclePainter.new()
	painter.art=IndustrialArt.new()
	painter.entity={"id":1,"kind":"harvester","owner":0,"hp":1000.0,"max_hp":1000.0,"angle":-0.42,"turret":0.0,"cargo":cargo*125.0,"harvest_state":"HARVEST" if state==1 else ("UNLOAD" if state==2 else "IDLE"),"drive_frame":frame,"visual_animation_state":state,"animation_frame_count":4,"visual_cargo_state":cargo,"visual_damage_state":damage,"velocity":Vector2.ZERO}
	painter.team=Color("69d6c0")
	painter.faction="forge"
	root.add_child(painter)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	assert(image!=null and not image.is_empty(),"the authored %s pose should render through the in-game vehicle cache painter"%name_value)
	var directory:=DirAccess.open("res://test-output")
	if directory==null: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-output"))
	image.save_png("res://test-output/harvester_"+name_value+".png")
	painter.queue_free()
	await process_frame
	return image

func pose_difference(a: Image, b: Image) -> float:
	var area:=Rect2i(620,240,700,640).intersection(Rect2i(Vector2i.ZERO,a.get_size()))
	var total:=0.0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var pa:=a.get_pixel(x,y); var pb:=b.get_pixel(x,y)
			total+=(absf(pa.r-pb.r)+absf(pa.g-pb.g)+absf(pa.b-pb.b))/3.0
	return total/maxf(1.0,float(area.size.x*area.size.y))

func run() -> void:
	print("Loading harvester cache preview poses")
	var idle:=await capture_pose("idle",0,0,4,0)
	var moving:=await capture_pose("moving",3,1,4,0)
	var harvesting:=await capture_pose("harvesting",1,1,4,0)
	var unloading:=await capture_pose("unloading",2,2,4,0)
	var movement_change:=pose_difference(idle,moving)
	var harvest_change:=pose_difference(idle,harvesting)
	var unload_change:=pose_difference(idle,unloading)
	assert(movement_change>0.001,"the imported Move clip must visibly change the rendered vehicle pose")
	assert(harvest_change>0.001,"the rotary cutter and conveyor must visibly change during Harvest")
	assert(unload_change>0.001,"the articulated work head must visibly change during Unload")
	print("Rendered pose differences from idle: Move %.4f, Harvest %.4f, Unload %.4f"%[movement_change,harvest_change,unload_change])
	print("Authored harvester Idle/Move/Harvest/Unload rendered in the real VehicleCachePainter SubViewport.")
	quit()
