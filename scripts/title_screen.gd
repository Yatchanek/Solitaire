extends Control


signal new_game
signal quit_game
signal continue_game

# Called when the node enters the scene tree for the first time.
func _ready():
	for button in $Buttons.get_children():
		button.connect("pressed", self, "_on_Button_pressed", [button.name])
	slide_in()

func slide_in():
	var tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property($Label, "rect_position:x", 0.0, 1.75)
	tw.connect("finished", self, "_on_Title_shown")


func reset():
	$Label.rect_position.x = -3000
	$Buttons.modulate.a = 0

func _on_Title_shown():
	var tw = create_tween()
	tw.tween_property($Buttons, "modulate:a", 1.0, 0.5)
	tw.connect("finished", self, "_on_Buttons_shown")

func _on_Buttons_shown():
	for button in $Buttons.get_children():
		button.disabled = false	
		if button.name == "Continue":
			var f = File.new()
			if !f.file_exists("user://save.sav"):
				button.disabled = true

func _on_Button_pressed(_name : String):
	for button in $Buttons.get_children():
		button.disabled = true
	if _name == "NewGame":
		emit_signal("new_game")
	elif _name == "Quit":
		emit_signal("quit_game")
	else:
		emit_signal("continue_game")
