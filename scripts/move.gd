extends Resource
class_name Move

var card : Card
var card_flipped : Card
var slot_idx : int
var slot_from : CardSlot
var slot_to : CardSlot
var position_from : Vector2
var was_card_in_play : bool
var was_card_in_deck : bool
var was_card_in_pool : bool
var was_card_added_to_pool : bool
var deck_flipped : bool

var slots : Array
var deck : Array
var pool : Array

signal deck_flipped
signal card_back_in_pool

func initialize(_card : Card, _slots : Array, _deck : Array, _pool : Array):
	slots = _slots
	deck = _deck
	pool = _pool
	if _card:
		card = _card
		slot_idx = _card.slot_idx
		var card_idx : int
		if slot_idx >= 0:
			slot_from = slots[slot_idx]
			card_idx = slot_from.cards.find(card)
			if card_idx >= 0 and slot_from.cards[card_idx - 1].current_state == Card.State.NOT_FLIPPED:
				card_flipped = slot_from.cards[card_idx - 1]
		was_card_in_play = _card.is_in_play
		was_card_in_deck = deck.has(card)
		was_card_in_pool = pool.has(card)
		was_card_added_to_pool = was_card_in_deck
		position_from = _card.move_start_position

func register_deck_flip():
	deck_flipped = true
		
func undo():
	if deck_flipped:
		while deck.size() > 0:
			var _card : Card = deck.pop_back()
			pool.append(_card)
			_card.emit_signal("move_to_top")
			_card.get_node("CardOuter").texture = load(_card.texture_path)
			_card.move_to(_card.rect_global_position + Vector2(Globals.MARGIN + Globals.SLOT_WIDTH, 0))
		emit_signal("deck_flipped")
		
	else:	
		if slot_to:
			slot_to.remove_card(card)
		if slot_from:
			if !slot_from.is_empty():
				slot_from.get_last_card().lower_card = card
			slot_from.cards.append(card)
			var next_card : Card = card.lower_card
			while next_card:
				slot_from.cards.append(next_card)
				next_card = next_card.lower_card
		
		card.is_in_play = was_card_in_play
		card.slot_idx = slot_idx
		if was_card_added_to_pool:
			pool.erase(card)
		if was_card_in_deck:
			deck.append(card)
			emit_signal("card_back_in_pool")
		if was_card_in_pool:
			pool.append(card)
			emit_signal("card_back_in_pool")

			
		if card_flipped:
			card_flipped.set_state(Card.State.NOT_FLIPPED, card_flipped.current_state)	
		
		card.create_stack()
		card.move_to(position_from)
