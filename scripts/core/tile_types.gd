class_name TileTypes
extends Object

enum Terrain { DIRT = 0, GRASS = 1, WATER = 2 }
enum Zone { NONE = 0, RESIDENTIAL = 1, COMMERCIAL = 2, INDUSTRIAL = 3 }
enum Service { NONE = 0, POWER_PLANT = 1, WATER_TOWER = 2, HQ = 3 }

static func terrain_color(t: int) -> Color:
	match t:
		Terrain.DIRT:
			return Color(0.45, 0.32, 0.18)
		Terrain.GRASS:
			return Color(0.28, 0.55, 0.22)
		Terrain.WATER:
			return Color(0.15, 0.35, 0.65)
		_:
			return Color(0.2, 0.2, 0.2)

static func zone_color(z: int, occupancy: float = 0.0, damaged: bool = false) -> Color:
	var base: Color
	match z:
		Zone.RESIDENTIAL:
			base = Color(0.25, 0.85, 0.35)  # green
		Zone.COMMERCIAL:
			base = Color(0.25, 0.55, 0.95)  # blue
		Zone.INDUSTRIAL:
			base = Color(0.95, 0.75, 0.15)  # yellow
		_:
			return Color(0, 0, 0, 0)
	if damaged:
		base = base.darkened(0.55)
		base.a = 0.7
	else:
		# Brighten with occupancy for readable silhouettes
		base = base.lightened(occupancy * 0.25)
		base.a = 0.55 + occupancy * 0.4
	return base

static func road_color() -> Color:
	return Color(0.42, 0.45, 0.5)

static func fog_color() -> Color:
	return Color(0.08, 0.09, 0.11, 0.92)

static func service_color(s: int) -> Color:
	match s:
		Service.POWER_PLANT:
			return Color(0.95, 0.35, 0.2)
		Service.WATER_TOWER:
			return Color(0.2, 0.75, 0.95)
		Service.HQ:
			return Color(0.95, 0.95, 0.95)
		_:
			return Color.WHITE

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
