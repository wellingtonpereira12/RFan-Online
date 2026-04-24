extends Node

const MELEE_SKILLS_PATH = "res://database/melee_skills.json"
const RANGED_SKILLS_PATH = "res://database/ranged_skills.json"
const FORCE_SKILLS_PATH = "res://database/force_skills.json"

var skills: Dictionary = {}

func _ready() -> void:
	_load_all_skills()

func _load_all_skills():
	skills.clear()
	_load_file(MELEE_SKILLS_PATH, "melee_skills", "melee")
	_load_file(RANGED_SKILLS_PATH, "ranged_skills", "range")
	_load_file(FORCE_SKILLS_PATH, "force_skills", "force")
	print("[SkillDatabase] Total: ", skills.size(), " habilidades carregadas.")

func _load_file(path: String, root_key: String, category: String):
	if not FileAccess.file_exists(path): return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(content) == OK:
		var data = json.data
		if data.has(root_key):
			for skill_info in data[root_key]:
				skill_info["category"] = category
				# Garantir que skills melee e range tenham tipo 'none' ou similar se necessário
				if not skill_info.has("tipo"):
					skill_info["tipo"] = "physical"
				skills[skill_info["key"]] = skill_info
			print("[SkillDatabase] Categoria '", category, "' carregada.")

func get_skill(key: String) -> Dictionary:
	return skills.get(key, {})

func get_all_skills_by_category(category: String) -> Array:
	var result = []
	for skill in skills.values():
		if skill["category"] == category:
			result.append(skill)
	return result

func get_skills_by_category_and_type(category: String, type: String) -> Array:
	var result = []
	for skill in skills.values():
		if skill["category"] == category and skill["tipo"] == type:
			result.append(skill)
	return result

func reload():
	_load_all_skills()
