extends Node

# Estrutura: { "skill_key": { "level": 1, "xp": 0 } }
var player_skills_data: Dictionary = {}
var leveling_config: Dictionary = {}

signal skill_leveled_up(skill_key, new_level)
signal skill_xp_updated(skill_key, current_xp, required_xp)

func _ready():
	_load_config()
	_load_player_skills() # Simulação de carregamento de save

func _load_config():
	var file_path = "res://database/skill_leveling_config.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		leveling_config = JSON.parse_string(file.get_as_text())
		print("[SkillManager] Config de níveis carregada.")

func _load_player_skills():
	# Futuramente carregar de um save.json
	# Inicializa com dados vazios por enquanto
	pass

func get_skill_status(skill_key: String) -> Dictionary:
	if not player_skills_data.has(skill_key):
		player_skills_data[skill_key] = { "level": 1, "xp": 0 }
	return player_skills_data[skill_key]

func add_xp(skill_key: String):
	var status = get_skill_status(skill_key)
	if status.level >= 7: return # Já é GM
	
	var xp_to_add = leveling_config.get("xp_per_use", 10)
	status.xp += xp_to_add
	
	var level_data = leveling_config["levels"][str(status.level)]
	var required = level_data["xp_required"]
	
	if status.xp >= required:
		status.xp -= required
		status.level += 1
		skill_leveled_up.emit(skill_key, status.level)
		print("[SkillManager] Skill ", skill_key, " subiu para o nível ", status.level)
	
	skill_xp_updated.emit(skill_key, status.xp, required)

func get_damage_multiplier(skill_key: String) -> float:
	var status = get_skill_status(skill_key)
	var level_data = leveling_config["levels"][str(status.level)]
	return level_data.get("damage_mult", 1.0)

func get_level_label(skill_key: String) -> String:
	var status = get_skill_status(skill_key)
	return leveling_config["levels"][str(status.level)]["label"]
