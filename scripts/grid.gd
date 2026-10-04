extends RefCounted
class_name WorldGrid

var width: int
var height: int
var tile: int = 32
var terrain: PackedInt32Array = []
var resources: Dictionary = {}
var occupancy: Dictionary = {}
var astar := AStarGrid2D.new()
const COLORS = [Color("bc783b"),Color("79624b"),Color("d39750"),Color("b1ede3"),Color("927450"),Color("66472f"),Color("514133")]
const TERRAIN = {"sand":0,"rock":1,"dunes":2,"resource":3,"hard_ground":4,"crater":5,"cliff":6}

func _init(map: Dictionary) -> void:
	width = int(map.width)
	height = int(map.height)
	terrain.resize(width * height)
	terrain.fill(0)
	for region in map.terrain_regions:
		var r = region.rect
		for y in range(r[1], r[1]+r[3]):
			for x in range(r[0],r[0]+r[2]): terrain[y*width+x] = TERRAIN[region.type]
	for patch in map.resources:
		var c := Vector2i(int(patch.cell[0]),int(patch.cell[1]))
		for y in range(-int(patch.radius),int(patch.radius)+1):
			for x in range(-int(patch.radius),int(patch.radius)+1):
				var p := c+Vector2i(x,y)
				if Vector2(x,y).length() <= float(patch.radius) and inside(p):
					terrain[p.y*width+p.x] = 3
					resources[key(p)] = float(patch.amount)
	astar.region = Rect2i(0,0,width,height)
	astar.cell_size = Vector2(tile,tile)
	astar.offset = Vector2(tile/2.0,tile/2.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in height:
		for x in width:
			var c := Vector2i(x,y)
			astar.set_point_solid(c, type_at(c)==6)
			astar.set_point_weight_scale(c,1.8 if type_at(c)==2 else 1.0)

func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height

func key(c: Vector2i) -> String:
	return "%d,%d" % [c.x,c.y]

func parse_key(s: String) -> Vector2i:
	var parts = s.split(",")
	return Vector2i(int(parts[0]),int(parts[1]))

func cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/tile),floori(p.y/tile))

func center(c: Vector2i) -> Vector2:
	return Vector2(c*tile)+Vector2.ONE*tile*0.5

func type_at(c: Vector2i) -> int:
	return terrain[c.y*width+c.x] if inside(c) else 6

func is_free(c: Vector2i) -> bool:
	return inside(c) and not astar.is_point_solid(c)

func nearest_free(c: Vector2i) -> Vector2i:
	if is_free(c): return c
	for radius in range(1,12):
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				if abs(x)!=radius and abs(y)!=radius: continue
				var p := c+Vector2i(x,y)
				if is_free(p): return p
	return Vector2i(-1,-1)

func reserve(c: Vector2i, size: Array, id: int, solid: bool) -> void:
	for y in int(size[1]):
		for x in int(size[0]):
			var p := c+Vector2i(x,y)
			if not inside(p): continue
			if solid: occupancy[key(p)] = id
			else: occupancy.erase(key(p))
			astar.set_point_solid(p,solid or type_at(p)==6)

func path(from: Vector2, to: Vector2) -> Array:
	var a := nearest_free(cell(from))
	var b := nearest_free(cell(to))
	if a.x < 0 or b.x < 0: return []
	var result: Array = []
	for p in astar.get_point_path(a,b): result.append(p)
	if not result.is_empty(): result.pop_front()
	return result
