class_name GameConstants
extends Object
## War-room locked constants for Metro Ops.

const MAP_SIZE: int = 256
const CHUNK_SIZE: int = 16
const CHUNKS_PER_SIDE: int = MAP_SIZE / CHUNK_SIZE  # 16
const TILE_PX: int = 8

const TARGET_FPS: int = 40
const VIEWPORT_W: int = 1280
const VIEWPORT_H: int = 800

const FSR_MODE: int = 2  # FSR2
const FSR_SCALE: float = 0.67
const FSR_SHARPNESS: float = 0.2

const POWER_RADIUS: int = 24
const WATER_RADIUS: int = 20
const FOG_REVEAL_RADIUS: int = 10
const ROAD_CONNECT_RADIUS: int = 1

const STARTING_CASH: int = 25000
const ROAD_COST: int = 10
const ZONE_COST: int = 25
const POWER_PLANT_COST: int = 2500
const WATER_TOWER_COST: int = 1500
const POWER_UPKEEP: int = 40
const WATER_UPKEEP: int = 25
const TAX_PER_OCCUPANCY: float = 0.35

const WAR_EMBARGO_TAX_MULT: float = 0.45
const WAR_LEVY_HIT: int = 4000
const WAR_DURATION_TICKS: int = 120

const DISASTER_DEMAND_MULT: float = 0.35
const DISASTER_DURATION_TICKS: int = 80

const SIM_TICK_SEC: float = 0.5
