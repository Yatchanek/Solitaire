extends Control

signal color_changed
signal options_closed

func _ready():
	
	for button in $Panel/MarginContainer/VBoxContainer/HBoxContainer.get_children():
		if button is Button:
			button.connect("pressed", Callable(self, "_on_Button_pressed").bind(button.name))
			button.connect("mouse_entered", Callable(self, "_on_Button_hovered").bind(button))
			button.connect("mouse_exited", Callable(self, "_on_Button_unhovered").bind(button))
	$Panel/OK.connect("pressed", Callable(self, "_on_Button_pressed").bind($Panel/OK.name))
	$Panel/OK.connect("mouse_entered", Callable(self, "_on_Button_hovered").bind($Panel/OK))
	$Panel/OK.connect("mouse_exited", Callable(self, "_on_Button_unhovered").bind($Panel/OK))

func setup():
	$Panel/MarginContainer/VBoxContainer/HBoxContainer/Card.texture = load("res://assets/cards" + str(Globals.card_design) + "/13_0.png")
	$Panel/MarginContainer/VBoxContainer/HBoxContainer2/Border/Color.color = Globals.bkg_color
	$Panel/MarginContainer/VBoxContainer/HBoxContainer3/FullScreen.button_pressed = ((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (get_window().mode == Window.MODE_FULLSCREEN))
	
func save_settings():
	var f = FileAccess.open("user://settings.dat", FileAccess.WRITE)
	
	var settings_data = {
		"card_design" : Globals.card_design,
		"bkg_color" : Globals.bkg_color
	}
	f.store_var(settings_data)
	f.close()
		
func _on_Button_pressed(button_name):
	match button_name:
		"Prev":
			Globals.card_design = posmod(Globals.card_design - 1, 2)
			$Panel/MarginContainer/VBoxContainer/HBoxContainer/Card.texture = load("res://assets/cards" + str(Globals.card_design) + "/13_0.png")
		"Next":
			Globals.card_design = posmod(Globals.card_design + 1, 2)
			$Panel/MarginContainer/VBoxContainer/HBoxContainer/Card.texture = load("res://assets/cards" + str(Globals.card_design) + "/13_0.png")
		"OK":
			save_settings()
			$Panel/ColorPicker.hide()
			self.hide()
			emit_signal("options_closed")

func _on_Button_hovered(button):
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(button, "scale", Vector2(1.25, 1.25), 0.1)
	
func _on_Button_unhovered(button):
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(button, "scale", Vector2.ONE, 0.1)

func _on_Color_gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			$Panel/ColorPicker.visible = !$Panel/ColorPicker.visible


func _on_ColorPicker_color_changed(color):
	Globals.bkg_color = color
	$Panel/MarginContainer/VBoxContainer/HBoxContainer2/Border/Color.color = Globals.bkg_color
	emit_signal("color_changed", color)


func _on_Options_visibility_changed():
	if visible:
		setup()


func _on_FullScreen_toggled(button_pressed):
	get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (button_pressed) else Window.MODE_WINDOWED
	
