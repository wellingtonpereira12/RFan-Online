extends Control

@onready var background = $Background
@onready var hp_slider = $Background/TabContainer/AutoPotion/Margin/Sections/HPSection/HBox/Slider
@onready var hp_val_label = $Background/TabContainer/AutoPotion/Margin/Sections/HPSection/Header/Value
@onready var hp_slot_panel = $Background/TabContainer/AutoPotion/Margin/Sections/HPSection/HBox/Slot
@onready var hp_bar = $Background/TabContainer/AutoPotion/Margin/Sections/HPSection/ProgressBar
@onready var hp_status_label = $Background/TabContainer/AutoPotion/Margin/Sections/HPSection/ProgressBar/Status

@onready var sp_slider = $Background/TabContainer/AutoPotion/Margin/Sections/SPSection/HBox/Slider
@onready var sp_val_label = $Background/TabContainer/AutoPotion/Margin/Sections/SPSection/Header/Value
@onready var sp_slot_panel = $Background/TabContainer/AutoPotion/Margin/Sections/SPSection/HBox/Slot
@onready var sp_bar = $Background/TabContainer/AutoPotion/Margin/Sections/SPSection/ProgressBar
@onready var sp_status_label = $Background/TabContainer/AutoPotion/Margin/Sections/SPSection/ProgressBar/Status

@onready var fp_slider = $Background/TabContainer/AutoPotion/Margin/Sections/FPSection/HBox/Slider
@onready var fp_val_label = $Background/TabContainer/AutoPotion/Margin/Sections/FPSection/Header/Value
@onready var fp_slot_panel = $Background/TabContainer/AutoPotion/Margin/Sections/FPSection/HBox/Slot
@onready var fp_bar = $Background/TabContainer/AutoPotion/Margin/Sections/FPSection/ProgressBar
@onready var fp_status_label = $Background/TabContainer/AutoPotion/Margin/Sections/FPSection/ProgressBar/Status

var hp_slot: AutoPotSlot
var sp_slot: AutoPotSlot
var fp_slot: AutoPotSlot

var dragging = false
var drag_offset = Vector2.ZERO

func _ready() -> void:
	visible = false
	
	# Importante: O painel pai do slot DEVE ignorar o mouse para o slot (filho) receber o drop
	hp_slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp_slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fp_slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Inicializa os slots
	hp_slot = _setup_slot(hp_slot_panel, "hp")
	sp_slot = _setup_slot(sp_slot_panel, "sp")
	fp_slot = _setup_slot(fp_slot_panel, "fp")
	
	# Conecta sliders
	hp_slider.value_changed.connect(_on_hp_slider_changed)
	sp_slider.value_changed.connect(_on_sp_slider_changed)
	fp_slider.value_changed.connect(_on_fp_slider_changed)
	
	# Inicializa labels
	_on_hp_slider_changed(hp_slider.value)
	_on_sp_slider_changed(sp_slider.value)
	_on_fp_slider_changed(fp_slider.value)
	
	# Conecta sinal do inventário
	var inv = get_tree().get_first_node_in_group("inventory_manager")
	if inv:
		inv.inventory_updated.connect(_on_inventory_updated)
	
	# Ativa o arraste da janela pelo fundo
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.gui_input.connect(_on_background_gui_input)

func _setup_slot(panel: Panel, type: String) -> AutoPotSlot:
	var slot = AutoPotSlot.new()
	slot.pot_type = type
	panel.add_child(slot)
	slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.item_changed.connect(_update_system_config.bind(type))
	return slot

func _on_inventory_updated(_idx: int) -> void:
	if visible:
		if hp_slot: hp_slot._update_amount()
		if sp_slot: sp_slot._update_amount()
		if fp_slot: fp_slot._update_amount()

func _process(_delta: float) -> void:
	if not visible: return
	
	var player = get_tree().get_first_node_in_group("players")
	if player and player.has_node("VitalsComponent"):
		var vitals = player.get_node("VitalsComponent")
		_update_bar(hp_bar, hp_status_label, vitals.hp, vitals.max_hp)
		_update_bar(sp_bar, sp_status_label, vitals.sp, vitals.max_sp)
		_update_bar(fp_bar, fp_status_label, vitals.fp, vitals.max_fp)

func _update_bar(bar: ProgressBar, label: Label, current: int, max_val: int):
	bar.max_value = max_val
	bar.value = current
	label.text = str(current) + " / " + str(max_val)

func _update_system_config(_id: String, type: String) -> void:
	var player = get_tree().get_first_node_in_group("players")
	if not player: return
	var system = player.get_node_or_null("AutoPotionSystem")
	if not system: return
	
	match type:
		"hp": system.set_config("hp", hp_slot.item_id, hp_slider.value / 100.0)
		"sp": system.set_config("sp", sp_slot.item_id, sp_slider.value / 100.0)
		"fp": system.set_config("fp", fp_slot.item_id, fp_slider.value / 100.0)

func _on_hp_slider_changed(value: float) -> void:
	hp_val_label.text = str(int(value)) + "%"
	_update_system_config("", "hp")

func _on_sp_slider_changed(value: float) -> void:
	sp_val_label.text = str(int(value)) + "%"
	_update_system_config("", "sp")

func _on_fp_slider_changed(value: float) -> void:
	fp_val_label.text = str(int(value)) + "%"
	_update_system_config("", "fp")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Y:
			visible = !visible
			if visible:
				_on_inventory_updated(-1)

func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = get_global_mouse_position() - background.global_position
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		background.global_position = get_global_mouse_position() - drag_offset
