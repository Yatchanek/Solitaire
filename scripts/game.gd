extends Control


var back_to_menu : bool = false
var quit_game : bool = false
var continue_game : bool = false

func _ready():
	for button in $GameWin/Buttons.get_children():
		button.connect("pressed", self, "_on_Button_pressed", [button.name])


func start_transition():
	var tw = create_tween()
	tw.tween_property($Veil, "modulate:a", 1.0, 1.0)
	tw.tween_interval(0.5)
	tw.tween_property($Veil, "modulate:a", 0.0, 1.0)
	tw.connect("step_finished", self, "_on_Start_Tween_step_finished")

func _on_Start_Tween_step_finished(idx : int):
	match idx:
		0:
			$GameWin.hide()
			$GameWin.modulate.a = 0
			if back_to_menu:
				$TitleScreen.reset()
				$TitleScreen.show()
			else:
				$TitleScreen.hide()
		1:
			
			if !back_to_menu and !quit_game:
				$Board.start(continue_game)
			elif quit_game:
				get_tree().quit()
				
		2: 
			if back_to_menu:
				back_to_menu = false
				continue_game = false
				$TitleScreen.slide_in()
			

func _on_Board_back_to_menu():
	back_to_menu = true
	start_transition()

func _on_TitleScreen_quit_game():
	quit_game = true
	start_transition()

func _on_TitleScreen_continue_game():
	continue_game = true
	start_transition()

func _on_Game_won_message_shown():
	for button in $GameWin/Buttons.get_children():
		button.disabled = false

func _on_Button_pressed(button_name):
	for button in $GameWin/Buttons.get_children():
		button.disabled = true
	match button_name:
		"NewGame":
			start_transition()
		"Quit":
			back_to_menu = true
			start_transition()

func _on_Board_game_won():
	$GameWin.show()
	var tw = create_tween()
	tw.connect("finished", self, "_on_Game_won_message_shown")
	tw.tween_property($GameWin, "modulate:a", 1.0, 1.0)


func _on_TitleScreen_new_game():
	continue_game = false
	start_transition()
