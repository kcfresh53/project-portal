extends CPUParticles2D

@export var camera_data_manager: CameraDataManager
@export var gesture_textures: Dictionary[String, Texture]

# Debug
@export var texture_rect: TextureRect
@export var _log: bool

func _ready() -> void:
	if camera_data_manager:
		camera_data_manager.gesture_changed.connect(_on_gesture_changed)


func _on_gesture_changed(_old_gesture: String, new_gesture: String, _confidence: float) -> void:
	#prints("Gesture recognition result:", gesture_name, confidence)

	# Display corresponding texture (if available)
	if gesture_textures.has(new_gesture):
		texture = gesture_textures[new_gesture]
		if texture_rect: texture_rect.texture = texture
		emitting = true
	else:
		if not _log: return
		printerr("No texture assigned for gesture: ", new_gesture)
