extends RefCounted
class_name Simulation

signal event(kind: String, position: Vector2, message: String)
signal presentation(kind: String, data: Dictionary)
var db: Catalog
var grid: WorldGrid
var entities: Dictionary = {}
var projectiles: Array = []
var effects: Array = []
var credits: Array = [0.0,0.0]
var factions: Array = ["forge","drift"]
var player_colors: Array = ["19ddd4","f34c32","b967ef","408bf4","f1c744","74ce47","f478bf","eee0bc"]
var fog: Array = []
var explored: Array = []
var known: Array = [{},{}]
var next_id := 1
var time := 0.0
var fog_timer := 0.0
var ai_timer := 0.0
var difficulty := "normal"
var campaign_tech_level := 0
var result := ""
var online_mode := ""
var view_owner := 0
var winner := -1
var side_stats: Array = []
var ai_state := "ECONOMY"
var ai_scout_index := 0
var ai_production_timer := 0.0
var combat_heat := 0.0
var base_alarm := 0.0
var path_requests: Array = []
var stats := {"gathered":0.0,"produced":0,"lost":0,"kills":0,"built":0,"buildings_lost":0}
var rng := RandomNumberGenerator.new()
var objective_announced: Dictionary = {}
var triggered_waves: Dictionary = {}

# Approximate body radii; ephemeral neighbour buckets never enter save/network data.
const UNIT_RADII := {"scout":14.0,"tank":22.0,"siege":26.0,"harvester":28.0,"raider":21.0,"lancer":29.0,"scorcher":23.0,"bulwark":34.0}
var movement_buckets: Dictionary = {}
var movement_buckets_valid := false
var building_ids: Array[int] = []
var mobile_entity_count := 0

func unit_radius(kind: String) -> float:
	return float(UNIT_RADII.get(kind,22.0))

func rebuild_movement_buckets() -> void:
	movement_buckets.clear()
	mobile_entity_count=0
	for e in entities.values():
		if e.building: continue
		mobile_entity_count+=1
		var cell := Vector2i(floor(e.pos.x/80.0),floor(e.pos.y/80.0))
		if not movement_buckets.has(cell): movement_buckets[cell]=[]
		movement_buckets[cell].append(e)
	movement_buckets_valid=true

func unit_separation(e: Dictionary) -> Vector2:
	var force := Vector2.ZERO
	var cell := Vector2i(floor(e.pos.x/80.0),floor(e.pos.y/80.0))
	for y in range(-1,2):
		for x in range(-1,2):
			for other in movement_buckets.get(cell+Vector2i(x,y),[]):
				if other.id==e.id or not entities.has(other.id): continue
				var difference: Vector2 = e.pos-other.pos
				var distance := difference.length()
				var gap := unit_radius(e.kind)+unit_radius(other.kind)+4.0
				var combat_spread := false
				if e.order in ["attack","attack_move"] and int(e.get("target",0))>0 and entities.has(int(e.target)):
					var combat_target: Dictionary=entities[int(e.target)]
					combat_spread=combat_target.building and e.pos.distance_to(combat_target.pos)<190.0
				if combat_spread: gap+=8.0
				if distance>=gap: continue
				# A deterministic opposite impulse also resolves coincident spawn points.
				var away := difference/distance if distance>0.01 else Vector2.from_angle(float(mini(e.id,other.id)%17)*0.37)*(1.0 if e.id>other.id else -1.0)
				if distance<gap*0.65:
					away=away.rotated(sin(float(mini(e.id,other.id)*7+maxi(e.id,other.id)*3))*0.5)
				force+=away*(gap-distance)*(2.05 if combat_spread else 1.6)
	return force

func team_color(owner: int) -> Color:
	return Color(player_colors[owner]) if owner>=0 and owner<player_colors.size() else Color("eac557")

func _init(catalog: Catalog, faction: String = "forge", level: String = "normal", tech_level: int = 0) -> void:
	db = catalog
	side_stats=[stats,stats.duplicate(true)]
	campaign_tech_level=clampi(tech_level,0,2)
	grid = WorldGrid.new(db.mission)
	factions = [faction, "drift" if faction != "drift" else "forge"]
	difficulty = level
	# Missions may tune the same AI profile without changing later scenarios.
	var mission_overrides: Dictionary=db.mission.get("rules_overrides",{}).get(level,{})
	for rule_name in mission_overrides:
		if db.rules.get(rule_name) is Dictionary:
			db.rules[rule_name][level]=mission_overrides[rule_name]
	credits = db.mission.credits.duplicate()
	rng.seed = int(db.mission.seed)
	for owner in 2:
		var f := PackedByteArray()
		f.resize(grid.width*grid.height)
		f.fill(0)
		fog.append(f)
		explored.append(f.duplicate())
	for s in db.mission.structures:
		spawn(s.kind,int(s.owner),Vector2(s.cell[0],s.cell[1])*grid.tile,true)
	for u in db.mission.units:
		spawn(u.kind,int(u.owner),grid.center(Vector2i(u.cell[0],u.cell[1])),false)
	update_fog()

func definition(e: Dictionary) -> Dictionary:
	return db.buildings[e.kind] if e.building else db.units[e.kind]

func cost(kind: String, owner: int) -> int:
	var d: Dictionary = db.buildings[kind] if db.buildings.has(kind) else db.units[kind]
	return roundi(float(d.cost)*float(db.factions[factions[owner]].cost))

func spawn(kind: String, owner: int, pos: Vector2, building: bool, completed: bool = true, rotation: int = 0) -> int:
	var d: Dictionary = db.buildings[kind] if building else db.units[kind]
	var e := {"id":next_id,"kind":kind,"owner":owner,"owner_id":owner,"team_id":owner,"faction_id":factions[owner],"building":building,"pos":pos,"hp":float(d.health)*float(db.factions[factions[owner]].health),"max_hp":float(d.health)*float(db.factions[factions[owner]].health),"angle":0.0,"turret":0.0,"path":[],"destination":pos,"order":"guard","target":0,"reload":0.0,"queue":[],"progress":0.0,"complete":completed,"build_progress":float(d.time) if completed else 0.0,"rally":pos+Vector2(0,130),"cargo":0.0,"harvest_state":"SEARCH_RESOURCE" if kind=="harvester" else "IDLE","resource":"","repair":false,"stuck":0.0,"last_pos":pos,"path_pending":false,"velocity":Vector2.ZERO}
	if building:
		e.upgrade_level=0
		e.upgrading=false
		e.upgrade_progress=0.0
		e.rotation=rotation
		var size_value := building_footprint(kind,rotation)
		var c := grid.cell(pos)
		e.pos = Vector2(c*grid.tile)+Vector2(size_value[0],size_value[1])*grid.tile*0.5
		e.cell = c
		e.rally = e.pos+Vector2(0,100).rotated(rotation*PI/2)
		grid.reserve(c,size_value,next_id,true)
	e.path_goal=e.destination
	entities[next_id] = e
	if building: building_ids.append(next_id)
	else:
		mobile_entity_count+=1
		if movement_buckets_valid:
			var movement_cell:=Vector2i(floor(e.pos.x/80.0),floor(e.pos.y/80.0))
			if not movement_buckets.has(movement_cell): movement_buckets[movement_cell]=[]
			movement_buckets[movement_cell].append(e)
	next_id += 1
	return next_id-1

func buildings(owner: int, kind: String = "", completed: bool = true) -> Array:
	var found: Array = []
	for id in building_ids:
		if not entities.has(id): continue
		var e: Dictionary=entities[id]
		if e.owner==owner and (kind=="" or e.kind==kind) and (not completed or e.complete): found.append(e)
	return found

func missing_requirements(kind: String, owner: int) -> Array[String]:
	var d: Dictionary = db.buildings[kind] if db.buildings.has(kind) else db.units[kind]
	var missing: Array[String]=[]
	if int(d.get("campaign_level",0))>campaign_tech_level:
		missing.append("Kampagnenfreigabe Einsatz %d"%int(d.campaign_level))
	for pre in d.get("requires",[]):
		if buildings(owner,pre).is_empty(): missing.append("Gebäude: "+str(db.buildings.get(pre,{}).get("name",pre)))
	if int(d.get("required_level",0))>0:
		var found_level:=false
		for facility in buildings(owner,"armory"):
			if int(facility.get("upgrade_level",0))>=int(d.required_level): found_level=true; break
		if not found_level: missing.append("Rüstungswerkstatt Stufe %d"%int(d.required_level))
	for facility_kind in d.get("facility_level",{}):
		var found_level:=false
		for facility in buildings(owner,str(facility_kind)):
			if int(facility.get("upgrade_level",0))>=int(d.facility_level[facility_kind]): found_level=true; break
		if not found_level: missing.append("%s Stufe %d"%[db.buildings[facility_kind].name,int(d.facility_level[facility_kind])])
	var power_needed:=int(d.get("power_required",0))
	if power_needed>0:
		var p:=power(owner)
		var reserved:=0
		for producer in buildings(owner,"factory"):
			for queue_index in range(1,producer.queue.size()):
				reserved+=int(db.units[str(producer.queue[queue_index].kind)].get("power_required",0))
		var spare:=int(p.y-p.x)-reserved
		if spare<power_needed: missing.append("Freie Energie: %d benötigt, %d verfügbar"%[power_needed,spare])
	return missing

func prerequisites(kind: String, owner: int) -> bool:
	return missing_requirements(kind,owner).is_empty()

func upgrade_building(id: int, owner: int) -> bool:
	if not entities.has(id): return false
	var e: Dictionary=entities[id]
	if owner!=e.owner or not e.building or not e.complete or e.get("upgrading",false): return false
	var next_level:=int(e.get("upgrade_level",0))+1
	var definition_value: Dictionary=db.buildings[e.kind]
	if next_level>int(definition_value.get("max_level",0)): return false
	var unlocks: Array=definition_value.get("upgrade_campaign_levels",[])
	var required_tech:=int(unlocks[next_level]) if next_level<unlocks.size() else next_level
	if required_tech>campaign_tech_level: return false
	var cost_value:=int(definition_value.upgrade_costs[next_level])
	if credits[owner]<cost_value: return false
	credits[owner]-=cost_value
	e.upgrading=true
	e.upgrade_target=next_level
	e.upgrade_progress=0.0
	e.upgrade_paid=cost_value
	e.upgrade_owner=owner
	e.upgrade_time=float(definition_value.upgrade_times[next_level])
	event.emit("upgrade",e.pos,definition_value.name+" · Ausbau auf Stufe %d begonnen"%next_level)
	return true

func power(owner: int) -> Vector2:
	var p := Vector2.ZERO
	for e in buildings(owner):
		var amount = definition(e).power
		if amount > 0: p.y += amount
		else: p.x -= amount
	# The active heavy vehicle occupies spare power while it is being assembled.
	# Queued jobs after the first reserve headroom in missing_requirements().
	for producer in buildings(owner,"factory"):
		if producer.queue.is_empty(): continue
		p.x+=int(db.units[str(producer.queue[0].kind)].get("power_required",0))
	return p

func powered(owner: int) -> bool:
	var p := power(owner)
	return p.y >= p.x

func building_footprint(kind: String, rotation: int = 0) -> Array:
	var size_value: Array = db.buildings[kind].footprint
	return [int(size_value[1]),int(size_value[0])] if rotation%2==1 else [int(size_value[0]),int(size_value[1])]

func footprint(e: Dictionary) -> Array:
	return building_footprint(e.kind,int(e.get("rotation",0)))

func build_reason(kind: String, owner: int, c: Vector2i, rotation: int = 0) -> String:
	if not prerequisites(kind,owner): return "ANFORDERUNG FEHLT: "+", ".join(missing_requirements(kind,owner))
	if credits[owner] < cost(kind,owner): return "ZU WENIG SOLARIT"
	var size_value := building_footprint(kind,rotation)
	var in_range := false
	for e in buildings(owner):
		if e.pos.distance_to(grid.center(c)) <= float(db.rules.build_radius)*grid.tile: in_range=true
	if not in_range: return "AUSSERHALB DES BAURADIUS"
	for y in int(size_value[1]):
		for x in int(size_value[0]):
			var cell := c+Vector2i(x,y)
			if not grid.inside(cell) or grid.type_at(cell) in [2,3,5,6]: return "UNGEEIGNETES TERRAIN"
			if not grid.is_free(cell): return "BAUFLÄCHE BLOCKIERT"
			if fog[owner][cell.y*grid.width+cell.x] == 0: return "NICHT IM SICHTBEREICH"
			for u in entities.values():
				if not u.building and grid.cell(u.pos)==cell: return "EINHEIT AUF BAUFLÄCHE"
	return ""

func build(kind: String, owner: int, c: Vector2i, rotation: int = 0) -> int:
	if build_reason(kind,owner,c,rotation)!="": return 0
	credits[owner] -= cost(kind,owner)
	var id := spawn(kind,owner,Vector2(c*grid.tile),true,false,rotation)
	event.emit("build",entities[id].pos,"Konstruktion begonnen")
	return id

func enqueue(kind: String, owner: int, producer_id: int = 0) -> bool:
	if not prerequisites(kind,owner) or credits[owner]<cost(kind,owner): return false
	var producers := buildings(owner,"factory")
	if producers.is_empty(): return false
	var producer: Dictionary={}
	if producer_id>0:
		for candidate in producers:
			if int(candidate.id)==producer_id: producer=candidate; break
		if producer.is_empty() or producer.queue.size()>=12: return false
	else:
		producers.sort_custom(func(a,b): return a.queue.size() < b.queue.size())
		producer=producers[0]
		if producer.queue.size()>=12: return false
	credits[owner] -= cost(kind,owner)
	producer.queue.append({"kind":kind,"paid":cost(kind,owner)})
	return true

func cancel_queue(kind: String, owner: int) -> bool:
	for factory in buildings(owner,"factory"):
		for i in range(factory.queue.size()-1,-1,-1):
			if factory.queue[i].kind==kind:
				return cancel_queue_at(int(factory.id),i,owner)
	return false

func cancel_queue_at(factory_id: int, queue_index: int, owner: int) -> bool:
	if not entities.has(factory_id): return false
	var factory: Dictionary=entities[factory_id]
	if factory.owner!=owner or factory.kind!="factory" or queue_index<0 or queue_index>=factory.queue.size(): return false
	var job: Dictionary=factory.queue[queue_index]
	credits[owner]+=float(job.get("paid",0))*float(db.rules.cancel_refund)
	factory.queue.remove_at(queue_index)
	if queue_index==0: factory.progress=0.0
	event.emit("queue_cancel",factory.pos,"Auftrag entfernt · %s"%db.units[str(job.kind)].name)
	return true

func prioritize_queue(factory_id: int, queue_index: int, owner: int) -> bool:
	if not entities.has(factory_id): return false
	var factory: Dictionary=entities[factory_id]
	if factory.owner!=owner or factory.kind!="factory" or queue_index<=1 or queue_index>=factory.queue.size(): return false
	var job: Dictionary=factory.queue.pop_at(queue_index)
	factory.queue.insert(1,job)
	event.emit("queue_priority",factory.pos,"Auftrag priorisiert · %s"%db.units[str(job.kind)].name)
	return true

func move_queue(factory_id: int, queue_index: int, direction: int, owner: int) -> bool:
	if not entities.has(factory_id): return false
	var factory: Dictionary=entities[factory_id]
	if factory.owner!=owner or factory.kind!="factory" or queue_index<1 or queue_index>=factory.queue.size(): return false
	if direction not in [-1,1]: return false
	var target_index: int=queue_index+direction
	# Index 0 is already in production and must never be displaced by priority changes.
	if target_index<1 or target_index>=factory.queue.size(): return false
	var job: Dictionary=factory.queue.pop_at(queue_index)
	factory.queue.insert(target_index,job)
	event.emit("queue_priority",factory.pos,("Priorität erhöht · " if direction<0 else "Priorität gesenkt · ")+db.units[str(job.kind)].name)
	return true

func formation_destination(preferred: Vector2, reserved_cells: Dictionary) -> Vector2:
	var preferred_cell:=grid.cell(preferred)
	if grid.inside(preferred_cell) and grid.is_free(preferred_cell) and not reserved_cells.has(preferred_cell):
		reserved_cells[preferred_cell]=true
		return preferred
	# Formation slots may land inside a building footprint or on the far side of an
	# obstacle. Resolve to the nearest free, unclaimed neighbouring cell instead of
	# letting several units converge on the same blocked destination.
	var best_cell:=Vector2i(-1,-1)
	var best_distance:=INF
	for radius in range(1,5):
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				if abs(x)!=radius and abs(y)!=radius: continue
				var cell:=preferred_cell+Vector2i(x,y)
				if not grid.inside(cell) or not grid.is_free(cell) or reserved_cells.has(cell): continue
				var distance:=grid.center(cell).distance_squared_to(preferred)
				if distance<best_distance:
					best_distance=distance
					best_cell=cell
		if best_cell.x>=0: break
	if best_cell.x>=0:
		reserved_cells[best_cell]=true
		return grid.center(best_cell)
	return preferred

func command(ids: Array, point: Vector2, order: String = "move", target: int = 0) -> void:
	var count := 0
	var mobile_count := 0
	var spacing := 32.0
	for id in ids:
		if not entities.has(int(id)) or entities[int(id)].building: continue
		if order=="return" and entities[int(id)].kind!="harvester": continue
		mobile_count+=1
		spacing=maxf(spacing,unit_radius(entities[int(id)].kind)*2.0+10.0)
	var columns := maxi(1,ceili(sqrt(float(mobile_count))))
	var rows := ceili(float(mobile_count)/columns)
	var reserved_destinations: Dictionary={}
	for id in ids:
		if not entities.has(int(id)): continue
		var e: Dictionary = entities[int(id)]
		if e.building:
			if e.kind=="factory" and order in ["move","attack","attack_move"]: e.rally=point
			continue
		if order=="return" and e.kind!="harvester": continue
		# Superseding an order also cancels path requests that have not been processed yet.
		path_requests.erase(e.id)
		e.path_pending=false; e.path=[]
		e.order=order
		e.target=target
		var offset := Vector2.ZERO
		if mobile_count>1:
			var row := count/columns
			var stagger := 0.22 if row%2 else -0.22
			offset=Vector2(float(count%columns)-(columns-1)*0.5+stagger,float(row)-(rows-1)*0.5)*spacing
			offset+=Vector2(sin(count*2.4),cos(count*1.7))*3.0
		e.destination=formation_destination(point+offset,reserved_destinations) if order not in ["stop","hold","guard"] else point+offset
		if order in ["stop","hold","guard"]:
			e.path=[]
			e.destination=e.pos
		elif not (e.kind=="harvester" and order in ["harvest","return"]):
			request_path(e,e.destination)
		if e.kind=="harvester":
			if order=="harvest":
				var k := grid.key(grid.cell(point))
				var cell := grid.cell(point)
				if grid.inside(cell) and explored[e.owner][cell.y*grid.width+cell.x]>0 and grid.resources.has(k) and float(grid.resources[k])>0:
					e.resource=k; e.harvest_state="MOVE_TO_RESOURCE"; request_path(e,grid.center(grid.cell(point)))
				else: e.harvest_state="SEARCH_RESOURCE"; e.resource=""; e.path=[]
			elif order=="return": e.harvest_state="RETURN_TO_BASE"; e.path=[]
			else: e.harvest_state="IDLE"
		count+=1

# Serializable command boundary. Issuer comes from the trusted local player/AI caller,
# never from the payload. A future transport must authenticate it before dispatch.
func submit_command(packet: Dictionary, issuer: int) -> bool:
	if issuer<0 or issuer>=factions.size(): return false
	if not number(packet.get("owner_id")) or float(packet.owner_id)!=issuer: return false
	var kind: String = str(packet.get("type",""))
	if kind in ["build","produce","cancel_produce","cancel_queue_at","prioritize_queue","move_queue","upgrade"]:
		var item: String = str(packet.get("kind",""))
		if kind=="upgrade":
			var building_id=packet.get("id")
			if not number(building_id) or float(building_id)!=floor(float(building_id)): return false
			return upgrade_building(int(building_id),issuer)
		if kind in ["cancel_queue_at","prioritize_queue","move_queue"]:
			var factory_id=packet.get("factory_id")
			var queue_index=packet.get("queue_index")
			if not number(factory_id) or float(factory_id)!=floor(float(factory_id)) or not number(queue_index) or float(queue_index)!=floor(float(queue_index)): return false
			if kind=="cancel_queue_at": return cancel_queue_at(int(factory_id),int(queue_index),issuer)
			if kind=="prioritize_queue": return prioritize_queue(int(factory_id),int(queue_index),issuer)
			var direction=packet.get("direction")
			if not number(direction) or float(direction)!=floor(float(direction)) or int(direction) not in [-1,1]: return false
			return move_queue(int(factory_id),int(queue_index),int(direction),issuer)
		if kind=="build":
			if not db.buildings.has(item) or item=="core" or not vector_valid(packet.get("cell")): return false
			if float(packet.cell[0])!=floor(float(packet.cell[0])) or float(packet.cell[1])!=floor(float(packet.cell[1])): return false
			var rotation = packet.get("rotation",0)
			if not number(rotation) or float(rotation)!=floor(float(rotation)) or int(rotation) not in [0,1,2,3]: return false
			return build(item,issuer,Vector2i(packet.cell[0],packet.cell[1]),int(rotation))>0
		if not db.units.has(item): return false
		if kind=="cancel_produce": return cancel_queue(item,issuer)
		var producer_id:=0
		if packet.has("producer_id"):
			if not number(packet.producer_id) or float(packet.producer_id)!=floor(float(packet.producer_id)) or int(packet.producer_id)<0: return false
			producer_id=int(packet.producer_id)
		return enqueue(item,issuer,producer_id)
	if kind not in ["move","attack","attack_move","harvest","stop","hold","guard","rally","repair","return"]: return false
	if not packet.get("ids") is Array or packet.ids.is_empty(): return false
	var ids: Array = []
	for value in packet.ids:
		if not number(value) or float(value)!=floor(float(value)) or ids.has(int(value)): return false
		if not entities.has(int(value)) or entities[int(value)].owner!=issuer: return false
		var entity: Dictionary = entities[int(value)]
		if kind in ["harvest","return"] and entity.kind!="harvester": return false
		if kind=="repair" and not entity.complete: return false
		if kind=="rally" and (not entity.building or entity.kind!="factory"): return false
		ids.append(int(value))
	var point := Vector2.ZERO
	if kind in ["move","attack","attack_move","harvest","rally"]:
		if not vector_valid(packet.get("point")): return false
		point=Vector2(packet.point[0],packet.point[1])
		if not grid.inside(grid.cell(point)): return false
	var target_id := 0
	if kind=="attack":
		if not number(packet.get("target_id")) or float(packet.target_id)!=floor(float(packet.target_id)): return false
		target_id=int(packet.target_id)
		if not entities.has(target_id) or entities[target_id].owner==issuer or not is_visible(entities[target_id],issuer): return false
	if kind=="repair":
		if packet.has("enabled") and not packet.enabled is bool: return false
		var destinations := {}
		for id in ids:
			if entities[id].building: continue
			var destination := service_destination(entities[id])
			if destination.x<0: return false
			destinations[id]=destination
		for id in ids:
			if entities[id].building: entities[id].repair=packet.get("enabled",not entities[id].repair)
			else: command([id],destinations[id],"service")
	elif kind=="rally":
		for id in ids: entities[id].rally=point
	else: command(ids,point,kind,target_id)
	return true

func service_destination(unit: Dictionary) -> Vector2:
	if not powered(unit.owner): return Vector2(-1,-1)
	var hangars := buildings(unit.owner,"repair")
	hangars.sort_custom(func(a,b):return unit.pos.distance_squared_to(a.pos)<unit.pos.distance_squared_to(b.pos))
	for hangar in hangars:
		if unit.pos.distance_to(hangar.pos)<95: return unit.pos
		var footprint: Array = footprint(hangar)
		var candidates: Array[Vector2] = []
		for x in range(-1,int(footprint[0])+1):
			for y in range(-1,int(footprint[1])+1):
				if x>=0 and x<int(footprint[0]) and y>=0 and y<int(footprint[1]): continue
				var cell: Vector2i = hangar.cell+Vector2i(x,y)
				var goal := grid.center(cell)
				if grid.is_free(cell) and goal.distance_to(hangar.pos)<100: candidates.append(goal)
		candidates.sort_custom(func(a,b):return unit.pos.distance_squared_to(a)<unit.pos.distance_squared_to(b))
		for goal in candidates:
			if not grid.path(unit.pos,goal).is_empty(): return goal
	return Vector2(-1,-1)

func request_path(e: Dictionary, dest: Vector2) -> void:
	e.path_goal=dest
	if not e.path_pending:
		e.path_pending=true
		path_requests.append(e.id)

func tick(dt: float) -> void:
	if result!="": return
	time+=dt
	combat_heat=maxf(0,combat_heat-dt*0.07)
	base_alarm=maxf(0,base_alarm-dt)
	for i in mini(4,path_requests.size()):
		var id: int = path_requests.pop_front()
		if entities.has(id):
			var e: Dictionary = entities[id]
			e.path=grid.path(e.pos,e.path_goal)
			e.path_pending=false
	rebuild_movement_buckets()
	for e in entities.values():
		if not entities.has(e.id): continue
		if e.building:
			process_building(e,dt)
		else:
			if e.kind=="harvester": harvest(e,dt)
			move_unit(e,dt)
		if e.complete: combat(e,dt)
	process_projectiles(dt)
	for fx in effects: fx.life-=dt
	effects=effects.filter(func(f):return f.life>0)
	fog_timer-=dt
	if fog_timer<=0:
		update_fog()
		fog_timer=0.25
	ai_timer-=dt
	ai_production_timer-=dt
	if ai_timer<=0:
		if online_mode!="versus" and bool(db.mission.get("ai_enabled",true)): think_ai()
		ai_timer=float(db.rules.ai_interval[difficulty])
	if online_mode!="versus": process_mission_waves()
	check_objectives()

func process_building(e: Dictionary, dt: float) -> void:
	var speed := 1.0 if powered(e.owner) else 0.4
	if not e.complete:
		e.build_progress+=dt*speed
		if e.build_progress>=float(definition(e).time):
			e.complete=true
			side_stats[e.owner].built+=1
			if e.kind=="refinery":
				e.included_harvester=true
			event.emit("complete",e.pos,definition(e).name+" einsatzbereit")
		return
	if e.get("upgrading",false):
		e.upgrade_progress+=dt*speed
		if e.upgrade_progress>=float(e.get("upgrade_time",1)):
			e.upgrade_level=int(e.get("upgrade_target",int(e.get("upgrade_level",0))+1))
			e.upgrading=false
			e.upgrade_progress=0.0
			event.emit("upgrade_complete",e.pos,definition(e).name+" · Stufe %d einsatzbereit"%e.upgrade_level)
		return
	if e.get("included_harvester",false):
		var p := exit_cell(e)
		if p.x>=0: spawn("harvester",e.owner,grid.center(p),false); e.included_harvester=false
	if not e.queue.is_empty():
		var job: Dictionary = e.queue[0]
		e.progress+=dt*speed
		var production_time:=float(db.units[job.kind].time)*(0.85 if int(e.get("upgrade_level",0))>0 else 1.0)
		if e.progress>=production_time:
			var p := exit_cell(e)
			if p.x>=0:
				var id := spawn(job.kind,e.owner,grid.center(p),false)
				if job.kind!="harvester": command([id],e.rally)
				e.queue.pop_front()
				e.progress=0.0
				side_stats[e.owner].produced+=1
				event.emit("ready",e.pos,db.units[job.kind].name+" bereit")
	if e.repair and e.hp<e.max_hp: repair_entity(e,e.owner,dt)
	if e.kind=="repair" and powered(e.owner):
		for u in entities.values():
			if u.owner==e.owner and not u.building and u.pos.distance_to(e.pos)<100 and u.hp<u.max_hp:
				repair_entity(u,e.owner,dt)

func exit_cell(building: Dictionary) -> Vector2i:
	var size_value: Array = footprint(building)
	# Only perimeter exits are valid. A surrounded factory waits at 100%.
	var candidates: Array[Vector2i] = []
	for x in range(-1,int(size_value[0])+1):
		candidates.append(building.cell+Vector2i(x,int(size_value[1])))
		candidates.append(building.cell+Vector2i(x,-1))
	for y in int(size_value[1]):
		candidates.append(building.cell+Vector2i(-1,y))
		candidates.append(building.cell+Vector2i(int(size_value[0]),y))
	if int(building.get("rotation",0))!=0:
		var front := Vector2.DOWN.rotated(float(building.rotation)*PI/2)
		candidates.sort_custom(func(a,b):return (grid.center(a)-building.pos).dot(front)>(grid.center(b)-building.pos).dot(front))
	for c in candidates:
		if not grid.is_free(c): continue
		var occupied := false
		for u in entities.values():
			if not u.building and u.pos.distance_to(grid.center(c))<23: occupied=true; break
		if not occupied: return c
	return Vector2i(-1,-1)

func repair_entity(e: Dictionary, owner: int, dt: float) -> void:
	var amount := minf(float(db.rules.repair_rate)*dt,e.max_hp-e.hp)
	amount=minf(amount,float(credits[owner])/float(db.rules.repair_cost))
	credits[owner]-=amount*float(db.rules.repair_cost)
	e.hp+=amount

func move_unit(e: Dictionary, dt: float) -> void:
	if e.path.is_empty():
		e.velocity=Vector2.ZERO
		var settle := unit_separation(e).limit_length(18.0)*dt
		if settle.length_squared()>0.01 and grid.is_free(grid.cell(e.pos+settle)):
			e.pos+=settle
		return
	var target: Vector2 = e.path[0]
	var direction: Vector2 = target-e.pos
	if direction.length()<5:
		e.path.pop_front()
		return
	var d: Dictionary = definition(e)
	var speed := float(d.speed)*float(db.factions[factions[e.owner]].speed)
	if grid.type_at(grid.cell(e.pos))==2: speed*=0.6
	var desired: Vector2 = direction.normalized()*speed
	var separation := unit_separation(e)
	e.velocity=e.velocity.move_toward(desired,dt*speed*4)
	var delta_pos: Vector2 = (e.velocity+separation.limit_length(speed*0.6))*dt
	if delta_pos.length()>direction.length(): delta_pos=direction
	# Face the actual blended movement vector. During diagonal turns, inertia and
	# unit separation can differ from the next path segment for several frames.
	if delta_pos.length_squared()>0.01:
		e.angle=rotate_toward(e.angle,delta_pos.angle(),float(d.turn_speed)*dt)
	var proposed: Vector2 = e.pos+delta_pos
	if grid.is_free(grid.cell(proposed)):
		e.pos=proposed
	else:
		request_path(e,e.path_goal)
	e.stuck+=dt
	if e.stuck>=1.5:
		if e.pos.distance_to(e.last_pos)<6: request_path(e,e.path_goal)
		e.last_pos=e.pos
		e.stuck=0.0

func nearest_building(e: Dictionary, kind: String) -> Dictionary:
	var found: Dictionary = {}
	var best := INF
	for b in buildings(e.owner,kind):
		var distance: float = e.pos.distance_squared_to(b.pos)
		if distance<best: best=distance; found=b
	return found

func harvest(e: Dictionary, dt: float) -> void:
	if e.harvest_state=="IDLE":
		# A service order keeps collectors at the hangar until fully repaired.
		if e.order=="service" and e.hp<e.max_hp: return
		# Moving a collector relocates it; on arrival its autonomous work resumes.
		if e.order in ["stop","hold"] or not e.path.is_empty() or e.path_pending: return
		e.harvest_state="RETURN_TO_BASE" if e.cargo>0 else "SEARCH_RESOURCE"
	if e.harvest_state=="EVADE":
		if e.path.is_empty(): e.harvest_state="RETURN_TO_BASE" if e.cargo>0 else "SEARCH_RESOURCE"
		return
	if e.harvest_state=="SEARCH_RESOURCE":
		var best := INF
		var found := ""
		# Continue the explicitly assigned field after each unload until it is depleted.
		if float(grid.resources.get(e.resource,0))>0: found=e.resource; best=-1.0
		for k in grid.resources:
			if float(grid.resources[k])<=0: continue
			var c := grid.parse_key(k)
			if explored[e.owner][c.y*grid.width+c.x]==0: continue
			var distance: float = e.pos.distance_squared_to(grid.center(c))
			if distance<best: best=distance; found=k
		if found=="": return
		e.resource=found
		e.harvest_state="MOVE_TO_RESOURCE"
		request_path(e,grid.center(grid.parse_key(found)))
	elif e.harvest_state=="MOVE_TO_RESOURCE":
		if float(grid.resources.get(e.resource,0))<=0: e.harvest_state="SEARCH_RESOURCE"; return
		if e.pos.distance_to(grid.center(grid.parse_key(e.resource)))<27: e.harvest_state="HARVEST"; e.path=[]
		elif e.path.is_empty() and not e.path_pending: e.harvest_state="SEARCH_RESOURCE"
	elif e.harvest_state=="HARVEST":
		var amount := minf(float(db.rules.harvest_rate)*dt,float(grid.resources.get(e.resource,0)))
		amount=minf(amount,float(db.rules.harvest_capacity)-float(e.cargo))
		grid.resources[e.resource]-=amount
		e.cargo+=amount
		if e.cargo>=float(db.rules.harvest_capacity) or grid.resources[e.resource]<=0:
			e.harvest_state="RETURN_TO_BASE"
	elif e.harvest_state in ["RETURN_TO_BASE","UNLOAD"]:
		var refinery := nearest_building(e,"refinery")
		if refinery.is_empty(): e.path=[]; return
		var dock: Vector2 = refinery_dock(e,refinery)
		if dock==Vector2(-1,-1): return
		if e.pos.distance_to(dock)>32:
			e.harvest_state="RETURN_TO_BASE"
			if e.path.is_empty() and not e.path_pending: request_path(e,dock)
		else:
			e.path=[]
			e.harvest_state="UNLOAD"
			var amount := minf(e.cargo,float(db.rules.unload_rate)*dt)
			e.cargo-=amount
			var bonus:=1.0+0.20*float(refinery.get("upgrade_level",0))
			credits[e.owner]+=amount*bonus
			side_stats[e.owner].gathered+=amount*bonus
			if e.cargo<=0: e.harvest_state="SEARCH_RESOURCE"

func refinery_dock(e: Dictionary, refinery: Dictionary) -> Vector2:
	# Pick a reachable perimeter cell on whichever side is easiest to approach.
	# The old fixed south-side dock made collectors circle whole refineries and
	# could leave them looking stranded when that single route was obstructed.
	var refinery_id:=int(refinery.id)
	if int(e.get("harvest_dock_refinery",0))==refinery_id:
		var cached:Variant=e.get("harvest_dock",Vector2(-1,-1))
		if cached is Vector2 and cached!=Vector2(-1,-1): return cached
	var origin: Vector2i=refinery.get("cell",grid.cell(refinery.pos))
	var size_value:=footprint(refinery)
	var best:=INF
	var dock:=Vector2(-1,-1)
	for y in range(-1,int(size_value[1])+1):
		for x in range(-1,int(size_value[0])+1):
			if x>=0 and x<int(size_value[0]) and y>=0 and y<int(size_value[1]): continue
			var cell:=origin+Vector2i(x,y)
			if not grid.is_free(cell): continue
			var point:=grid.center(cell)
			var path:=grid.path(e.pos,point)
			if path.is_empty() and e.pos.distance_to(point)>32.0: continue
			var cost:float=float(path.size())+e.pos.distance_to(point)/float(grid.tile)*0.05
			if cost<best: best=cost; dock=point
	e.harvest_dock_refinery=refinery_id
	e.harvest_dock=dock
	return dock

func is_visible(e: Dictionary, owner: int) -> bool:
	var c := grid.cell(e.pos)
	return grid.inside(c) and fog[owner][c.y*grid.width+c.x]>0

func update_fog(remember: bool = true) -> void:
	for owner in 2:
		fog[owner].fill(0)
		for e in entities.values():
			if e.owner!=owner or not e.complete: continue
			var c := grid.cell(e.pos)
			var radius := int(definition(e).vision)+(4*int(e.get("upgrade_level",0)) if e.kind=="radar" else 0)
			for y in range(maxi(0,c.y-radius),mini(grid.height,c.y+radius+1)):
				for x in range(maxi(0,c.x-radius),mini(grid.width,c.x+radius+1)):
					if Vector2(x-c.x,y-c.y).length_squared()<=radius*radius:
						fog[owner][y*grid.width+x]=1
						explored[owner][y*grid.width+x]=1
		if not remember: continue
		for e in entities.values():
			if e.owner!=owner and is_visible(e,owner): known[owner][str(e.id)]={"pos":e.pos,"kind":e.kind,"building":e.building,"seen":time,"rotation":e.get("rotation",0)}
		for k in known[owner].keys():
			var memory: Dictionary = known[owner][k]
			var c := grid.cell(memory.pos)
			if grid.inside(c) and fog[owner][c.y*grid.width+c.x]>0 and not entities.has(int(k)): known[owner].erase(k)

func combat(e: Dictionary, dt: float) -> void:
	var d: Dictionary = definition(e)
	if not d.has("weapon"): return
	if e.building and not powered(e.owner): return
	e.reload=maxf(0,e.reload-dt)
	var weapon: Dictionary = db.weapons[d.weapon]
	var target: Dictionary = entities.get(int(e.target),{})
	if not target.is_empty() and (target.owner==e.owner or not is_visible(target,e.owner)): target={}; e.target=0
	if not target.is_empty() and e.order in ["move","guard","stop","hold"] and not definition(target).has("weapon"):
		target={}; e.target=0
	if target.is_empty():
		var best := float(weapon.range)+100 if e.order=="attack_move" else float(weapon.range)
		var best_score := INF
		for other in entities.values():
			if other.owner==e.owner or not is_visible(other,e.owner): continue
			var distance: float = e.pos.distance_to(other.pos)
			# Armed threats take precedence over economy targets during automatic defense.
			var score := distance+(0.0 if definition(other).has("weapon") else best*2.0)
			if distance<best and distance>=float(weapon.minimum_range) and score<best_score:
				best_score=score; target=other
		if not target.is_empty(): e.target=target.id
	if target.is_empty():
		if not e.building and e.order=="attack_move" and e.path.is_empty() and not e.path_pending and e.pos.distance_to(e.destination)>25:
			request_path(e,e.destination)
		return
	var direction: Vector2 = target.pos-e.pos
	var distance := direction.length()
	e.turret=rotate_toward(e.turret,direction.angle(),4*dt)
	if distance>float(weapon.range):
		if not e.building and e.order in ["attack","attack_move"] and not e.path_pending:
			if e.path.is_empty() or time-float(e.get("pursuit_time",0))>1.5:
				var original: Vector2 = e.destination
				request_path(e,target.pos)
				if e.order=="attack_move": e.destination=original
				e.pursuit_time=time
		return
	if distance<float(weapon.minimum_range): return
	if e.order in ["attack","attack_move"]: e.path=[]
	if e.reload>0: return
	e.reload=float(weapon.reload)
	projectiles.append({"pos":e.pos,"last":target.pos,"target":target.id,"owner":e.owner,"weapon":d.weapon,"life":5.0})
	combat_heat=minf(1,combat_heat+0.06)
	event.emit("shot",e.pos,"")
	presentation.emit("shot",{"pos":e.pos,"angle":e.turret,"weapon":d.weapon,"owner":e.owner,"id":e.id})

func process_projectiles(dt: float) -> void:
	var alive: Array = []
	for p in projectiles:
		p.life-=dt
		var weapon: Dictionary = db.weapons[p.weapon]
		var target: Dictionary = entities.get(int(p.target),{})
		if not target.is_empty(): p.last=target.pos
		var delta_pos: Vector2 = p.last-p.pos
		if delta_pos.length()<=float(weapon.speed)*dt:
			if float(weapon.splash)>0:
				for e in entities.values():
					if e.owner!=p.owner and e.pos.distance_to(p.last)<float(weapon.splash): damage(e,weapon,p.owner)
			elif not target.is_empty(): damage(target,weapon,p.owner)
			effects.append({"pos":p.last,"life":0.35,"max_life":0.35,"radius":18.0,"event_backed":true})
			presentation.emit("impact",{"pos":p.last,"weapon":p.weapon,"owner":p.owner})
		else:
			p.pos+=delta_pos.normalized()*float(weapon.speed)*dt
			if p.life>0: alive.append(p)
	projectiles=alive

func damage(e: Dictionary, weapon: Dictionary, attacker: int) -> void:
	var modifier := float(db.rules.armor[weapon.type].get(definition(e).armor,1.0))
	e.hp-=float(weapon.damage)*modifier*float(db.factions[factions[attacker]].damage)
	presentation.emit("hit",{"pos":e.pos,"id":e.id,"owner":e.owner,"building":e.building})
	if e.owner==0 and e.building:
		if base_alarm<=0: event.emit("alarm",e.pos,"BASIS WIRD ANGEGRIFFEN")
		base_alarm=6.0
	if e.kind=="harvester" and e.harvest_state!="EVADE":
		var refinery := nearest_building(e,"refinery")
		if not refinery.is_empty(): request_path(e,refinery.pos+Vector2(0,100)); e.harvest_state="EVADE"
	if e.hp<=0: destroy(e.id)

func destroy(id: int) -> void:
	if not entities.has(id): return
	var e: Dictionary = entities[id]
	if e.building: grid.reserve(e.cell,footprint(e),id,false)
	if e.building: side_stats[e.owner].buildings_lost+=1
	else: side_stats[e.owner].lost+=1
	if e.building: building_ids.erase(id)
	else: mobile_entity_count=maxi(0,mobile_entity_count-1)
	side_stats[1-e.owner].kills+=1
	effects.append({"pos":e.pos,"life":0.8,"max_life":0.8,"radius":55.0 if e.building else 30.0,"event_backed":true})
	presentation.emit("destroy",{"id":e.id,"pos":e.pos,"owner":e.owner,"building":e.building,"kind":e.kind,"angle":float(e.get("rotation",0))*PI/2 if e.building else e.angle,"visual_footprint":footprint(e) if e.building else [1,1],"visual_size":maxf(float(footprint(e)[0]),float(footprint(e)[1])) if e.building else 1.0})
	event.emit("explosion",e.pos,"")
	entities.erase(id)
	for other in entities.values():
		if int(other.target)==id:
			other.target=0
			if other.order=="attack_move": request_path(other,other.destination)

func objective_complete(objective: Dictionary) -> bool:
	var objective_type: String=str(objective.get("type",""))
	var owner: int=int(objective.get("owner",0))
	var kind: String=str(objective.get("kind",""))
	match objective_type:
		"destroy_target":
			return buildings(owner,kind,false).is_empty()
		"destroy_all":
			for entity in entities.values():
				if int(entity.owner)!=owner: continue
				if kind!="" and str(entity.kind)!=kind: continue
				return false
			return true
		"protect":
			return not buildings(owner,kind,false).is_empty()
		"survive":
			return time>=float(objective.get("seconds",0.0))
		"harvest_amount":
			return float(stats.gathered)>=float(objective.get("amount",0.0))
		"build_structure":
			return buildings(owner,kind,true).size()>=int(objective.get("count",1))
	return false

func objective_failed(objective: Dictionary) -> bool:
	if str(objective.get("type",""))!="protect": return false
	return buildings(int(objective.get("owner",0)),str(objective.get("kind","")),false).is_empty()

func objective_progress_text(objective: Dictionary) -> String:
	var objective_type: String=str(objective.get("type",""))
	match objective_type:
		"survive":
			var target:=int(objective.get("seconds",0))
			return "%02d:%02d / %02d:%02d" % [mini(int(time),target)/60,mini(int(time),target)%60,target/60,target%60]
		"harvest_amount":
			return "%d / %d" % [mini(int(stats.gathered),int(objective.get("amount",0))),int(objective.get("amount",0))]
		"build_structure":
			return "%d / %d" % [buildings(int(objective.get("owner",0)),str(objective.get("kind","")),true).size(),int(objective.get("count",1))]
	return ""

func objective_latched(objective: Dictionary) -> bool:
	if str(objective.get("type",""))=="protect": return objective_complete(objective)
	return objective_announced.has(str(objective.get("id",""))) or objective_complete(objective)

func hud_objective_text() -> String:
	if online_mode=="versus": return "1:1 · ZERSTÖRE DEN FEINDLICHEN BAUKERN"
	for objective in db.mission.get("objectives",[]):
		if not bool(objective.get("primary",false)) or objective_failed(objective) or objective_latched(objective): continue
		var text_value: String=str(objective.get("hud",objective.get("text","MISSIONSZIEL"))).to_upper()
		var progress:=objective_progress_text(objective)
		return text_value+("  ·  "+progress if not progress.is_empty() else "")
	return "MISSIONSZIELE ERFÜLLT" if result=="victory" else "EINSATZZIELE AKTIV"

func optional_objective_progress_text() -> String:
	if online_mode!="": return ""
	var optional_total:=0
	var optional_complete:=0
	var parts: Array[String]=[]
	for objective in db.mission.get("objectives",[]):
		if not bool(objective.get("optional",false)): continue
		optional_total+=1
		var done:=objective_latched(objective)
		if done: optional_complete+=1
		var title:=str(objective.get("hud",objective.get("text","NEBENZIEL"))).to_upper()
		var progress:=objective_progress_text(objective)
		parts.append(("✓ " if done else "")+title+(" · "+progress if not done and not progress.is_empty() else ""))
	if optional_total==0: return ""
	return "NEBENZIELE %d/%d  ·  %s" % [optional_complete,optional_total,"  /  ".join(parts)]

func process_mission_waves() -> void:
	var waves: Array=db.mission.get("waves",[])
	for index in range(waves.size()):
		var key:=str(index)
		if triggered_waves.has(key): continue
		var wave: Dictionary=waves[index]
		if time<float(wave.get("time",INF)): continue
		triggered_waves[key]=true
		var unit_data: Variant=wave.get("units",[])
		var unit_kinds: Array=[]
		if unit_data is Dictionary:
			unit_kinds=unit_data.get(difficulty,unit_data.get("normal",[])).duplicate()
		elif unit_data is Array:
			unit_kinds=unit_data.duplicate()
		var raw_spawn: Array=wave.get("spawn_cell",[grid.width-2,2])
		var spawn_cell:=Vector2i(int(raw_spawn[0]),int(raw_spawn[1]))
		var ids: Array=[]
		for unit_index in range(unit_kinds.size()):
			var kind: String=str(unit_kinds[unit_index])
			if not db.units.has(kind): continue
			var offset:=Vector2i(unit_index%4,floori(float(unit_index)/4.0))
			var cell:=grid.nearest_free(spawn_cell+offset)
			if cell.x<0: continue
			ids.append(spawn(kind,1,grid.center(cell),false))
		var target:=Vector2.ZERO
		if wave.has("target_cell"):
			var raw_target: Array=wave.target_cell
			target=grid.center(Vector2i(int(raw_target[0]),int(raw_target[1])))
		elif not buildings(0,"core",false).is_empty(): target=buildings(0,"core",false)[0].pos
		if not ids.is_empty(): command(ids,target,"attack_move")
		var home:=buildings(0,"core",false)
		var notice_pos: Vector2=home[0].pos if not home.is_empty() else target
		event.emit("alarm",notice_pos,str(wave.get("message","FEINDBEWEGUNG ERKANNT")))

func check_objectives() -> void:
	if result!="": return
	if online_mode=="versus":
		if buildings(0,"core",false).is_empty() or buildings(1,"core",false).is_empty():
			winner=1 if buildings(0,"core",false).is_empty() else 0
			result="victory" if winner==view_owner else "defeat"
		return
	var primary_total:=0
	var primary_complete:=0
	for objective in db.mission.get("objectives",[]):
		var id: String=str(objective.get("id",""))
		if objective_failed(objective):
			result="defeat"
			return
		var completed_now:=objective_complete(objective)
		if completed_now and not objective_announced.has(id) and str(objective.get("type",""))!="protect":
			objective_announced[id]=true
			var home:=buildings(0,"core",false)
			var event_pos: Vector2=home[0].pos if not home.is_empty() else Vector2.ZERO
			event.emit("complete",event_pos,"ZIEL ERFÜLLT · "+str(objective.get("text","")))
		if bool(objective.get("primary",false)):
			primary_total+=1
			if completed_now or objective_announced.has(id): primary_complete+=1
	if primary_total>0 and primary_complete==primary_total:
		result="victory"
	# A destroyed player core always takes precedence.
	if buildings(0,"core",false).is_empty(): result="defeat"

func think_ai() -> void:
	var owner := 1
	var cores := buildings(owner,"core")
	if cores.is_empty(): return
	var home: Vector2 = cores[0].pos
	var army: Array = []
	var harvesters := 0
	for e in entities.values():
		if e.owner!=owner or e.building: continue
		if e.kind=="harvester": harvesters+=1
		else: army.append(e)
	var threat: Array = []
	for e in entities.values():
		if e.owner==0 and is_visible(e,owner) and e.pos.distance_to(home)<450: threat.append(e)
	if not threat.is_empty():
		ai_state="DEFEND"
		for e in army: command([e.id],threat[0].pos,"attack",threat[0].id)
	else:
		var intel: Array = known[owner].values().filter(func(k):return k.building)
		if time>=float(db.rules.attack_grace[difficulty]) and army.size()>=int(db.rules.attack_size[difficulty]) and not intel.is_empty():
			ai_state="ATTACK"
			intel.sort_custom(func(a,b):return a.kind=="core" and b.kind!="core")
			var ids: Array = []
			var committed := 0
			for e in army:
				if e.hp/e.max_hp<0.25:
					command([e.id],home+Vector2(0,150),"move")
				elif committed<int(db.rules.attack_commit[difficulty]): ids.append(e.id); committed+=1
			command(ids,intel[0].pos,"attack_move")
		else:
			ai_state="SCOUT" if intel.is_empty() else "REGROUP"
			for e in army:
				if e.kind=="scout" and e.path.is_empty():
					# Search waypoints cover the map; they do not reference hidden enemy positions.
					var points := [Vector2(31,27),Vector2(18,27),Vector2(12,48),Vector2(15,12),Vector2(48,48)]
					command([e.id],points[ai_scout_index%points.size()]*grid.tile,"attack_move")
					ai_scout_index+=1
	var needed := ""
	if not powered(owner) or buildings(owner,"power",false).is_empty(): needed="power"
	elif buildings(owner,"refinery",false).is_empty(): needed="refinery"
	elif buildings(owner,"factory",false).is_empty(): needed="factory"
	elif difficulty=="hard" and buildings(owner,"radar",false).is_empty(): needed="radar"
	if needed!="" and credits[owner]>=cost(needed,owner):
		ai_state="REBUILD" if time>60 else "ECONOMY"
		for radius in range(3,9):
			var placed := false
			for offset in [Vector2i(radius,0),Vector2i(0,radius),Vector2i(-radius,0),Vector2i(0,-radius),Vector2i(radius,radius),Vector2i(-radius,radius)]:
				var c: Vector2i = grid.cell(home)+offset
				if build_reason(needed,owner,c)=="": build(needed,owner,c); placed=true; break
			if placed: break
	if harvesters==0 and not buildings(owner,"factory").is_empty():
		var queued := false
		for f in buildings(owner,"factory"):
			for j in f.queue:
				if j.kind=="harvester": queued=true
		if not queued: enqueue("harvester",owner)
	for f in buildings(owner,"factory"):
		if ai_production_timer<=0 and f.queue.size()<2 and army.size()<int(db.rules.army_limit[difficulty]):
			var kind := "tank"
			if army.filter(func(e):return e.kind=="scout").is_empty(): kind="scout"
			elif difficulty=="hard" and prerequisites("siege",owner) and army.size()%4==3: kind="siege"
			if enqueue(kind,owner): ai_production_timer=float(db.rules.ai_production_interval[difficulty])

func snapshot() -> Dictionary:
	var all: Array = []
	for e in entities.values():
		var copy: Dictionary = e.duplicate(true)
		for field in ["pos","destination","path_goal","rally","last_pos","velocity"]: copy[field]=[e[field].x,e[field].y]
		if e.building: copy.cell=[e.cell.x,e.cell.y]
		copy.path=[]
		for p in e.path: copy.path.append([p.x,p.y])
		all.append(copy)
	var bullets: Array = []
	for p in projectiles:
		var copy: Dictionary = p.duplicate(true)
		for field in ["pos","last"]: copy[field]=[p[field].x,p[field].y]
		bullets.append(copy)
	var memory: Array = known.duplicate(true)
	for side in memory:
		for k in side: side[k].pos=[side[k].pos.x,side[k].pos.y]
	var save_state: Dictionary={"online_mode":online_mode,"view_owner":view_owner,"winner":winner,"side_stats":side_stats.duplicate(true),"format_version":1,"mission":db.mission.id,"entities":all,"projectiles":bullets,"credits":credits,"resources":grid.resources,"factions":factions,"player_colors":player_colors.duplicate(),"time":time,"next_id":next_id,"rng_state":str(rng.state),"difficulty":difficulty,"result":result,"stats":stats,"explored":[Array(explored[0]),Array(explored[1])],"known":memory,"ai_state":ai_state,"ai_timer":ai_timer,"ai_scout_index":ai_scout_index,"ai_production_timer":ai_production_timer,"combat_heat":combat_heat,"base_alarm":base_alarm,"triggered_waves":triggered_waves.duplicate(true),"objective_announced":objective_announced.duplicate(true)}
	return save_state

func restore(save: Dictionary) -> Error:
	if save.get("online_mode","") not in ["","versus"]: return ERR_INVALID_DATA
	if not NetworkProtocol.is_integer(save.get("view_owner",0)) or int(save.get("view_owner",0)) not in [0,1] or not NetworkProtocol.is_integer(save.get("winner",-1)) or int(save.get("winner",-1)) not in [-1,0,1]: return ERR_INVALID_DATA
	if save.has("side_stats"):
		if not save.side_stats is Array or save.side_stats.size()!=2: return ERR_INVALID_DATA
		for side in save.side_stats:
			if not side is Dictionary: return ERR_INVALID_DATA
			for key in stats:
				if not number(side.get(key)): return ERR_INVALID_DATA
	if save.has("viewer_fog"):
		if not save.viewer_fog is Array or save.viewer_fog.size()!=grid.width*grid.height: return ERR_INVALID_DATA
		for value in save.viewer_fog:
			if not number(value) or float(value)!=floor(float(value)) or int(value) not in [0,1]: return ERR_INVALID_DATA
	if save.has("player_colors"):
		if not save.player_colors is Array or save.player_colors.size()<2 or save.player_colors.size()>8: return ERR_INVALID_DATA
		for value in save.player_colors:
			if not value is String or not Color.html_is_valid(value): return ERR_INVALID_DATA
	if save.get("format_version",0)!=1 or save.get("mission","")!=db.mission.id: return ERR_INVALID_DATA
	for field in ["entities","projectiles","credits","resources","factions","explored","known","time","next_id","rng_state","difficulty","result","stats","ai_state","ai_timer","ai_scout_index","combat_heat","base_alarm"]:
		if not save.has(field): return ERR_INVALID_DATA
	if not save.entities is Array or not save.projectiles is Array or not save.resources is Dictionary: return ERR_INVALID_DATA
	if not save.credits is Array or save.credits.size()!=2 or not save.factions is Array or save.factions.size()!=2: return ERR_INVALID_DATA
	if not db.rules.ai_interval.has(save.difficulty) or save.result not in ["","victory","defeat"]: return ERR_INVALID_DATA
	for f in save.factions:
		if not db.factions.has(f): return ERR_INVALID_DATA
	for c in save.credits:
		if not number(c) or float(c)<0: return ERR_INVALID_DATA
	if not save.explored is Array or save.explored.size()!=2 or not save.known is Array or save.known.size()!=2: return ERR_INVALID_DATA
	for i in 2:
		if not save.explored[i] is Array or save.explored[i].size()!=grid.width*grid.height or not save.known[i] is Dictionary: return ERR_INVALID_DATA
		for value in save.explored[i]:
			if not number(value) or (value!=0 and value!=1): return ERR_INVALID_DATA
		for k in save.known[i]:
			var memory = save.known[i][k]
			if not memory is Dictionary or not vector_valid(memory.get("pos")) or not memory.has("kind") or not memory.has("building") or not number(memory.get("seen")): return ERR_INVALID_DATA
			if memory.has("rotation") and (not number(memory.rotation) or float(memory.rotation)!=floor(float(memory.rotation)) or int(memory.rotation) not in [0,1,2,3]): return ERR_INVALID_DATA
	var ids: Dictionary = {}
	for e in save.entities:
		if not e is Dictionary: return ERR_INVALID_DATA
		for field in ["id","kind","owner","building","hp","max_hp","angle","turret","path","order","target","reload","queue","progress","complete","build_progress","cargo","harvest_state","resource","repair","stuck"]:
			if not e.has(field): return ERR_INVALID_DATA
		if not number(e.id) or ids.has(int(e.id)) or not number(e.owner) or int(e.owner) not in [0,1] or not e.building is bool: return ERR_INVALID_DATA
		ids[int(e.id)]=true
		for field in ["owner_id","team_id"]:
			if e.has(field) and (not number(e[field]) or float(e[field])!=float(e.owner)): return ERR_INVALID_DATA
		if e.has("faction_id") and e.faction_id!=save.factions[int(e.owner)]: return ERR_INVALID_DATA
		if not (db.buildings.has(e.kind) if e.building else db.units.has(e.kind)): return ERR_INVALID_DATA
		for field in ["pos","destination","path_goal","rally","last_pos","velocity"]:
			if not vector_valid(e.get(field)): return ERR_INVALID_DATA
		if e.building and not vector_valid(e.get("cell")): return ERR_INVALID_DATA
		if e.has("rotation") and (not number(e.rotation) or float(e.rotation)!=floor(float(e.rotation)) or int(e.rotation) not in [0,1,2,3]): return ERR_INVALID_DATA
		if not e.path is Array or not e.queue is Array: return ERR_INVALID_DATA
		for p in e.path:
			if not vector_valid(p): return ERR_INVALID_DATA
		for j in e.queue:
			if not j is Dictionary or not db.units.has(j.get("kind","")) or not number(j.get("paid")): return ERR_INVALID_DATA
		for field in ["hp","max_hp","angle","turret","reload","progress","build_progress","cargo","stuck"]:
			if not number(e[field]): return ERR_INVALID_DATA
		if e.max_hp<=0 or e.hp<=0: return ERR_INVALID_DATA
	for p in save.projectiles:
		if not p is Dictionary or not vector_valid(p.get("pos")) or not vector_valid(p.get("last")): return ERR_INVALID_DATA
		if not db.weapons.has(p.get("weapon","")) or int(p.get("owner",-1)) not in [0,1] or not number(p.get("target")) or not number(p.get("life")): return ERR_INVALID_DATA
	for k in save.resources:
		if not grid.resources.has(k) or not number(save.resources[k]) or save.resources[k]<0: return ERR_INVALID_DATA
	if not save.stats is Dictionary: return ERR_INVALID_DATA
	for k in stats:
		if not number(save.stats.get(k)): return ERR_INVALID_DATA
	for k in ["time","next_id","ai_timer","ai_scout_index","combat_heat","base_alarm"]:
		if not number(save[k]): return ERR_INVALID_DATA
	if save.has("triggered_waves") and not save.triggered_waves is Dictionary: return ERR_INVALID_DATA
	if save.has("objective_announced") and not save.objective_announced is Dictionary: return ERR_INVALID_DATA
	grid=WorldGrid.new(db.mission)
	entities.clear()
	building_ids.clear(); mobile_entity_count=0
	movement_buckets.clear(); movement_buckets_valid=false
	path_requests.clear()
	effects.clear()
	for raw in save.entities:
		var e: Dictionary = raw.duplicate(true)
		for field in ["pos","destination","path_goal","rally","last_pos","velocity"]: e[field]=Vector2(e[field][0],e[field][1])
		var points: Array = []
		for p in e.path: points.append(Vector2(p[0],p[1]))
		e.path=points
		e.path_pending=false
		e.id=int(e.id); e.owner=int(e.owner); e.target=int(e.target)
		e.owner_id=e.owner; e.team_id=e.owner; e.faction_id=save.factions[e.owner]
		for job in e.queue: job.paid=int(job.paid)
		if e.building:
			e.rotation=int(e.get("rotation",0))
			e.cell=Vector2i(e.cell[0],e.cell[1])
			grid.reserve(e.cell,footprint(e),e.id,true)
		entities[e.id]=e
		if e.building: building_ids.append(e.id)
		else: mobile_entity_count+=1
	credits=save.credits.duplicate()
	factions=save.factions.duplicate()
	if save.has("player_colors"): player_colors=save.player_colors.duplicate()
	grid.resources=save.resources.duplicate()
	time=float(save.time); next_id=int(save.next_id); result=save.result; difficulty=save.difficulty
	rng.state=int(save.rng_state)
	stats=save.stats.duplicate()
	online_mode=str(save.get("online_mode",""))
	view_owner=int(save.get("view_owner",0))
	winner=int(save.get("winner",-1))
	side_stats=save.get("side_stats",[stats,stats.duplicate(true)]).duplicate(true)
	side_stats[view_owner]=stats
	ai_state=save.ai_state; ai_timer=float(save.ai_timer); ai_scout_index=int(save.ai_scout_index)
	ai_production_timer=float(save.get("ai_production_timer",0))
	combat_heat=float(save.combat_heat); base_alarm=float(save.base_alarm)
	triggered_waves=save.get("triggered_waves",{}).duplicate(true)
	objective_announced=save.get("objective_announced",{}).duplicate(true)
	explored=[PackedByteArray(save.explored[0]),PackedByteArray(save.explored[1])]
	known=save.known.duplicate(true)
	for side in known:
		for k in side:
			side[k].pos=Vector2(side[k].pos[0],side[k].pos[1])
			if side[k].has("rotation"): side[k].rotation=int(side[k].rotation)
	projectiles=save.projectiles.duplicate(true)
	for p in projectiles:
		for field in ["pos","last"]: p[field]=Vector2(p[field][0],p[field][1])
		p.owner=int(p.owner); p.target=int(p.target)
	rebuild_movement_buckets()
	update_fog(false)
	if save.has("viewer_fog"):
		fog[view_owner]=PackedByteArray(save.viewer_fog)
		fog[1-view_owner].fill(0)
		explored[1-view_owner].fill(0)
	return OK

func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func vector_valid(value: Variant) -> bool:
	return value is Array and value.size()==2 and number(value[0]) and number(value[1])

func configure_versus(config: Dictionary, owner: int = 0) -> void:
	online_mode="versus"; view_owner=owner; winner=-1; result=""
	factions=[str(config.get("host_faction","forge")),str(config.get("client_faction","drift"))]
	player_colors[0]=str(config.get("host_color","19ddd4"))
	player_colors[1]=str(config.get("client_color","f34c32"))
	campaign_tech_level=2
	credits=[float(config.get("start_credits",4200)),float(config.get("start_credits",4200))]
	entities.clear(); building_ids.clear(); mobile_entity_count=0
	movement_buckets.clear(); movement_buckets_valid=false
	projectiles.clear(); path_requests.clear(); effects.clear()
	grid=WorldGrid.new(db.mission); next_id=1; time=0.0
	stats={"gathered":0.0,"produced":0,"lost":0,"kills":0,"built":0,"buildings_lost":0}
	side_stats=[stats,stats.duplicate(true)]; stats=side_stats[view_owner]
	known=[{},{}]; triggered_waves.clear(); objective_announced.clear()
	for side in explored: side.fill(0)
	for side in 2:
		var start: Array=db.mission.player_starts[side]
		var cell:=Vector2i(int(start[0])-1,int(start[1])-1)
		spawn("core",side,Vector2(cell)*grid.tile,true)
		var scout_cell:=Vector2i(int(start[0])+3,int(start[1])+3)
		spawn("scout",side,grid.center(scout_cell),false)
	update_fog()

func snapshot_for(owner: int) -> Dictionary:
	if online_mode!="versus": return snapshot()
	var state:=snapshot().duplicate(true)
	var visible_ids: Dictionary={}
	var visible_entities: Array=[]
	for raw in state.entities:
		var entity: Dictionary=entities[int(raw.id)]
		if int(raw.owner)!=owner and not is_visible(entity,owner): continue
		visible_ids[int(raw.id)]=true
		if int(raw.owner)!=owner:
			var public_fields:=["id","kind","owner","owner_id","team_id","faction_id","building","hp","max_hp","angle","turret","pos","velocity","cell","rotation","complete","build_progress","upgrade_level","path","destination","path_goal","rally","last_pos","target","order","reload","queue","progress","cargo","resource","harvest_state","repair","stuck","path_pending"]
			for field in raw.keys():
				if field not in public_fields: raw.erase(field)
			# Only public appearance; no queues, targets, paths or economic intentions.
			for field in ["destination","path_goal","rally","last_pos"]: raw[field]=raw.pos.duplicate()
			raw.path=[]; raw.queue=[]; raw.target=0; raw.order="guard"
			raw.reload=0.0; raw.progress=0.0; raw.cargo=0.0; raw.resource=""
			raw.harvest_state="IDLE"; raw.repair=false; raw.stuck=0.0
			for field in ["pursuit_time","upgrade_paid","upgrade_owner","service_id","included_harvester"]:
				raw.erase(field)
		visible_entities.append(raw)
	state.entities=visible_entities
	for raw in state.entities:
		if not visible_ids.has(int(raw.target)): raw.target=0
	var visible_projectiles: Array=[]
	for raw in state.projectiles:
		var cell:=grid.cell(Vector2(raw.pos[0],raw.pos[1]))
		if not grid.inside(cell) or fog[owner][cell.y*grid.width+cell.x]==0: continue
		if not visible_ids.has(int(raw.target)): raw.target=0; raw.last=raw.pos.duplicate()
		visible_projectiles.append(raw)
	state.projectiles=visible_projectiles
	state.view_owner=owner
	state.credits[1-owner]=0.0
	state.stats=side_stats[owner].duplicate(true)
	state.side_stats=[{},{}]
	state.side_stats[owner]=state.stats.duplicate(true)
	state.side_stats[1-owner]={"gathered":0.0,"produced":0,"lost":0,"kills":0,"built":0,"buildings_lost":0}
	state.explored[1-owner]=Array(fog[owner].duplicate())
	state.explored[1-owner].fill(0)
	state.known[1-owner]={}
	state.viewer_fog=Array(fog[owner])
	state.rng_state="0"; state.ai_state="DUELL"; state.ai_timer=0.0
	state.ai_scout_index=0; state.ai_production_timer=0.0; state.base_alarm=0.0
	state.combat_heat=0.0; state.triggered_waves={}; state.objective_announced={}
	state.next_id=1
	for raw in visible_entities: state.next_id=maxi(state.next_id,int(raw.id)+1)
	for key in state.resources:
		var parts:=str(key).split(",")
		var cell:=Vector2i(int(parts[0]),int(parts[1]))
		if explored[owner][cell.y*grid.width+cell.x]==0: state.resources[key]=0.0
	state.result="" if winner<0 else ("victory" if winner==owner else "defeat")
	return state
