extends Node
class_name CombatComponent

@onready var vitals: VitalsComponent = $"../VitalsComponent"
@onready var player = get_parent()

var equipped_skills: Dictionary = {}
var cooldown_timers: Dictionary = {}

func _process(delta: float) -> void:
	for slot in cooldown_timers.keys():
		if cooldown_timers[slot] > 0:
			cooldown_timers[slot] -= delta
			if cooldown_timers[slot] < 0:
				cooldown_timers[slot] = 0.0

func register_skill(slot: int, skill: SkillResource) -> void:
	equipped_skills[slot] = skill
	cooldown_timers[slot] = 0.0

func try_cast_skill(slot: int) -> void:
	if not equipped_skills.has(slot): 
		return
		
	var skill: SkillResource = equipped_skills[slot]
	
	if cooldown_timers[slot] > 0:
		print("Skill [", skill.skill_name, "] em recarga: ", snapped(cooldown_timers[slot], 0.1), "s")
		return
		
	if vitals.sp < skill.sp_cost:
		print("SP Insuficiente para ", skill.skill_name)
		return
		
	var target = player.current_target
	if not target:
		print("Selecione um alvo para a Skill!")
		return
		
	var dist = player.global_position.distance_to(target.global_position)
	if dist > skill.skill_range:
		print("Alvo muito longe! Max: ", skill.skill_range, "m")
		return
		
	# Sucesso no Cast
	vitals.consume_sp(skill.sp_cost)
	cooldown_timers[slot] = skill.cooldown
	
	# Aplica Dano
	var base_dmg = player.class_stats.base_physical_attack
	var final_dmg = int(base_dmg * skill.damage_multiplier)
	print("=> [", skill.skill_name, "] atinge violentamente ", target.name, " causando ", final_dmg, " DANO!")
	
	if target.has_node("VitalsComponent"):
		target.get_node("VitalsComponent").take_damage(final_dmg)
