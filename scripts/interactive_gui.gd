extends Control
class_name InteractiveGUI

@export_range(0, 5) var selected: int = 0:
	set = set_selection

@export var dial: TextureRect
@export var led: TextureRect

@export_range(-90, 90) var dial_rot_range: float = 80

@export_range(-90, 90) var led_rot_range: float = 90

signal sector_selected(selected: int)
signal sector_hovered(sector: int)

var tween: Tween
var total_options: int = 6
var current_hovered_sector: int = -1

func _ready() -> void:
	# Initialize the dial position based on the selected value
	if dial:
		var initial_rotation = _get_dial_pos(selected, total_options)
		dial.rotation_degrees = initial_rotation
		_randomize_dial_selection()
	
	# Initialize LED position if it exists
	if led:
		_update_led_position(selected)

func _randomize_dial_selection() -> void:
	selected = randi_range(0, 5)  # 0-5 for 6 options
	var final_rotation = _get_dial_pos(selected, total_options)
	_animate_dial(final_rotation)

func _get_dial_pos(selected_option: int, option_size: int) -> float:
	# return a position between the rotation range of the dial
	# based on the selected option (dividing the rotational sectors into option sizes)
	if option_size <= 1:
		return 0.0
	
	# Calculate the angle per sector
	var angle_per_sector = (dial_rot_range * 2.0) / option_size
	
	# Calculate position: start from -dial_rot_range and add the sector offset
	var pos: float = -dial_rot_range + (selected_option * angle_per_sector) + (angle_per_sector * 0.5)
	
	return pos

func _animate_dial(final_rot: float) -> void:
	# Starts a tween that bounces back and forth within rotation bounds before landing on the final option
	# The rotations are elastic and erractic with their easing functions.
	# Sector_selected signal is emit when the dial stops at its final rotation
	
	if not dial:
		return
	
	# Kill existing tween if running
	if tween:
		tween.kill()
	
	tween = create_tween()
	
	var current_rotation = dial.rotation_degrees
	
	# Define rotation bounds
	var min_bound = -dial_rot_range
	var max_bound = dial_rot_range
	
	# Create bouncing animation with multiple back-and-forth movements
	var bounce_duration = 1.5
	var num_bounces = 5
	
	var last_position = current_rotation
	
	# Create erratic bouncing between bounds
	for i in range(num_bounces):
		var target_position: float
		
		# Alternate between bounds with some randomness
		if i % 2 == 0:
			target_position = max_bound + randf_range(-20.0, 0.0)
		else:
			target_position = min_bound + randf_range(0.0, 20.0)
		
		# Ensure we stay within bounds
		target_position = clamp(target_position, min_bound, max_bound)
		
		# Animate to target position with decreasing intensity
		var current_duration = bounce_duration * (1.0 - float(i) / num_bounces * 0.5)
		tween.tween_method(_set_dial_rotation, last_position, target_position, current_duration)
		
		if i < 2:
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_BACK)
		else:
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.set_trans(Tween.TRANS_ELASTIC)
		
		last_position = target_position
	
	# Final settle to exact position with bounce
	tween.tween_method(_set_dial_rotation, last_position, final_rot, 0.8)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	
	# Emit signal when animation completes
	tween.tween_callback(_on_dial_animation_complete)

func _set_dial_rotation(rot: float) -> void:
	if dial:
		dial.rotation_degrees = rot
		_check_sector_hover(rot)

func _check_sector_hover(rot: float) -> void:
	# Calculate which sector the dial is currently pointing to
	var sector = _get_sector_from_rotation(rot)
	
	# Only emit signal if sector has changed
	if sector != current_hovered_sector and sector >= 0 and sector < total_options:
		current_hovered_sector = sector
		sector_hovered.emit(sector)
		_update_led_position(sector)

func _get_sector_from_rotation(rot: float) -> int:
	# Convert rotation back to sector index
	# This is the inverse of _get_dial_pos()
	var angle_per_sector = (dial_rot_range * 2.0) / total_options
	var normalized_rotation = rot + dial_rot_range
	var sector = int(normalized_rotation / angle_per_sector)
	
	# Clamp to valid range
	return clamp(sector, 0, total_options - 1)

func _update_led_position(sector: int = -1) -> void:
	if led:
		# Use provided sector or current hovered sector
		var target_sector = sector if sector >= 0 else current_hovered_sector
		
		# Snap LED to the sector position using the same calculation as dial
		if target_sector >= 0 and target_sector < total_options:
			var sector_rotation = _get_dial_pos(target_sector, total_options)
			# Map dial rotation to LED rotation range
			var normalized_pos = (sector_rotation + dial_rot_range) / (dial_rot_range * 2.0)
			led.rotation_degrees = (normalized_pos * led_rot_range * 2.0) - led_rot_range

func _on_dial_animation_complete() -> void:
	# Snap LED to final selected position
	_update_led_position(selected)
	sector_selected.emit(selected)
	
	GuiTransitions.hide("dial_logo")
	await get_tree().create_timer(2.5).timeout
	GuiTransitions.hide("dial")

# Public function to manually set selection and animate
func set_selection(new_selection: int) -> void:
	selected = clamp(new_selection, 0, 5)
	var final_rotation = _get_dial_pos(selected, total_options)
	_animate_dial(final_rotation)

# Public function to get current selection without animation
func get_current_selection() -> int:
	return selected
