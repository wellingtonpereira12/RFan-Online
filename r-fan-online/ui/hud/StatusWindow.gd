extends PanelContainer

@onready var hp_label = $VBox/Scroll/Content/Resources/HP
@onready var hp_bar = $VBox/Scroll/Content/Resources/HPBar
@onready var sp_label = $VBox/Scroll/Content/Resources/SP
@onready var sp_bar = $VBox/Scroll/Content/Resources/SPBar
@onready var fp_label = $VBox/Scroll/Content/Resources/FP
@onready var fp_bar = $VBox/Scroll/Content/Resources/FPBar

@onready var atk_label = $VBox/Scroll/Content/Combat/Atk
@onready var def_label = $VBox/Scroll/Content/Combat/Def
@onready var block_label = $VBox/Scroll/Content/Combat/Block

@onready var ms_label = $VBox/Scroll/Content/Movement/MS
@onready var as_label = $VBox/Scroll/Content/Movement/AS

@onready var acc_label = $VBox/Scroll/Content/Accuracy/Acc
@onready var dodge_label = $VBox/Scroll/Content/Accuracy/Dodge
@onready var debuff_label = $VBox/Scroll/Content/Accuracy/Debuff

@onready var fire_label = $VBox/Scroll/Content/Elemental/Fire
@onready var water_label = $VBox/Scroll/Content/Elemental/Water
@onready var earth_label = $VBox/Scroll/Content/Elemental/Earth
@onready var wind_label = $VBox/Scroll/Content/Elemental/Wind

@onready var close_btn = $VBox/Footer/CloseBtn

# Variáveis para arrastar a janela
var dragging = false
var drag_offset = Vector2.ZERO

func _ready():
	close_btn.pressed.connect(hide)
	StatusManager.status_updated.connect(update_ui)
	
	# Conecta aos sinais do jogador se ele já existir
	_connect_to_player_vitals()
	
	update_ui()
	visible = false

func _connect_to_player_vitals():
	var player = get_tree().get_first_node_in_group("players")
	if player:
		var vitals = player.get_node_or_null("VitalsComponent")
		if vitals:
			if not vitals.hp_changed.is_connected(_on_vitals_changed):
				vitals.hp_changed.connect(func(_curr, _max): _on_vitals_changed())
			if not vitals.sp_changed.is_connected(_on_vitals_changed):
				vitals.sp_changed.connect(func(_curr, _max): _on_vitals_changed())
			if not vitals.fp_changed.is_connected(_on_vitals_changed):
				vitals.fp_changed.connect(func(_curr, _max): _on_vitals_changed())

func _on_vitals_changed():
	if visible:
		update_ui()

func toggle():
	visible = !visible
	if visible:
		_connect_to_player_vitals()
		StatusManager.calculate_status()
		update_ui()
		move_to_front()

func _input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"): # ESC por padrão
		hide()
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = get_global_mouse_position() - global_position
		else:
			dragging = false
	
	if event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset

func update_ui():
	var stats = StatusManager.get_total_status()
	
	var player = get_tree().get_first_node_in_group("players")
	var current_hp = stats["hp"]
	var current_sp = stats["sp"]
	var current_fp = stats["fp"]
	
	if player:
		var vitals = player.get_node_or_null("VitalsComponent")
		if vitals:
			current_hp = vitals.hp
			current_sp = vitals.sp
			current_fp = vitals.fp
	
	hp_label.text = "HP: %d / %d" % [current_hp, stats["hp"]]
	hp_bar.max_value = stats["hp"]
	hp_bar.value = current_hp
	
	sp_label.text = "SP: %d / %d" % [current_sp, stats["sp"]]
	sp_bar.max_value = stats["sp"]
	sp_bar.value = current_sp
	
	fp_label.text = "FP: %d / %d" % [current_fp, stats["fp"]]
	fp_bar.max_value = stats["fp"]
	fp_bar.value = current_fp
	
	atk_label.text = "Ataque Total: %d" % stats["ataque"]
	def_label.text = "Defesa Total: %d" % stats["defesa"]
	block_label.text = "Chance de Bloqueio: %d%%" % stats["block"]
	
	ms_label.text = "Vel. Movimento: %.1f" % stats["move_speed"]
	as_label.text = "Vel. Ataque: %.1f" % stats["attack_speed"]
	
	acc_label.text = "Chance de Acerto: %d%%" % stats["accuracy"]
	dodge_label.text = "Chance de Esquiva: %d%%" % stats["dodge"]
	debuff_label.text = "Resist. Debuff: %d%%" % stats["debuff_resist"]
	
	fire_label.text = "Fogo: %d" % stats["elemental"]["fire"]
	water_label.text = "Água: %d" % stats["elemental"]["water"]
	earth_label.text = "Terra: %d" % stats["elemental"]["earth"]
	wind_label.text = "Vento: %d" % stats["elemental"]["wind"]
