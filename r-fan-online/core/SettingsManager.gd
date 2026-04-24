extends Node

const SETTINGS_PATH = "res://database/settings.json"

var settings: Dictionary = {
	"fullscreen": true,
	"resolution": "1920x1080",
	"volume_music": 80,
	"volume_effects": 70
}

func _ready():
	load_settings()
	apply_settings()

func load_settings():
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_text) == OK:
			settings = json.data
			print("[Settings] Configurações carregadas.")

func save_settings():
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()
		print("[Settings] Configurações salvas.")

func apply_settings():
	# Aplicar Modo de Tela
	if settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# Aplicar Resolução (Apenas se não estiver em Fullscreen ou se o SO permitir redimensionar)
	var res_parts = settings["resolution"].split("x")
	if res_parts.size() == 2:
		var w = int(res_parts[0])
		var h = int(res_parts[1])
		DisplayServer.window_set_size(Vector2i(w, h))
		
	# Aplicar Áudio (Futuro: Conectar aos barramentos do AudioServer)
	# AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(settings["volume_music"] / 100.0))
	# AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(settings["volume_effects"] / 100.0))
