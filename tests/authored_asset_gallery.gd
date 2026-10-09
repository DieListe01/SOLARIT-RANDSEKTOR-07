extends SceneTree

const KINDS_VEHICLE=["scout","tank","siege","harvester","raider","lancer","scorcher","bulwark"]
const KINDS_BUILDING=["core","power","refinery","factory","tower","radar","repair","armory"]
const SUBVIEW_SIZE:=Vector2i(1920,1080)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport:=SubViewport.new(); viewport.size=SUBVIEW_SIZE
	viewport.transparent_bg=false; viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	viewport.msaa_3d=Viewport.MSAA_4X
	root.add_child(viewport)
	var world:=Node3D.new(); viewport.add_child(world)
	var env_node:=WorldEnvironment.new(); var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR; env.background_color=Color("17201f")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("b9c9c0"); env.ambient_light_energy=.75
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC; env.ssao_enabled=true; env.ssao_radius=1.0
	env_node.environment=env; world.add_child(env_node)
	var sun:=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-50,-32,0); sun.light_energy=1.6; sun.shadow_enabled=true; world.add_child(sun)
	var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=13.5
	camera.position=Vector3(12,16,-22); world.add_child(camera); camera.look_at(Vector3(0,.65,0),Vector3.UP); camera.current=true
	for mode in ["vehicles","buildings"]:
		var kinds=KINDS_VEHICLE if mode=="vehicles" else KINDS_BUILDING
		for index in kinds.size():
			var kind:String=kinds[index]
			var row:=index/4; var col:=index%4
			var pos:=Vector3(-7.5+float(col)*5.0,0,-3.15+float(row)*6.3)
			var platform:=MeshInstance3D.new(); var tile:=BoxMesh.new(); tile.size=Vector3(4.35,.12,5.25)
			platform.mesh=tile; platform.position=pos+Vector3(0,-.09,0)
			var pmat:=StandardMaterial3D.new(); pmat.albedo_color=Color("303632") if row==0 else Color("39342e"); pmat.roughness=.9
			platform.material_override=pmat; world.add_child(platform)
			var scene_path="res://assets/models/%s/%s.glb"%["vehicles" if mode=="vehicles" else "buildings",kind]
			var packed=ResourceLoader.load(scene_path,"PackedScene") as PackedScene
			assert(packed!=null,"Gallery asset must import: "+scene_path)
			var model=packed.instantiate() as Node3D; model.position=pos; world.add_child(model)
			if mode=="vehicles": model.rotation.y=deg_to_rad(-14.0)
			var label:=Label3D.new(); label.text=kind.to_upper(); label.font_size=64; label.pixel_size=.004
			label.position=pos+Vector3(0,.12,-2.10); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			label.modulate=Color("eac27b"); label.outline_size=12; label.outline_modulate=Color("121715")
			world.add_child(label)
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image()
		assert(image!=null and not image.is_empty(),"Asset gallery should render the authored models")
		var directory=DirAccess.open("res://test-output")
		if directory==null: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-output"))
		var target="res://test-output/%s_gallery_v0.37.0.png"%mode
		assert(image.save_png(target)==OK,"Gallery image should be written: "+target)
		print("Authored model gallery: "+target)
		for child in world.get_children():
			if child!=env_node and child!=sun and child!=camera: child.queue_free()
		await process_frame
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	quit()
