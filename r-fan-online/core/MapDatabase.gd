extends Node

var _maps_data: Dictionary = {}

func _ready():
	_load_database()

func _load_database():
	var file_path = "res://database/maps.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		
		if parse_result == OK:
			_maps_data = json.data
			print("[MapDatabase] Banco de dados de mapas carregado com sucesso.")
		else:
			print("[MapDatabase] Erro ao processar JSON: ", json.get_error_message())
	else:
		print("[MapDatabase] Erro: Arquivo não encontrado em ", file_path)

func get_map(map_id: String) -> Dictionary:
	if _maps_data.has(map_id):
		return _maps_data[map_id]
	return {}

func get_all_maps() -> Dictionary:
	return _maps_data
