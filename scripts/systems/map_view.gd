extends Node2D
## Colored-tile map renderer — saturated silhouettes, no shadows/volumetrics.

@export var tile_px: int = GameConstants.TILE_PX

var map: MapData
var show_power: bool = false
var show_water: bool = false
var cursor_tile: Vector2i = Vector2i(-1, -1)
var dirty: bool = true

var _img: Image
var _tex: ImageTexture
var _sprite: Sprite2D


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


func _on_dirty() -> void:
	dirty = true


func _process(_dt: float) -> void:
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
	var z: int = map.zone[i]
	if z != TileTypes.Zone.NONE:
		var zc := TileTypes.zone_color(z, map.occupancy[i], map.damaged_tile[i] == 1)
		col = col.lerp(zc, zc.a)
		col.a = 1.0
	if map.road[i] == 1:
		col = TileTypes.road_color()
	var s: int = map.service[i]
	if s != TileTypes.Service.NONE:
		col = TileTypes.service_color(s)
	if show_power and map.powered[i] == 1 and map.revealed[i] == 1:
		col = col.lerp(Color(1.0, 0.4, 0.15, 1), 0.25)
	if show_water and map.watered[i] == 1 and map.revealed[i] == 1:
		col = col.lerp(Color(0.2, 0.7, 1.0, 1), 0.25)
	return col


func _draw() -> void:
	if map == null:
		return
	# Chunk grid (subtle)
	var cs := map.chunk_size * tile_px
	var side := map.chunks_side
	for cy in side:
		for cx in side:
			var chunk: ChunkData = map.chunks[cy * side + cx]
			if not chunk.active:
				continue
			var r := Rect2(cx * cs, cy * cs, cs, cs)
			var outline := Color(1, 1, 1, 0.08)
			if chunk.damaged:
				outline = Color(1, 0.2, 0.2, 0.55)
			draw_rect(r, outline, false, 1.0)
	# Cursor
	if cursor_tile.x >= 0:
		var cr := Rect2(cursor_tile.x * tile_px, cursor_tile.y * tile_px, tile_px, tile_px)
		draw_rect(cr, Color(1, 1, 1, 0.85), false, 2.0)


func world_to_tile(world: Vector2) -> Vector2i:
	return Vector2i(int(world.x / tile_px), int(world.y / tile_px))


func map_pixel_size() -> Vector2:
	return Vector2(map.size * tile_px, map.size * tile_px)
