class_name AdvisorSystem
extends RefCounted
## Blocks / warns bad first moves (zones before power, etc.).

signal advice_changed(messages: Array)

enum Severity { INFO, WARN, BLOCK }

var messages: Array = []  # Array of {sev, text}


func evaluate(map: MapData, budget: BudgetSystem, tool_name: String) -> Array:
	messages.clear()
	var has_power := map.power_plants.size() > 0
	var has_water := map.water_towers.size() > 0
	var zone_count := _count_zones(map)

	if budget.cash < 500:
		_add(Severity.WARN, "Treasury low. Cut upkeep or grow taxed occupancy.")

	if not has_power:
		_add(Severity.WARN, "No power plant. Zones will not grow occupancy.")
		if tool_name.begins_with("zone_"):
			_add(Severity.BLOCK, "Advisor: place a Power Plant before zoning (or expect empty lots).")

	if not has_water:
		_add(Severity.WARN, "No water tower. Zones need water + power to fill.")
		if tool_name.begins_with("zone_") and has_power:
			_add(Severity.BLOCK, "Advisor: place a Water Tower before heavy zoning.")

	if has_power and has_water and zone_count == 0:
		_add(Severity.INFO, "Services online. Paint roads, then R/C/I beside them.")

	if zone_count > 0 and not has_power:
		_add(Severity.BLOCK, "Zoned tiles lack city power — build a plant near roads.")

	if budget.tax_mult < 1.0:
		_add(Severity.WARN, "War embargo active — tax income reduced.")
	if budget.demand_mult < 1.0:
		_add(Severity.WARN, "Disaster demand crash — growth slowed.")

	if messages.is_empty():
		_add(Severity.INFO, "City stable. Expand roads to reveal fog-of-build.")

	advice_changed.emit(messages)
	return messages


func should_block_paint(tool_name: String, map: MapData) -> bool:
	# Soft-block: still allow paint, but UI flashes; hard-block first-zone without any service path
	if not tool_name.begins_with("zone_"):
		return false
	# Allow tiny starter zones under HQ bubble; block mass zoning with zero plants
	if map.power_plants.is_empty() and _count_zones(map) >= 8:
		return true
	return false


func _count_zones(map: MapData) -> int:
	var n := 0
	# Sample active chunks only
	for c in map.chunks:
		var chunk: ChunkData = c
		if not chunk.active:
			continue
		n += chunk.res_tiles + chunk.com_tiles + chunk.ind_tiles
	# Before first sim tick counts are 0 — scan revealed near HQ cheaply
	if n == 0:
		var r := 20
		for y in range(map.hq.y - r, map.hq.y + r):
			for x in range(map.hq.x - r, map.hq.x + r):
				if map.in_bounds(x, y) and map.zone[map.idx(x, y)] != TileTypes.Zone.NONE:
					n += 1
	return n


func _add(sev: int, text: String) -> void:
	messages.append({"sev": sev, "text": text})
