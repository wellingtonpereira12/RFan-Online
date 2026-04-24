extends CanvasLayer
class_name HUD

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar
@onready var sp_bar: ProgressBar = $MarginContainer/VBoxContainer/SPBar
@onready var fp_bar: ProgressBar = $MarginContainer/VBoxContainer/FPBar
@onready var exp_bar: ProgressBar = $BottomUI/EXPBottomContainer/EXPBarPremium
@onready var exp_label: Label = $BottomUI/EXPBottomContainer/EXPLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/CombatStatus/LevelLabel
@onready var status_circle: ColorRect = $MarginContainer/VBoxContainer/CombatStatus/StatusCircle
@onready var skill_bar: Control = $BottomUI/SkillBarContainer/SkillBar
@onready var skill_window: Control = $SkillWindow
@onready var settings_menu: Control = $SettingsMenu

@onready var target_frame: PanelContainer = $TargetFrame
@onready var target_hp_bar: ProgressBar = $TargetFrame/VBoxContainer/TargetHPBar
@onready var target_name_label: Label = $TargetFrame/VBoxContainer/TargetName

signal run_toggled(is_running_mode: bool)
signal auto_attack_mode_toggled(is_auto: bool)

var current_target_vitals: Node = null

func _ready() -> void:
	# Conecta os sinais da SkillBar (os botões de correr/auto ficam nela agora)
	skill_bar.run_mode_changed.connect(func(v): run_toggled.emit(v))
	skill_bar.auto_attack_changed.connect(func(v): auto_attack_mode_toggled.emit(v))
	skill_bar.skills_pressed.connect(func(): skill_window.toggle())
	skill_bar.settings_pressed.connect(func(): settings_menu.toggle())

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

func update_exp(current: int, max_val: int) -> void:
	exp_bar.max_value = max_val
	exp_bar.value = current
	
	_update_exp_label(current, max_val)

func _update_exp_label(current, max_val):
	var percent = 0.0
	if max_val > 0:
		percent = (float(current) / float(max_val)) * 100.0
	exp_label.text = str(current) + " / " + str(max_val) + " (" + str(snapped(percent, 0.01)) + "%)"
	level_label.text = str(ExperienceManager.current_level)

var combat_timer_ref: float = 0.0
var blink_alpha: float = 0.0

func _process(delta: float) -> void:
	if combat_timer_ref > 0 and combat_timer_ref <= 5.0:
		blink_alpha += delta * 10.0 # Velocidade do pisca
		status_circle.modulate.a = 0.4 + (sin(blink_alpha) * 0.6 + 0.6) / 2.0
	else:
		status_circle.modulate.a = 1.0

func update_combat_status(in_combat: bool, time_left: float = 0.0) -> void:
	combat_timer_ref = time_left
	if in_combat:
		status_circle.color = Color(1, 0.2, 0.2, 1) # Vermelho Batalha
	else:
		status_circle.color = Color(0, 0.5, 1, 1) # Azul Normal
		status_circle.modulate.a = 1.0

# Atualiza a UI quando a lógica interna do Player força a voltar a andar (FP zerada)
func force_walk_mode() -> void:
	var run_btn = skill_bar.get_node_or_null("RunButton")
	if run_btn and run_btn.button_pressed:
		run_btn.button_pressed = false # Isso vai disparar o sinal toggled automaticamente

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

# --- Efeito Visual de Clique do Mouse ---
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if not (focus_owner is LineEdit):
			if event.keycode == KEY_B:
				skill_window.toggle()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		spawn_click_effect(event.position)

func spawn_click_effect(pos: Vector2) -> void:
	var effect = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.9, 1.0, 0.7) # Bolinha meio azulada brilhante (estilo Sci-Fi/RF)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	
	effect.add_theme_stylebox_override("panel", style)
	effect.custom_minimum_size = Vector2(20, 20)
	effect.size = Vector2(20, 20)
	effect.pivot_offset = Vector2(10, 10) # Centro da bolinha para escalar perfeitamente
	effect.position = pos - Vector2(10, 10)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_child(effect)
	
	# Animação da bolinha crescendo e sumindo
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(2.5, 2.5), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(effect, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(effect.queue_free)
