extends Control
class_name Card

var is_dragged : bool = false
var click_position : Vector2
var click_global_position : Vector2
var lower_card : Card
var suits_verbose = ["Hearts", "Spades", "Diamonds", "Clubs"]
var suits = ["res://suit_hearts.png", "res://suit_spades.png", "res://suit_diamonds.png", "res://suit_clubs.png"]
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

var texture_path : String
var suit : int
var value : int
var dragged_from : int 
var is_in_play : bool = false
var on_ace_slot : bool = false
var can_doubleclick : bool = false
var drag_start_position : Vector2
var drag_start_time : int
var ticks : int
var current_state : int = State.IN_DECK
var previous_state : int
var stack_size : int

var stack = []

signal dragged
signal dropped
signal move_to_top
signal drawn
signal put_on_ace_slot
signal move_started
signal move_ended


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
			$CardOuter.texture = load("res://assets/cards2/Back.png")
		
		State.NOT_FLIPPED:
			set_process(false)
			mouse_default_cursor_shape = Control.CURSOR_ARROW
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
			emit_signal("move_to_top")
			set_process(false)
			if is_blocking_signals():
				set_block_signals(false)
			emit_signal("drawn", self)
			
		State.DRAGGED:
			create_stack()
			emit_signal("dragged", self, click_global_position)
		
		State.RETURNING:
			if !is_in_play:
				move_to_pool()
			else:
				go_back()
				
		State.ON_ACE_SLOT:
			set_process(false)
			is_in_play = false

func _ready():
	connect("dragged", get_parent(), "_on_Card_dragged")
	connect("dropped", get_parent(), "_on_Card_dropped")
	connect("put_on_ace_slot", get_parent(), "_on_Double_click")
	connect("drawn", get_parent(), "_on_Card_drawn")
	connect("move_started", get_parent(), "_on_Card_move_started")
	connect("move_ended", get_parent(), "_on_Card_move_ended")
	connect("move_to_top", get_parent(), "_on_Card_move_to_top", [self])
	
	set_process(false)


func _process(_delta):
	match current_state:
		State.CLICKED:
			if Time.get_ticks_msec() - drag_start_time > 100:
				can_doubleclick = false
				set_state(State.DRAGGED, current_state)
		State.DRAGGED:
			rect_global_position = get_global_mouse_position() - click_position
			move_stack()
		State.RETURNING, State.MOVING:
			move_stack()

func initialize(_data : Vector2):
	suit = _data.x
	value = _data.y
	texture_path = "res://assets/cards2/" + values[value] + " of " + suits_verbose[suit]  + ".png"
	$CardOuter.texture = load("res://assets/cards2/Back.png")
	
func create_stack():
	stack = [self]
	emit_signal("move_to_top")
	if lower_card:
		var card_to_append = lower_card
		while card_to_append:
			stack.append(card_to_append)
			card_to_append.emit_signal("move_to_top")
			card_to_append = card_to_append.lower_card
	stack_size = stack.size()

func move_stack():
	if stack_size <= 1:
		return
	for i in range(1, stack_size):
		stack[i].rect_global_position = stack[i - 1].rect_global_position + Vector2.DOWN * Globals.OFFSET

func request_move_to_top():
	emit_signal("move_to_top")
	if lower_card:
		lower_card.request_move_to_top()

func move_to_pool():
	move_to(get_parent().rect_position + Vector2(2 * Globals.MARGIN + Globals.SLOT_WIDTH, 20))
	is_in_play = false

func move_to(_position):
	set_state(State.MOVING, current_state)
	emit_signal("move_started")
	var tw = create_tween()
	tw.connect("finished", self, "_on_Move_to_ended")
	tw.tween_property(self, "rect_global_position", _position, 0.1)	

func move_along(_card : Card):
	rect_global_position = _card.rect_global_position + Vector2.DOWN * Globals.OFFSET
	if lower_card != null:
		lower_card.move_along(self)

func go_back():
	get_parent().slots[dragged_from].add_card(self, drag_start_position + Vector2(50, 50))


func _on_Return_to_stack():
	set_state(State.DRAWN, current_state)
	emit_signal("move_ended")
	
func _on_Move_to_ended():
	move_stack()
	if is_in_play:
		set_state(State.IDLE, current_state)
	else:
		set_state(State.DRAWN, current_state)
	emit_signal("move_ended")
	
func _on_Card_gui_input(event):
	if get_parent().can_move == false:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == BUTTON_LEFT:
			match current_state:
				State.IDLE, State.DRAWN:
					set_process(true)
					drag_start_time = Time.get_ticks_msec()
					click_position = event.position
					click_global_position = event.global_position
					drag_start_position = rect_global_position
					set_state(State.CLICKED, current_state)

					
				State.IN_DECK:
					$CardOuter.texture = load(texture_path)
					move_to_pool()
	
		if event.pressed and event.button_index == BUTTON_RIGHT:
			if current_state == State.IDLE or current_state == State.DRAWN:
				set_process(false)
				set_state(State.IDLE, current_state)
				drag_start_position = rect_global_position
				create_stack()
				emit_signal("put_on_ace_slot", self, event.global_position)	
						
		if !event.pressed and event.button_index == BUTTON_LEFT:
			match current_state:
				State.DRAGGED:
					emit_signal("dropped", self, event.global_position)
				State.CLICKED:
					set_state(previous_state, current_state)

