extends Control
class_name InteractiveBG


@export var cdm: CameraDataManager

@export var mask: TextureRect
@export var rgb: TextureRect


func _ready() -> void:
	if !cdm: return
	
	cdm.mask_texture_rect = mask
	cdm.rgb_texture_rect = rgb
