extends Node
class_name GUIPopup

var _last_gesture: String

func confirm_exit(gesture: String):
	_last_gesture = gesture
	if gesture == "Thumb_Down":
		GuiTransitions.show("pop")
		await get_tree().create_timer(3.0).timeout
		if _last_gesture == gesture:
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		else:
			GuiTransitions.hide("pop")
