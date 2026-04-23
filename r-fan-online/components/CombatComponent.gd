extends Node
class_name CombatComponent

@onready var vitals: VitalsComponent = $"../VitalsComponent"
@onready var player = get_parent()

func process_action(slot_index: int, action_data, skill_bar) -> void:
	if action_data == null:
		return

	# Processamento Fake de Itens
	if "skill_name" in action_data and action_data.skill_name == "Pote de HP":
		print("=> [INVENTÁRIO] Usou Poção! +50 HP")
		vitals.hp = clampi(vitals.hp + 50, 0, vitals.max_hp)
		vitals.hp_changed.emit(vitals.hp, vitals.max_hp)
		if skill_bar.has_method("trigger_cooldown_on_slot"):
			skill_bar.trigger_cooldown_on_slot(slot_index, action_data.cooldown)
		elif skill_bar.has_method("trigger_cooldown"):
			skill_bar.trigger_cooldown(slot_index, action_data.cooldown)
		return

	# Processamento de Dano de Magia
	var skill: SkillResource = action_data
	
	if vitals.sp < skill.sp_cost:
		print(">> SP Insuficiente para ", skill.skill_name)
		return
		
	var target = player.current_target
	if not target:
		print(">> Selecione um alvo primeiro!")
		return
		
	var dist = player.global_position.distance_to(target.global_position)
	if dist > skill.skill_range:
		print(">> Alvo longe demais! (Máx: ", skill.skill_range, "m)")
		return
		
	# Sucesso no Cast Clássico
	vitals.consume_sp(skill.sp_cost)
	if skill_bar.has_method("trigger_cooldown_on_slot"):
		skill_bar.trigger_cooldown_on_slot(slot_index, skill.cooldown)
	elif skill_bar.has_method("trigger_cooldown"):
		skill_bar.trigger_cooldown(slot_index, skill.cooldown)
	
	# Aplica Dano Híbrido
	if player.class_stats:
		var base_dmg = player.class_stats.base_physical_attack
		var final_dmg = int(base_dmg * skill.damage_multiplier)
		print("=> [", skill.skill_name, "] rasga ", target.name, " com um acerto crítico de ", final_dmg, " DANO!")
		
		if target.has_node("VitalsComponent"):
			target.get_node("VitalsComponent").take_damage(final_dmg)
