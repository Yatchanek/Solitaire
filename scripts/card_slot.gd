extends Resource
class_name CardSlot

var cards = []
var position : Vector2
var rect : Rect2
var is_ace_slot : bool
var index : int

signal card_placed
signal card_rejected

func initialize(_pos, _is_ace_slot = false, _index : int = 0):
	position = _pos
	is_ace_slot = _is_ace_slot
	index = _index

func is_empty():
	return cards.size() == 0

func get_last_card():
	return cards[cards.size() - 1]
	
func can_place(_card : Card, last_card : Card):
	if is_ace_slot:
		if _card.lower_card:
			return false
		return last_card.value == _card.value - 1 and last_card.suit == _card.suit
	else:
		if _card.current_state == _card.State.RETURNING or _card.dragged_from == self.index:
			return true
		return last_card.value == _card.value + 1 and (last_card.suit + _card.suit) % 2 == 1

func add_card(_card : Card, _position : Vector2, by_doubleclick : bool = false):
	if is_ace_slot:
		rect = Rect2(position, Vector2(Globals.SLOT_WIDTH, Globals.SLOT_HEIGHT))
		if !rect.has_point(_position) and !by_doubleclick:
			_card.set_state(_card.State.RETURNING, _card.current_state)
			emit_signal("card_rejected")
			return
		if is_empty():
			if _card.value == 1:		
				cards.append(_card)
				if by_doubleclick:
					_card.emit_signal("move_to_top")
				_card.move_to(self.position)
				SoundManager.play_sound(SoundManager.CARD_SLIDE_1)
				emit_signal("card_placed", _card, self)

			else:
				_card.set_state(_card.State.RETURNING, _card.current_state)
				emit_signal("card_rejected")
		else:
			var last_card : Card = get_last_card()
			if can_place(_card, last_card):
				cards.append(_card)
				if by_doubleclick:
					_card.emit_signal("move_to_top")
				_card.move_to(self.position)
				SoundManager.play_sound(SoundManager.CARD_SLIDE_1)		
				emit_signal("card_placed", _card, self)

			else:
				_card.set_state(_card.State.RETURNING, _card.current_state)

	else:
		rect = Rect2(position + Vector2(0, cards.size() * Globals.OFFSET), Vector2(Globals.SLOT_WIDTH, Globals.SLOT_HEIGHT))
		if !rect.has_point(_position):
			_card.set_state(_card.State.RETURNING, _card.current_state)
			return
		if is_empty():
			if _card.value == 13 or _card.current_state == _card.State.RETURNING:
				cards.append_array(_card.stack)	

				_card.is_in_play = true
				_card.move_to(self.position)
				SoundManager.play_sound(SoundManager.CARD_SLIDE_1)
				emit_signal("card_placed", _card, self)
			else:
				_card.set_state(_card.State.RETURNING, _card.current_state)
				emit_signal("card_rejected")

		else:
			var last_card : Card = get_last_card()
			if can_place(_card, last_card):
				cards.append_array(_card.stack)	
				if last_card != _card:
					last_card.lower_card = _card
	
				_card.is_in_play = true
				_card.move_to(last_card.rect_global_position + Vector2.DOWN * Globals.OFFSET)
				SoundManager.play_sound(SoundManager.CARD_SLIDE_1)
				emit_signal("card_placed", _card, self)
				return true
			else:
				_card.set_state(_card.State.RETURNING, _card.current_state)
				emit_signal("card_rejected")
				return false
		
func add_card_on_deal(_card : Card):
	var last_card : Card
	if !is_empty():
		last_card = get_last_card()
	cards.append(_card)
	_card.is_in_play = true
	if last_card:
		last_card.lower_card = _card

func remove_card(_card):
	if is_empty():
		return
	var idx = cards.find(_card)
	cards.resize(idx)
	if !is_empty():
		get_last_card().lower_card = null
