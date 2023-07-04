extends Control
class_name Card

var click_position : Vector2
var click_global_position : Vector2
var lower_card : Card

var suits = {
	0 : "Hearts",
	1 : "Spades",
	2 : "Diamonds",
	3 : "Clubs"
}

var values = {
	1 : 'Ace',
	2 : 'Two',
	3 : 'Three',
	4 : 'Four',
	5 : 'Five',
	6 : 'Six',
	7 : 'Seven',
	8 : 'Eight',
	9 : 'Nine',
	10 : 'Ten',
	11 : 'Jack',
	12 : 'Queen',
	13 : 'King'
}

var designs = ["", "2"]

var texture_path : String
var suit : int
var value : int
var dragged_from : int 
var is_in_play : bool = false
var move_failed : bool = false
var move_start_position : Vector2
var drag_start_time : int
var ticks : int
var current_state : int = State.IN_DECK
var previous_state : int
var stack_size : int
var slot_idx : int

var stack = []

var board

signal dragged
signal dropped
signal move_before
signal put_on_ace_slot
signal move_started
signal move_ended
signal in_pool


enum State {
	IN_DECK,
	NOT_FLIPPED,
	DRAWN,
	IDLE,
	CLICKED,
	DRAGGED,
	RETURNING,
	ON_ACE_SLOT,
	MOVING,
}

func set_state(_next_state, _current_state):
	current_state = _next_state
	previous_state = _current_state
	match _next_state:
		State.IN_DECK:
			set_process(false)
			if is_blocking_signals():
				set_block_signals(false)
			$CardOuter.texture = load("res://assets/cards" + str(Globals.card_design) + "/Back.png")
		
		State.NOT_FLIPPED:
			set_process(false)
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			$CardOuter.texture = load("res://assets/cards" + str(Globals.card_design) + "/Back.png")
			if board.current_state == board.State.PLAYING:
				set_block_signals(true)
		
		State.IDLE:
			set_process(false)
			if _current_state == State.NOT_FLIPPED or _current_state == State.IN_DECK:
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				$CardOuter.texture = load(texture_path)
			is_in_play = true
			if is_blocking_signals():
				set_block_signals(false)
			
		State.DRAWN:
			set_process(false)
			if is_blocking_signals():
				set_block_signals(false)
#			emit_signal("drawn", self)
			
		State.DRAGGED:
			move_failed = false
			create_stack()
			emit_signal("dragged", self, click_global_position)
		
		State.RETURNING:
			move_failed = true
			if !is_in_play:
				emit_signal("in_pool", self)
			else:
				go_back()

func _ready():
	board = get_parent()
	connect("dragged", Callable(board, "_on_Card_dragged"))
	connect("dropped", Callable(board, "_on_Card_dropped"))
	connect("put_on_ace_slot", Callable(board, "_on_Put_on_foundation"))
	connect("move_started", Callable(board, "_on_Card_move_started"))
	connect("move_ended", Callable(board, "_on_Card_move_ended"))
	connect("move_before", Callable(board, "_on_Card_move_to_top").bind(self))
	connect("in_pool", Callable(board, "_on_Card_in_pool"))
	set_process(false)
	add_to_group("Cards")
	slot_idx = -1

func _process(_delta):
	match current_state:
		State.CLICKED:
			if Time.get_ticks_msec() - drag_start_time > 100:
				move_start_position = global_position
				set_state(State.DRAGGED, current_state)

		State.DRAGGED:
			global_position = get_global_mouse_position() - click_position
			move_stack()
			
		State.RETURNING, State.MOVING:
			move_stack()

func initialize(_data : Vector2):
	suit = _data.x
	value = _data.y
	slot_idx = -1
	texture_path = "res://assets/cards" + str(Globals.card_design) + "/" + str(value) + "_" + str(suit) + ".png"
	$CardOuter.texture = load("res://assets/cards" + str(Globals.card_design) + "/Back.png")

func set_slot_idx(_idx : int):
	slot_idx = _idx
	if lower_card:
		lower_card.set_slot_idx(_idx)
	
func create_stack():
	stack = [self]
	emit_signal("move_before")
	if lower_card:
		var card_to_append = lower_card
		while card_to_append:
			stack.append(card_to_append)
			card_to_append.emit_signal("move_before")
			card_to_append = card_to_append.lower_card
	stack_size = stack.size()

func move_stack():
	if stack_size <= 1:
		return
	for i in range(1, stack_size):
		stack[i].global_position = stack[i - 1].global_position + Vector2.DOWN * Globals.OFFSET

func request_move_to_top():
	emit_signal("move_before")
	if lower_card:
		lower_card.request_move_to_top()


func move_to(_position):
	if board.current_state == board.State.PLAYING:
		set_state(State.MOVING, current_state)
		if !lower_card and !board.pool.has(self):
			emit_signal("move_before")
		emit_signal("move_started")
	var tw = create_tween()
	tw.connect("finished", Callable(self, "_on_Move_to_ended"))
	tw.tween_property(self, "global_position", _position, Globals.MOVE_SPEED)	

func move_along(_card : Card):
	global_position = _card.global_position + Vector2.DOWN * Globals.OFFSET
	if lower_card != null:
		lower_card.move_along(self)

func go_back():
	board.slots[dragged_from].add_card(self, move_start_position + Vector2(50, 50))

func toggle_hint():
	$HintFrame.visible = !$HintFrame.visible
	
func _on_Move_to_ended():
	if board.current_state == board.State.PLAYING:
		if stack_size > 1:
			move_stack()
		if position == Vector2(Globals.MARGIN, 20):
			set_state(State.IN_DECK, current_state)
			is_in_play = false
		elif is_in_play:
			set_state(State.IDLE, current_state)
		else:
			set_state(State.DRAWN, current_state)
		stack = [self]
		stack_size = 1
		move_failed = false
	emit_signal("move_ended", self)
	
func _on_Card_gui_input(event):
	if board.can_move == false:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			match current_state:
				State.IDLE, State.DRAWN:
					if board.pool.has(self) and board.pool.find(self) != board.pool.size() - 1:
						return
					set_process(true)
					drag_start_time = Time.get_ticks_msec()
					click_position = event.position
					click_global_position = event.global_position
					
					set_state(State.CLICKED, current_state)
				
				State.IN_DECK:
					move_start_position = global_position
					$CardOuter.texture = load(texture_path)
					emit_signal("in_pool", self)

	
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if lower_card:
				return
			if current_state == State.IDLE or current_state == State.DRAWN:
				set_process(false)
				create_stack()
				emit_signal("put_on_ace_slot", self)	
						
		if !event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			match current_state:
				State.DRAGGED:
					emit_signal("dropped", self, event.global_position)
				State.CLICKED:
					set_state(previous_state, current_state)

