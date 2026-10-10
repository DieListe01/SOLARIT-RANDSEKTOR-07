extends SceneTree

const CatalogType=preload("res://scripts/catalog.gd")
const SimulationType=preload("res://scripts/simulation.gd")

func _initialize()->void: call_deferred("run")

func run()->void:
	var catalog=CatalogType.new()
	var factions=["forge","drift","lumen"]
	var rows=["role,faction,collision_radius,visual_width,visual_height,visual_depth,target_point,weapon_origin,range,sight,hp,damage,speed,turn_speed,cost,production_seconds"]
	for kind in catalog.units:
		var unit:Dictionary=catalog.units[kind]
		var reference_radius:float=-1.0
		var reference_unit:Dictionary={}
		for faction in factions:
			var sim=SimulationType.new(catalog,faction,"normal")
			sim.factions[0]=faction
			var id:int=sim.spawn(kind,0,Vector2(400,400),false)
			var entity:Dictionary=sim.entities[id]
			var multiplier:Dictionary=catalog.factions[faction]
			var weapon:Dictionary=catalog.weapons[unit.weapon] if unit.has("weapon") else {}
			var measured_damage=float(weapon.damage)*float(multiplier.damage) if not weapon.is_empty() else 0.0
			var measured_range=float(weapon.range) if not weapon.is_empty() else 0.0
			var measured_sight=float(unit.vision)
			var measured_cost=sim.cost(kind,0)
			var measured_hp=float(entity.max_hp)
			if reference_radius<0.0:
				reference_radius=sim.unit_radius(kind); reference_unit=unit.duplicate(true)
			assert(is_equal_approx(sim.unit_radius(kind),reference_radius),"%s/%s must share the role collision radius"%[kind,faction])
			assert(unit==reference_unit,"%s/%s must share role movement, turn, sight, range and production definitions"%[kind,faction])
			assert(entity.pos==Vector2(400,400),"all faction models use the same simulation target and projectile origin")
			assert(is_equal_approx(float(unit.time),float(reference_unit.time)),"production duration is role-authored and faction independent")
			var asset_path="res://assets/models/vehicles/factions/%s_%s.glb"%[faction,kind]
			if faction=="forge": asset_path="res://assets/models/vehicles/%s.glb"%kind
			var packed=load(asset_path) as PackedScene
			assert(packed!=null,"%s/%s model must exist for bounds fairness check"%[faction,kind])
			var model=packed.instantiate() as Node3D
			root.add_child(model)
			var bounds:=_world_bounds(model)
			model.free()
			var origin="unit center (shared simulation origin)"
			rows.append("%s,%s,%.1f,%.2f,%.2f,%.2f,%s,%s,%.1f,%.1f,%.1f,%.1f,%.1f,%.2f,%d,%.1f"%[
				kind,faction,sim.unit_radius(kind),float(bounds.get("x",0.0)),float(bounds.get("y",0.0)),float(bounds.get("z",0.0)),origin,origin,measured_range,measured_sight,measured_hp,measured_damage,
				float(unit.speed)*float(multiplier.speed),float(unit.turn_speed),measured_cost,float(unit.time)])
			assert(float(bounds.get("x",0.0))>0.0 and float(bounds.get("z",0.0))>0.0,"%s/%s geometry must have measurable world bounds"%[kind,faction])
	var file=FileAccess.open("res://test-output/faction_vehicle_balance_audit.csv",FileAccess.WRITE)
	file.store_string("\n".join(rows)+"\n"); file.close()
	print("Faction balance audit: collision, targeting, muzzle origin, role sight/range/turn/time all remain shared; faction combat/economy scalars are explicit in test-output/faction_vehicle_balance_audit.csv")
	quit()

func _world_bounds(root_node:Node3D)->Dictionary:
	var found:=false; var bounds:=AABB(); var stack:Array[Node]=[root_node]
	while not stack.is_empty():
		var node:Node=stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh!=null:
			var mesh:=node as MeshInstance3D; var transformed:=mesh.global_transform*mesh.get_aabb()
			bounds=transformed if not found else bounds.merge(transformed); found=true
		for child in node.get_children(): stack.append(child)
	return {"x":snappedf(bounds.size.x,0.01),"y":snappedf(bounds.size.y,0.01),"z":snappedf(bounds.size.z,0.01)} if found else {}
