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
	player.set_in_combat()
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
	
	# --- CÁLCULO DE ACERTO / EVASÃO ---
	var my_stats = StatusManager.get_total_status()
	var target_stats = {} # Mobs podem ter stats simplificados ou vir de um StatusManager se forem players
	if target.has_method("get_stats"): 
		target_stats = target.get_stats()
	else:
		# Fallback para mobs simples
		target_stats = {"dodge": 5, "block": 5, "defesa": 10}

	# 1. Chance de Acerto (Accuracy vs Dodge)
	var hit_chance = my_stats["accuracy"] - target_stats["dodge"]
	if randf_range(0, 100) > hit_chance:
		DamageTextManager.display_damage(0, DamageTextManager.DamageType.MISS, target.global_position)
		_send_system_msg("[color=gray]Você errou o golpe![/color]")
		return

	# 2. Chance de Bloqueio (Shield Block)
	if randf_range(0, 100) < target_stats["block"]:
		DamageTextManager.display_damage(0, DamageTextManager.DamageType.BLOCK, target.global_position)
		_send_system_msg("[color=blue]O alvo bloqueou o ataque![/color]")
		return

	# 3. Cálculo de Dano Base
	var base_dmg = StatusManager.get_total_status()["ataque"]
	var skill_mult = SkillManager.get_damage_multiplier(skill["key"])
	var raw_dmg = (base_dmg + skill["dano"]) * skill_mult
	
	# Redução de Defesa
	var final_dmg = int(max(1, raw_dmg - target_stats["defesa"]))
	
	# 4. Chance de Crítico (Fixo 10% por enquanto, ou vindo de stats)
	var is_crit = randf_range(0, 100) < 10.0
	var damage_type = DamageTextManager.DamageType.DEALT
	
	if is_crit:
		final_dmg = int(final_dmg * 1.5)
		damage_type = DamageTextManager.DamageType.CRITICAL

	# APLICAÇÃO FINAL
	if is_instance_valid(target):
		var target_vitals = target.get_node_or_null("VitalsComponent")
		if not target_vitals: target_vitals = target.get_node_or_null("HealthComponent")
		
		if target_vitals:
			target_vitals.take_damage(final_dmg, damage_type)
			SkillManager.add_xp(skill["key"])

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
