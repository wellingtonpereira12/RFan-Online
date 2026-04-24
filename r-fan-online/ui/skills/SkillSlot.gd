extends PanelContainer

@onready var name_label = $HBox/VBox/NameLabel
@onready var desc_label = $HBox/VBox/DescLabel
@onready var info_label = $HBox/VBox/InfoLabel
@onready var icon_rect = $HBox/IconContainer/Icon
@onready var lock_overlay = $LockOverlay
@onready var lock_label = $LockOverlay/LockLabel
@onready var cooldown_overlay = $HBox/IconContainer/CooldownOverlay
@onready var cooldown_label = $CooldownLabel
@onready var xp_bar = $HBox/VBox/XPBar

var skill_data: Dictionary = {}
var is_locked: bool = false

signal skill_right_clicked(data: Dictionary)

func _ready():
	SkillManager.skill_xp_updated.connect(_on_skill_xp_updated)
	SkillManager.skill_leveled_up.connect(_on_skill_leveled_up)

func setup(data: Dictionary):
	skill_data = data
	name_label.text = data["nome"]
	desc_label.text = data["descricao"]
	
	var cost_type = "FP" if data.get("category") == "range" else "SP"
	var cost_val = data.get("custo_fp") if cost_type == "FP" else data.get("custo_sp")
	var range_info = (" | Alc: " + str(data["alcance"]) + "m") if data.has("alcance") else ""
	
	info_label.text = "Dano: %d | %s: %d | CD: %.1fs%s" % [data["dano"], cost_type, cost_val, data["cooldown"], range_info]
	
	# Checa nível
	var player_level = ExperienceManager.current_level
	if player_level < data["nivel_minimo"]:
		is_locked = true
		lock_overlay.visible = true
		lock_label.text = "LEVEL " + str(data["nivel_minimo"])
	else:
		is_locked = false
		lock_overlay.visible = false
	
	_update_level_ui()

func _update_level_ui():
	var status = SkillManager.get_skill_status(skill_data["key"])
	var lv_label = SkillManager.get_level_label(skill_data["key"])
	name_label.text = skill_data["nome"] + " [" + lv_label + "]"
	
	var config = SkillManager.leveling_config["levels"][str(status.level)]
	xp_bar.max_value = config["xp_required"]
	xp_bar.value = status.xp
	
	# Se for GM (level 7), a barra some ou fica cheia
	if status.level >= 7:
		xp_bar.visible = false
	else:
		xp_bar.visible = true

func _on_skill_xp_updated(skill_key: String, current_xp: int, required_xp: int):
	if skill_data.get("key") == skill_key:
		xp_bar.max_value = required_xp
		xp_bar.value = current_xp

func _on_skill_leveled_up(skill_key: String, new_level: int):
	if skill_data.get("key") == skill_key:
		_update_level_ui()

func _get_drag_data(_at_position):
	if is_locked: return null
	
	var drag_preview = Control.new()
	var icon = ColorRect.new()
	icon.size = Vector2(40, 40)
	icon.color = Color(0.8, 0.2, 0.2, 0.8)
	drag_preview.add_child(icon)
	set_drag_preview(drag_preview)
	
	return {
		"type": "skill",
		"skill_key": skill_data["key"],
		"skill_data": skill_data
	}

func _gui_input(event: InputEvent) -> void:
	if is_locked: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		skill_right_clicked.emit(skill_data)

func _process(_delta: float) -> void:
	if skill_data.is_empty() or is_locked: return
	
	# Busca o CombatComponent do jogador para checar cooldowns globais
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		var combat = players[0].get_node_or_null("CombatComponent")
		if combat and combat.global_cooldowns.has(skill_data["key"]):
			var end_time = combat.global_cooldowns[skill_data["key"]]
			var remaining_ms = end_time - Time.get_ticks_msec()
			var remaining_sec = remaining_ms / 1000.0
			
			if remaining_sec > 0:
				cooldown_overlay.visible = true
				cooldown_label.visible = true
				cooldown_label.text = str(snapped(remaining_sec, 0.1)) + "s"
				
				# Animação de preenchimento (estilo RF, de baixo para cima)
				# 0.0 = cheio, 1.0 = vazio
				cooldown_overlay.anchor_top = 1.0 - (remaining_sec / skill_data["cooldown"])
			else:
				cooldown_overlay.visible = false
				cooldown_label.visible = false
		else:
			cooldown_overlay.visible = false
			cooldown_label.visible = false
