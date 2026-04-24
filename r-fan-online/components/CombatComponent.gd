extends Node
class_name CombatComponent

@onready var vitals: VitalsComponent = $"../VitalsComponent"
@onready var player = get_parent()

# Cooldowns Globais por Key da Skill
var global_cooldowns: Dictionary = {}

func process_action(slot_index: int, action_data, skill_bar) -> void:
	if action_data == null:
		return

	# 1. Processamento de Itens (Poções)
	if typeof(action_data) == TYPE_DICTIONARY and action_data.get("tipo", "") == "potion":
		var inv_manager = get_tree().get_first_node_in_group("inventory_manager")
		if inv_manager and inv_manager.has_method("consume_item_by_id"):
			if inv_manager.consume_item_by_id(action_data["id"], 1):
				_apply_potion_effect(action_data)
				var cd_sec = action_data.get("cooldown_ms", 1000) / 1000.0
				if skill_bar and skill_bar.has_method("trigger_cooldown"):
					skill_bar.trigger_cooldown(slot_index, cd_sec)
			else:
				_send_system_msg("Você não tem mais " + action_data["nome"] + "!")
		return

	# 2. Processamento de Habilidades (Skills do SkillDatabase)
	if typeof(action_data) == TYPE_DICTIONARY and action_data.has("category"):
		_handle_skill_usage(slot_index, action_data, skill_bar)
		return

func _apply_potion_effect(data: Dictionary):
	if data["efeito"] == "hp" or data["efeito"] == "hp_sp":
		vitals.hp = clampi(vitals.hp + data["valor"], 0, vitals.max_hp)
		vitals.hp_changed.emit(vitals.hp, vitals.max_hp)
	if data["efeito"] == "sp" or data["efeito"] == "hp_sp":
		vitals.sp = clampi(vitals.sp + data["valor"], 0, vitals.max_sp)
		vitals.sp_changed.emit(vitals.sp, vitals.max_sp)
	if data["efeito"] == "fp":
		vitals.fp = clampi(vitals.fp + data["valor"], 0, vitals.max_fp)
		vitals.fp_changed.emit(vitals.fp, vitals.max_fp)
	_send_system_msg("Você usou [color=cyan]" + data["nome"] + "[/color].")

func _handle_skill_usage(slot_index: int, skill: Dictionary, skill_bar):
	# Validação de Cooldown Global
	var skill_key = skill["key"]
	if global_cooldowns.has(skill_key):
		var remaining = (global_cooldowns[skill_key] - Time.get_ticks_msec()) / 1000.0
		if remaining > 0:
			_send_system_msg("Habilidade em espera... (" + str(snapped(remaining, 0.1)) + "s)")
			return

	# Validação de Nível
	if ExperienceManager.current_level < skill["nivel_minimo"]:
		_send_system_msg("[color=red]Nível insuficiente[/color] para usar " + skill["nome"])
		return

	# Validação de Recurso (Melee: SP, Range: FP)
	var is_range = skill["category"] == "range"
	if is_range:
		if vitals.fp < skill["custo_fp"]:
			_send_system_msg("[color=red]FP insuficiente[/color] para usar " + skill["nome"])
			return
	else:
		if vitals.sp < skill["custo_sp"]:
			_send_system_msg("[color=red]SP insuficiente[/color] para usar " + skill["nome"])
			return

	# Validação de Alvo
	var target = player.current_target
	if not target:
		_send_system_msg("Selecione um alvo primeiro!")
		return

	var dist = player.global_position.distance_to(target.global_position)
	var max_range = skill.get("alcance", 3.5)
	
	if dist > max_range:
		_send_system_msg("[color=yellow]Alvo fora de alcance![/color] (Dist: " + str(int(dist)) + "m / Max: " + str(int(max_range)) + "m)")
		return

	# EXECUÇÃO COM SUCESSO
	# Registrar Cooldown Global
	global_cooldowns[skill["key"]] = Time.get_ticks_msec() + (skill["cooldown"] * 1000)

	if is_range:
		vitals.consume_fp(skill["custo_fp"])
	else:
		vitals.consume_sp(skill["custo_sp"])
		
	# Sincroniza Cooldown na Barra de Skills (se houver o método)
	if skill_bar:
		# Se usou via Hotbar, o slot_index é válido. 
		# Se usou via Janela, precisamos varrer a barra pra achar onde essa skill está e ativar o CD visual.
		if slot_index != -1:
			skill_bar.trigger_cooldown(slot_index, skill["cooldown"])
		else:
			_sync_bar_cooldowns(skill["key"], skill["cooldown"], skill_bar)
	
	_send_system_msg("Você usou [color=orange]" + skill["nome"] + "[/color]!")
	
	# Delay curto para "viagem" do golpe
	if is_range:
		await get_tree().create_timer(0.2).timeout
	
	# Cálculo de Dano
	var base_dmg = 10
	if player.class_stats:
		base_dmg = player.class_stats.base_physical_attack
		
	var final_dmg = int(base_dmg + skill["dano"])
	
	if is_instance_valid(target) and target.has_node("VitalsComponent"):
		target.get_node("VitalsComponent").take_damage(final_dmg)
		print("=> SKILL (", skill["category"], "): ", skill["nome"], " causou ", final_dmg, " de dano.")

func use_skill_directly(skill_data: Dictionary):
	var skill_bar = get_tree().get_first_node_in_group("skill_bar")
	_handle_skill_usage(-1, skill_data, skill_bar)

func _sync_bar_cooldowns(skill_key: String, duration: float, skill_bar):
	if not skill_bar or not skill_bar.has_method("trigger_cooldown"): return
	for i in range(skill_bar.slots.size()):
		var slot = skill_bar.slots[i]
		if slot.action_data and typeof(slot.action_data) == TYPE_DICTIONARY:
			if slot.action_data.get("key") == skill_key:
				skill_bar.trigger_cooldown(i + 1, duration)

func _send_system_msg(text: String):
	ChatManager.receive_message({
		"sender": "SISTEMA",
		"text": text,
		"race": GameManager.player_race,
		"channel": ChatManager.Channel.LOCAL
	})
