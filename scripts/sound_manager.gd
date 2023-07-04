extends Node

@onready var audioPlayer: AudioStreamPlayer = AudioStreamPlayer.new()

enum {
	CARD_PLACE_1,
	CARD_PLACE_2,
	CARD_SLIDE_1,
	CARD_SLIDE_2
}

func _ready():
	pass

func play_sound(index: int):
	match index:
		CARD_PLACE_1:
			$AudioStreamPlayer1.play()
		CARD_PLACE_2:
			$AudioStreamPlayer2.play()
		CARD_SLIDE_1:
			$AudioStreamPlayer3.play()
		CARD_SLIDE_2:
			$AudioStreamPlayer4.play()
