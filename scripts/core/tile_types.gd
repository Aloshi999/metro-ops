class_name TileTypes
extends Object
## Saturated silhouette palette — readable at 800p under FSR2 @ 0.67.
## High chroma + hard value steps so nearest-neighbor upscale still pops.

enum Terrain { DIRT = 0, GRASS = 1, WATER = 2 }
enum Zone { NONE = 0, RESIDENTIAL = 1, COMMERCIAL = 2, INDUSTRIAL = 3 }
enum Service { NONE = 0, POWER_PLANT = 1, WATER_TOWER = 2, HQ = 3 }

static func terrain_color(t: int) -> Color:
	match t:
		Terrain.DIRT:
			# Warm umber — sits under zone overlays without muddying chroma
			return Color(0.38, 0.26, 0.14)
		Terrain.GRASS:
			return Color(0.18, 0.48, 0.16)
		Terrain.WATER:
			# Deep saturated blue; FSR2 keeps the hue better than pale fills
			return Color(0.08, 0.28, 0.62)
		_:
			return Color(0.12, 0.12, 0.14)

static func zone_color(z: int, occupancy: float = 0.0, damaged: bool = false) -> Color:
	var base: Color
	match z:
		Zone.RESIDENTIAL:
			base = Color(0.12, 0.92, 0.38)  # electric green
		Zone.COMMERCIAL:
			base = Color(0.15, 0.55, 1.0)   # vivid blue
		Zone.INDUSTRIAL:
			base = Color(1.0, 0.78, 0.05)   # amber yellow
		_:
			return Color(0, 0, 0, 0)
	if damaged:
		# Charred — still readable as "was a zone"
		base = Color(base.r * 0.35, base.g * 0.28, base.b * 0.28, 0.75)
		return base
	# Occupancy → skyline mass: empty plots translucent, dense blocks opaque + lit
	var mass := clampf(occupancy, 0.0, 1.0)
	base = base.lightened(mass * 0.18)
	base.a = 0.42 + mass * 0.55
	return base

## Fake building silhouette at 8px: dark roof band when dense, bright facade when mid.
static func skyline_modulate(occupancy: float) -> Color:
	var m := clampf(occupancy, 0.0, 1.0)
	if m < 0.25:
		return Color(1, 1, 1, 1)  # empty plot — no shift
	if m < 0.65:
		# Mid rise: slightly brighter facade
		return Color(1.12, 1.1, 1.05, 1)
	# Dense block: darker roof silhouette for skyline read at distance
	return Color(0.72, 0.74, 0.78, 1)

static func road_color() -> Color:
	# Cool asphalt with a hair of blue so roads separate from dirt under FSR
	return Color(0.32, 0.34, 0.40)

static func fog_color() -> Color:
	return Color(0.05, 0.06, 0.08, 0.94)

static func service_color(s: int) -> Color:
	match s:
		Service.POWER_PLANT:
			return Color(1.0, 0.28, 0.08)   # hot orange beacon
		Service.WATER_TOWER:
			return Color(0.05, 0.82, 1.0)   # cyan beacon
		Service.HQ:
			return Color(1.0, 0.98, 0.88)   # warm white landmark
		_:
			return Color.WHITE

static func war_tint() -> Color:
	return Color(0.55, 0.08, 0.05, 0.22)

static func disaster_tint() -> Color:
	return Color(0.85, 0.35, 0.05, 0.18)

static func zone_name(z: int) -> String:
	match z:
		Zone.RESIDENTIAL:
			return "Residential"
		Zone.COMMERCIAL:
			return "Commercial"
		Zone.INDUSTRIAL:
			return "Industrial"
		_:
			return "None"
