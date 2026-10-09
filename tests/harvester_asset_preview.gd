extends SceneTree

const VehiclePainter=preload("res://scripts/vehicle_cache_painter.gd")
const FRAME_COUNT:=8
const HEADING_COUNT:=32
const TILE_SIZE:=128
const CROP:=Rect2i(620,240,700,640)

func _initialize() -> void:
	print("Rendering H09 turntable and eight-phase animation contact sheet")
	call_deferred("run")

func capture_pose(name_value: String, state: int, frame: int, cargo: int, damage: int, heading: int=-1) -> Image:
	var painter=VehiclePainter.new()
	painter.art=IndustrialArt.new()
	var angle:float=-0.42 if heading<0 else TAU*float(heading)/float(HEADING_COUNT)
	painter.entity={"id":1,"kind":"harvester","owner":0,"hp":1000.0,"max_hp":1000.0,"angle":angle,"turret":0.0,"cargo":cargo*125.0,"harvest_state":"HARVEST" if state==1 else ("UNLOAD" if state==2 else "IDLE"),"drive_frame":frame,"visual_animation_state":state,"animation_frame_count":FRAME_COUNT,"visual_cargo_state":cargo,"visual_damage_state":damage,"velocity":Vector2.ZERO}
	painter.team=Color("69d6c0")
	painter.faction="forge"
	root.add_child(painter)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	assert(image!=null and not image.is_empty(),"the authored %s pose should render through the in-game vehicle cache painter"%name_value)
	painter.queue_free()
	await process_frame
	return image

func crop_pose(image: Image) -> Image:
	var tile:=image.get_region(CROP)
	tile.resize(TILE_SIZE,TILE_SIZE,Image.INTERPOLATE_LANCZOS)
	return tile

func pose_difference(a: Image, b: Image) -> float:
	var left:=crop_pose(a)
	var right:=crop_pose(b)
	var total:=0.0
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var pa:=left.get_pixel(x,y); var pb:=right.get_pixel(x,y)
			total+=(absf(pa.r-pb.r)+absf(pa.g-pb.g)+absf(pa.b-pb.b))/3.0
	return total/float(TILE_SIZE*TILE_SIZE)

func difference_from_idle(idle: Image, frames: Array[Image]) -> float:
	var maximum:=0.0
	for frame in frames:
		maximum=maxf(maximum,pose_difference(idle,frame))
	return maximum

func save_contact_sheet(heading_rows: Array[Array], animation_rows: Array[Array]) -> void:
	var rows:Array[Array]=[]
	rows.append_array(heading_rows)
	rows.append_array(animation_rows)
	var sheet:=Image.create(TILE_SIZE*FRAME_COUNT,TILE_SIZE*rows.size(),false,Image.FORMAT_RGBA8)
	for row_index in range(rows.size()):
		for column in range(FRAME_COUNT):
			var tile:=crop_pose(rows[row_index][column])
			tile.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(column*TILE_SIZE,row_index*TILE_SIZE))
	var directory:=DirAccess.open("res://test-output")
	if directory==null: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-output"))
	assert(sheet.save_png("res://test-output/harvester_turntable_animation_sheet.png")==OK,"H09 contact sheet should be saved")

func run() -> void:
	var headings:Array[Image]=[]
	for heading in range(HEADING_COUNT):
		headings.append(await capture_pose("heading %d"%heading,0,0,4,0,heading))
	var heading_rows:Array[Array]=[]
	for row_index in range(4):
		var heading_row:Array[Image]=[]
		for column in range(FRAME_COUNT): heading_row.append(headings[row_index*FRAME_COUNT+column])
		heading_rows.append(heading_row)
	var idle:=await capture_pose("idle",0,0,4,0)
	var moving:Array[Image]=[]
	var harvesting:Array[Image]=[]
	var unloading:Array[Image]=[]
	for frame in range(FRAME_COUNT):
		moving.append(await capture_pose("move frame %d"%frame,3,frame,4,0))
		harvesting.append(await capture_pose("harvest frame %d"%frame,1,frame,4,0))
		unloading.append(await capture_pose("unload frame %d"%frame,2,frame,4,0))
	save_contact_sheet(heading_rows,[moving,harvesting,unloading])
	var movement_change:=difference_from_idle(idle,moving)
	var harvest_change:=difference_from_idle(idle,harvesting)
	var unload_change:=difference_from_idle(idle,unloading)
	var heading_change:=1.0
	for heading in range(1,HEADING_COUNT):
		heading_change=minf(heading_change,pose_difference(headings[heading-1],headings[heading]))
	assert(heading_change>0.002,"all 32 turntable headings should produce distinct review images")
	assert(movement_change>0.002,"eight Move phases should visibly change the in-game cached pose")
	assert(harvest_change>0.002,"eight Harvest phases should visibly move the cutter and conveyor")
	assert(unload_change>0.002,"eight Unload phases should visibly animate the hatch and head from the same camera")
	print("At 128x128 review size: min adjacent 32-heading change %.4f; max change from idle Move %.4f, Harvest %.4f, Unload %.4f"%[heading_change,movement_change,harvest_change,unload_change])
	print("Contact sheet includes all 32 body headings plus eight temporal frames each for Move, Harvest and Unload: test-output/harvester_turntable_animation_sheet.png")
	quit()
