extends Node
## Gamepad-first Deck controls + keyboard fallback.

signal paint_pressed
signal paint_released
signal cycle_next
signal cycle_prev
signal toggle_pause
signal toggle_fps
signal war_pressed
signal disaster_pressed

@export var pan_speed: float = 420.0
@export var stick_deadzone: float = 0.25

var pan_vector: Vector2 = Vector2.ZERO
var painting: bool = false


func _process(_dt: float) -> void:
	pan_vector = Vector2.ZERO
	if Input.is_action_pressed("pan_up"):
		pan_vector.y -= 1
	if Input.is_action_pressed("pan_down"):
		pan_vector.y += 1
	if Input.is_action_pressed("pan_left"):
		pan_vector.x -= 1
	if Input.is_action_pressed("pan_right"):
		pan_vector.x += 1

	# Left stick
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	if stick.length() > stick_deadzone:
		pan_vector += stick

	if pan_vector.length() > 1.0:
		pan_vector = pan_vector.normalized()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("paint"):
		painting = true
		paint_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("paint"):
		painting = false
		paint_released.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_tool_next"):
		cycle_next.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_tool_prev"):
		cycle_prev.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_advisor"):
		toggle_pause.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fps"):
		toggle_fps.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("trigger_war"):
		war_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("trigger_disaster"):
		disaster_pressed.emit()
		get_viewport().set_input_as_handled()
