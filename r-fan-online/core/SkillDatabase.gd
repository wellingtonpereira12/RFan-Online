extends Node

const MELEE_SKILLS_PATH = "res://database/melee_skills.json"
const RANGED_SKILLS_PATH = "res://database/ranged_skills.json"

var skills: Dictionary = {}

func _ready() -> void:
	_load_skills()

func _load_skills():
	if not FileAccess.file_exists(MELEE_SKILLS_PATH):
		printerr("[SkillDatabase] Erro: melee_skills.json não encontrado!")
		return
		
	var file = FileAccess.open(MELEE_SKILLS_PATH, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(content) == OK:
		var data = json.data
		for skill_info in data["melee_skills"]:
			skill_info["category"] = "melee"
			skills[skill_info["key"]] = skill_info
		print("[SkillDatabase] Habilidades melee carregadas.")
		
	# Carregar Ranged
	if FileAccess.file_exists(RANGED_SKILLS_PATH):
		file = FileAccess.open(RANGED_SKILLS_PATH, FileAccess.READ)
		content = file.get_as_text()
		file.close()
		if json.parse(content) == OK:
			var data = json.data
			for skill_info in data["ranged_skills"]:
				skill_info["category"] = "range"
				skills[skill_info["key"]] = skill_info
			print("[SkillDatabase] Habilidades range carregadas.")
			
	print("[SkillDatabase] Total: ", skills.size(), " habilidades carregadas.")

func get_skill(key: String) -> Dictionary:
	if skills.has(key):
		return skills[key].duplicate()
	return {}

func get_all_skills_by_category(category: String) -> Array:
	var result = []
	for skill in skills.values():
		if skill["category"] == category:
			result.append(skill)
	return result
