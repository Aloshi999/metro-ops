class_name SimSystem
extends RefCounted
## Active-chunk aggregate sim only. No per-citizen agents, no traffic pathfinding.

signal tick_done

var tick_count: int = 0
var war_timer: int = 0
var disaster_timer: int = 0


func tick(map: MapData, budget: BudgetSystem) -> void:
	tick_count += 1
	_tick_events(budget)
	_sim_active_chunks(map)
	budget.tick(map)
	tick_done.emit()


func _tick_events(budget: BudgetSystem) -> void:
	if war_timer > 0:
		war_timer -= 1
		if war_timer <= 0:
			budget.tax_mult = 1.0
	if disaster_timer > 0:
		disaster_timer -= 1
		if disaster_timer <= 0:
			budget.demand_mult = 1.0


func _sim_active_chunks(map: MapData) -> void:
	for c in map.chunks:
		var chunk: ChunkData = c
		if chunk.damaged:
			chunk.damage_timer -= 1
			if chunk.damage_timer <= 0:
				map.clear_chunk_damage(chunk)
		if not chunk.active:
			continue
		_sim_chunk(map, chunk)


func _sim_chunk(map: MapData, chunk: ChunkData) -> void:
	chunk.reset_counts()
	var x0 := chunk.cx * map.chunk_size
	var y0 := chunk.cy * map.chunk_size
	var res_sum := 0.0
	var com_sum := 0.0
	var ind_sum := 0.0

	for y in range(y0, y0 + map.chunk_size):
		for x in range(x0, x0 + map.chunk_size):
			var i := map.idx(x, y)
			var z: int = map.zone[i]
			if z == TileTypes.Zone.NONE:
				continue
			var has_power: bool = map.powered[i] == 1
			var has_water: bool = map.watered[i] == 1
			var has_road: bool = map.has_road_neighbor(x, y)
			if has_power:
				chunk.powered_zone_tiles += 1
			if has_water:
				chunk.watered_zone_tiles += 1

			var target := 0.0
			if has_power and has_water and has_road and map.damaged_tile[i] == 0 and not chunk.damaged:
				chunk.serviced_zone_tiles += 1
				target = 1.0
			elif has_power or has_water:
				target = 0.15
			else:
				target = 0.0

			# Aggregate growth toward target (no agents)
			var occ: float = map.occupancy[i]
			var rate: float = 0.08 if target > occ else 0.12
			occ = lerpf(occ, target, rate)
			map.occupancy[i] = occ

			match z:
				TileTypes.Zone.RESIDENTIAL:
					chunk.res_tiles += 1
					res_sum += occ
				TileTypes.Zone.COMMERCIAL:
					chunk.com_tiles += 1
					com_sum += occ
				TileTypes.Zone.INDUSTRIAL:
					chunk.ind_tiles += 1
					ind_sum += occ

	chunk.res_occ = (res_sum / float(chunk.res_tiles)) if chunk.res_tiles > 0 else 0.0
	chunk.com_occ = (com_sum / float(chunk.com_tiles)) if chunk.com_tiles > 0 else 0.0
	chunk.ind_occ = (ind_sum / float(chunk.ind_tiles)) if chunk.ind_tiles > 0 else 0.0


func start_war(budget: BudgetSystem) -> Dictionary:
	war_timer = GameConstants.WAR_DURATION_TICKS
	budget.tax_mult = GameConstants.WAR_EMBARGO_TAX_MULT
	budget.apply_levy(GameConstants.WAR_LEVY_HIT)
	return {
		"title": "Trade Embargo + Military Levy",
		"body": "War event: tax income cut to %d%%. Levy −$%d." % [
			int(GameConstants.WAR_EMBARGO_TAX_MULT * 100.0),
			GameConstants.WAR_LEVY_HIT
		]
	}


func start_disaster(map: MapData, budget: BudgetSystem) -> Dictionary:
	disaster_timer = GameConstants.DISASTER_DURATION_TICKS
	budget.demand_mult = GameConstants.DISASTER_DEMAND_MULT
	var active: Array = []
	for c in map.chunks:
		var chunk: ChunkData = c
		if chunk.active and not chunk.damaged:
			active.append(chunk)
	var target: ChunkData
	if active.is_empty():
		# Fall back to HQ chunk
		target = map.chunk_at(map.hq.x, map.hq.y)
	else:
		target = active[randi() % active.size()]
	map.damage_chunk(target.cx, target.cy)
	return {
		"title": "Disaster Strikes",
		"body": "Chunk (%d,%d) damaged — zones offline. Demand crashed temporarily." % [
			target.cx, target.cy
		]
	}
