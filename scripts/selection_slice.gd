extends VideoStreamPlayer
class_name SelectionSlice


@export var interactive_gui: InteractiveGUI

@export var hover_stream: VideoStreamTheora
@export var selected_stream: VideoStreamTheora

var _hovered: bool

func _ready() -> void:
	if stream:
		paused = true
		stream_position = 0
	
	if interactive_gui:
		interactive_gui.sector_selected.connect(_on_sector_selected)
		interactive_gui.sector_hovered.connect(_on_sector_hovered)
	
	finished.connect(_on_finished)


func _set_stream(video_stream: VideoStreamTheora):
	stream = video_stream
	paused = false
	play()


func _on_sector_selected(sector: int) -> void:
	if get_index() != sector: return
	if !selected_stream: return
	
	_set_stream(selected_stream)


func _on_sector_hovered(sector: int) -> void:
	_hovered = false
	if get_index() != sector: return
	
	_hovered = true
	if !hover_stream: return
	
	_set_stream(hover_stream)

func _on_finished() -> void:
	pass
