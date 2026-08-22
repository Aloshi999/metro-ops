extends Node2D
## Metro Ops vertical slice — War-room Deck city-builder.

@onready var camera: Camera2D = $Camera2D
@onready var map_view: Node2D = $MapView
@onready var deck: Node = $DeckController
@onready var hud: CanvasLayer = $HUD

var map: MapData
var budget: BudgetSystem
var sim: SimSystem
var advisor: AdvisorSystem
var tools: ToolSystem
var radial: Control

var paused: bool = false
var sim_accum: float = 0.0
var cursor: Vector2i = Vector2i(128, 128)

const ZOOM_MIN: float = 0.55
const ZOOM_MAX: float = 2.4


func _ready() -> void:
	Engine.max_fps = GameConstants.TARGET_FPS
	# Lock FSR2 / scale from project settings (also re-assert at runtime)
	get_viewport().scaling_3d_mode = GameConstants.FSR_MODE
	get_viewport().scaling_3d_scale = GameConstants.FSR_SCALE
	get_viewport().fsr_sharpness = GameConstants.FSR_SHARPNESS

	map = MapData.new()
	budget = BudgetSystem.new()
	sim = SimSystem.new()
	advisor = AdvisorSystem.new()
	tools = ToolSystem.new()

	map_view.setup(map)
	camera.position = Vector2(
		map.hq.x * GameConstants.TILE_PX,
		map.hq.y * GameConstants.TILE_PX
	)
	cursor = map.hq

	radial = preload("res://scripts/ui/radial_menu.gd").new()
	hud.add_child(radial)

	deck.paint_pressed.connect(_on_paint)
	deck.cycle_next.connect(func(): tools.cycle(1); _refresh_advisor())
	deck.cycle_prev.connect(func(): tools.cycle(-1); _refresh_advisor())
	deck.toggle_pause.connect(_toggle_pause)
	deck.toggle_fps.connect(hud.toggle_fps_overlay)
	deck.war_pressed.connect(_trigger_war)
	deck.disaster_pressed.connect(_trigger_disaster)
	deck.radial_toggled.connect(_on_radial_toggled)
	deck.radial_select.connect(_on_radial_select)
	deck.brush_cycled.connect(_on_brush_cycled)

	hud.war_clicked.connect(_trigger_war)
	hud.disaster_clicked.connect(_trigger_disaster)
	hud.advisor_dismissed.connect(func(): paused = false; hud.set_paused(false))

	tools.tool_changed.connect(func(_id, label): hud.set_tool(label, tools.brush))
	budget.cash_changed.connect(hud.set_cash)
	sim.demand_changed.connect(_on_demand_changed)

	hud.set_tool(tools.label(), tools.brush)
	hud.set_cash(budget.cash, 0, 0)
	hud.set_rci(sim.demand_label())
	_refresh_advisor()
	# Open on advisor so Deck players see controls + first warnings
	paused = true
	hud.set_paused(true)


func _process(dt: float) -> void:
	# Pan — zoom-scaled so Deck stick feel stays consistent
	var speed: float = deck.pan_speed_at_zoom(camera.zoom.x)
	var pan: Vector2 = deck.pan_vector * speed * dt
	if pan != Vector2.ZERO and not deck.radial_open:
		camera.position += pan
		_clamp_camera()

	# Zoom from right stick / keys
	if absf(deck.zoom_delta) > 0.01 and not deck.radial_open:
		var z: float = camera.zoom.x * (1.0 + deck.zoom_delta * dt)
		z = clampf(z, ZOOM_MIN, ZOOM_MAX)
		camera.zoom = Vector2(z, z)
		_clamp_camera()

	# Cursor: camera center + gamepad offset (no mouse steal)
	var center := camera.position
	var offset_px: Vector2 = deck.cursor_offset * float(GameConstants.TILE_PX)
	cursor = map_view.world_to_tile(center + offset_px)
	cursor.x = clampi(cursor.x, 0, map.size - 1)
	cursor.y = clampi(cursor.y, 0, map.size - 1)
	map_view.cursor_tile = cursor
	map_view.cursor_brush = tools.brush

	# Mouse only after real pointer activity — never when stick is driving
	if deck.using_mouse() and not deck.radial_open:
		var mouse := get_global_mouse_position()
		var mt: Vector2i = map_view.world_to_tile(mouse)
		if map.in_bounds(mt.x, mt.y):
			map_view.cursor_tile = mt
			cursor = mt

	if deck.radial_open:
		radial.set_aim(deck.radial_aim)

	if deck.painting and not paused and not deck.radial_open:
		_try_paint_at(cursor)

	if not paused:
		sim_accum += dt
		while sim_accum >= GameConstants.SIM_TICK_SEC:
			sim_accum -= GameConstants.SIM_TICK_SEC
			sim.tick(map, budget)
			map_view.dirty = true
			_refresh_advisor()


func _clamp_camera() -> void:
	var half := Vector2(GameConstants.VIEWPORT_W, GameConstants.VIEWPORT_H) * 0.5 / camera.zoom
	var map_px: Vector2 = map_view.map_pixel_size()
	camera.position.x = clampf(camera.position.x, half.x, map_px.x - half.x)
	camera.position.y = clampf(camera.position.y, half.y, map_px.y - half.y)


func _on_paint() -> void:
	if paused or deck.radial_open:
		return
	_try_paint_at(cursor)


func _try_paint_at(tile: Vector2i) -> void:
	if advisor.should_block_paint(tools.id_name(), map):
		hud.show_event("Advisor Block", "Build power before mass zoning.")
		_refresh_advisor()
		return
	var half: int = tools.brush / 2
	var any := false
	for oy in range(-half, half + 1):
		for ox in range(-half, half + 1):
			# Circular-ish brush for 3/5; 1×1 exact
			if tools.brush > 1 and ox * ox + oy * oy > half * half + 1:
				continue
			var t := Vector2i(tile.x + ox, tile.y + oy)
			if _paint_one(t):
				any = true
	if any:
		_refresh_advisor()


func _paint_one(tile: Vector2i) -> bool:
	if not map.in_bounds(tile.x, tile.y):
		return false
	var cost := tools.cost()
	if not budget.can_afford(cost):
		hud.show_event("Broke", "Not enough cash ($%d needed)." % cost)
		return false
	var ok := false
	match tools.current:
		ToolSystem.Tool.ROAD:
			ok = map.paint_road(tile.x, tile.y)
		ToolSystem.Tool.ZONE_R:
			ok = map.paint_zone(tile.x, tile.y, TileTypes.Zone.RESIDENTIAL)
		ToolSystem.Tool.ZONE_C:
			ok = map.paint_zone(tile.x, tile.y, TileTypes.Zone.COMMERCIAL)
		ToolSystem.Tool.ZONE_I:
			ok = map.paint_zone(tile.x, tile.y, TileTypes.Zone.INDUSTRIAL)
		ToolSystem.Tool.POWER:
			ok = map.place_service(tile.x, tile.y, TileTypes.Service.POWER_PLANT)
			if ok:
				map_view.show_power = true
		ToolSystem.Tool.WATER:
			ok = map.place_service(tile.x, tile.y, TileTypes.Service.WATER_TOWER)
			if ok:
				map_view.show_water = true
	if ok:
		budget.spend(cost)
	return ok


func _on_radial_toggled(open: bool) -> void:
	radial.set_open(open)
	if open:
		radial.set_aim(deck.radial_aim)


func _on_radial_select(index: int) -> void:
	if index < 0 or index >= ToolSystem.ORDER.size():
		return
	tools.set_tool(ToolSystem.ORDER[index])
	_refresh_advisor()


func _on_brush_cycled(size: int) -> void:
	tools.brush = size
	hud.set_tool(tools.label(), tools.brush)


func _toggle_pause() -> void:
	paused = not paused
	hud.set_paused(paused)
	_refresh_advisor()


func _on_demand_changed(_r: float, _c: float, _i: float) -> void:
	hud.set_rci(sim.demand_label())


func _refresh_advisor() -> void:
	var msgs: Array = advisor.evaluate(map, budget, tools.id_name(), sim)
	hud.set_advisor(msgs)


func _trigger_war() -> void:
	if paused:
		paused = false
		hud.set_paused(false)
	var info: Dictionary = sim.start_war(budget)
	hud.show_event(info["title"], info["body"])
	map_view.pulse_war()
	_refresh_advisor()


func _trigger_disaster() -> void:
	if paused:
		paused = false
		hud.set_paused(false)
	var info: Dictionary = sim.start_disaster(map, budget)
	hud.show_event(info["title"], info["body"])
	map_view.dirty = true
	map_view.pulse_disaster()
	_refresh_advisor()
