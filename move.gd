extends Resource
class_name Move

var card : Card
var card_flipped : Card
var return_slot : CardSlot
var current_slot : CardSlot
var slot_idx : int
var state : int
var return_position : Vector2
var pool_before_flip : Array
var card_in_play : bool
var card_was_in_pool : bool
var card_was_in_deck : bool
var card_added_to_pool : bool
var deck_flipped : bool

signal add_to_pool
signal add_to_deck
signal remove_from_pool
signal undo_deck_flip

func setup(_card : Card, slots, pool, deck, _slot : CardSlot = null):
	card = _card
	slot_idx = _card.slot_idx
	if slot_idx >= 0:
		return_slot = slots[slot_idx]
		var card_idx = return_slot.cards.find(_card)
		if card_idx > 0 and return_slot.cards[card_idx - 1].current_state == Card.State.NOT_FLIPPED:
			card_flipped = return_slot.cards[card_idx - 1]
	return_position = _card.move_start_position
	card_in_play = _card.is_in_play
	card_was_in_deck = deck.has(card)
	card_was_in_pool = pool.has(card)
		
	
func register_deck_flip():
	deck_flipped = true

func undo():
	if deck_flipped:
		emit_signal("undo_deck_flip")
	
	else:
		card.slot_idx = slot_idx	
		if return_slot:
			if !return_slot.is_empty():
				return_slot.get_last_card().lower_card = card
			return_slot.cards.append(card)
			if card.lower_card:
				var next_card = card.lower_card
				while next_card:
					return_slot.cards.append(next_card)
					next_card = next_card.lower_card	
		
		if current_slot:
			current_slot.remove_card(card)
			
		
		if card_flipped:
			card_flipped.set_state(Card.State.NOT_FLIPPED, Card.State.IDLE)
		
		card.is_in_play = card_in_play
		
		if card_was_in_pool:
			card.is_in_play = false
			emit_signal("add_to_pool", card)
			
		if card_added_to_pool:
			emit_signal("remove_from_pool", card)
			
		if card_was_in_deck:
			emit_signal("add_to_deck", card)
			card.set_state(Card.State.IN_DECK, Card.State.IDLE)
			card.is_in_play = false
				
		card.move_to(return_position)
