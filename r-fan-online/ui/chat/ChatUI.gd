extends Control

@onready var message_list = $Background/VBox/Scroll/MessageList
@onready var input_field = $Background/VBox/InputRow/LineEdit
@onready var channel_btn = $Background/VBox/InputRow/ChannelBtn
@onready var send_btn = $Background/VBox/InputRow/SendBtn
@onready var input_row = $Background/VBox/InputRow
@onready var close_btn = $Background/VBox/InputRow/CloseBtn
@onready var resize_handle = $Background/ResizeHandle
@onready var background = $Background
@onready var settings_btn = $Background/SettingsBtn
@onready var settings_panel = $SettingsPanel
@onready var check_local = $SettingsPanel/VBox/CheckLocal
@onready var check_global = $SettingsPanel/VBox/CheckGlobal
@onready var check_sistema = $SettingsPanel/VBox/CheckSistema

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
	close_btn.pressed.connect(_hide_input)
	# Conecta ao ChatManager global
	ChatManager.message_received.connect(_on_message_received)
	
	input_row.visible = false # Esconde o input por padrão
	
	_load_history()
	_update_channel_ui()
	
	# Conecta sinais para redimensionar
	resize_handle.button_down.connect(func(): is_resizing = true)
	resize_handle.button_up.connect(func(): is_resizing = false)
	
	# Conecta sinal para mover a janela clicando no fundo
	background.gui_input.connect(_on_bg_input)
	
	# Configurações de Filtro
	settings_btn.pressed.connect(func(): settings_panel.visible = !settings_panel.visible)
	check_local.toggled.connect(func(_v): _refresh_chat())
	check_global.toggled.connect(func(_v): _refresh_chat())
	check_sistema.toggled.connect(func(_v): _refresh_chat())
	
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
	_refresh_chat()

func _refresh_chat():
	message_list.clear()
	message_list.append_text("[color=#888]--- Filtros Aplicados ---[/color]")
	
	for msg in ChatManager.chat_history:
		_add_message_to_list(msg, true)

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
	_hide_input()

func _show_input():
	input_row.visible = true
	input_field.grab_focus()

func _hide_input():
	input_row.visible = false
	input_field.release_focus()


func _on_message_received(data: Dictionary):
	_add_message_to_list(data)

func _add_message_to_list(data: Dictionary, is_refresh: bool = false):
	# 1. Filtro de Raça (Segurança Extra)
	if data["race"] != GameManager.player_race:
		return
		
	# 2. Filtro de Canais do Usuário
	var is_system = data["sender"] == "SISTEMA"
	
	if is_system and not check_sistema.button_pressed: return
	if not is_system:
		if data["channel"] == ChatManager.Channel.GLOBAL and not check_global.button_pressed: return
		if data["channel"] == ChatManager.Channel.LOCAL and not check_local.button_pressed: return
	
	# Exibe
	var race_color = ChatManager.RACE_COLORS.get(data["race"], "#ffffff")
	var channel_tag = "[G]" if data["channel"] == ChatManager.Channel.GLOBAL else "[L]"
	if is_system: channel_tag = "[S]"
	
	var formatted_msg = "\n[color=#888]" + channel_tag + "[/color] [color=" + race_color + "][b]" + data["sender"] + "[/b][/color]: " + data["text"]
	message_list.append_text(formatted_msg)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Só abre o chat se o T for pressionado e NENHUM input estiver focado
		var focus_owner = get_viewport().gui_get_focus_owner()
		if event.keycode == KEY_T and not (focus_owner is LineEdit):
			_show_input()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and input_row.visible:
			_hide_input()
			get_viewport().set_input_as_handled()
