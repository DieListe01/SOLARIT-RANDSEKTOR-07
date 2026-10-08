extends RefCounted
class_name LowpolyModelFactory

const DARK := Color("182120")
const STEEL := Color("3d4844")
const SAND := Color("a67a4e")
const CREAM := Color("d8c39a")
const CYAN := Color("35d6c8")
const AMBER := Color("edaa52")
static var _surface_texture: ImageTexture

static func vehicle(root: Node3D, entity: Dictionary, team: Color, faction: String, turret_angle: float) -> void:
	var model := Node3D.new()
	model.name="Vehicle body"
	# Rotate the full model around the vertical axis before the fixed isometric camera
	# renders it, instead of spinning one flat projection to imitate a direction.
	model.rotation.y=-PI*0.5-float(entity.get("angle",0.0))
	root.add_child(model)
	var kind := str(entity.get("kind", "tank"))
	var scale: float = float({"scout":0.86,"tank":1.0,"siege":1.18,"harvester":1.08,"raider":0.84,"lancer":0.98,"scorcher":0.9,"bulwark":1.32}.get(kind,1.0))
	var hull := _faction_hull(faction)
	# Keep faction armor recognizable while making ownership readable at RTS zoom.
	var accent := team
	var hull_mat := _material(hull, 0.78, 0.16)
	var dark_mat := _material(DARK, 0.9, 0.12)
	var trim_mat := _material(accent, 0.46, 0.28)
	var armor_mat := _material(CREAM.lerp(hull, 0.2), 0.7, 0.08)
	var length: float = float({"scout":2.4,"tank":3.25,"siege":3.8,"harvester":3.6,"raider":2.8,"lancer":3.15,"scorcher":2.9,"bulwark":4.0}.get(kind,3.0)) * scale
	var width: float = float({"scout":1.25,"tank":1.95,"siege":2.2,"harvester":2.5,"raider":1.55,"lancer":1.9,"scorcher":1.8,"bulwark":2.7}.get(kind,1.8)) * scale
	var track_unit := kind in ["tank", "siege", "harvester", "scorcher", "bulwark"]
	var drive_frame:=posmod(int(entity.get("drive_frame",0)),4)
	if track_unit:
		for side in [-1.0, 1.0]:
			_box(model, "Track", Vector3(0.34*scale,0.5*scale,length*0.92), Vector3(side*width*0.47,0.28*scale,0), dark_mat)
			for i in 6:
				var wheel_pos:=Vector3(side*width*0.58,0.3*scale,-length*0.38+i*length*0.152)
				_cylinder(model,"Road wheel",0.17*scale,0.13*scale,wheel_pos,dark_mat,12,Vector3(0,0,PI*0.5))
				_cylinder(model,"Wheel hub",0.085*scale,0.145*scale,wheel_pos,armor_mat,8,Vector3(0,0,PI*0.5))
				for bolt in 4:
					var bolt_angle:=TAU*float(bolt)/4.0+PI*0.25
					var bolt_pos:=wheel_pos+Vector3(side*0.078*scale,sin(bolt_angle)*0.105*scale,cos(bolt_angle)*0.105*scale)
					_cylinder(model,"Road wheel fastener",0.018*scale,0.018*scale,bolt_pos,dark_mat,6,Vector3(0,0,PI*0.5))
			var tread_step:=length*0.078
			for i in 12:
				var tread_z:float=-length*0.43+i*tread_step+tread_step*float(drive_frame)*0.25
				_box(model,"Track cleat",Vector3(0.37*scale,0.055*scale,0.12*scale),Vector3(side*width*0.47,0.54*scale,tread_z),armor_mat)
	else:
		if kind=="scout":
			# Four exposed wheels, a low cabin and front bumper make the recon
			# vehicle read clearly at normal gameplay zoom.
			for side in [-1.0,1.0]:
				for axle in [-1.0,1.0]:
					var wheel_pos:=Vector3(side*width*0.48,0.27*scale,axle*length*0.31)
					_cylinder(model,"Scout tire",0.22*scale,0.15*scale,wheel_pos,dark_mat,10,Vector3(0,0,PI*0.5))
					_cylinder(model,"Scout wheel hub",0.105*scale,0.17*scale,wheel_pos,armor_mat,8,Vector3(0,0,PI*0.5))
			_box(model,"Scout front bumper",Vector3(width*0.9,0.18*scale,0.16*scale),Vector3(0,0.4*scale,-length*0.46),dark_mat)
		else:
			for side in [-1.0,1.0]:
				_cylinder(model,"Hover pod",0.25*scale,0.58*scale,Vector3(side*width*0.42,0.22*scale,0.2*scale),dark_mat,8,Vector3(0,0,PI*0.5))
				_box(model,"Hover emitter",Vector3(0.13*scale,0.1*scale,0.34*scale),Vector3(side*width*0.42,0.14*scale,0.2*scale),trim_mat)
	_box(model,"Lower hull",Vector3(width*0.82,0.48*scale,length*0.82),Vector3(0,0.47*scale,0),hull_mat)
	_box(model,"Forward glacis",Vector3(width*0.76,0.18*scale,length*0.22),Vector3(0,0.75*scale,-length*0.3),armor_mat)
	_box(model,"Rear deck",Vector3(width*0.68,0.16*scale,length*0.2),Vector3(0,0.75*scale,length*0.29),_material(SAND.lerp(hull,0.28),0.86,0.05))
	_box(model,"Hull stripe",Vector3(0.2*scale,0.07*scale,length*0.54),Vector3(0,0.84*scale,0.01),trim_mat)
	for side in [-1.0,1.0]:
		_box(model,"Side armor skirt",Vector3(0.1*scale,0.22*scale,length*0.42),Vector3(side*width*0.43,0.58*scale,0.02*scale),armor_mat)
		_box(model,"Front lamp",Vector3(0.2*scale,0.1*scale,0.08*scale),Vector3(side*width*0.27,0.78*scale,-length*0.42),_material(Color("fff0bd"),0.3,0.0,true))
		_box(model,"Rear marker",Vector3(0.15*scale,0.09*scale,0.07*scale),Vector3(side*width*0.26,0.74*scale,length*0.42),_material(Color("f27e52"),0.4,0.0,true))
	for i in 3:
		_box(model,"Hull access panel",Vector3(width*0.13,0.06*scale,length*0.1),Vector3(-width*0.28+i*width*0.28,0.86*scale,length*0.22),dark_mat)
	# Small service hardware breaks up the broad armor planes at gameplay scale.
	for i in 5:
		_box(model,"Engine cooling louver",Vector3(width*0.13,0.035*scale,0.06*scale),Vector3(-width*0.27+i*width*0.135,0.87*scale,length*0.35),dark_mat)
	for side in [-1.0,1.0]:
		_box(model,"Hull side panel",Vector3(0.045*scale,0.12*scale,length*0.18),Vector3(side*width*0.445,0.72*scale,-length*0.12),_material(hull.lightened(0.08),0.78,0.16))
		for i in 3:
			_box(model,"Hull panel fastener",Vector3(0.028*scale,0.035*scale,0.035*scale),Vector3(side*width*0.47,0.76*scale,-length*0.18+i*length*0.06),armor_mat)
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
	# A broad top ID plate stays visible from the elevated RTS camera, including
	# when the vehicle is angled or partly hidden in a formation.
	_box(turret,"Team ID plate",Vector3(turret_size.x*0.78,0.045*scale,turret_size.z*0.34),Vector3(0,0.704*scale,turret_size.z*0.1),trim_mat)
	_box(turret,"Commander hatch",Vector3(turret_size.x*0.28,0.09*scale,turret_size.z*0.24),Vector3(-turret_size.x*0.2,0.69*scale,turret_size.z*0.23),dark_mat)
	_cylinder(turret,"Targeting optic",0.075*scale,0.12*scale,Vector3(turret_size.x*0.28,0.67*scale,-turret_size.z*0.24),_material(Color("8de8e0"),0.25,0.1,true),8)
	for side in [-1.0,1.0]:
		_box(turret,"Turret side cheek",Vector3(0.07*scale,turret_size.y*0.38,turret_size.z*0.56),Vector3(side*turret_size.x*0.48,0.34*scale,0.02),armor_mat)
		for i in 2:
			_cylinder(turret,"Turret hinge",0.045*scale,0.025*scale,Vector3(side*turret_size.x*0.53,0.31*scale,-turret_size.z*0.16+i*turret_size.z*0.32),dark_mat,8,Vector3(0,0,PI*0.5))
	var weapon := Node3D.new()
	weapon.position=Vector3(0,0.35*scale,-turret_size.z*0.34)
	turret.add_child(weapon)
	var barrel_len: float = float({"scout":0.5,"tank":1.0,"siege":1.45,"harvester":0.18,"raider":0.64,"lancer":1.45,"scorcher":0.5,"bulwark":1.0}.get(kind,0.8))*scale
	var barrel_mat := trim_mat if kind=="lancer" else armor_mat
	if kind=="siege":
		_box(weapon,"Mortar base",Vector3(0.62*scale,0.2*scale,0.62*scale),Vector3(0,0.08*scale,-0.18*scale),dark_mat)
		_box(weapon,"Mortar tube",Vector3(0.36*scale,0.42*scale,barrel_len),Vector3(0,0.26*scale,-barrel_len*0.38),barrel_mat)
		_cylinder(weapon,"Muzzle ring",0.23*scale,0.12*scale,Vector3(0,0.26*scale,-barrel_len*0.72),armor_mat,8,Vector3(PI*0.5,0,0))
	else:
		_box(weapon,"Weapon",Vector3((0.16 if kind!="bulwark" else 0.28)*scale,0.18*scale,barrel_len),Vector3(0,0.08*scale,-barrel_len*0.4),barrel_mat)
		_box(weapon,"Muzzle",Vector3(0.22*scale,0.22*scale,0.14*scale),Vector3(0,0.08*scale,-barrel_len*0.83),dark_mat)
		if kind in ["raider","scorcher"]:
			_box(weapon,"Twin weapon",Vector3(0.14*scale,0.16*scale,barrel_len*0.86),Vector3(0.3*scale,0.04*scale,-barrel_len*0.33),barrel_mat)
	if kind=="harvester":
		_box(model,"Collector frame",Vector3(width*0.72,0.13*scale,0.14*scale),Vector3(0,0.78*scale,-length*0.48),dark_mat)
		for side in [-1.0,1.0]:
			_box(model,"Collector arm",Vector3(0.12*scale,0.18*scale,length*0.26),Vector3(side*width*0.28,0.69*scale,-length*0.4),trim_mat)
			_cylinder(model,"Collection drum",0.14*scale,width*0.18,Vector3(side*width*0.39,0.55*scale,-length*0.46),armor_mat,8,Vector3(0,0,PI*0.5))
		var cargo_crystals := clampi(roundi(float(entity.get("cargo",0.0))/80.0),0,3)
		for i in range(cargo_crystals):
			var crystal := PrismMesh.new()
			crystal.size=Vector3(0.3*scale,0.52*scale,0.3*scale)
			_mesh(model,"Cargo crystal",crystal,Vector3(-0.45*scale+i*0.45*scale,0.92*scale,0.82*scale),_material(CYAN,0.35,0.05,true))
	if kind=="lancer": _box(weapon,"Energy core",Vector3(0.22*scale,0.22*scale,barrel_len*0.58),Vector3(0,0.08*scale,-barrel_len*0.3),_material(Color("70edff"),0.28,0.1,true))
	if kind=="scorcher":
		for side in [-1.0,1.0]:
			_cylinder(model,"Fuel tank",0.22*scale,0.65*scale,Vector3(side*width*0.28,0.76*scale,length*0.19),_material(AMBER,0.68),10,Vector3(PI*0.5,0,0))
			_box(model,"Flame nozzle",Vector3(0.2*scale,0.18*scale,0.32*scale),Vector3(side*width*0.25,0.62*scale,-length*0.46),_material(Color("ff8a3d"),0.35,0.0,true))
	if kind=="scout":
		_box(model,"Scout sensor mast",Vector3(0.07*scale,0.42*scale,0.07*scale),Vector3(0,1.12*scale,length*0.15),dark_mat)
		_cylinder(model,"Scout sensor",0.11*scale,0.32*scale,Vector3(0,1.34*scale,length*0.15),trim_mat,8,Vector3(0,0,PI*0.5))
	if kind=="raider":
		for side in [-1.0,1.0]:
			_box(model,"Raider flank",Vector3(0.16*scale,0.22*scale,length*0.38),Vector3(side*width*0.48,0.52*scale,0.02),trim_mat)
			_box(model,"Raider side blade",Vector3(0.3*scale,0.12*scale,0.38*scale),Vector3(side*width*0.48,0.55*scale,-length*0.3),armor_mat)
	if kind=="lancer":
		_box(weapon,"Lance emitter",Vector3(0.3*scale,0.28*scale,0.34*scale),Vector3(0,0.08*scale,-0.22*scale),dark_mat)
	if int(entity.get("hp",1)) < int(entity.get("max_hp",1))*0.65:
		_box(model,"Battle scar",Vector3(width*0.3,0.025*scale,length*0.16),Vector3(width*0.18,0.88*scale,length*0.1),_material(Color("352a25"),1.0))
	if kind=="bulwark":
		for side in [-1.0,1.0]: _box(model,"Ram plate",Vector3(0.3*scale,0.4*scale,0.22*scale),Vector3(side*width*0.38,0.62*scale,-length*0.45),armor_mat)
		_box(model,"Bulwark prow",Vector3(width*0.76,0.35*scale,0.24*scale),Vector3(0,0.58*scale,-length*0.47),dark_mat)
		for i in 5: _box(model,"Prow reinforcement",Vector3(width*0.11,0.08*scale,0.1*scale),Vector3(-width*0.28+i*width*0.14,0.78*scale,-length*0.48),trim_mat)

static func building(root: Node3D, entity: Dictionary, team: Color, faction: String, footprint: Vector2) -> void:
	var kind := str(entity.get("kind","core"))
	# Keep buildings inside their map footprint so vehicles remain visible nearby.
	var sx := maxf(1.0,footprint.x/32.0)*0.94
	var sz := maxf(1.0,footprint.y/32.0)*0.94
	var hull := _faction_hull(faction)
	var hull_mat := _material(hull,0.82,0.14)
	var dark_mat := _material(DARK,0.9,0.12)
	var armor_mat := _material(CREAM.lerp(hull,0.24),0.76,0.08)
	var trim_mat := _material(team.lerp(CYAN,0.18),0.42,0.25)
	var amber_mat := _material(AMBER,0.62,0.08)
	var height: float = float({"core":1.8,"power":1.2,"refinery":1.45,"factory":1.7,"tower":1.25,"radar":1.35,"repair":1.2,"armory":1.35}.get(kind,1.25))
	_box(root,"Reinforced foundation",Vector3(sx,0.18,sz),Vector3(0,0.09,0),dark_mat)
	_box(root,"Foundation rim",Vector3(sx*0.92,0.12,sz*0.9),Vector3(0,0.22,0),_material(Color("554638"),0.92))
	# Give each structure a distinct silhouette before applying shared team trim.
	match kind:
		"core":
			_box(root,"Command hull",Vector3(sx*0.8,height*0.66,sz*0.72),Vector3(0,0.55,0.08),hull_mat)
			_box(root,"Command roof",Vector3(sx*0.72,0.16,sz*0.61),Vector3(-0.04,1.12,0.02),armor_mat)
			_box(root,"Raised command deck",Vector3(sx*0.4,0.62,sz*0.38),Vector3(0,1.5,-0.02),dark_mat)
			_box(root,"Command canopy",Vector3(sx*0.44,0.16,sz*0.42),Vector3(0,1.87,-0.02),armor_mat)
			_box(root,"Command beacon",Vector3(sx*0.25,0.08,0.12),Vector3(0,2.02,-0.08),trim_mat)
			_box(root,"Blast door",Vector3(sx*0.52,0.34,0.12),Vector3(0,0.45,sz*0.44),dark_mat)
			_box(root,"Access ramp",Vector3(sx*0.44,0.11,0.35),Vector3(0,0.28,sz*0.54),armor_mat)
			for i in 4: _box(root,"Door light",Vector3(0.09,0.07,0.035),Vector3((-0.3+i*0.2)*sx,0.49,sz*0.5),trim_mat)
			for side in [-1.0,1.0]: _box(root,"Command brace",Vector3(0.12,0.78,0.14),Vector3(side*sx*0.42,0.55,sz*0.34),armor_mat)
		"power":
			_box(root,"Reactor hall",Vector3(sx*0.68,height*0.72,sz*0.64),Vector3(0,0.52,0),hull_mat)
			_box(root,"Reactor roof",Vector3(sx*0.74,0.15,sz*0.68),Vector3(0,0.98,0),armor_mat)
			for side in [-1.0,1.0]:
				_box(root,"Generator housing",Vector3(sx*0.2,0.62,sz*0.55),Vector3(side*sx*0.28,0.47,0.03),dark_mat)
				_cylinder(root,"Generator cap",0.2,0.13,Vector3(side*sx*0.28,0.81,0.03),armor_mat,10)
			for i in 5: _box(root,"Cooling grille",Vector3(sx*0.22,0.045,0.045),Vector3(0,0.35+i*0.095,-sz*0.35),trim_mat if i==2 else dark_mat)
			_box(root,"Power conduit",Vector3(0.11,0.12,sz*0.66),Vector3(0,1.09,0),trim_mat)
		"refinery":
			_box(root,"Processing hall",Vector3(sx*0.64,height*0.62,sz*0.6),Vector3(-sx*0.08,0.47,-sz*0.04),hull_mat)
			_box(root,"Refinery roof",Vector3(sx*0.68,0.14,sz*0.62),Vector3(-sx*0.08,0.88,-sz*0.04),armor_mat)
			_box(root,"Loading platform",Vector3(sx*0.74,0.26,0.34),Vector3(0,0.36,sz*0.4),dark_mat)
			for i in 3:
				var x := -sx*0.3+i*sx*0.3
				_cylinder(root,"Fractionation tank",0.2,0.98,Vector3(x,1.48,sz*0.19),armor_mat,10)
				_cylinder(root,"Tank collar",0.23,0.1,Vector3(x,1.0,sz*0.19),trim_mat,10)
				_cylinder(root,"Tank cap",0.12,0.12,Vector3(x,1.99,sz*0.19),dark_mat,10)
			_box(root,"Feed pipe",Vector3(0.1,0.11,sz*0.52),Vector3(-sx*0.4,0.92,0.1),trim_mat)
			_box(root,"Service pipe",Vector3(sx*0.58,0.1,0.1),Vector3(0,1.11,sz*0.36),dark_mat)
			_box(root,"Conveyor",Vector3(sx*0.48,0.12,0.22),Vector3(sx*0.33,0.72,sz*0.46),trim_mat)
		"factory":
			_box(root,"Hangar shell",Vector3(sx*0.78,height*0.72,sz*0.7),Vector3(0,0.56,0.04),hull_mat)
			_box(root,"Hangar roof",Vector3(sx*0.9,0.2,sz*0.76),Vector3(0,1.24,0.02),armor_mat)
			_box(root,"Vehicle bay",Vector3(sx*0.68,0.66,0.12),Vector3(0,0.56,sz*0.42),dark_mat)
			_box(root,"Bay door",Vector3(sx*0.56,0.52,0.06),Vector3(0,0.52,sz*0.49),_material(Color("69756b"),0.9))
			_box(root,"Loading ramp",Vector3(sx*0.58,0.1,0.34),Vector3(0,0.3,sz*0.58),dark_mat)
			for side in [-1.0,1.0]:
				_box(root,"Hangar pillar",Vector3(0.15,1.45,0.15),Vector3(side*sx*0.4,0.8,sz*0.36),trim_mat)
				_box(root,"Roof girder",Vector3(0.1,0.1,sz*0.72),Vector3(side*sx*0.4,1.39,0.02),dark_mat)
			for i in 4: _box(root,"Bay hazard stripe",Vector3(0.12,0.055,0.04),Vector3(-0.24+i*0.16,0.32,sz*0.5),amber_mat)
		"tower":
			_box(root,"Gun tower",Vector3(sx*0.52,height*0.9,sz*0.52),Vector3(0,0.63,0),hull_mat)
			_box(root,"Turret ring",Vector3(sx*0.58,0.14,sz*0.58),Vector3(0,1.18,0),dark_mat)
			var turret := Node3D.new()
			turret.name="Rotating gun mount"
			turret.position=Vector3(0,1.27,0)
			turret.rotation.y=-float(entity.get("turret",0.0))
			root.add_child(turret)
			_box(turret,"Turret armor",Vector3(sx*0.43,0.32,sz*0.4),Vector3(0,0.14,0),armor_mat)
			_box(turret,"Gun barrel",Vector3(0.16,0.16,0.78),Vector3(0,0.18,-0.51),trim_mat)
			_box(root,"Armored door",Vector3(sx*0.34,0.3,0.1),Vector3(0,0.39,sz*0.43),dark_mat)
		"radar":
			_box(root,"Radar control block",Vector3(sx*0.62,0.72,sz*0.6),Vector3(0,0.55,0),hull_mat)
			_box(root,"Radar deck",Vector3(sx*0.7,0.12,sz*0.68),Vector3(0,0.98,0),armor_mat)
			_box(root,"Radar mast",Vector3(0.12,0.94,0.12),Vector3(0,1.5,0),dark_mat)
			_box(root,"Radar dish",Vector3(0.72,0.12,0.24),Vector3(0,1.98,-0.1),trim_mat)
			_box(root,"Dish receiver",Vector3(0.1,0.24,0.1),Vector3(0,2.04,-0.08),armor_mat)
			for side in [-1.0,1.0]: _box(root,"Signal antenna",Vector3(0.06,0.62,0.06),Vector3(side*sx*0.34,1.22,sz*0.27),trim_mat)
		"repair":
			_box(root,"Service bay",Vector3(sx*0.72,0.68,sz*0.64),Vector3(0,0.49,0),hull_mat)
			_box(root,"Repair deck",Vector3(sx*0.82,0.12,sz*0.76),Vector3(0,0.91,0),armor_mat)
			for side in [-1.0,1.0]:
				_box(root,"Gantry leg",Vector3(0.16,1.16,0.16),Vector3(side*sx*0.38,0.76,-sz*0.26),trim_mat)
				_box(root,"Gantry lamp",Vector3(0.18,0.12,0.16),Vector3(side*sx*0.38,1.37,-sz*0.26),amber_mat)
			_box(root,"Repair crossbeam",Vector3(sx*0.82,0.15,0.16),Vector3(0,1.34,-sz*0.26),dark_mat)
			_box(root,"Workshop door",Vector3(sx*0.5,0.4,0.08),Vector3(0,0.44,sz*0.38),dark_mat)
		"armory":
			_box(root,"Armory block",Vector3(sx*0.72,height*0.8,sz*0.68),Vector3(0,0.56,0),hull_mat)
			_box(root,"Armory roof",Vector3(sx*0.8,0.14,sz*0.76),Vector3(0,1.16,0),armor_mat)
			_box(root,"Armory entrance",Vector3(sx*0.38,0.38,0.09),Vector3(0,0.42,sz*0.42),dark_mat)
			for side in [-1.0,1.0]:
				_box(root,"Armor rack",Vector3(0.15,0.86,sz*0.46),Vector3(side*sx*0.38,0.66,0.02),trim_mat)
				for i in 3: _box(root,"Stored armor plate",Vector3(0.12,0.12,0.38),Vector3(side*sx*0.38,0.42+i*0.22,0.02),armor_mat)
	# Shared panels, corner guards and glowing team marks finish the silhouettes.
	_box(root,"Team stripe",Vector3(0.13,0.08,sz*0.46),Vector3(-sx*0.29,0.54,0.04),trim_mat)
	for side in [-1.0,1.0]: _box(root,"Corner armor",Vector3(0.1,height*0.46,0.12),Vector3(side*sx*0.43,0.49,sz*0.32),armor_mat)
	var front_detail_z:float=float({"core":0.45,"power":0.36,"refinery":0.31,"factory":0.42,"tower":0.30,"radar":0.34,"repair":0.34,"armory":0.38}.get(kind,0.38))*sz
	for i in 3: _box(root,"Front vent",Vector3(sx*0.18,0.04,0.04),Vector3(-sx*0.21+i*sx*0.21,0.52,front_detail_z),dark_mat)
	# Layered access panels, handles and status lamps give each broad wall a
	# readable industrial scale without changing the structure footprint.
	for i in 2:
		var panel_x:float=(-0.29+float(i)*0.58)*sx
		_box(root,"Front service panel",Vector3(sx*0.14,0.2,0.035),Vector3(panel_x,0.77,front_detail_z),_material(hull.darkened(0.12),0.82,0.14))
		_box(root,"Panel seam",Vector3(sx*0.105,0.014,0.012),Vector3(panel_x,0.77,front_detail_z+0.022),_material(CREAM.lerp(hull,0.24).darkened(0.2),0.76,0.08))
		for fastener in [-1.0,1.0]:
			_cylinder(root,"Front panel bolt",0.022,0.018,Vector3(panel_x+fastener*sx*0.052,0.84,front_detail_z+0.027),amber_mat,6,Vector3(PI*0.5,0,0))
	for i in 4:
		_box(root,"Front armor rib",Vector3(0.035,height*0.36,0.035),Vector3(-sx*0.43+i*sx*0.285,0.62,front_detail_z+0.028),_material(CREAM.lerp(hull,0.24).darkened(0.12),0.76,0.08))
	_box(root,"Service handle",Vector3(0.035,0.13,0.025),Vector3(sx*0.38,0.52,front_detail_z+0.035),trim_mat)
	for i in 3:
		_box(root,"Status indicator",Vector3(0.055,0.045,0.025),Vector3(-sx*0.1+i*sx*0.1,0.34,front_detail_z+0.032),trim_mat if i==1 else amber_mat)
	var rotation := posmod(int(entity.get("rotation",0)),4)*PI*0.5
	for child in root.get_children():
		if child is Node3D and child.name!="Soft ground shadow":
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
	if not glow:
		material.albedo_texture=_surface_detail_texture()
		material.uv1_triplanar=true
		material.uv1_scale=Vector3(3.5,3.5,3.5)
	if glow:
		material.emission_enabled=true
		material.emission=color.darkened(0.35)
	return material

static func _surface_detail_texture() -> ImageTexture:
	if _surface_texture!=null: return _surface_texture
	var noise := FastNoiseLite.new()
	noise.seed=218607
	noise.frequency=0.17
	noise.fractal_octaves=3
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var grain:=noise.get_noise_2d(float(x),float(y))
			var brushed:=noise.get_noise_2d(float(x)*0.22,float(y)*2.6)
			var value:=clampf(0.95+grain*0.045+brushed*0.018,0.84,1.0)
			if y%19==0 and x%5!=0: value*=0.94
			if posmod(x*37+y*71,127)==0: value*=0.88
			image.set_pixel(x,y,Color(value,value,value,1.0))
	image.generate_mipmaps()
	_surface_texture=ImageTexture.create_from_image(image)
	return _surface_texture

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
