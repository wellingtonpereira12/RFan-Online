extends CanvasLayer
class_name HUD

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar
@onready var sp_bar: ProgressBar = $MarginContainer/VBoxContainer/SPBar
@onready var fp_bar: ProgressBar = $MarginContainer/VBoxContainer/FPBar
@onready var run_button: Button = $RunButton
@onready var auto_button: Button = $AutoAttackButton

@onready var target_frame: PanelContainer = $TargetFrame
@onready var target_hp_bar: ProgressBar = $TargetFrame/VBoxContainer/TargetHPBar
@onready var target_name_label: Label = $TargetFrame/VBoxContainer/TargetName

signal run_toggled(is_running_mode: bool)
signal auto_attack_mode_toggled(is_auto: bool)

var is_running_state: bool = false
var is_auto_attack_mode: bool = false
var current_target_vitals: Node = null

func _ready() -> void:
	run_button.pressed.connect(_on_run_button_pressed)
	auto_button.pressed.connect(_on_auto_button_pressed)
	_update_button_text()

# Atualizadores das Barras
func update_hp(current: int, max_val: int) -> void:
	hp_bar.max_value = max_val
	hp_bar.value = current

func update_sp(current: int, max_val: int) -> void:
	sp_bar.max_value = max_val
	sp_bar.value = current

func update_fp(current: int, max_val: int) -> void:
	fp_bar.max_value = max_val
	fp_bar.value = current

# Atualiza a UI quando a lógica interna do Player força a voltar a andar
func force_walk_mode() -> void:
	if is_running_state:
		is_running_state = false
		_update_button_text()

func _on_run_button_pressed() -> void:
	run_button.release_focus()
	is_running_state = !is_running_state
	_update_button_text()
	run_toggled.emit(is_running_state)

func _on_auto_button_pressed() -> void:
	auto_button.release_focus()
	is_auto_attack_mode = !is_auto_attack_mode
	_update_button_text()
	auto_attack_mode_toggled.emit(is_auto_attack_mode)

func _update_button_text() -> void:
	if is_running_state:
		run_button.text = "Modo: CORRENDO"
	else:
		run_button.text = "Modo: ANDANDO"
		
	if is_auto_attack_mode:
		auto_button.text = "Ataque: AUTO"
	else:
		auto_button.text = "Ataque: MANUAL"

# --- Sistema de Target HUD ---
func bind_target(enemy_node: Node) -> void:
	unbind_target()
	if enemy_node and enemy_node.has_node("VitalsComponent"):
		target_frame.visible = true
		target_name_label.text = enemy_node.name
		current_target_vitals = enemy_node.get_node("VitalsComponent")
		current_target_vitals.hp_changed.connect(_on_target_hp_changed)
		current_target_vitals.died.connect(unbind_target)
		_on_target_hp_changed(current_target_vitals.hp, current_target_vitals.max_hp)

func unbind_target() -> void:
	target_frame.visible = false
	if current_target_vitals:
		if current_target_vitals.hp_changed.is_connected(_on_target_hp_changed):
			current_target_vitals.hp_changed.disconnect(_on_target_hp_changed)
		if current_target_vitals.died.is_connected(unbind_target):
			current_target_vitals.died.disconnect(unbind_target)
		current_target_vitals = null

func _on_target_hp_changed(current: int, max_val: int) -> void:
	target_hp_bar.max_value = max_val
	target_hp_bar.value = current
