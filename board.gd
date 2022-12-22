extends Control

var card_scene = preload("res://card_textured.tscn")
var slot_scene = preload("res://ace_slot.tscn")

var deck : PoolVector2Array = []
var pool : Array = []
var slots : Array = []


var can_move : bool = true
var dragged_from : int = 0

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_ENTER:
			get_tree().reload_current_scene()
		if event.pressed and event.scancode == KEY_SPACE:
			auto_put_on_ace()
		if event.pressed and event.scancode == KEY_ESCAPE:
			get_tree().quit()

func _ready():
	pass

func start():
	create_deck()
	deal()
	update_label()
	

func create_deck():
	for suit in 4:
		for value in range(1, 14):
			deck.append(Vector2(suit, value))

func deal():
	slots.resize(Globals.COLUMNS)
	for i in Globals.COLUMNS:
		var slot = CardSlot.new()
		slot.connect("card_placed", self, "_on_Card_changed_slots")
		slot.connect("card_rejected", self, "_on_Card_move_started")
		slot.initialize(rect_position + Vector2(Globals.MARGIN + i * (Globals.SLOT_WIDTH + Globals.MARGIN), 275), false, i)
		slots[i] = slot
	
		
	for row in Globals.COLUMNS:
		for col in Globals.COLUMNS:
			if col < row:
				continue
			var idx = randi() % deck.size()
			var card_data = deck[idx]
			var card = card_scene.instance()
			card.initialize(card_data)
			deck.remove(idx)
			card.rect_position = Vector2(Globals.MARGIN + col * (Globals.SLOT_WIDTH + Globals.MARGIN), 275 + Globals.OFFSET * row)
			call_deferred("add_child", card)
			slots[col].add_card_on_deal(card)
			if col == row:
				card.set_state(card.State.IDLE, card.current_state)
			else: 
				card.set_state(card.State.NOT_FLIPPED, card.current_state)

	
	var begin_slot = slot_scene.instance()
	begin_slot.rect_position = Vector2(Globals.MARGIN, 20)
	begin_slot.connect("gui_input", self, "_on_Begin_slot_clicked")
	call_deferred("add_child", begin_slot)
			
	while deck.size() > 0:
		var idx = randi() % deck.size()
		var card_data = deck[idx]
		var card = card_scene.instance()
		card.initialize(card_data)
		card.set_state(card.State.IN_DECK, card.current_state)
		deck.remove(idx)	
		card.rect_position = Vector2(Globals.MARGIN, 20) #+ Vector2(randi() % 10, 0) * pow(-1, randi() % 2)
		call_deferred("add_child", card)
		
	for i in Globals.ACE_SLOTS:
		var slot = slot_scene.instance()
		slot.rect_position = Vector2(Globals.MARGIN + (i + 3) * (Globals.SLOT_WIDTH + Globals.MARGIN), 20)
		slot.rect_size = Vector2(Globals.SLOT_WIDTH, Globals.SLOT_HEIGHT)
		call_deferred("add_child", slot)
		var ace_slot = CardSlot.new()
		ace_slot.connect("card_placed", self, "_on_Card_changed_slots")
		ace_slot.connect("card_rejected", self, "_on_Card_move_started")
		ace_slot.initialize(rect_position + Vector2(Globals.MARGIN + (i + 3) * (Globals.SLOT_WIDTH + Globals.MARGIN), 20), true, i + Globals.COLUMNS)
		slots.append(ace_slot)

func determine_slot(_position):
	var slot : int
	if _position.y < 250:
		if _position.x < rect_position.x + 3 * (Globals.SLOT_WIDTH + Globals.MARGIN):
			slot =  -1
		else:
			slot =  Globals.COLUMNS + floor((_position.x - - rect_position.x - Globals.MARGIN - 3 * (Globals.SLOT_WIDTH + Globals.MARGIN)) / (Globals.SLOT_WIDTH + Globals.MARGIN))	
	else:
		if _position.x > rect_position.x + Globals.COLUMNS * (Globals.SLOT_WIDTH + Globals.MARGIN) + Globals.SLOT_WIDTH:
			slot =  -1
		else:
			slot =  floor((_position.x - Globals.MARGIN - rect_position.x) / (Globals.SLOT_WIDTH + Globals.MARGIN))
	
	return slot

func check_against_ace_slots(_card : Card) -> int: 
	var suitable_slot : int = - 1
	var empty_slot : int = - 1
	for i in Globals.ACE_SLOTS:
		var checked_slot = slots[Globals.COLUMNS + i]
		if _card.value == 1:
			if checked_slot.is_empty() and empty_slot < 0:
				empty_slot = i + Globals.COLUMNS
				break
		else:
			if checked_slot.is_empty():
				continue
			else:
				var last_card = checked_slot.get_last_card()
				if last_card.suit == _card.suit and last_card.value == _card.value - 1:
					suitable_slot = i + Globals.COLUMNS
					break
	if suitable_slot < Globals.COLUMNS:
		suitable_slot = empty_slot

	return suitable_slot


func restore_deck():
	while pool.size():
		var card : Card = pool.pop_back()
		card.set_state(card.State.IN_DECK, card.current_state)
		card.rect_global_position = rect_position + Vector2(Globals.MARGIN, 20)
		card.emit_signal("move_to_top")	

		
func flip_card(_card):
	if dragged_from >= 0:
		var column : CardSlot = slots[dragged_from]
		if !column.is_empty():
			column.get_last_card().set_state(Card.State.IDLE, Card.State.NOT_FLIPPED)
		dragged_from = -1

func auto_put_on_ace():
	var found : bool = false
	for i in Globals.COLUMNS:
		if slots[i].cards.size() > 0:
			var card = slots[i].get_last_card()
			var suitable_slot = check_against_ace_slots(card)
			if suitable_slot >= Globals.COLUMNS:
				dragged_from = i
				card.dragged_from = i
				slots[i].remove_card(card)
				#card.move_to_slot(ace_slots[suitable_slot])
				slots[suitable_slot].add_card(card, slots[suitable_slot].position + Vector2(50, 50), true)
				found = true
				update_label()
	if pool.size() > 0:
		var card : Card = pool[pool.size() - 1]
		var suitable_slot = check_against_ace_slots(card)
		if suitable_slot >= Globals.COLUMNS:
			pool.erase(card)
			
			#card.move_to_slot(ace_slots[suitable_slot])
			slots[suitable_slot].add_card(card, slots[suitable_slot].position + Vector2(50, 50), true)
			found = true
			update_label()		
	if found:
		auto_put_on_ace()

func check_for_win():
	var game_won : bool = true
	for i in Globals.ACE_SLOTS:
		if !slots[i + Globals.COLUMNS].cards.size() == 13:
			game_won = false
			return
	if game_won:
		print("Game won!")

func update_label():
	var string = ""
	for col_num in Globals.COLUMNS:
		string += "Column " + str(col_num) + ": "
		var column : CardSlot = slots[col_num]
		for card in column.cards.size():
			string += str(column.cards[card].values[column.cards[card].value]) + " of " + column.cards[card].suits_verbose[column.cards[card].suit] + ", "
		string += "\n" 
	for slot_num in Globals.ACE_SLOTS:
		string += "Ace slot " + str(slot_num + Globals.COLUMNS) + ": "
		var slot : CardSlot = slots[slot_num  + Globals.COLUMNS]
		for card in slot.cards.size():
			string += str(slot.cards[card].values[slot.cards[card].value]) + " of " + slot.cards[card].suits_verbose[slot.cards[card].suit] + ", "			
		string += "\n"
	$Label.text = string


func _on_Card_move_to_top(_card):
	move_child(_card, get_child_count())

func _on_Card_dragged(_card, _position):
	if _card.is_in_play:
		var slot_num = determine_slot(_position)
		var slot : CardSlot = slots[slot_num]
		dragged_from = slot_num
		_card.dragged_from = slot_num
		slot.remove_card(_card)
	update_label()
	
func _on_Card_changed_slots(_card : Card, slot : CardSlot):
	if _card in pool:
		pool.erase(_card)
	if slot.is_ace_slot or slot.index != dragged_from:
		flip_card(_card)
	_card.move_stack()
	if slot.is_ace_slot:
		check_for_win()
	update_label()

func _on_Card_dropped(_card : Card, _position : Vector2):
	var slot_num : int = determine_slot(_position)
	var	slot = slots[slot_num]
	if slot_num < 0:
		_card.set_state(_card.State.RETURNING, _card.previous_state)
	else:
		slot.add_card(_card, _position)
		

func _on_Card_drawn(_card : Card):
	pool.append(_card)

func _on_Double_click(_card : Card, _position : Vector2):
	if _card.is_in_play:
		var suitable_slot : int = check_against_ace_slots(_card)
		if suitable_slot >= Globals.COLUMNS:
			var slot_num = determine_slot(_position)
			dragged_from = slot_num
			_card.dragged_from = slot_num
			var slot : CardSlot = slots[dragged_from]
			slot.remove_card(_card)
			slots[suitable_slot].add_card(_card, slots[suitable_slot].position + Vector2(50, 50), true)


func _on_Begin_slot_clicked(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == BUTTON_LEFT:
			restore_deck()

func _on_Card_move_started():
	can_move = false
	
func _on_Card_move_ended():
	can_move = true
