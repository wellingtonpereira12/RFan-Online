extends Node

var config: Dictionary = {
	"min": 1.0,
	"max": 7.0,
	"step": 0.1
}

var current_speed_value: float = 1.0

func _ready():
	_load_config()

func _load_config():
	var path = "res://database/movement_speed.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		config = JSON.parse_string(file.get_as_text())
		print("[MovementSpeed] Configurações carregadas.")

func set_speed(value: float):
	# Validar limites
	current_speed_value = clampf(value, config["min"], config["max"])
	
	# Arredondar para o step (0.1)
	current_speed_value = snappedf(current_speed_value, config["step"])
	
	# Notificar sistemas (Player e UI)
	var player = get_tree().get_first_node_in_group("players")
	if player and player.has_method("update_movement_speed"):
		player.update_movement_speed()
	
	# Forçar atualização na janela de status se estiver aberta
	var status_window = get_tree().get_first_node_in_group("status_window")
	if status_window and status_window.visible:
		status_window.update_ui()
	
	print("[MovementSpeed] Velocidade ajustada para: ", current_speed_value, " (+", get_bonus_percent(current_speed_value), "%)")
	return current_speed_value

func get_speed() -> float:
	return current_speed_value

func get_bonus_percent(value: float) -> int:
	# Fórmula: (valor - 1.0) * 10
	# Ex: 3.0 -> (3.0 - 1.0) * 10 = 20%
	return int((value - 1.0) * 10.0)
