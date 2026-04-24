extends Control

@onready var message_list = $Background/VBox/Scroll/MessageList
@onready var input_field = $Background/VBox/InputRow/LineEdit
@onready var channel_btn = $Background/VBox/InputRow/ChannelBtn
@onready var send_btn = $Background/VBox/InputRow/SendBtn
@onready var resize_handle = $Background/ResizeHandle
@onready var background = $Background

var current_channel = ChatManager.Channel.GLOBAL

# Variáveis para Redimensionamento e Movimentação
var is_resizing = false
var is_dragging = false
var drag_offset = Vector2.ZERO
var min_size = Vector2(250, 150)
var max_size = Vector2(600, 500)

func _ready() -> void:
	input_field.text_submitted.connect(_on_text_submitted)
	send_btn.pressed.connect(func(): _on_text_submitted(input_field.text))
	channel_btn.pressed.connect(_on_toggle_channel)
	# Conecta ao ChatManager global
	ChatManager.message_received.connect(_on_message_received)
	
	_load_history()
	_update_channel_ui()
	
	# Conecta sinais para redimensionar
	resize_handle.button_down.connect(func(): is_resizing = true)
	resize_handle.button_up.connect(func(): is_resizing = false)
	
	# Conecta sinal para mover a janela clicando no fundo
	background.gui_input.connect(_on_bg_input)
	_update_channel_ui()

func _process(_delta: float) -> void:
	if is_resizing:
		var mouse_pos = get_local_mouse_position()
		# Ajusta o tamanho baseado na posição do mouse relativa ao canto superior esquerdo (0,0)
		# Como o handle está no canto inferior direito da janela, o mouse_pos define o novo size
		size.x = clamp(mouse_pos.x, min_size.x, max_size.x)
		size.y = clamp(mouse_pos.y, min_size.y, max_size.y)

func _on_bg_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
		else:
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset

func _on_toggle_channel():
	if current_channel == ChatManager.Channel.GLOBAL:
		current_channel = ChatManager.Channel.LOCAL
	else:
		current_channel = ChatManager.Channel.GLOBAL
	_update_channel_ui()

func _load_history():
	message_list.clear()
	message_list.append_text("[color=#888]--- Chat History Loaded ---[/color]")
	
	for msg in ChatManager.chat_history:
		# Só mostra se for da mesma raça
		if msg["race"] == GameManager.player_race:
			_on_message_received(msg)

func _update_channel_ui():
	if current_channel == ChatManager.Channel.GLOBAL:
		channel_btn.text = "[Glob]"
		channel_btn.modulate = Color(1, 0.8, 0.2)
	else:
		channel_btn.text = "[Loc]"
		channel_btn.modulate = Color(1, 1, 1)

func _on_text_submitted(new_text: String):
	if new_text.strip_edges() == "":
		input_field.release_focus()
		return
	ChatManager.send_message(new_text, current_channel)
	input_field.clear()
	input_field.release_focus()

func _on_message_received(data: Dictionary):
	var race_color = ChatManager.RACE_COLORS.get(data["race"], "#ffffff")
	var channel_tag = "[G]" if data["channel"] == ChatManager.Channel.GLOBAL else "[L]"
	var formatted_msg = "\n[color=#888]" + channel_tag + "[/color] [color=" + race_color + "][b]" + data["sender"] + "[/b][/color]: " + data["text"]
	message_list.append_text(formatted_msg)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not input_field.has_focus():
		input_field.grab_focus()
		get_viewport().set_input_as_handled()
