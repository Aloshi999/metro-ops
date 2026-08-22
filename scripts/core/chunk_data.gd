class_name ChunkData
extends RefCounted
## Aggregate stats for one 16×16 tile chunk. No per-citizen agents.

var cx: int = 0
var cy: int = 0
var active: bool = false
var damaged: bool = false
var damage_timer: int = 0

# Aggregate occupancy counts (tiles with zone that have power+water+road)
var res_tiles: int = 0
var com_tiles: int = 0
var ind_tiles: int = 0
var res_occ: float = 0.0  # 0..1 average
var com_occ: float = 0.0
var ind_occ: float = 0.0

var powered_zone_tiles: int = 0
var watered_zone_tiles: int = 0
var serviced_zone_tiles: int = 0  # both + road adjacency aggregate

func reset_counts() -> void:
	res_tiles = 0
	com_tiles = 0
	ind_tiles = 0
	powered_zone_tiles = 0
	watered_zone_tiles = 0
	serviced_zone_tiles = 0

func tax_yield(tax_per: float, demand_mult: float) -> float:
	if damaged:
		return 0.0
	var occ_sum := res_occ * res_tiles + com_occ * com_tiles + ind_occ * ind_tiles
	return occ_sum * tax_per * demand_mult
