extends RefCounted
class_name LowpolyModelFactory

const DARK := Color("182120")
const STEEL := Color("3d4844")
const SAND := Color("a67a4e")
const CREAM := Color("d8c39a")
const CYAN := Color("35d6c8")
const AMBER := Color("edaa52")

static func vehicle(root: Node3D, entity: Dictionary, team: Color, faction: String, turret_angle: float) -> void:
	var model := Node3D.new()
	model.name="Vehicle body"
	# Cache sprites face screen-right at a zero 2D heading, matching the RTS angle convention.
	model.rotation.y=-PI*0.5
	root.add_child(model)
	var kind := str(entity.get("kind", "tank"))
	var scale: float = float({"scout":0.68,"tank":1.0,"siege":1.18,"harvester":1.08,"raider":0.84,"lancer":0.98,"scorcher":0.9,"bulwark":1.32}.get(kind,1.0))
	var hull := _faction_hull(faction)
	var accent := team.lerp(CYAN, 0.22)
	var hull_mat := _material(hull, 0.78, 0.16)
	var dark_mat := _material(DARK, 0.9, 0.12)
	var trim_mat := _material(accent, 0.46, 0.28)
	var armor_mat := _material(CREAM.lerp(hull, 0.2), 0.7, 0.08)
	var length: float = float({"scout":2.4,"tank":3.25,"siege":3.8,"harvester":3.6,"raider":2.8,"lancer":3.15,"scorcher":2.9,"bulwark":4.0}.get(kind,3.0)) * scale
	var width: float = float({"scout":1.25,"tank":1.95,"siege":2.2,"harvester":2.5,"raider":1.55,"lancer":1.9,"scorcher":1.8,"bulwark":2.7}.get(kind,1.8)) * scale
	var track_unit := kind in ["tank", "siege", "harvester", "scorcher", "bulwark"]
	if track_unit:
		for side in [-1.0, 1.0]:
			_box(model, "Track", Vector3(0.34*scale,0.5*scale,length*0.92), Vector3(side*width*0.47,0.28*scale,0), dark_mat)
			for i in range(5):
				_cylinder(model,"Road wheel",0.19*scale,0.12*scale,Vector3(side*width*0.58,0.3*scale,-length*0.36+i*length*0.18),armor_mat,12,Vector3(0,0,PI*0.5))
	else:
		for side in [-1.0,1.0]:
			_cylinder(model,"Hover pod",0.24*scale,0.52*scale,Vector3(side*width*0.42,0.25*scale,0.2*scale),dark_mat,8,Vector3(0,0,PI*0.5))
	_box(model,"Lower hull",Vector3(width*0.82,0.48*scale,length*0.82),Vector3(0,0.47*scale,0),hull_mat)
	_box(model,"Forward glacis",Vector3(width*0.76,0.18*scale,length*0.22),Vector3(0,0.75*scale,-length*0.3),armor_mat)
	_box(model,"Rear deck",Vector3(width*0.68,0.16*scale,length*0.2),Vector3(0,0.75*scale,length*0.29),_material(SAND.lerp(hull,0.28),0.86,0.05))
	_box(model,"Hull stripe",Vector3(0.12*scale,0.07*scale,length*0.54),Vector3(0,0.84*scale,0.01),trim_mat)
	var turret := Node3D.new()
	turret.name="Turret"
	turret.position=Vector3(0,0.82*scale,0)
	turret.rotation.y=-turret_angle
	model.add_child(turret)
	var turret_size := Vector3(width*0.6,0.48*scale,length*0.38)
	if kind=="scout": turret_size=Vector3(width*0.66,0.3*scale,length*0.27)
	if kind=="siege": turret_size=Vector3(width*0.7,0.56*scale,length*0.43)
	if kind=="bulwark": turret_size=Vector3(width*0.72,0.62*scale,length*0.43)
	if kind=="harvester": turret_size=Vector3(width*0.56,0.34*scale,length*0.32)
	_box(turret,"Turret base",Vector3(turret_size.x*1.08,0.16*scale,turret_size.z*1.08),Vector3(0,0.03*scale,0),dark_mat)
	_box(turret,"Turret body",turret_size,Vector3(0,0.32*scale,0),hull_mat)
	_box(turret,"Turret armor",Vector3(turret_size.x*0.78,0.12*scale,turret_size.z*0.66),Vector3(0,0.61*scale,0.01),armor_mat)
	_box(turret,"Turret stripe",Vector3(turret_size.x*0.58,0.045*scale,0.1*scale),Vector3(0,0.69*scale,0),trim_mat)
	var weapon := Node3D.new()
	weapon.position=Vector3(0,0.35*scale,-turret_size.z*0.34)
	turret.add_child(weapon)
	var barrel_len: float = float({"scout":0.5,"tank":1.0,"siege":1.45,"harvester":0.18,"raider":0.64,"lancer":1.45,"scorcher":0.5,"bulwark":1.0}.get(kind,0.8))*scale
	var barrel_mat := trim_mat if kind=="lancer" else armor_mat
	if kind=="siege":
		_box(weapon,"Mortar base",Vector3(0.62*scale,0.2*scale,0.62*scale),Vector3(0,0.08*scale,-0.18*scale),dark_mat)
		_box(weapon,"Mortar tube",Vector3(0.36*scale,0.42*scale,barrel_len),Vector3(0,0.26*scale,-barrel_len*0.38),barrel_mat)
	else:
		_box(weapon,"Weapon",Vector3((0.16 if kind!="bulwark" else 0.28)*scale,0.18*scale,barrel_len),Vector3(0,0.08*scale,-barrel_len*0.4),barrel_mat)
		if kind in ["raider","scorcher"]:
			_box(weapon,"Twin weapon",Vector3(0.14*scale,0.16*scale,barrel_len*0.86),Vector3(0.3*scale,0.04*scale,-barrel_len*0.33),barrel_mat)
	if kind=="harvester":
		var cargo_crystals := clampi(roundi(float(entity.get("cargo",0.0))/80.0),0,3)
		for i in range(cargo_crystals):
			var crystal := PrismMesh.new()
			crystal.size=Vector3(0.3*scale,0.52*scale,0.3*scale)
			_mesh(model,"Cargo crystal",crystal,Vector3(-0.45*scale+i*0.45*scale,0.92*scale,0.82*scale),_material(CYAN,0.35,0.05,true))
	if kind=="lancer": _box(weapon,"Energy core",Vector3(0.22*scale,0.22*scale,barrel_len*0.58),Vector3(0,0.08*scale,-barrel_len*0.3),_material(Color("70edff"),0.28,0.1,true))
	if kind=="scorcher":
		for side in [-1.0,1.0]: _cylinder(model,"Fuel tank",0.22*scale,0.65*scale,Vector3(side*width*0.28,0.76*scale,length*0.19),_material(AMBER,0.68),10,Vector3(PI*0.5,0,0))
	if int(entity.get("hp",1)) < int(entity.get("max_hp",1))*0.65:
		_box(model,"Battle scar",Vector3(width*0.3,0.025*scale,length*0.16),Vector3(width*0.18,0.88*scale,length*0.1),_material(Color("352a25"),1.0))
	if kind=="bulwark":
		for side in [-1.0,1.0]: _box(model,"Ram plate",Vector3(0.3*scale,0.4*scale,0.22*scale),Vector3(side*width*0.38,0.62*scale,-length*0.45),armor_mat)

static func building(root: Node3D, entity: Dictionary, team: Color, faction: String, footprint: Vector2) -> void:
	var kind := str(entity.get("kind","core"))
	var sx := maxf(1.0,footprint.x/32.0)*1.1
	var sz := maxf(1.0,footprint.y/32.0)*1.1
	var hull := _faction_hull(faction)
	var hull_mat := _material(hull,0.82,0.14)
	var dark_mat := _material(DARK,0.9,0.12)
	var armor_mat := _material(CREAM.lerp(hull,0.24),0.76,0.08)
	var trim_mat := _material(team.lerp(CYAN,0.18),0.42,0.25)
	var height: float = float({"core":1.9,"power":1.15,"refinery":1.5,"factory":1.85,"tower":1.45,"radar":1.65,"repair":1.35,"armory":1.45}.get(kind,1.25))
	_box(root,"Foundation",Vector3(sx,0.2,sz),Vector3(0,0.1,0),dark_mat)
	_box(root,"Main structure",Vector3(sx*0.82,height,sz*0.78),Vector3(0,0.18+height*0.5,0),hull_mat)
	_box(root,"Front armor",Vector3(sx*0.66,0.25,0.14),Vector3(0,0.36,-sz*0.43),armor_mat)
	_box(root,"Faction stripe",Vector3(0.14,0.07,sz*0.6),Vector3(0,height*0.56,0),trim_mat)
	_box(root,"Roof plate",Vector3(sx*0.65,0.13,sz*0.58),Vector3(0,height+0.25,0),armor_mat)
	for side in [-1.0,1.0]:
		_box(root,"Side armor",Vector3(0.12,height*0.52,sz*0.52),Vector3(side*sx*0.46,height*0.46,0),armor_mat)
	match kind:
		"core":
			_box(root,"Core tower",Vector3(sx*0.45,height*0.58,sz*0.42),Vector3(0,height+0.54,0),dark_mat)
			_box(root,"Core beacon",Vector3(sx*0.3,0.14,0.12),Vector3(0,height+0.88,-0.1),trim_mat)
			for i in range(3): _cylinder(root,"Reactor cap",0.18,0.18,Vector3(-0.42+i*0.42,height+0.38,sz*0.28),trim_mat,10)
		"power":
			for side in [-1.0,1.0]:
				_cylinder(root,"Generator",0.22,0.6,Vector3(side*sx*0.25,height+0.24,0),armor_mat,12)
			_box(root,"Power conduit",Vector3(0.1,0.13,sz*0.64),Vector3(0,height+0.38,0),trim_mat)
		"refinery":
			for i in range(3): _cylinder(root,"Refinery stack",0.14,0.75,Vector3(-sx*0.26+i*sx*0.26,height+0.35,-sz*0.27),armor_mat,10)
			_box(root,"Loading bay",Vector3(sx*0.64,0.42,0.26),Vector3(0,0.48,sz*0.42),dark_mat)
		"factory":
			_box(root,"Hangar roof",Vector3(sx*0.66,0.28,sz*0.44),Vector3(0,height+0.18,-sz*0.08),armor_mat)
			_box(root,"Hangar door",Vector3(sx*0.58,0.62,0.12),Vector3(0,0.55,sz*0.405),dark_mat)
			for i in range(3): _box(root,"Door light",Vector3(0.13,0.07,0.04),Vector3(-0.28+i*0.28,0.85,sz*0.48),trim_mat)
		"tower":
			_box(root,"Gun turret",Vector3(0.66,0.42,0.66),Vector3(0,height+0.35,0),dark_mat)
			_box(root,"Gun barrel",Vector3(0.16,0.17,0.9),Vector3(0,height+0.4,-0.68),armor_mat)
		"radar":
			_cylinder(root,"Radar mast",0.07,1.0,Vector3(0,height+0.52,0),armor_mat,8)
			_box(root,"Radar dish",Vector3(0.68,0.1,0.28),Vector3(0,height+1.03,-0.18),trim_mat)
		"repair":
			_box(root,"Repair gantry",Vector3(sx*0.8,0.18,0.16),Vector3(0,height+0.38,0),trim_mat)
			for side in [-1.0,1.0]: _box(root,"Gantry leg",Vector3(0.14,0.66,0.14),Vector3(side*sx*0.34,height+0.08,0),armor_mat)
		"armory":
			for side in [-1.0,1.0]: _box(root,"Armor rack",Vector3(0.18,0.58,sz*0.48),Vector3(side*sx*0.35,height+0.12,0),trim_mat)
	var rotation := posmod(int(entity.get("rotation",0)),4)*PI*0.5
	for child in root.get_children():
		if child is MeshInstance3D and child.name!="Soft ground shadow":
			child.position=child.position.rotated(Vector3.UP,rotation)
			child.rotation.y+=rotation

static func _faction_hull(faction: String) -> Color:
	match faction:
		"drift": return Color("88765b")
		"lumen": return Color("343b54")
		_: return STEEL

static func _material(color: Color, roughness: float=0.8, metallic: float=0.0, glow: bool=false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=roughness
	material.metallic=metallic
	if glow:
		material.emission_enabled=true
		material.emission=color.darkened(0.35)
	return material

static func _box(parent: Node3D, label: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name=label
	var mesh := BoxMesh.new()
	mesh.size=size
	instance.mesh=mesh
	instance.position=pos
	instance.material_override=material
	parent.add_child(instance)
	return instance

static func _cylinder(parent: Node3D, label: String, radius: float, height: float, pos: Vector3, material: Material, segments: int=10, rotation: Vector3=Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name=label
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=segments
	instance.mesh=mesh
	instance.position=pos
	instance.rotation=rotation
	instance.material_override=material
	parent.add_child(instance)
	return instance

static func _mesh(parent: Node3D, label: String, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name=label
	instance.mesh=mesh
	instance.position=pos
	instance.material_override=material
	parent.add_child(instance)
	return instance
