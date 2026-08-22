extends Node2D
## Colored-tile map renderer — saturated silhouettes, cheap event FX.
## Nearest-neighbor only. No shadows, volumetrics, or per-tile particles.

@export var tile_px: int = GameConstants.TILE_PX

var map: MapData
var show_power: bool = false
var show_water: bool = false
var cursor_tile: Vector2i = Vector2i(-1, -1)
var cursor_brush: int = 1
var dirty: bool = true

## Cheap screen FX timers (seconds). Set from main on war/disaster — do not touch Sim.
var war_fx: float = 0.0
var disaster_fx: float = 0.0

var _img: Image
var _tex: ImageTexture
var _sprite: Sprite2D
var _fx_time: float = 0.0


func setup(m: MapData) -> void:
	map = m
	map.map_changed.connect(_on_dirty)
	map.fog_changed.connect(_on_dirty)
	map.services_changed.connect(_on_dirty)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_rebuild_image()
	queue_redraw()


func pulse_war(seconds: float = 2.4) -> void:
	war_fx = maxf(war_fx, seconds)


func pulse_disaster(seconds: float = 2.0) -> void:
	disaster_fx = maxf(disaster_fx, seconds)


func _on_dirty() -> void:
	dirty = true


func _process(dt: float) -> void:
	_fx_time += dt
	if war_fx > 0.0:
		war_fx = maxf(0.0, war_fx - dt)
	if disaster_fx > 0.0:
		disaster_fx = maxf(0.0, disaster_fx - dt)
	if dirty and map != null:
		_rebuild_image()
		dirty = false
	queue_redraw()


func _rebuild_image() -> void:
	var w := map.size
	var h := map.size
	if _img == null or _img.get_width() != w:
		_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			_img.set_pixel(x, y, _color_at(x, y))
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
	else:
		_tex.update(_img)
	_sprite.texture = _tex
	_sprite.scale = Vector2(tile_px, tile_px)


func _color_at(x: int, y: int) -> Color:
	var i := map.idx(x, y)
	if map.revealed[i] == 0:
		return TileTypes.fog_color()
	var col := TileTypes.terrain_color(map.terrain[i])
	# Soft checker on grass/dirt so empty land isn't a flat mud slab at 800p
	if map.zone[i] == TileTypes.Zone.NONE and map.road[i] == 0 and map.service[i] == TileTypes.Service.NONE:
		if map.terrain[i] != TileTypes.Terrain.WATER and ((x + y) & 1) == 1:
			col = col.lightened(0.04)
	var z: int = map.zone[i]
	if z != TileTypes.Zone.NONE:
		var occ: float = map.occupancy[i]
		var zc := TileTypes.zone_color(z, occ, map.damaged_tile[i] == 1)
		col = col.lerp(zc, zc.a)
		var sky: Color = TileTypes.skyline_modulate(occ)
		col = Color(col.r * sky.r, col.g * sky.g, col.b * sky.b, 1.0)
		# Checker "roof" on dense blocks → readable skyline mass after FSR
		if occ >= 0.65 and ((x * 3 + y * 5) % 7) == 0:
			col = col.darkened(0.22)
	if map.road[i] == 1:
		col = TileTypes.road_color()
		# Center stripe hint on even tiles — cheap arterial read
		if (x + y) % 4 == 0:
			col = col.lightened(0.12)
	var s: int = map.service[i]
	if s != TileTypes.Service.NONE:
		col = TileTypes.service_color(s)
	if show_power and map.powered[i] == 1 and map.revealed[i] == 1 and s == TileTypes.Service.NONE:
		col = col.lerp(Color(1.0, 0.45, 0.12, 1), 0.22)
	if show_water and map.watered[i] == 1 and map.revealed[i] == 1 and s == TileTypes.Service.NONE:
		col = col.lerp(Color(0.15, 0.75, 1.0, 1), 0.22)
	return col


func _draw() -> void:
	if map == null:
		return
	var map_px := map.size * tile_px
	# Chunk grid (subtle) + damaged chunk flash
	var cs := map.chunk_size * tile_px
	var side := map.chunks_side
	for cy in side:
		for cx in side:
			var chunk: ChunkData = map.chunks[cy * side + cx]
			if not chunk.active and not chunk.damaged:
				continue
			var r := Rect2(cx * cs, cy * cs, cs, cs)
			if chunk.damaged:
				var pulse := 0.35 + 0.25 * sin(_fx_time * 6.0)
				draw_rect(r, Color(1.0, 0.15, 0.05, pulse), true)
				draw_rect(r, Color(1.0, 0.35, 0.1, 0.7), false, 2.0)
			elif chunk.active:
				draw_rect(r, Color(1, 1, 1, 0.06), false, 1.0)
	# War: full-map crimson wash + edge vignette (one draw each — free vs particles)
	if war_fx > 0.0:
		var a := clampf(war_fx / 2.4, 0.0, 1.0)
		var tint := TileTypes.war_tint()
		tint.a *= a
		draw_rect(Rect2(0, 0, map_px, map_px), tint, true)
		var edge := int(48.0 * a)
		draw_rect(Rect2(0, 0, map_px, edge), Color(0.4, 0, 0, 0.35 * a), true)
		draw_rect(Rect2(0, map_px - edge, map_px, edge), Color(0.4, 0, 0, 0.35 * a), true)
	# Disaster: amber pulse over map (no particles)
	if disaster_fx > 0.0:
		var a2 := clampf(disaster_fx / 2.0, 0.0, 1.0)
		var pulse2 := 0.5 + 0.5 * sin(_fx_time * 10.0)
		var dtint := TileTypes.disaster_tint()
		dtint.a *= a2 * pulse2
		draw_rect(Rect2(0, 0, map_px, map_px), dtint, true)
	# Cursor — thick enough to survive FSR2 @ 0.67 on Deck; brush footprint for zone paint
	if cursor_tile.x >= 0:
		var half := cursor_brush / 2
		for oy in range(-half, half + 1):
			for ox in range(-half, half + 1):
				if cursor_brush > 1 and ox * ox + oy * oy > half * half + 1:
					continue
				var cr := Rect2((cursor_tile.x + ox) * tile_px, (cursor_tile.y + oy) * tile_px, tile_px, tile_px)
				var core := ox == 0 and oy == 0
				draw_rect(cr, Color(1, 1, 1, 0.95 if core else 0.55), false, 2.0 if core else 1.0)
				if core:
					draw_rect(cr.grow(1.0), Color(0.05, 0.05, 0.08, 0.7), false, 1.0)


func world_to_tile(world: Vector2) -> Vector2i:
	return Vector2i(int(world.x / tile_px), int(world.y / tile_px))


func map_pixel_size() -> Vector2:
	return Vector2(map.size * tile_px, map.size * tile_px)
