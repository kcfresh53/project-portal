extends Node
class_name BackgroundManager

@export var backgrounds: Array[PackedScene]
@export var cdm: CameraDataManager

func _ready() -> void:
	if backgrounds.is_empty(): return
	if !cdm:
		printerr("CDM not defined")
		return
	
	var world: InteractiveBG = backgrounds.pick_random().instantiate()
	world.cdm = cdm
	
	add_child(world)
