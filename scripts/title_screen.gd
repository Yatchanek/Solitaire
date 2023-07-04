extends Control


signal new_game
signal quit_game
signal continue_game
signal options

# Called when the node enters the scene tree for the first time.
func _ready():
	for button in $Buttons.get_children():
		button.connect("pressed", Callable(self, "_on_Button_pressed").bind(button.name))
		button.connect("mouse_entered", Callable(self, "_on_Button_hovered").bind(button))
		button.connect("mouse_exited", Callable(self, "_on_Button_unhovered").bind(button))
		

func reset():
	for button in $Buttons.get_children():
		button.disabled = false	
		if button.name == "Continue":
			var f = FileAccess.open("user://save.sav", FileAccess.READ) 
			if !f.file_exists("user://save.sav"):
				button.disabled = true

func _on_Button_hovered(button):
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(button, "scale", Vector2(1.25, 1.25), 0.1)
	
func _on_Button_unhovered(button):
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(button, "scale", Vector2.ONE, 0.1)
	

func _on_Button_pressed(_name : String):
	for button in $Buttons.get_children():
		button.disabled = true
	match _name:
		"NewGame":
			emit_signal("new_game")
		"Quit":
			emit_signal("quit_game")
		"Continue":
			emit_signal("continue_game")
		"Options":
			emit_signal("options")

func enable_buttons():
	for button in $Buttons.get_children():
		button.disabled = false
