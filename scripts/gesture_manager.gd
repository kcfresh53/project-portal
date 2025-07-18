extends Node
class_name GestureManager

@export var camera_data_manager: CameraDataManager

@export var video_player: VideoStreamPlayer
@export var gesture_streams: Dictionary[String, VideoStreamTheora]


func _ready() -> void:
	if camera_data_manager:
		camera_data_manager.gesture_changed.connect(_on_gesture_changed)


func _on_gesture_changed(_old_gesture: String, new_gesture: String, _confidence: float) -> void:
	if new_gesture == "Thumb_Down":
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	
	if gesture_streams.has(new_gesture):
		if !video_player: return
		if video_player.is_playing(): return
		
		video_player.stream = gesture_streams[new_gesture]
		video_player.play()
