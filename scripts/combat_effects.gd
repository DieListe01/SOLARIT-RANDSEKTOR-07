extends RefCounted
class_name CombatEffects

# Local, bounded presentation state. Never feeds back into Simulation or its RNG.
var particles: Array[Dictionary] = []
var free_particles: Array[Dictionary] = []
var particle_pool_created := 0
var particle_pool_reused := 0
var particle_pool_peak := 0
var ruins: Array[Dictionary] = []
var flashes: Dictionary = {}
var shake := 0.0
var clock := 0.0
var quality := 2
var shake_mode := 1
var offset := Vector2.ZERO
var visual_rng := RandomNumberGenerator.new()
var craters: Array[Dictionary] = []
var profile_smoke_ms := 0.0
var profile_hit_ms := 0.0
var profile_shot_ms := 0.0
var profile_impact_ms := 0.0
var profile_destroy_ms := 0.0
var profile_dust_ms := 0.0
var profile_wrecks_ms := 0.0
const MAX_RUINS := 128
const MAX_CRATERS := 80
const OBJECT_KINDS := ["core", "power", "refinery", "factory", "radar", "repair", "armory", "tower", "scout", "tank", "siege", "harvester", "raider", "lancer", "scorcher", "bulwark"]
# Presentation profiles, not weapon balance. Five families are reserved for future weapons.
const FAMILIES = {
	"BALLISTIC_LIGHT": [22.0, "ffc477", 0.32, 0.0],
	"BALLISTIC_HEAVY": [48.0, "ffb347", 0.85, 2.0],
	"AUTOCANNON": [30.0, "ffe3a1", 0.45, 0.0],
	"ARTILLERY": [90.0, "ffa34d", 2.6, 5.0],
	"MISSILE": [66.0, "ff833d", 2.0, 3.0],
	"ENERGY": [34.0, "96f9ff", 0.65, 0.0],
	"SIEGE": [115.0, "ffb15a", 3.1, 6.5],
	"SPECIAL": [60.0, "c9a2ff", 1.6, 2.5]
}

func family(weapon: String) -> String:
	if FAMILIES.has(weapon): return weapon
	return {"pulse":"ENERGY", "cannon":"BALLISTIC_HEAVY", "mortar":"SIEGE", "shard":"AUTOCANNON", "lance":"SPECIAL", "flame":"ARTILLERY", "breaker":"SIEGE"}.get(weapon,"BALLISTIC_LIGHT")

func hit_offset(id: int) -> Vector2:
	var strength: float = float(flashes.get(id,0.0))/0.13
	return Vector2(sin(clock*110+id),cos(clock*93+id))*strength*1.8

func damage_stage(ratio: float) -> int:
	return 3 if ratio<0.15 else (2 if ratio<0.4 else (1 if ratio<0.7 else 0))

func recycle_particle(particle: Dictionary) -> void:
	if free_particles.size()>=220: return
	free_particles.append(particle)

func reset() -> void:
	for particle in particles: recycle_particle(particle)
	particles.clear(); ruins.clear(); craters.clear(); flashes.clear(); shake=0; offset=Vector2.ZERO

func persistence_snapshot() -> Dictionary:
	var result := {"version":1,"ruins":[],"craters":[]}
	for collection in ["ruins","craters"]:
		for record in (ruins if collection=="ruins" else craters):
			var item: Dictionary = record.duplicate(true)
			item.pos=[record.pos.x,record.pos.y]
			result[collection].append(item)
	return result

func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func restore_persistence(data: Variant, bounds: Vector2) -> Error:
	# Validate everything before assignment. Optional cosmetic extension to save format 1.
	if not data is Dictionary or data.get("version",0)!=1: return ERR_INVALID_DATA
	var restored := {"ruins":[],"craters":[]}
	for collection in ["ruins","craters"]:
		var records: Variant = data.get(collection,[])
		if not records is Array or records.size()>(MAX_RUINS if collection=="ruins" else MAX_CRATERS): return ERR_INVALID_DATA
		for record in records:
			if not record is Dictionary: return ERR_INVALID_DATA
			var pos: Variant = record.get("pos",null)
			if not pos is Array or pos.size()!=2: return ERR_INVALID_DATA
			for axis in 2:
				if not finite_number(pos[axis]) or float(pos[axis])<0 or float(pos[axis])>=bounds[axis]: return ERR_INVALID_DATA
			for field in ["radius","age"]:
				if not finite_number(record.get(field,null)) or float(record[field])<0: return ERR_INVALID_DATA
			if float(record.radius)>256 or float(record.age)>1e9: return ERR_INVALID_DATA
			var item := {"pos":Vector2(pos[0],pos[1]),"radius":float(record.radius),"age":float(record.age)}
			if collection=="ruins":
				if not record.get("building",null) is bool or not record.get("core",null) is bool: return ERR_INVALID_DATA
				if not record.get("object_kind",null) is String or not record.object_kind in OBJECT_KINDS: return ERR_INVALID_DATA
				if record.building!=(record.object_kind in OBJECT_KINDS.slice(0,7)) or record.core!=(record.object_kind=="core"): return ERR_INVALID_DATA
				if not finite_number(record.get("angle",null)) or not finite_number(record.get("variant",null)): return ERR_INVALID_DATA
				if float(record.variant)!=int(record.variant) or int(record.variant)<0 or int(record.variant)>3: return ERR_INVALID_DATA
				var footprint: Variant = record.get("footprint",null)
				if not footprint is Array or footprint.size()!=2: return ERR_INVALID_DATA
				for dimension in footprint:
					if not finite_number(dimension) or float(dimension)!=int(dimension) or int(dimension)<1 or int(dimension)>8: return ERR_INVALID_DATA
				item.merge({"building":record.building,"core":record.core,"object_kind":record.object_kind,"angle":float(record.angle),"variant":int(record.variant),"footprint":footprint.duplicate()})
			restored[collection].append(item)
	reset()
	ruins.assign(restored.ruins); craters.assign(restored.craters)
	return OK

func update(dt: float) -> void:
	clock+=dt
	for mark in craters: mark.age+=dt
	for p in particles: p.age+=dt
	for index in range(particles.size()-1,-1,-1):
		if particles[index].age>=particles[index].duration:
			var expired: Dictionary=particles[index]
			particles.remove_at(index)
			recycle_particle(expired)
	for ruin in ruins: ruin.age+=dt
	for id in flashes.keys():
		flashes[id]-=dt
		if flashes[id]<=0: flashes.erase(id)
	shake=maxf(0,shake-dt*12)
	offset=Vector2(sin(clock*83),cos(clock*107))*shake*(0 if shake_mode==0 else (0.45 if shake_mode==1 else 1.0))

func emit_effect(kind: String, data: Dictionary, distance: float = 0.0) -> void:
	if kind=="hit": flashes[int(data.id)]=0.13
	var p: Dictionary
	if not free_particles.is_empty():
		p=free_particles.pop_back()
		p.clear()
		particle_pool_reused+=1
	else:
		p={}
		particle_pool_created+=1
	p.merge(data)
	p.kind=kind; p.age=0.0; p.duration=0.65
	var weapon: String = data.get("weapon","cannon")
	p.family=family(weapon)
	var profile: Array = FAMILIES[p.family]
	p.variant=visual_rng.randi_range(0,3); p.rotation=visual_rng.randf_range(0,TAU)
	p.muzzle="muzzle_"+p.family.to_lower()+"_0"+str(1+p.variant%2)
	p.energy=p.family in ["ENERGY","SPECIAL"]
	p.radius=float(profile[0]); p.duration=float(profile[2]); p.hot=Color(profile[1])
	p.core=kind=="destroy" and data.get("kind","")=="core"
	if kind=="hit": p.duration=0.28; p.radius=22.0
	if kind=="shot":
		p.origin=p.pos; p.duration=0.28
		p.pos+=Vector2.from_angle(data.angle)*(32 if p.family in ["ARTILLERY","SIEGE"] else 24)
	if kind=="dust": p.duration=0.7; p.radius=24.0
	if kind=="impact" and p.family in ["ARTILLERY","SIEGE","MISSILE"]:
		craters.append({"pos":p.pos,"radius":p.radius*0.33,"age":0.0})
		while craters.size()>MAX_CRATERS: craters.pop_front()
	if kind=="destroy":
		var building: bool = data.get("building",false)
		p.radius=155.0 if p.core else (65.0+float(data.get("visual_size",2.0))*20.0 if building else {"scout":38.0,"tank":64.0,"siege":88.0,"harvester":74.0}.get(data.get("kind","tank"),58.0))
		p.duration=5.5 if p.core else (3.8 if building else 1.9)
		p.energy=false; p.hot=Color("ffc15c")
		ruins.append({"pos":data.pos,"building":building,"core":p.core,"angle":data.angle,"age":0.0,"radius":p.radius*0.4,"variant":p.variant,"object_kind":data.get("kind","tank"),"footprint":data.get("visual_footprint",[2,2])})
		if ruins.size()>MAX_RUINS:
			# Recycle the oldest vehicle first, ordinary buildings next, cores last.
			var victim := 0
			for i in range(ruins.size()-1):
				if not ruins[i].building: victim=i; break
				if ruins[victim].core and not ruins[i].core: victim=i
			ruins.remove_at(victim)
	if distance<900 and kind in ["destroy","impact","shot"]:
		var impulse: float = (10.0 if p.core else (7.0 if data.get("building",false) else 4.0)) if kind=="destroy" else float(profile[3])
		if kind=="shot": impulse*=0.6
		shake=maxf(shake,impulse*clampf(1-distance/900.0,0,1))
	particles.append(p)
	particle_pool_peak=maxi(particle_pool_peak,particles.size())
	while particles.size()>220:
		var expired: Dictionary=particles.pop_front()
		recycle_particle(expired)

func draw_ground(c: WorldRenderer) -> void:
	# Preserve detailed wrecks in ordinary play; trim only tiny debris marks when
	# a dense battlefield would otherwise submit thousands of tiny draw commands.
	var compact_wrecks := ruins.size()>12 or c.vfx_budget_tier>=1
	for mark in craters:
		if not in_view(c,mark.pos) or not explored(c,mark.pos): continue
		var fade := 1.0
		effect_circle(c,mark.pos,mark.radius,Color(0.13,0.065,0.025,0.42*fade))
		effect_circle(c,mark.pos+Vector2(2,2),mark.radius*0.70,Color(0.11,0.055,0.03,0.18))
		c.draw_arc(mark.pos,mark.radius,0.2,PI,16 if c.vfx_budget_tier>=2 else 32,Color(0.85,0.61,0.32,0.22*fade),2,true)
		for i in (3 if c.vfx_budget_tier>=2 else 9):
			var q: Vector2 = mark.pos+Vector2.from_angle(i*2.4)*mark.radius*0.82
			c.draw_line(q,q+Vector2(3,-1),Color(0.58,0.36,0.18,0.38),2,true)
	# All scorch decals precede all remaining structures, including overlapping deaths.
	var wreck_started:=Time.get_ticks_usec() if c.profile_enabled else 0
	var visible_ruin_count := 0
	for visible_ruin in ruins:
		if in_view(c,visible_ruin.pos) and explored(c,visible_ruin.pos): visible_ruin_count+=1
	var very_dense_wrecks := visible_ruin_count>18 or c.vfx_budget_tier>=3
	for ruin in ruins:
		if not in_view(c,ruin.pos) or not explored(c,ruin.pos): continue
		var scorch := PackedVector2Array()
		var scorch_segments := 12 if c.vfx_budget_tier>=2 else (16 if compact_wrecks else 24)
		for i in scorch_segments: scorch.append(ruin.pos+Vector2.from_angle(i*TAU/scorch_segments)*float(ruin.radius)*(0.65+float(i%3)*0.055))
		c.smooth_polygon(scorch,Color(0.12,0.055,0.025,0.14))
	for ruin in ruins:
		if not in_view(c,ruin.pos) or not explored(c,ruin.pos): continue
		var r: float = ruin.get("radius",42.0 if ruin.building else 21.0)
		var fade := 1.0
		var aged_compact := (float(ruin.get("age",0.0))>18.0 and very_dense_wrecks) or (c.vfx_budget_tier>=2 and float(ruin.get("age",0.0))>30.0)
		if aged_compact:
			if ruin.building:
				var extent_simple := Vector2(ruin.footprint[0],ruin.footprint[1])*32.0*0.40
				var simple_base := Rect2(ruin.pos-extent_simple,extent_simple*2)
				c.draw_rect(simple_base,Color(0.20,0.15,0.11,0.58))
				c.draw_line(simple_base.position+Vector2(5,5),simple_base.end-Vector2(6,6),Color(0.42,0.31,0.21,0.65),2,true)
				c.draw_line(Vector2(simple_base.end.x-6,simple_base.position.y+6),Vector2(simple_base.position.x+6,simple_base.end.y-6),Color(0.10,0.07,0.05,0.55),2,true)
			else:
				var direction_simple := Vector2.from_angle(ruin.angle)
				var side_simple := direction_simple.orthogonal()
				var length_simple := 12.0 if ruin.object_kind=="scout" else (21.0 if ruin.object_kind in ["siege","harvester"] else 17.0)
				c.smooth_polygon(PackedVector2Array([ruin.pos-direction_simple*length_simple-side_simple*7,ruin.pos+direction_simple*length_simple-side_simple*6,ruin.pos+direction_simple*(length_simple-3)+side_simple*7,ruin.pos-direction_simple*(length_simple-2)+side_simple*7]),Color(0.19,0.14,0.10,0.72))
				c.draw_line(ruin.pos-direction_simple*length_simple,ruin.pos+direction_simple*length_simple,Color(0.42,0.31,0.21,0.55),2,true)
			continue
		if ruin.building:
			c.smooth_polygon(PackedVector2Array([ruin.pos+Vector2(-r,-r*0.55),ruin.pos+Vector2(r*0.6,-r*0.5),ruin.pos+Vector2(r,r*0.45),ruin.pos+Vector2(-r*0.7,r*0.5)]),Color(0.24,0.18,0.12,0.65*fade))
		if ruin.building:
			var extent := Vector2(ruin.footprint[0],ruin.footprint[1])*32.0*0.42
			var base := Rect2(ruin.pos-extent,extent*2)
			c.draw_rect(base.grow(3),Color(0.11,0.065,0.04,0.20*fade))
			c.smooth_polygon(PackedVector2Array([base.position+Vector2(7,0),base.position+Vector2(base.size.x-8,2),base.end-Vector2(0,9),base.end-Vector2(12,0),base.position+Vector2(5,base.size.y-4)]),Color(0.29,0.23,0.18,0.70*fade))
			c.draw_line(base.position,base.position+Vector2(base.size.x,0),Color(0.55,0.43,0.28,fade),2,true)
			var panel_rows := 2 if compact_wrecks else 3
			var panel_columns := 3 if compact_wrecks else 4
			for row in panel_rows:
				for column in panel_columns:
					var q: Vector2 = base.position+Vector2(column*base.size.x/panel_columns+4,row*base.size.y/panel_rows+6)
					c.draw_line(q,q+Vector2(base.size.x/panel_columns-7,2),Color("34271e"),1,true)
					if (row+column)%3==0:
						c.smooth_polygon(PackedVector2Array([q,q+Vector2(12,-3),q+Vector2(17,7),q+Vector2(4,10)]),Color("59422f"))
						c.draw_line(q,q+Vector2(12,-3),Color("947044"),1,true)
			var wall_count := 3 if compact_wrecks else 5
			for i in wall_count:
				var wall: Vector2 = base.position+Vector2(base.size.x*float(i)/wall_count,base.size.y*0.12)
				c.smooth_polygon(PackedVector2Array([wall,wall+Vector2(12,-10-float(i%3)*4),wall+Vector2(16,1),wall+Vector2(8,5)]),Color(0.20,0.15,0.12,fade))
			if ruin.object_kind=="refinery":
				for i in 3:
					var q: Vector2 = ruin.pos+Vector2((i-1)*extent.x*0.55,-5)
					c.draw_arc(q,extent.x*0.23,0.2,PI*1.8,24,Color(0.50,0.39,0.26,fade),4,true)
				c.draw_polyline(PackedVector2Array([ruin.pos+Vector2(-extent.x,12),ruin.pos+Vector2(-7,16),ruin.pos+Vector2(4,26)]),Color("5d4834"),4,true)
			elif ruin.object_kind=="power":
				for side in [-1,1]:
					var q: Vector2 = ruin.pos+Vector2(side*extent.x*0.4,-2)
					c.draw_arc(q,12,0.4,5.0,20,Color("67513a"),4,true)
					c.draw_line(q,q+Vector2(19,14),Color("403126"),10,true)
					for rib in 4: c.draw_line(q+Vector2(rib*4,2),q+Vector2(rib*4+8,15),Color("8c6c46"),1,true)
			elif ruin.object_kind=="tower":
				effect_circle(c,ruin.pos,14,Color("433326"))
				c.draw_polyline(PackedVector2Array([ruin.pos,ruin.pos+Vector2(16,-8),ruin.pos+Vector2(29,3)]),Color("806044"),5,true)
			elif ruin.object_kind in ["core","radar"]:
				if ruin.core:
					var q: Vector2 = ruin.pos-Vector2(extent.x*0.23,extent.y*0.1)
					c.smooth_polygon(PackedVector2Array([q+Vector2(-12,14),q+Vector2(18,17),q+Vector2(22,-4),q+Vector2(6,-23),q+Vector2(-10,-16)]),Color("292017"))
					c.smooth_polygon(PackedVector2Array([q+Vector2(-10,-16),q+Vector2(6,-23),q+Vector2(22,-4),q+Vector2(2,2)]),Color("6b5037"))
					c.draw_polyline(PackedVector2Array([q+Vector2(-10,-16),q+Vector2(6,-23),q+Vector2(22,-4)]),Color("a47b4c"),1.5,true)
					for rib in 3: c.draw_line(q+Vector2(-8,rib*5+2),q+Vector2(11,rib*5+4),Color("84633e"),2,true)
				c.draw_line(ruin.pos+Vector2(-6,5),ruin.pos+Vector2(18,-26),Color(0.39,0.30,0.21,fade),5,true)
				c.draw_line(ruin.pos+Vector2(18,-26),ruin.pos+Vector2(31,-18),Color(0.62,0.48,0.30,fade),2,true)
			elif ruin.object_kind in ["factory","repair"]:
				for side in [-1,1]: c.draw_line(ruin.pos+Vector2(side*extent.x*0.65,extent.y*0.5),ruin.pos+Vector2(side*extent.x*0.55,-extent.y*0.75),Color(0.46,0.35,0.23,fade),4,true)
				c.smooth_polygon(PackedVector2Array([base.position+Vector2(9,8),ruin.pos+Vector2(14,-8),ruin.pos+Vector2(-8,16)]),Color("55402f"))
				for panel in 5: c.draw_line(ruin.pos+Vector2(panel*7-18,15),ruin.pos+Vector2(panel*7-25,28),Color("806244"),2,true)
		else:
			var direction := Vector2.from_angle(ruin.angle)
			var side := direction.orthogonal()
			var length := 13.0 if ruin.object_kind=="scout" else (24.0 if ruin.object_kind in ["siege","harvester"] else 19.0)
			c.smooth_polygon(PackedVector2Array([ruin.pos-direction*length-side*8,ruin.pos+direction*length-side*7,ruin.pos+direction*(length-4)+side*9,ruin.pos-direction*(length-3)+side*8]),Color(0.23,0.17,0.12,fade))
			for sign_value in [-1,1]: c.draw_line(ruin.pos-direction*length+side*sign_value*10,ruin.pos+direction*(length-3)+side*sign_value*10,Color(0.095,0.065,0.045,fade),4,true)
			for sign_value in [-1,1]:
				for wheel in 4:
					var q: Vector2 = ruin.pos+direction*(-length+4+wheel*length*0.48)+side*sign_value*10
					effect_circle(c,q,2.3,Color("857058"))
					effect_circle(c,q,1.1,Color("2b241e"))
					c.draw_line(q-side*2.8,q+side*2.8,Color("493a2c"),0.7,true)
			var engine: Vector2 = ruin.pos-direction*length*0.5
			for rib in 5:
				var q: Vector2 = engine+direction*rib*2.4-side*4
				c.draw_line(q,q+side*8,Color("8f795f"),0.8,true)
			c.draw_polyline(PackedVector2Array([engine-side*3,engine-direction*8-side*5,engine-direction*11+side*3]),Color("a48a66"),1.2,true)
			c.draw_line(ruin.pos+direction*3-side*5,ruin.pos+direction*9+side*2,Color("1c1915"),3,true)
			c.draw_line(ruin.pos+direction*3-side*5,ruin.pos+direction*7-side*2,Color("b29671"),0.7,true)
			c.draw_line(ruin.pos-direction*8-side*4,ruin.pos+direction*6-side*4,Color(0.53,0.40,0.26,fade),2,true)
			if ruin.object_kind in ["tank","siege"]:
				effect_circle(c,ruin.pos+side*2,7,Color(0.32,0.24,0.16,fade))
				c.draw_line(ruin.pos,ruin.pos+Vector2.from_angle(ruin.angle+0.7)*26,Color(0.40,0.30,0.20,fade),3,true)
			elif ruin.object_kind=="harvester":
				for rib in 5: c.draw_line(ruin.pos-direction*13+direction*rib*6-side*6,ruin.pos-direction*13+direction*rib*6+side*5,Color("6a5137"),2,true)
				c.draw_polyline(PackedVector2Array([ruin.pos+direction*17,ruin.pos+direction*29+side*8,ruin.pos+direction*32+side*2]),Color("876442"),3,true)
		var fragment_count := (4 if ruin.core else 3) if c.vfx_budget_tier>=2 and ruin.building else ((7 if ruin.core else 6) if compact_wrecks and ruin.building else (3 if c.vfx_budget_tier>=2 else (4 if compact_wrecks else (12 if ruin.building else 6))))
		for i in fragment_count:
			var angle: float = i*2.399+ruin.angle
			var direction := Vector2.from_angle(angle)
			var side := direction.orthogonal()
			var q: Vector2 = ruin.pos+direction*r*(0.18+float(i%3)*0.15)
			var length := 3.0+float(i%4)*1.5
			c.smooth_polygon(PackedVector2Array([q-direction*length,q+side*2,q+direction*length-side,q-side*2]),Color("584737"))
			c.draw_line(q-direction*length,q+side*2,Color("ae8960"),0.7,true)
			c.draw_line(q+side*2,q+direction*length-side,Color("30271f"),1,true)
			if i%2==0: c.draw_arc(q,2.2,0.2,4.4,12,Color("897256"),1,true)
	if c.profile_enabled: profile_wrecks_ms=float(Time.get_ticks_usec()-wreck_started)/1000.0

func explored(c: WorldRenderer, pos: Vector2) -> bool:
	var cell := c.sim.grid.cell(pos)
	return c.sim.grid.inside(cell) and c.sim.explored[0][cell.y*c.sim.grid.width+cell.x]>0

func visible(c: WorldRenderer, pos: Vector2) -> bool:
	var cell := c.sim.grid.cell(pos)
	return c.sim.grid.inside(cell) and c.sim.fog[0][cell.y*c.sim.grid.width+cell.x]>0

func in_view(c: WorldRenderer, pos: Vector2) -> bool:
	return Rect2(c.camera-c.logical_size*0.5/c.zoom,c.logical_size/c.zoom).grow(200).has_point(pos)

func effect_circle(c: WorldRenderer, center: Vector2, radius: float, color: Color) -> void:
	# Dynamic effect discs are appended to one color-mesh and submitted in one draw call.
	c.append_impact_disc(center,radius,color)

func effect_puff(c: WorldRenderer, center: Vector2, radius: float, color: Color, variant: float = 0.0) -> void:
	c.append_pixel_puff(center,radius,color,variant)

func smoke_strength(ruin: Dictionary) -> float:
	var age: float = ruin.age
	var hot_end := 10.0 if ruin.building else 5.0
	var warm_end := 30.0 if ruin.building else 20.0
	var cold_end := 90.0 if ruin.building else 60.0
	if age<hot_end: return 0.8
	if age<warm_end: return 0.40
	return 0.18*(1-(age-warm_end)/(cold_end-warm_end)) if age<cold_end else 0.0

func draw_effects(c: WorldRenderer) -> void:
	profile_smoke_ms=0.0
	profile_hit_ms=0.0; profile_shot_ms=0.0; profile_impact_ms=0.0; profile_destroy_ms=0.0; profile_dust_ms=0.0
	# Attenuate overlapping smoke locally so dense battles retain readable hulls.
	var smoke_density: Dictionary = {}
	var hit_spark_batches: Array[PackedVector2Array]=[]
	for _i in 4: hit_spark_batches.append(PackedVector2Array())
	var visible_destructions := 0
	for p in particles:
		if p.kind not in ["destroy","impact"] or not in_view(c,p.pos) or not visible(c,p.pos): continue
		if p.kind=="destroy": visible_destructions+=1
		var bucket := Vector2i(floori(p.pos.x/96),floori(p.pos.y/96))
		smoke_density[bucket]=int(smoke_density.get(bucket,0))+1
	var dense_effects := visible_destructions>7 or c.vfx_budget_tier>=1
	var destruction_index := 0
	for p in particles:
		if not in_view(c,p.pos) or not visible(c,p.pos): continue
		var particle_started := Time.get_ticks_usec() if c.profile_enabled else 0
		var detailed_blast := true
		if p.kind=="destroy":
			destruction_index+=1
			detailed_blast=not dense_effects or p.core or destruction_index%maxi(2,ceili(float(visible_destructions)/8.0))==0
		var t: float = p.age/p.duration
		var fade := 1.0-t
		var hot: Color = p.hot
		var bucket := Vector2i(floori(p.pos.x/96),floori(p.pos.y/96))
		var smoke_opacity := 1.0/sqrt(float(maxi(1,int(smoke_density.get(bucket,1)))))
		if p.kind=="dust":
			for i in 7:
				var q: Vector2 = p.pos+Vector2.from_angle(i*2.4)*p.radius*t
				effect_puff(c,q,2+t*7,Color(0.72,0.44,0.21,fade*0.13))
			if c.profile_enabled: profile_dust_ms+=float(Time.get_ticks_usec()-particle_started)/1000.0
			continue
		if p.kind=="hit":
			if p.age<0.065: effect_puff(c,p.pos,3.5,Color(1,0.93,0.66,fade),p.rotation)
			var line_count:=3+quality if c.vfx_budget_tier==0 else (2 if c.vfx_budget_tier==1 else 1)
			var fade_bucket:=clampi(floori(fade*4),0,3)
			var spark_batch: PackedVector2Array=hit_spark_batches[fade_bucket]
			for i in line_count:
				var direction := Vector2.from_angle(i*2.4+p.rotation)
				var q: Vector2 = p.pos+direction*(3+t*14)
				spark_batch.append(q); spark_batch.append(q-direction*3.5)
				if i%3==0 and c.vfx_budget_tier<2:
					spark_batch.append(q+Vector2(0,t*t*12)); spark_batch.append(q+Vector2(4,t*t*12))
			hit_spark_batches[fade_bucket]=spark_batch
			if c.profile_enabled: profile_hit_ms+=float(Time.get_ticks_usec()-particle_started)/1000.0
			continue
		if p.kind=="shot":
			if p.family in ["BALLISTIC_HEAVY","ARTILLERY","SIEGE"]:
				for i in 6+quality*3:
					var q: Vector2 = p.origin+Vector2.from_angle(i*2.4)*p.radius*t*0.5
					effect_puff(c,q,3+t*7,Color(0.72,0.48,0.26,fade*0.17))
			if p.family=="MISSILE":
				c.smooth_polygon(PackedVector2Array([p.pos,p.pos-Vector2.from_angle(p.angle)*28+Vector2(0,5),p.pos-Vector2.from_angle(p.angle)*40,p.pos-Vector2.from_angle(p.angle)*28-Vector2(0,5)]),Color(1,0.42,0.08,fade))
			if p.family=="AUTOCANNON":
				for j in 3: effect_circle(c,p.pos+Vector2.from_angle(p.angle)*(j*8),2+fade*2,Color(1,0.94,0.68,fade))
			if p.energy:
				c.append_impact_arc(p.pos,5+t*18,0,TAU,24,Color(hot,fade*0.7))
			else:
				effect_puff(c,p.pos-Vector2(0,t*15),3+t*8,Color(0.22,0.17,0.12,fade*0.35))
			var forward := Vector2.from_angle(p.angle)
			c.append_impact_glow(p.pos,p.radius*fade,Color(hot,fade*0.65))
			c.smooth_polygon(PackedVector2Array([p.pos-forward*5,p.pos+forward*(18+p.variant*3)*fade+forward.orthogonal()*(4+p.variant),p.pos+forward*(32+p.variant*4)*fade,p.pos+forward*18*fade-forward.orthogonal()*4]),Color(hot,fade))
			effect_circle(c,p.pos,4*fade,Color(1,0.98,0.85,fade))
			if c.profile_enabled: profile_shot_ms+=float(Time.get_ticks_usec()-particle_started)/1000.0
			continue
		if p.kind=="impact" and p.energy:
			# A compact contact pulse, not long radial spokes over the target silhouette.
			c.append_impact_glow(p.pos,12+t*9,Color(hot,fade*0.38))
			effect_circle(c,p.pos,2.5*fade,Color(0.88,1,0.96,fade))
			c.append_impact_arc(p.pos,5+t*10,p.rotation,p.rotation+PI*1.3,20,Color(hot,fade*0.48))
			for i in 2+quality:
				var q: Vector2 = p.pos+Vector2.from_angle(i*2.4+p.rotation)*(4+t*13)
				effect_circle(c,q,0.7+fade,Color(hot,fade*0.65))
			if c.profile_enabled: profile_impact_ms+=float(Time.get_ticks_usec()-particle_started)/1000.0
			continue
		var r: float = p.radius*(1.0 if p.kind=="destroy" else 0.68)
		var precursor := 0.32 if p.core else (0.18 if p.kind=="destroy" and p.get("building",false) else 0.0)
		var blast_age: float = maxf(0,p.age-precursor)
		if p.age<precursor:
			for i in 3:
				c.append_impact_glow(p.pos+Vector2.from_angle(i*2.4)*r*0.22,18,Color(1,0.60,0.18,0.5))
		if p.core and p.age<0.32:
			c.append_impact_glow(p.pos,80,Color(0.6,0.95,1,p.age*2))
			c.append_impact_arc(p.pos,70*(1-p.age/0.32),0,TAU,48,Color(0.7,0.95,1,0.8))
		var fire_age := minf(1,blast_age/(0.9 if p.kind=="destroy" else (0.65 if p.family=="SIEGE" else 0.32)))
		var fire := 0.0 if p.age<precursor else 1.0-fire_age
		c.append_impact_glow(p.pos,r*(0.6+fire_age*0.4),Color(hot,fire*0.7))
		if p.age>=precursor and blast_age<0.10: effect_circle(c,p.pos,r*0.24,Color(1,0.98,0.87,1-blast_age*10))
		var count := (7+quality*3 if p.kind=="destroy" else 4+quality) if detailed_blast else 4
		for i in count:
			var direction := Vector2.from_angle(i*2.39996+p.rotation)
			var spread := r*fire_age*(0.35+float(i%5)*0.15)
			var q: Vector2 = p.pos+direction*spread
			if fire>0:
				var flame_size := (3+r*0.09+float(i%4)*2)*fire
				effect_puff(c,q,flame_size,Color(hot.lerp(Color("e75117"),fire_age),fire*0.8))
				if not p.energy and p.kind=="destroy":
					for lobe in (3 if detailed_blast else 1):
						var lift := float(lobe)*flame_size*0.5
						var curl := sin(i+clock*7+lobe)*flame_size*0.2
						effect_puff(c,q+Vector2(curl,-lift),flame_size*(0.65-lobe*0.16),Color(1,0.50+fire*0.3,0.12,fire*0.48))
					effect_puff(c,q-Vector2(0,flame_size*0.2),flame_size*0.35,Color(1,0.91,0.52,fire*0.8))
				c.append_impact_line(q,q-direction*(3+fire*8),Color(1,0.77,0.32,fire),1.3)
			if p.kind=="destroy" or not p.energy:
				var smoke: Vector2 = p.pos+direction*r*t*0.6+Vector2(sin(i)*t*12,-t*r*(1.4 if p.core else 0.85))
				if detailed_blast or i%2==0:
					effect_puff(c,smoke,3+r*(0.045+t*0.065),Color(0.14,0.11,0.085,sin(t*PI)*0.17*smoke_opacity),i+p.rotation)
				var dust: Vector2 = p.pos+direction*r*sqrt(t)
				if detailed_blast or i%2==0:
					effect_puff(c,dust,3+r*t*0.07,Color(0.72,0.42,0.20,fade*0.10))
			if (p.kind=="destroy" and (detailed_blast or i%3==0)) or (p.family in ["SIEGE","ARTILLERY","BALLISTIC_HEAVY"] and i%2==0):
				var fragment: Vector2 = p.pos+direction*r*minf(1,p.age)*0.8-Vector2(0,sin(minf(1,p.age)*PI)*r*0.4)
				c.append_impact_line(fragment,fragment+direction*(3+i%4),Color(0.38,0.28,0.18,fade),2)
		if p.kind=="destroy" or p.family in ["SIEGE","ARTILLERY"]:
			c.append_impact_arc(p.pos,r*sqrt(t),p.rotation,p.rotation+PI*1.6,32 if detailed_blast else 20,Color(hot,fade*0.12))
		if p.kind=="destroy" and p.get("building",false):
			for i in ((7 if p.core else 4) if detailed_blast else (3 if p.core else 1)):
				var delay := 0.12+i*0.23
				var flash := maxf(0,1-absf(p.age-delay)/0.16)
				c.append_impact_glow(p.pos+Vector2.from_angle(i*2.4)*r*0.3,30,Color(1,0.48,0.12,flash*0.6))

		if p.energy and fire>0:
			for i in 3+quality:
				var direction := Vector2.from_angle(i*2.4+p.rotation)
				var tip: Vector2 = p.pos+direction*r*(0.45+fire_age)
				var bend: Vector2 = p.pos+direction*r*0.35+direction.orthogonal()*sin(clock*70+i)*10
				c.append_impact_polyline(PackedVector2Array([p.pos,bend,tip]),Color(hot,fire),1.8)
		if c.profile_enabled:
			if p.kind=="destroy": profile_destroy_ms+=float(Time.get_ticks_usec()-particle_started)/1000.0
			else: profile_impact_ms+=float(Time.get_ticks_usec()-particle_started)/1000.0
	var hit_batch_started:=Time.get_ticks_usec() if c.profile_enabled else 0
	for i in 4:
		if not hit_spark_batches[i].is_empty():
			var alpha: float=(float(i)+0.5)/4.0*0.85
			c.draw_multiline(hit_spark_batches[i],Color(1,0.78,0.38,alpha),1.0,true)
	if c.profile_enabled: profile_hit_ms+=float(Time.get_ticks_usec()-hit_batch_started)/1000.0
	var smoke_sources := 0
	var smoke_buckets: Dictionary = {}
	for index in range(ruins.size()-1,-1,-1):
		var ruin: Dictionary = ruins[index]
		if not in_view(c,ruin.pos) or not visible(c,ruin.pos): continue
		var smoking := smoke_strength(ruin)
		if smoking<=0: continue
		if smoke_sources>=(5 if c.vfx_budget_tier>=2 else (7 if dense_effects else 8+quality*8)): break
		var bucket := Vector2i(floori(ruin.pos.x/96),floori(ruin.pos.y/96))
		if int(smoke_buckets.get(bucket,0))>=2: continue
		smoke_buckets[bucket]=int(smoke_buckets.get(bucket,0))+1
		smoke_sources+=1
		var smoke_started := Time.get_ticks_usec() if c.profile_enabled else 0
		var age: float = ruin.age
		var fire_end := 10.0 if ruin.building else 5.0
		if age<fire_end:
			for i in (3 if not dense_effects else 2):
				var q: Vector2 = ruin.pos+Vector2((i-1)*9,-3)
				var h := (8+sin(clock*8+i)*3)*(1-age/fire_end)
				for layer in (4 if not dense_effects else 2):
					var t := float(layer)/4
					var lobe: Vector2 = q+Vector2(sin(clock*7+i+t*3)*2*t,-h*t)
					effect_puff(c,lobe,(3.4-t*2)*(1-age/fire_end),Color(1,0.34+t*0.4,0.06,0.55))
					effect_puff(c,lobe+Vector2(0,1),1.2*(1-t),Color(1,0.91,0.54,0.6))
		if age<(30.0 if ruin.building else 20.0):
			for i in 3: effect_circle(c,ruin.pos+Vector2(i*7-7,2),1.4,Color(0.95,0.34,0.08,0.5))
		for i in (3+quality if not dense_effects else 2):
			var phase := fposmod(clock*0.3+i*0.21,1)
			effect_puff(c,ruin.pos+Vector2(phase*16+sin(i)*10,-phase*(95 if ruin.core else 45)),4+phase*10,Color(0.12,0.09,0.07,(1-phase)*smoking*0.22),i+ruin.variant)
		if c.profile_enabled: profile_smoke_ms+=float(Time.get_ticks_usec()-smoke_started)/1000.0

func draw_projectile(c: WorldRenderer, p: Dictionary, detail_tier: int=0) -> void:
	var style := family(p.weapon)
	var color := Color(FAMILIES[style][1])
	var direction: Vector2 = (p.last-p.pos).normalized()
	var q: Vector2 = p.pos
	if style in ["ARTILLERY","SIEGE"]:
		var traveled: float = maxf(0,5-float(p.life))*float(c.sim.db.weapons[p.weapon].speed)
		var total: float = traveled+p.pos.distance_to(p.last)
		var height := sin(PI*clampf(traveled/maxf(1,total),0,1))*minf(70,total*0.22)
		effect_circle(c,p.pos+Vector2(3,3),5,Color(0.12,0.06,0.025,0.4))
		q-=Vector2(0,height)
		var trail_count:=6 if detail_tier==0 else (4 if detail_tier==1 else 3)
		for i in trail_count:
			effect_circle(c,q-direction*(10+i*7)+Vector2(0,-i*1.2),2+i,Color(0.25,0.18,0.12,0.22-float(i)*0.025))
	elif style=="MISSILE":
		q+=direction.orthogonal()*sin(clock*18+float(p.target))*2
		var trail_count:=8 if detail_tier==0 else (5 if detail_tier==1 else 3)
		for i in trail_count:
			effect_circle(c,q-direction*(6+i*5),2+i*0.7,Color(0.28,0.22,0.16,0.28-i*0.025))
			c.append_impact_glow(q-direction*6,18,Color(1,0.45,0.08,0.55))
	var energy: bool = style in ["ENERGY","SPECIAL"]
	var width := 5.0 if style in ["SIEGE","ARTILLERY"] else (3.0 if energy else 2.0)
	c.append_impact_glow(q,30 if energy else 20,Color(color,0.30))
	c.append_impact_line(q-direction*(34 if energy else 23),q,Color(color,0.35),width*2)
	c.append_impact_line(q-direction*18,q,color,width)
	c.append_impact_line(q-direction*12,q,Color("fff9e7"),1.2)
	effect_circle(c,q,3 if width>=5 else 2,color)

