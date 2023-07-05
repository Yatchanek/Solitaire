extends Control


var back_to_menu_var : bool = false
var quit_game : bool = false
var continue_game : bool = false

func _ready():
	if !load_settings():
		$Background.color = Globals.bkg_color
	var stylebox = $Confirmation/Panel.get_theme_stylebox("panel").duplicate()
	stylebox.bg_color = Globals.bkg_color
	stylebox.bg_color.v = max(stylebox.bg_color.v - 0.2, 0.05)
	$Confirmation/Panel.add_theme_stylebox_override("panel", stylebox)
	for button in $GameWin/Buttons.get_children():
		button.connect("pressed", Callable(self, "_on_WinGame_button_pressed").bind(button.name))
		button.connect("mouse_entered", Callable(self, "_on_Button_hovered").bind(button))
		button.connect("mouse_exited", Callable(self, "_on_Button_unhovered").bind(button))

	for button in $Confirmation/Panel/MarginContainer/VBoxContainer/HBoxContainer.get_children():
		button.connect("pressed", Callable(self, "_on_Confirmation_button_pressed").bind(button.name))
	for button in $Buttons.get_children():
		button.connect("pressed", Callable(self, "_on_Board_button_pressed").bind(button.name))

	
func start_transition():
	var tw = create_tween()
	tw.tween_property($Veil, "modulate:a", 1.0, 1.0)
	tw.tween_interval(0.5)
	tw.tween_property($Veil, "modulate:a", 0.0, 1.0)
	tw.connect("step_finished", Callable(self, "_on_Start_Tween_step_finished"))

func _on_Start_Tween_step_finished(idx : int):
	match idx:
		0:
			$GameWin.hide()
			$GameWin.modulate.a = 0
			if back_to_menu_var:
				$TitleScreen.reset()
				$TitleScreen.show()
			else:
				$TitleScreen.hide()
		1:
			if !back_to_menu_var and !quit_game:
				pass
			elif quit_game:
				$Options.save_settings()
				get_tree().quit()
			else:
				$Buttons.hide()
				$Board.reset()
		2: 
			if back_to_menu_var:
				back_to_menu_var = false
				continue_game = false
			else:
				$Board.start(continue_game)
				$Buttons.show()

func load_settings():
	var f = FileAccess.open("user://settings.dat", FileAccess.READ)
	if f.file_exists("user://settings.dat"):
		if f.get_error() == OK:
			var settings_data = f.get_var()
			if settings_data != null && settings_data.has("card_design"):
				Globals.card_design = settings_data["card_design"]
			if settings_data != null && settings_data.has("bkg_color"):
				Globals.bkg_color = settings_data["bkg_color"]
				$Background.color = settings_data["bkg_color"]
			return false
		return false			

func back_to_menu():
	back_to_menu_var = true
	$Confirmation/Panel/MarginContainer/VBoxContainer/Label.text = "Are you sure you want to leave to the menu?"
	$Confirmation.show()

func _on_TitleScreen_quit_game():
	quit_game = true
	start_transition()

func _on_TitleScreen_continue_game():
	continue_game = true
	start_transition()
	
func _on_TitleScreen_options():
	$Options.show()

func _on_Game_won_message_shown():
	for button in $GameWin/Buttons.get_children():
		button.disabled = false

func _on_WinGame_button_pressed(button_name):
	$GameWin.hide()
	$GameWin.modulate.a = 0
	for button in $GameWin/Buttons.get_children():
		button.disabled = true
	match button_name:
		"NewGame":
			$Board.reset()
			start_transition()
		"Quit":
			$Board.reset()
			back_to_menu_var = true
			start_transition()
			
func _on_Confirmation_button_pressed(button_name):
	match button_name:
		"OK":
			if back_to_menu_var == true:
				$Board.save_layout()
				start_transition()
			else:
				$Board.restart()
			$Confirmation.hide()
		"Cancel":
			$Confirmation.hide()

func _on_Board_button_pressed(button_name):
	$Board.remove_frames()
	match button_name:
		"NewGame":
			back_to_menu_var = false
			$Confirmation/Panel/MarginContainer/VBoxContainer/Label.text = "Czy na pewno chcesz zacząć nową grę?"
			$Confirmation.show()
		"Quit":
			back_to_menu()

func _on_Board_game_won():
	$GameWin.show()
	var tw = create_tween()
	tw.connect("finished", Callable(self, "_on_Game_won_message_shown"))
	tw.tween_property($GameWin, "modulate:a", 1.0, 1.0)


func _on_TitleScreen_new_game():
	continue_game = false
	start_transition()


func _on_Button_hovered(button):
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(button, "scale", Vector2(1.25, 1.25), 0.1)
	
func _on_Button_unhovered(button):
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(button, "scale", Vector2.ONE, 0.1)


func _on_Options_color_changed(_color):
	$Background.color = _color
	var stylebox = $Confirmation/Panel.get_stylebox("panel").duplicate()
	stylebox.bg_color = _color
	stylebox.bg_color.v = max(stylebox.bg_color.v - 0.2, 0.05)
	$Confirmation/Panel.add_theme_stylebox_override("panel", stylebox)

func _on_Options_options_closed():
	$TitleScreen.enable_buttons()

