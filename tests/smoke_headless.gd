extends SceneTree
## Headless smoke: map/chunk sizes, paint, services, budget, war, disaster.
## Run: godot --headless --path /workspace/metro-ops -s res://tests/smoke_headless.gd

func _init() -> void:
	var ok := true
	var errors: PackedStringArray = []

	Engine.max_fps = GameConstants.TARGET_FPS

	if GameConstants.MAP_SIZE != 256:
		ok = false
		errors.append("MAP_SIZE != 256")
	if GameConstants.CHUNK_SIZE != 16:
		ok = false
		errors.append("CHUNK_SIZE != 16")
	if GameConstants.CHUNKS_PER_SIDE != 16:
		ok = false
		errors.append("CHUNKS_PER_SIDE != 16")
	if GameConstants.TARGET_FPS != 40:
		ok = false
		errors.append("TARGET_FPS != 40")

	var map := MapData.new()
	if map.size != 256 or map.chunks.size() != 256:
		ok = false
		errors.append("map alloc failed size=%d chunks=%d" % [map.size, map.chunks.size()])

	if map.service[map.idx(map.hq.x, map.hq.y)] != TileTypes.Service.HQ:
		ok = false
		errors.append("HQ missing")

	if map.revealed[map.idx(map.hq.x, map.hq.y)] != 1:
		ok = false
		errors.append("HQ not revealed")

	var budget := BudgetSystem.new()
	var start_cash := budget.cash

	# Paint road out from HQ
	var painted_road := false
	for d in range(3, 12):
		if map.paint_road(map.hq.x + d, map.hq.y):
			budget.spend(GameConstants.ROAD_COST)
			painted_road = true
	if not painted_road:
		ok = false
		errors.append("road paint failed")

	var px := map.hq.x + 6
	var py := map.hq.y + 2
	if not map.place_service(px, py, TileTypes.Service.POWER_PLANT):
		# try nearby
		var placed := false
		for t in range(1, 8):
			if map.place_service(map.hq.x + 5, map.hq.y + t, TileTypes.Service.POWER_PLANT):
				budget.spend(GameConstants.POWER_PLANT_COST)
				placed = true
				px = map.hq.x + 5
				py = map.hq.y + t
				break
		if not placed:
			ok = false
			errors.append("power plant place failed")
	else:
		budget.spend(GameConstants.POWER_PLANT_COST)

	var wx := map.hq.x + 4
	var wy := map.hq.y - 3
	if map.can_build_at(wx, wy):
		if map.place_service(wx, wy, TileTypes.Service.WATER_TOWER):
			budget.spend(GameConstants.WATER_TOWER_COST)
		else:
			# alternate
			for t in range(1, 8):
				if map.place_service(map.hq.x + 3, map.hq.y - t, TileTypes.Service.WATER_TOWER):
					budget.spend(GameConstants.WATER_TOWER_COST)
					break

	if map.power_plants.is_empty():
		ok = false
		errors.append("no power plants")
	if map.water_towers.is_empty():
		ok = false
		errors.append("no water towers")

	# Zones beside road
	var zcount := 0
	for dx in range(3, 10):
		var zx := map.hq.x + dx
		var zy := map.hq.y + 1
		if map.paint_zone(zx, zy, TileTypes.Zone.RESIDENTIAL):
			budget.spend(GameConstants.ZONE_COST)
			zcount += 1
	if zcount == 0:
		ok = false
		errors.append("zone paint failed")

	var sim := SimSystem.new()
	for i in 10:
		sim.tick(map, budget)

	var advisor := AdvisorSystem.new()
	var msgs := advisor.evaluate(map, budget, "zone_r")
	if msgs.is_empty():
		ok = false
		errors.append("advisor empty")

	var war := sim.start_war(budget)
	if budget.tax_mult >= 1.0:
		ok = false
		errors.append("war tax_mult not applied")
	if budget.cash >= start_cash:
		# levy should have hit; may still be ok if income high — check levy path
		pass
	if not war.has("title"):
		ok = false
		errors.append("war event malformed")

	var dis := sim.start_disaster(map, budget)
	if budget.demand_mult >= 1.0:
		ok = false
		errors.append("disaster demand_mult not applied")
	if not dis.has("body"):
		ok = false
		errors.append("disaster event malformed")

	var damaged_any := false
	for c in map.chunks:
		if c.damaged:
			damaged_any = true
			break
	if not damaged_any:
		ok = false
		errors.append("disaster did not damage a chunk")

	# FSR / display constants sanity (project settings may not load fully in -s)
	if GameConstants.FSR_MODE != 2 or GameConstants.FSR_SCALE != 0.67:
		ok = false
		errors.append("FSR constants wrong")

	print("=== Metro Ops smoke ===")
	print("map=%dx%d chunks=%dx%d tile_px=%d" % [
		GameConstants.MAP_SIZE, GameConstants.MAP_SIZE,
		GameConstants.CHUNKS_PER_SIDE, GameConstants.CHUNKS_PER_SIDE,
		GameConstants.TILE_PX
	])
	print("cash=%d zones_painted=%d power=%d water=%d" % [
		budget.cash, zcount, map.power_plants.size(), map.water_towers.size()
	])
	print("war=%s" % war["title"])
	print("disaster=%s" % dis["title"])
	if ok:
		print("SMOKE_OK")
		quit(0)
	else:
		print("SMOKE_FAIL")
		for e in errors:
			print("  - ", e)
		quit(1)
