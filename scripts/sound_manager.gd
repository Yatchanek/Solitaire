extends Node

export (Array, AudioStream) var sounds

onready var channels = get_children()

enum {
	CARD_PLACE_1,
	CARD_PLACE_2,
	CARD_SLIDE_1,
	CARD_SLIDE_2
}
# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func play_sound(_index : int):
	for channel in channels:
		if !channel.is_playing():
			channel.stream = sounds[_index]
			channel.play()
			break
