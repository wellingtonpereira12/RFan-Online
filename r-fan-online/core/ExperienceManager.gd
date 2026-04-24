extends Node

signal level_up(new_level: int)
signal exp_changed(current_exp: int, max_exp: int)

const CONFIG_PATH = "res://database/exp_config.json"
const MAX_LEVEL = 50

var current_level: int = 1
var current_exp: int = 0
var max_exp: int = 100

var exp_table: Dictionary = {}

func _ready() -> void:
	_load_config()

func _load_config():
	if not FileAccess.file_exists(CONFIG_PATH):
		printerr("[ExperienceManager] Erro: exp_config.json não encontrado!")
		return
		
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(content) == OK:
		var data = json.data
		for level_info in data["levels"]:
			exp_table[int(level_info["level"])] = int(level_info["exp_necessaria"])
		print("[ExperienceManager] Tabela de XP carregada.")

func setup_player(level: int, exp: int):
	current_level = level
	current_exp = exp
	max_exp = get_exp_required_for_level(current_level)
	exp_changed.emit(current_exp, max_exp)

func set_level(level: int):
	current_level = clamp(level, 1, MAX_LEVEL)
	current_exp = 0 # Resetar XP ao definir nível manualmente
	max_exp = get_exp_required_for_level(current_level)
	
	exp_changed.emit(current_exp, max_exp)
	level_up.emit(current_level)
	print("[ExperienceManager] Level definido via admin para: ", current_level)

func add_exp(amount: int):
	if current_level >= MAX_LEVEL:
		return
		
	current_exp += amount
	print("[XP] Ganhou ", amount, " XP. Total: ", current_exp, "/", max_exp)
	
	_check_level_up()
	exp_changed.emit(current_exp, max_exp)

func _check_level_up():
	while current_exp >= max_exp and current_level < MAX_LEVEL:
		current_exp -= max_exp
		current_level += 1
		max_exp = get_exp_required_for_level(current_level)
		
		level_up.emit(current_level)
		print("[Level Up] Parabéns! Agora você é level ", current_level)
		
		# Se atingiu o level máximo, limpa o XP excedente
		if current_level >= MAX_LEVEL:
			current_exp = 0
			break

func get_exp_required_for_level(level: int) -> int:
	return exp_table.get(level, 999999)

func get_data_to_save() -> Dictionary:
	return {
		"level": current_level,
		"exp": current_exp
	}
