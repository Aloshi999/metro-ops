class_name MapData
extends RefCounted
## Flat 256×256 tile map + 16×16 chunk grid. Fog-of-build + aggregate fields.

signal map_changed
signal fog_changed
signal services_changed

var size: int = GameConstants.MAP_SIZE
var chunk_size: int = GameConstants.CHUNK_SIZE
var chunks_side: int = GameConstants.CHUNKS_PER_SIDE

var terrain: PackedByteArray
var zone: PackedByteArray
var road: PackedByteArray          # 0/1
var service: PackedByteArray       # TileTypes.Service
var revealed: PackedByteArray      # fog-of-build
var powered: PackedByteArray       # 0/1 coverage
var watered: PackedByteArray
var occupancy: PackedFloat32Array  # 0..1 per tile (aggregate growth target)
var damaged_tile: PackedByteArray

var chunks: Array = []  # Array[ChunkData]
var hq: Vector2i = Vector2i(128, 128)

var power_plants: Array[Vector2i] = []
var water_towers: Array[Vector2i] = []


func _init() -> void:
	_alloc()
	_gen_terrain()
	_init_chunks()
	_place_hq()


func _alloc() -> void:
	var n := size * size
	terrain = PackedByteArray()
	terrain.resize(n)
	zone = PackedByteArray()
	zone.resize(n)
	road = PackedByteArray()
	road.resize(n)
	service = PackedByteArray()
	service.resize(n)
	revealed = PackedByteArray()
	revealed.resize(n)
	powered = PackedByteArray()
	powered.resize(n)
	watered = PackedByteArray()
	watered.resize(n)
	damaged_tile = PackedByteArray()
	damaged_tile.resize(n)
	occupancy = PackedFloat32Array()
	occupancy.resize(n)
	for i in n:
		occupancy[i] = 0.0


func idx(x: int, y: int) -> int:
	return y * size + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size


func _gen_terrain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for y in size:
		for x in size:
			var i := idx(x, y)
			var n := rng.randf()
			# Soft noise via cheap hash
			var h := fposmod(sin(x * 0.07 + y * 0.11) * 0.5 + cos(x * 0.03 - y * 0.05) * 0.5, 1.0)
			if h < 0.08:
				terrain[i] = TileTypes.Terrain.WATER
			elif n > 0.55:
				terrain[i] = TileTypes.Terrain.GRASS
			else:
				terrain[i] = TileTypes.Terrain.DIRT


func _init_chunks() -> void:
	chunks.clear()
	for cy in chunks_side:
		for cx in chunks_side:
			var c := ChunkData.new()
			c.cx = cx
			c.cy = cy
			chunks.append(c)


func chunk_at(x: int, y: int) -> ChunkData:
	var cx := x / chunk_size
	var cy := y / chunk_size
	return chunks[cy * chunks_side + cx]


func _place_hq() -> void:
	hq = Vector2i(size / 2, size / 2)
	var i := idx(hq.x, hq.y)
	terrain[i] = TileTypes.Terrain.DIRT
	service[i] = TileTypes.Service.HQ
	road[i] = 1
	# Seed a small cross of roads
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		var p := hq + d
		if in_bounds(p.x, p.y):
			var j := idx(p.x, p.y)
			if terrain[j] != TileTypes.Terrain.WATER:
				road[j] = 1
	_reveal_around(hq.x, hq.y, GameConstants.FOG_REVEAL_RADIUS + 4)
	_mark_chunk_active(hq.x, hq.y)
	recompute_services()


func _reveal_around(cx: int, cy: int, radius: int) -> void:
	var r2 := radius * radius
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if not in_bounds(x, y):
				continue
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2:
				revealed[idx(x, y)] = 1
	fog_changed.emit()


func _mark_chunk_active(x: int, y: int) -> void:
	chunk_at(x, y).active = true


func can_build_at(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var i := idx(x, y)
	return revealed[i] == 1 and terrain[i] != TileTypes.Terrain.WATER


func paint_road(x: int, y: int) -> bool:
	if not can_build_at(x, y):
		return false
	var i := idx(x, y)
	if road[i] == 1 or service[i] != TileTypes.Service.NONE:
		return false
	road[i] = 1
	zone[i] = TileTypes.Zone.NONE
	occupancy[i] = 0.0
	_reveal_around(x, y, GameConstants.FOG_REVEAL_RADIUS)
	_mark_chunk_active(x, y)
	# Cheap connectivity: reveal neighbors for fog-of-build
	recompute_services()
	map_changed.emit()
	return true


func paint_zone(x: int, y: int, z: int) -> bool:
	if not can_build_at(x, y):
		return false
	var i := idx(x, y)
	if road[i] == 1 or service[i] != TileTypes.Service.NONE:
		return false
	if zone[i] == z:
		return false
	zone[i] = z
	occupancy[i] = 0.0
	damaged_tile[i] = 0
	_mark_chunk_active(x, y)
	map_changed.emit()
	return true


func place_service(x: int, y: int, s: int) -> bool:
	if not can_build_at(x, y):
		return false
	var i := idx(x, y)
	if service[i] != TileTypes.Service.NONE:
		return false
	service[i] = s
	road[i] = 0
	zone[i] = TileTypes.Zone.NONE
	occupancy[i] = 0.0
	match s:
		TileTypes.Service.POWER_PLANT:
			power_plants.append(Vector2i(x, y))
		TileTypes.Service.WATER_TOWER:
			water_towers.append(Vector2i(x, y))
	_reveal_around(x, y, GameConstants.FOG_REVEAL_RADIUS)
	_mark_chunk_active(x, y)
	recompute_services()
	map_changed.emit()
	services_changed.emit()
	return true


func recompute_services() -> void:
	var n := size * size
	for i in n:
		powered[i] = 0
		watered[i] = 0
	_stamp_radius(power_plants, GameConstants.POWER_RADIUS, powered)
	_stamp_radius(water_towers, GameConstants.WATER_RADIUS, watered)
	# HQ provides a tiny starter power+water bubble so first builds aren't softlocked
	_stamp_one(hq, 8, powered)
	_stamp_one(hq, 8, watered)
	services_changed.emit()


func _stamp_radius(points: Array[Vector2i], radius: int, field: PackedByteArray) -> void:
	var r2 := radius * radius
	for p in points:
		_stamp_one(p, radius, field, r2)


func _stamp_one(p: Vector2i, radius: int, field: PackedByteArray, r2: int = -1) -> void:
	if r2 < 0:
		r2 = radius * radius
	for y in range(p.y - radius, p.y + radius + 1):
		for x in range(p.x - radius, p.x + radius + 1):
			if not in_bounds(x, y):
				continue
			var dx := x - p.x
			var dy := y - p.y
			if dx * dx + dy * dy <= r2:
				field[idx(x, y)] = 1


func has_road_neighbor(x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx := x + d.x
		var ny := y + d.y
		if in_bounds(nx, ny) and road[idx(nx, ny)] == 1:
			return true
	return false


func damage_chunk(cx: int, cy: int) -> void:
	if cx < 0 or cy < 0 or cx >= chunks_side or cy >= chunks_side:
		return
	var c: ChunkData = chunks[cy * chunks_side + cx]
	c.damaged = true
	c.damage_timer = GameConstants.DISASTER_DURATION_TICKS
	var x0 := cx * chunk_size
	var y0 := cy * chunk_size
	for y in range(y0, y0 + chunk_size):
		for x in range(x0, x0 + chunk_size):
			var i := idx(x, y)
			if zone[i] != TileTypes.Zone.NONE:
				damaged_tile[i] = 1
				occupancy[i] *= 0.15
	map_changed.emit()


func clear_chunk_damage(c: ChunkData) -> void:
	c.damaged = false
	c.damage_timer = 0
	var x0 := c.cx * chunk_size
	var y0 := c.cy * chunk_size
	for y in range(y0, y0 + chunk_size):
		for x in range(x0, x0 + chunk_size):
			damaged_tile[idx(x, y)] = 0
	map_changed.emit()
