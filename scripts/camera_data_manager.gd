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
@export var run_double_instance: bool = false

var update_timer: Timer
var masker_binary_path: String = ProjectSettings.globalize_path("user://bin/cdm")
var process_id: int = -1
var second_process_id: int = -1
var second_godot_instance_id: int = -1

# Instance tracking
var is_second_instance: bool = false
var camera_index: int = 0

# Gesture recognition variables
var last_gesture_timestamp: float = 0.0
var current_gesture: String = ""
var gesture_confidence: float = 0.0

signal gesture_detected(gesture_name: String, confidence: float)
signal gesture_changed(old_gesture: String, new_gesture: String, confidence: float)

func _ready():
	get_tree().set_auto_accept_quit(false)
	
	# Check if this is a second instance launched with command line arguments
	_check_command_line_args()
	
	log_debug("Initializing CameraDataManager (Camera %d)" % camera_index)
	
	# Start the binary process(es)
	_start_masker_binary()
	
	# Set up update timer based on FPS
	update_timer = Timer.new()
	update_timer.wait_time = 1.0 / fps
	update_timer.timeout.connect(_update_textures)
	add_child(update_timer)
	update_timer.start()
	
	log_debug("CameraDataManager initialized with FPS: %d (Camera %d)" % [fps, camera_index])

func _check_command_line_args():
	"""Check if this instance was launched with camera-specific arguments"""
	var args = OS.get_cmdline_user_args()  # Use user args instead of all cmdline args
	
	# Look for --second_instance flag in user arguments
	if "--second_instance" in args:
		is_second_instance = true
		camera_index = 1
		
		# Update file paths for second instance
		mask_bin_path = ProjectSettings.globalize_path("user://mask_cam1.bin")
		rgb_bin_path = ProjectSettings.globalize_path("user://rgb_cam1.bin")
		gesture_data_bin_path = ProjectSettings.globalize_path("user://gesture_data_cam1.bin")
		
		log_debug("This is a second instance, using camera 1")
		
		# Set window title to distinguish instances
		get_window().title = "CameraDataManager - Camera 1"
		
		# IMPORTANT: Second instance should NOT try to launch another instance
		run_double_instance = false
	else:
		# This is the primary instance
		camera_index = 0
		get_window().title = "CameraDataManager - Camera 0"

func _exit_tree():
	# Clean up the process when the node is destroyed
	kill_binary()

func kill_binary():
	if process_id != -1:
		log_debug("Terminating masker binary process")
		OS.kill(process_id)
		process_id = -1
	
	if second_process_id != -1:
		log_debug("Terminating second masker binary process")
		OS.kill(second_process_id)
		second_process_id = -1
	
	if second_godot_instance_id != -1:
		log_debug("Terminating second Godot instance")
		OS.kill(second_godot_instance_id)
		second_godot_instance_id = -1

func log_debug(message: String):
	"""Centralized logging function that can be disabled with debug_logging bool"""
	if debug_logging:
		print("[CameraDataManager-Cam%d] %s" % [camera_index, message])

func _start_masker_binary():
	"""Start the masker binary with appropriate arguments in non-blocking fashion"""
	log_debug("Starting masker binary: %s" % masker_binary_path)
	
	if not FileAccess.file_exists(masker_binary_path):
		log_debug("ERROR: Masker binary not found at: %s" % masker_binary_path)
		return
	
	if is_second_instance:
		# Second instance only starts its own CDM process
		_start_single_instance(camera_index, mask_bin_path, rgb_bin_path, gesture_data_bin_path)
	else:
		# Primary instance starts first CDM process
		_start_single_instance(camera_index, mask_bin_path, rgb_bin_path, gesture_data_bin_path)
		
		# Launch second Godot instance if enabled
		if run_double_instance:
			_launch_second_godot_instance()

func _launch_second_godot_instance():
	"""Launch a second Godot application window for the second camera"""
	# Prevent recursive launching
	if is_second_instance:
		log_debug("SKIP: Second instance should not launch another instance")
		return
	
	var godot_executable = OS.get_executable_path()
	var project_path = ProjectSettings.globalize_path("res://")
	
	# Get the main scene path to ensure both instances run the same scene
	var main_scene = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene.is_empty():
		log_debug("ERROR: No main scene defined in project settings")
		return
	
	# Arguments for the second Godot instance
	var arguments = [
		"--path", project_path,
		"--main-pack", "",  # Use project files, not packed
		main_scene,
		"--", # Separator for user arguments
		"--second_instance"
	]
	
	log_debug("Launching second Godot instance: %s" % godot_executable)
	log_debug("Arguments: %s" % str(arguments))
	
	# Launch the second Godot instance
	second_godot_instance_id = OS.create_process(godot_executable, arguments)
	
	if second_godot_instance_id == -1:
		log_debug("ERROR: Failed to launch second Godot instance")
	else:
		log_debug("SUCCESS: Second Godot instance launched with PID: %d" % second_godot_instance_id)

func _start_single_instance(cam_index: int, mask_path: String, rgb_path: String, gesture_path: String):
	"""Start a single instance of the masker binary for a specific camera"""
	var arguments = [
		"--cam", str(cam_index),
		"--out_path", mask_path,
		"--rgb_out_path", rgb_path,
		"--export_both",
		"--width", str(width),
		"--height", str(height),
		"--fps", str(fps)
	]
	
	# Add gesture recognition if enabled
	if enable_gesture_recognition:
		arguments.append("--recognize_gestures")
		arguments.append(gesture_path)
		log_debug("Gesture recognition enabled for camera %d, exporting to: %s" % [cam_index, gesture_path])
	
	log_debug("Starting camera %d with arguments: %s" % [cam_index, str(arguments)])
	
	# Start the process in non-blocking mode
	var pid = OS.create_process(masker_binary_path, arguments)
	
	if pid == -1:
		log_debug("ERROR: Failed to start masker binary for camera %d" % cam_index)
	else:
		log_debug("SUCCESS: Masker binary started for camera %d with PID: %d" % [cam_index, pid])
		
		if is_second_instance:
			second_process_id = pid
		else:
			process_id = pid

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

func set_double_instance(enabled: bool):
	"""Enable or disable double instance mode"""
	# Prevent second instance from trying to launch another instance
	if is_second_instance:
		log_debug("SKIP: Second instance cannot enable double instance mode")
		return
	
	if run_double_instance != enabled:
		run_double_instance = enabled
		log_debug("Double instance mode %s" % ("enabled" if enabled else "disabled"))
		
		if enabled:
			_launch_second_godot_instance()
		elif second_godot_instance_id != -1:
			OS.kill(second_godot_instance_id)
			second_godot_instance_id = -1

func restart_masker_binary():
	"""Restart the masker binary (useful for changing parameters)"""
	if process_id != -1:
		log_debug("Stopping existing masker binary process")
		OS.kill(process_id)
		process_id = -1
	
	if second_process_id != -1:
		log_debug("Stopping existing second masker binary process")
		OS.kill(second_process_id)
		second_process_id = -1
	
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

func is_second_godot_instance_running() -> bool:
	"""Check if the second Godot instance is still running"""
	if not run_double_instance or second_godot_instance_id == -1:
		return false
	
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

func get_camera_index() -> int:
	"""Get the camera index this instance is using"""
	return camera_index

func is_primary_instance() -> bool:
	"""Check if this is the primary instance"""
	return not is_second_instance

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		kill_binary()
		get_tree().quit()
