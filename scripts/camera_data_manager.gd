extends Node
class_name CameraDataManager

@export_file("*.bin") var mask_bin_path: String = ProjectSettings.globalize_path("user://mask.bin")
@export_file("*.bin") var rgb_bin_path: String = ProjectSettings.globalize_path("user://rgb.bin")
@export_file("*.bin") var gesture_data_bin_path: String = ProjectSettings.globalize_path("user://gesture_data.bin")

@export var width: int = 256
@export var height: int = 256
@export_range(24, 120, 1) var fps: int = 30

@export var mask_texture_rect: TextureRect
@export var rgb_texture_rect: TextureRect

@export var enable_gesture_recognition: bool = false
@export var debug_logging: bool = true

var update_timer: Timer
var masker_binary_path: String = ProjectSettings.globalize_path("user://bin/cdm")
var process_id: int = -1

# Gesture recognition variables
var last_gesture_timestamp: float = 0.0
var current_gesture: String = ""
var gesture_confidence: float = 0.0

signal gesture_detected(gesture_name: String, confidence: float)
signal gesture_changed(old_gesture: String, new_gesture: String, confidence: float)

func _ready():
	log_debug("Initializing CameraDataManager")
	
	# Start the binary process
	_start_masker_binary()
	
	# Set up update timer based on FPS
	update_timer = Timer.new()
	update_timer.wait_time = 1.0 / fps
	update_timer.timeout.connect(_update_textures)
	add_child(update_timer)
	update_timer.start()
	
	log_debug("CameraDataManager initialized with FPS: %d" % fps)

func _exit_tree():
	# Clean up the process when the node is destroyed
	if process_id != -1:
		log_debug("Terminating masker binary process")
		OS.kill(process_id)

func log_debug(message: String):
	"""Centralized logging function that can be disabled with debug_logging bool"""
	if debug_logging:
		print("[CameraDataManager] " + message)

func _start_masker_binary():
	"""Start the masker binary with appropriate arguments in non-blocking fashion"""
	log_debug("Starting masker binary: %s" % masker_binary_path)
	
	if not FileAccess.file_exists(masker_binary_path):
		log_debug("ERROR: Masker binary not found at: %s" % masker_binary_path)
		return
	
	var arguments = [
		"--out_path", mask_bin_path,
		"--rgb_out_path", rgb_bin_path,
		"--export_both",
		"--width", str(width),
		"--height", str(height),
		"--fps", str(fps)
	]
	
	# Add gesture recognition if enabled
	if enable_gesture_recognition:
		arguments.append("--recognize_gestures")
		arguments.append(gesture_data_bin_path)
		log_debug("Gesture recognition enabled, exporting to: %s" % gesture_data_bin_path)
	
	log_debug("Starting with arguments: %s" % str(arguments))
	
	# Start the process in non-blocking mode
	process_id = OS.create_process(masker_binary_path, arguments)
	
	if process_id == -1:
		log_debug("ERROR: Failed to start masker binary")
	else:
		log_debug("SUCCESS: Masker binary started with PID: %d" % process_id)

func _update_textures():
	"""Update both mask and RGB textures"""
	_update_texture_rect(mask_bin_path, mask_texture_rect, "MASK")
	_update_texture_rect(rgb_bin_path, rgb_texture_rect, "RGB")
	
	# Update gesture recognition if enabled
	if enable_gesture_recognition:
		_update_gesture_data()

func _update_texture_rect(bin_path: String, texture_rect: TextureRect, type_name: String):
	"""Generic function to update a texture rect from a binary file"""
	if texture_rect == null:
		log_debug("SKIP: %s TextureRect is null" % type_name)
		return
	
	log_debug("Checking for %s binary file: %s" % [type_name, bin_path])
	
	if not FileAccess.file_exists(bin_path):
		log_debug("SKIP: %s file not found" % type_name)
		return

	var file = FileAccess.open(bin_path, FileAccess.READ)
	if file == null:
		log_debug("ERROR: Failed to open %s binary file" % type_name)
		return

	var expected_size = width * height * 3
	var actual_size = file.get_length()
	
	log_debug("%s file size: %d, Expected: %d" % [type_name, actual_size, expected_size])

	if actual_size < expected_size:
		log_debug("SKIP: %s file too small, incomplete frame" % type_name)
		file.close()
		return

	var raw_data = file.get_buffer(expected_size)
	file.close()
	
	if raw_data.size() != expected_size:
		log_debug("ERROR: %s buffer size mismatch" % type_name)
		return

	var image = Image.create_from_data(width, height, false, Image.FORMAT_RGB8, raw_data)
	if image == null or image.is_empty():
		log_debug("ERROR: Failed to create %s image from raw data" % type_name)
		return

	var texture = ImageTexture.create_from_image(image)
	if texture == null:
		log_debug("ERROR: Failed to create %s texture from image" % type_name)
		return

	texture_rect.texture = texture
	log_debug("SUCCESS: %s texture applied to TextureRect" % type_name)

func _update_gesture_data():
	"""Read and parse gesture data from binary file"""
	if not FileAccess.file_exists(gesture_data_bin_path):
		log_debug("SKIP: Gesture data file not found")
		return

	var file = FileAccess.open(gesture_data_bin_path, FileAccess.READ)
	if file == null:
		log_debug("ERROR: Failed to open gesture data file")
		return

	var file_size = file.get_length()
	
	# Check if we have at least the minimum required data
	# 8 bytes (timestamp) + 4 bytes (name length) + 4 bytes (confidence) = 16 bytes minimum
	if file_size < 16:
		log_debug("SKIP: Gesture data file too small")
		file.close()
		return

	# Read the gesture data structure
	# Format: timestamp (8 bytes double) + gesture_name_length (4 bytes int) + gesture_name (variable) + confidence (4 bytes float)
	
	var timestamp = file.get_double()
	var gesture_name_length = file.get_32()
	
	# Validate gesture name length
	if gesture_name_length < 0 or gesture_name_length > 1000:  # Reasonable limit
		log_debug("ERROR: Invalid gesture name length: %d" % gesture_name_length)
		file.close()
		return
	
	# Check if we have enough data for the complete structure
	var expected_total_size = 8 + 4 + gesture_name_length + 4
	if file_size < expected_total_size:
		log_debug("SKIP: Gesture data file incomplete, expected: %d, got: %d" % [expected_total_size, file_size])
		file.close()
		return
	
	var gesture_name_bytes = file.get_buffer(gesture_name_length)
	var gesture_name = gesture_name_bytes.get_string_from_utf8()
	var confidence = file.get_float()
	
	file.close()
	
	# Only process if this is a new gesture data (newer timestamp)
	if timestamp > last_gesture_timestamp:
		last_gesture_timestamp = timestamp
		
		var old_gesture = current_gesture
		current_gesture = gesture_name
		gesture_confidence = confidence
		
		log_debug("Gesture detected: %s (confidence: %.2f)" % [gesture_name, confidence])
		
		# Emit signals
		gesture_detected.emit(gesture_name, confidence)
		
		# Emit gesture changed signal if the gesture actually changed
		if old_gesture != current_gesture:
			gesture_changed.emit(old_gesture, current_gesture, confidence)
			log_debug("Gesture changed from '%s' to '%s'" % [old_gesture, current_gesture])

func set_debug_logging(enabled: bool):
	"""Public function to enable/disable debug logging at runtime"""
	debug_logging = enabled
	log_debug("Debug logging %s" % ("enabled" if enabled else "disabled"))

func set_gesture_recognition(enabled: bool):
	"""Enable or disable gesture recognition"""
	if enable_gesture_recognition != enabled:
		enable_gesture_recognition = enabled
		log_debug("Gesture recognition %s" % ("enabled" if enabled else "disabled"))
		restart_masker_binary()

func restart_masker_binary():
	"""Restart the masker binary (useful for changing parameters)"""
	if process_id != -1:
		log_debug("Stopping existing masker binary process")
		OS.kill(process_id)
		process_id = -1
	
	_start_masker_binary()

func update_fps(new_fps: int):
	"""Update the FPS and restart the binary with new parameters"""
	fps = new_fps
	update_timer.wait_time = 1.0 / fps
	log_debug("FPS updated to: %d" % fps)
	restart_masker_binary()

func is_binary_running() -> bool:
	"""Check if the masker binary is still running"""
	if process_id == -1:
		return false
	
	# In Godot 4, we can check if a process is still running
	# This is a simple check - you might want to implement more robust monitoring
	return true

func get_current_gesture() -> String:
	"""Get the current gesture name"""
	return current_gesture

func get_gesture_confidence() -> float:
	"""Get the confidence of the current gesture"""
	return gesture_confidence

func get_last_gesture_timestamp() -> float:
	"""Get the timestamp of the last gesture detection"""
	return last_gesture_timestamp
