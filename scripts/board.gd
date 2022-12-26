extends Control

var card_scene = preload("res://scenes/card_textured.tscn")
var slot_scene = preload("res://scenes/ace_slot.tscn")
var frame_scene = preload("res://scenes/frame.tscn")
var hint_frame_scene = preload("res://scenes/hint_frame.tscn")

var cards : PoolVector2Array = []
var pool : Array = []
var slots : Array = []
var deck : Array = []
var highlighted_cards : Array = []

var can_move : bool = true
var dragged_from : int = 0
var slot_to_flip : int
var card_drawn_from_pool : bool = false
var game_won = false

signal back_to_menu
signal game_won

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_ENTER:
			reset()
			yield(get_tree(), "idle_frame")
			new_game()
		if event.pressed and event.scancode == KEY_SPACE:
			auto_put_on_ace()
		if event.pressed and event.scancode == KEY_H:
			find_hint()
		if event.pressed and event.scancode == KEY_ESCAPE:
			save_layout()
			emit_signal("back_to_menu")

func _ready():
	pass

func reset():
	cards  = []
	pool = []
	slots = []
	deck = []
	for card in get_children():
		if card is Card:
			card.queue_free()
	remove_frames()
	highlighted_cards = []
	game_won = false
	
func new_game():
	create_deck()
	create_slots()
	deal_cards()	
	$HintTimer.start()

func continue_game():
	var f = File.new()
	if f.file_exists("user://save.sav"):
		var err = f.open("user://save.sav", File.READ)
		if err == OK:
			var game_data = f.get_var()
			f.close()
			create_slots()
			restore_layout(game_data)
			$HintTimer.start()
		else:
			new_game()
	else:
		new_game()
		

func start(continue_game : bool = false):
	randomize()
	reset()
	if continue_game:
		continue_game()
	else:
		new_game()

	

func save_layout():
	var game_data = {}
	var slots_data = []
	var pool_data = []
	var deck_data = []
	for slot in slots:
		var slot_data = serialize_slot(slot)
		slots_data.append(slot_data)
	
	for card in deck:
		deck_data.append(serialize_card(card))
		
	for card in pool:
		pool_data.append(serialize_card(card))
	
	game_data["slots"] = slots_data
	game_data["deck"] = deck_data
	game_data["pool"] = pool_data
	
	var f = File.new()
	f.open("user://save.sav", File.WRITE)
	f.store_var(game_data)
	f.close()

func serialize_slot(_slot : CardSlot):
	var slot_data = []
	for card in _slot.cards:
		var card_data : Dictionary = serialize_card(card)
		slot_data.append(card_data)
	return slot_data

func serialize_card(card : Card):
	var card_data = {}
	card_data["data"] = Vector2(card.suit, card.value)
	card_data["current_state"] = card.current_state
	card_data["previous_state"] = card.previous_state
	card_data["is_in_play"] = card.is_in_play
	card_data["slot_idx"] = card.slot_idx
	return card_data

func deserialize_card(card_data : Dictionary):
	var card : Card = card_scene.instance()
	add_child(card)
	card.initialize(card_data.data)
	card.is_in_play = card_data.is_in_play
	card.current_state = card_data.current_state
	card.previous_state = card_data.previous_state
	card.slot_idx = card_data.slot_idx
	if card.current_state != Card.State.NOT_FLIPPED and card.current_state != Card.State.IN_DECK:
		card.get_node("CardOuter").texture = load(card.texture_path)
	elif card.current_state == Card.State.NOT_FLIPPED:
		card.set_block_signals(true)
	return card

func restore_layout(game_data):
	for i in slots.size():
		var target_slot = slots[i]
		var saved_slot = game_data.slots[i]
		for j in saved_slot.size():
			var card = deserialize_card(saved_slot[j])
			target_slot.cards.append(card)
			if i < Globals.COLUMNS:
				card.rect_position = target_slot.position - rect_position + Vector2.DOWN * j * Globals.OFFSET
			else:
				card.rect_position = target_slot.position - rect_position
			if j > 0:
				target_slot.cards[j - 1].lower_card = card
			if i >= Globals.COLUMNS:
				card.emit_signal("move_to_top")
			
	for _card in game_data.deck:
		var card = deserialize_card(_card)
		card.rect_position = Vector2(Globals.MARGIN, 20)
		deck.append(card)
	
	for _card in game_data.pool:
		var card = deserialize_card(_card)
		card.rect_position = Vector2(2 * Globals.MARGIN + Globals.SLOT_WIDTH, 20)
		pool.append(card)
		update_pool_layout()	
		
	var dir = Directory.new()
	
func create_deck():
	for suit in 4:
		for value in range(1, 14):
			cards.append(Vector2(suit, value))

func create_slots():
	slots.resize(Globals.COLUMNS)
	for i in Globals.COLUMNS:
		var slot = CardSlot.new()
		slot.connect("card_placed", self, "_on_Card_changed_slots")
		slot.connect("card_rejected", self, "_on_Card_move_started")
		slot.initialize(rect_position + Vector2(Globals.MARGIN + i * (Globals.SLOT_WIDTH + Globals.MARGIN), 250), false, i)
		slots[i] = slot
	
	for i in Globals.ACE_SLOTS:
		var slot = slot_scene.instance()
		slot.rect_position = Vector2(Globals.MARGIN + (i + 3) * (Globals.SLOT_WIDTH + Globals.MARGIN), 20)
		slot.rect_size = Vector2(Globals.SLOT_WIDTH, Globals.SLOT_HEIGHT)
		add_child(slot)
		var ace_slot = CardSlot.new()
		ace_slot.connect("card_placed", self, "_on_Card_changed_slots")
		ace_slot.connect("card_rejected", self, "_on_Card_move_started")
		ace_slot.initialize(rect_position + Vector2(Globals.MARGIN + (i + 3) * (Globals.SLOT_WIDTH + Globals.MARGIN), 20), true, i + Globals.COLUMNS)
		slots.append(ace_slot)
	
	var begin_slot = slot_scene.instance()
	begin_slot.rect_position = Vector2(Globals.MARGIN, 20)
	begin_slot.connect("gui_input", self, "_on_Begin_slot_clicked")
	add_child(begin_slot)
	move_child(begin_slot, 0)

func deal_cards():	
	while cards.size() > 0:
		var idx = randi() % cards.size()
		var card_data = cards[idx]
		var card = card_scene.instance()
		card.initialize(card_data)
		card.set_state(card.State.IN_DECK, card.current_state)
		cards.remove(idx)	
		card.rect_position = Vector2(Globals.MARGIN, 20) #+ Vector2(randi() % 10, 0) * pow(-1, randi() % 2)
		deck.append(card)
		add_child(card)
	
	yield(get_tree(), "idle_frame")
			
	for row in Globals.COLUMNS:
		for col in Globals.COLUMNS:
			if col < row:
				continue
			var card = deck.pop_back()

			card.rect_position = Vector2(Globals.MARGIN + col * (Globals.SLOT_WIDTH + Globals.MARGIN), 250 + Globals.OFFSET * row)
			card.emit_signal("move_to_top")

			slots[col].add_card_on_deal(card)
			if col == row:
				card.set_state(card.State.IDLE, card.current_state)
			else: 
				card.set_state(card.State.NOT_FLIPPED, card.current_state)		

	update_label()
	
func determine_slot(_position):
	var slot : int
	if _position.y < 250:
		if _position.x < rect_position.x + 3 * (Globals.SLOT_WIDTH + Globals.MARGIN):
			slot =  -1
		else:
			slot =  Globals.COLUMNS + floor((_position.x - rect_position.x - Globals.MARGIN - 3 * (Globals.SLOT_WIDTH + Globals.MARGIN)) / (Globals.SLOT_WIDTH + Globals.MARGIN))	
	else:
		if _position.x > rect_position.x + Globals.COLUMNS * (Globals.SLOT_WIDTH + Globals.MARGIN) + Globals.SLOT_WIDTH:
			slot =  -2
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
		deck.append(card)
		
		card.move_to(rect_position + Vector2(Globals.MARGIN, 20))
		#card.emit_signal("move_to_top")

		
func flip_card(slot_num):
	var slot : CardSlot = slots[slot_num]
	if !slot.is_empty():
		slot.get_last_card().set_state(Card.State.IDLE, Card.State.NOT_FLIPPED)
	dragged_from = -1

func auto_put_on_ace():
	var move_found : bool = true
	if can_move:
		move_found = false
		for i in Globals.COLUMNS:
			if slots[i].cards.size() > 0:
				var card : Card = slots[i].get_last_card()
				if card.lower_card:
					card.lower_card = null
				if card.current_state == Card.State.NOT_FLIPPED:
					continue
				var suitable_slot = check_against_ace_slots(card)
				if suitable_slot >= Globals.COLUMNS:
					dragged_from = i
					card.dragged_from = i
					slots[i].remove_card(card)
					slots[suitable_slot].add_card(card, slots[suitable_slot].position + Vector2(50, 50), true)
					move_found = true
					update_label()
					#break
		if pool.size() > 0 and !move_found:
			var card : Card = pool[pool.size() - 1]
			var suitable_slot = check_against_ace_slots(card)
			if suitable_slot >= Globals.COLUMNS:
				pool.erase(card)
				
				#card.move_to_slot(ace_slots[suitable_slot])
				slots[suitable_slot].add_card(card, slots[suitable_slot].position + Vector2(50, 50), true)
				move_found = true
				update_label()		
	if move_found:
		remove_frames()
		yield(get_tree(), "idle_frame")
		auto_put_on_ace()

func check_for_win():
	var win : bool = true
	for i in Globals.ACE_SLOTS:
		if !slots[i + Globals.COLUMNS].cards.size() == 13:
			win = false
			return
	if win:
		can_move = false
		game_won = true
		emit_signal("game_won")

func update_label():
	var string = ""
	for col_num in Globals.COLUMNS:
		string += "Column " + str(col_num) + ": "
		var column : CardSlot = slots[col_num]
		for card in column.cards.size():
			string += str(column.cards[card].values[column.cards[card].value]) + " of " + column.cards[card].suits[column.cards[card].suit] + ", "
		string += "\n" 
	for slot_num in Globals.ACE_SLOTS:
		string += "Ace slot " + str(slot_num + Globals.COLUMNS) + ": "
		var slot : CardSlot = slots[slot_num  + Globals.COLUMNS]
		for card in slot.cards.size():
			string += str(slot.cards[card].values[slot.cards[card].value]) + " of " + slot.cards[card].suits[slot.cards[card].suit] + ", "			
		string += "\n"
	string += "Pool: "
	for card in pool:
		string += card.values[card.value] + card.suits[card.suit] + " "

	get_parent().get_node("Label").text = string

func update_pool_layout():
	if pool.size() > 2 and pool[pool.size() - 1].rect_position.x < 4.0 * Globals.MARGIN  + Globals.SLOT_WIDTH:
		pool[pool.size() - 2].move_to(rect_position + Vector2(3 * Globals.MARGIN  + Globals.SLOT_WIDTH, 20))
		pool[pool.size() - 1].move_to(rect_position + Vector2(4 * Globals.MARGIN  + Globals.SLOT_WIDTH, 20))

func find_hint():
	remove_frames()
	var begin_card : Card
	var target_card : Card
	var target_slot : CardSlot
	var found = false
	var shuffled_slots = [0, 1, 2, 3, 4, 5, 6]
	shuffled_slots.shuffle()
	for i in shuffled_slots:
		if found:
			break
		var slot = slots[i]
		for j in slot.cards.size():
			if found:
				break
			var card_1 = slot.cards[j]
			if card_1.current_state == Card.State.NOT_FLIPPED:
				continue
			for t_i in Globals.COLUMNS + 4:
				if t_i == i:
					continue
				var t_slot = slots[t_i]
				if t_i < Globals.COLUMNS:
					if t_slot.is_empty() and card_1.value == 13 and j != 0:
						begin_card = card_1
						target_slot = t_slot
						found = true
						break
					elif !t_slot.is_empty() and t_slot.get_last_card().value > 1 and card_1.value == t_slot.get_last_card().value - 1 and (card_1.suit + t_slot.get_last_card().suit) % 2 == 1:
						begin_card = card_1
						found = true
						target_card = t_slot.get_last_card()
				else:
					if t_slot.is_empty() and card_1.value == 1:
						begin_card = card_1
						target_slot = t_slot
						found = true
						break
					elif !t_slot.is_empty() and card_1.lower_card == null and card_1.value == t_slot.get_last_card().value + 1 and card_1.suit == t_slot.get_last_card().suit:
						begin_card = card_1
						found = true
						target_card = t_slot.get_last_card()
					
	if !found and pool.size() > 0:
		var card_1 = pool[pool.size() - 1]
		for t_i in Globals.COLUMNS + 4:
			var t_slot = slots[t_i]
			if t_i < Globals.COLUMNS:	
				if t_slot.is_empty() and card_1.value == 13:
					begin_card = card_1
					target_slot = t_slot
					found = true
					break
				elif !t_slot.is_empty() and card_1.value > 1 and card_1.value == t_slot.get_last_card().value - 1 and (card_1.suit + t_slot.get_last_card().suit) % 2 == 1:
					found = true
					begin_card = card_1
					target_card = t_slot.get_last_card()
					break
			else:
				if t_slot.is_empty() and card_1.value == 1:
					begin_card = card_1
					target_slot = t_slot
					found = true
					break
				elif !t_slot.is_empty() and card_1.value == t_slot.get_last_card().value + 1 and card_1.suit == t_slot.get_last_card().suit:
					found = true
					begin_card = card_1
					target_card = t_slot.get_last_card()
					break
					
	if !begin_card and deck.size() > 0:
		begin_card = deck[deck.size() - 1]
	highlighted_cards.append(begin_card)
	highlighted_cards.append(target_card)
	show_hint(begin_card, target_card, target_slot)
	
		
func show_hint(begin_card : Card, target_card : Card, target_slot : CardSlot):

	if begin_card:
		begin_card.toggle_hint()	
		if target_card:
			target_card.toggle_hint()
		elif target_slot:
			var frame = hint_frame_scene.instance()
			frame.position = target_slot.position - rect_position
			$Frames.add_child(frame)
	else:
		var frame = hint_frame_scene.instance()
		frame.position = Vector2(Globals.MARGIN, 20)
		$Frames.add_child(frame)
	
func _on_Card_in_pool(_card : Card):
	remove_frames()
	var pool_size = pool.size()
	var target_pos : Vector2
	var offset = min(pool_size, 2)
	target_pos = rect_position + Vector2((2 + offset) * Globals.MARGIN  + Globals.SLOT_WIDTH, 20)
	if pool_size > 2:
		pool[pool_size - 2].move_to(target_pos - Vector2(2 * Globals.MARGIN, 0))
		pool[pool_size - 1].move_to(target_pos - Vector2(Globals.MARGIN, 0))
	
	_card.move_to(target_pos)
	_card.is_in_play = false
	pool.append(_card)
	if _card in deck:
		deck.erase(_card)
	update_label()

func remove_frames():
	for frame in $Frames.get_children():
		frame.queue_free()
	for card in highlighted_cards:
		if card != null:
			card.toggle_hint()
	highlighted_cards = []

func _on_Card_move_to_top(_card):
	move_child(_card, get_child_count())

func _on_Card_dragged(_card, _position):
	if _card.is_in_play:
		var slot_num = determine_slot(_position)
		var slot : CardSlot = slots[slot_num]
		dragged_from = slot_num
		_card.dragged_from = slot_num
		slot.remove_card(_card)
	if _card in pool:
		card_drawn_from_pool = true
		pool.erase(_card)
	remove_frames()
	update_label()
	$HintTimer.stop()
	
func _on_Card_changed_slots(_card : Card, slot : CardSlot):
	_card.slot_idx = slot.index

func _on_Card_dropped(_card : Card, _position : Vector2):
	var slot_num : int = determine_slot(_position)
	var	slot = slots[slot_num]
	if slot_num < 0:
		_card.set_state(_card.State.RETURNING, _card.previous_state)
	else:
		slot.add_card(_card, _position)
		
func _on_Card_drawn(_card : Card):
	if _card in deck:
		deck.erase(_card)
	if !_card in pool:
		pool.append(_card)

func _on_Double_click(_card : Card, _position : Vector2):
	if _card in pool:
		card_drawn_from_pool = true
	var suitable_slot : int = check_against_ace_slots(_card)
	if suitable_slot >= Globals.COLUMNS:
		if _card.slot_idx < 0:
			_card.slot_idx = determine_slot(_position)
		remove_frames()
		dragged_from = _card.slot_idx
		_card.dragged_from = _card.slot_idx
		var slot : CardSlot = slots[dragged_from]
		slot.remove_card(_card)
		slots[suitable_slot].add_card(_card, slots[suitable_slot].position + Vector2(50, 50), true)
	$HintTimer.stop()
	
func _on_Begin_slot_clicked(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == BUTTON_LEFT:
			restore_deck()

func _on_Card_move_started():
	if can_move:
		SoundManager.play_sound(0)
	can_move = false
	
func _on_Card_move_ended(_card):
	if _card in pool and _card.is_in_play:
		pool.erase(_card)
	if card_drawn_from_pool:
		update_pool_layout()
		card_drawn_from_pool = false
	if _card.slot_idx >= Globals.COLUMNS or _card.slot_idx != _card.dragged_from:
		flip_card(_card.dragged_from)
	if _card.slot_idx >= Globals.COLUMNS:
		var frame = frame_scene.instance()
		frame.position = _card.rect_position + Vector2(Globals.SLOT_WIDTH, Globals.SLOT_HEIGHT) * 0.5
		add_child(frame)
		check_for_win()
	
	$HintTimer.start()
	update_label()
	can_move = true

func _on_HintTimer_timeout():
	if !game_won:
		find_hint()
