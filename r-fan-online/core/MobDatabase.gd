extends Node
class_name MobDatabaseClass

# Caminho do JSON externo — edite sem precisar reiniciar o jogo!
const DB_PATH = "res://database/mobs.json"

var MOBS: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	MOBS.clear()
	if not FileAccess.file_exists(DB_PATH):
		printerr("[MobDatabase] ERRO: Arquivo não encontrado: ", DB_PATH)
		return

	var file = FileAccess.open(DB_PATH, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(content)
	if err != OK:
		printerr("[MobDatabase] ERRO ao parsear JSON: linha ", json.get_error_line(), " - ", json.get_error_message())
		return

	MOBS = json.data
	print("[MobDatabase] Banco de dados recarregado com sucesso! ", MOBS.size(), " mobs prontos.")
	if MOBS.has("bellato_guard"):
		print("[MobDatabase] DEBUG: HP do Guardião Bellato no JSON atual: ", MOBS["bellato_guard"]["hp"])

func get_mob(key: String) -> Dictionary:
	if MOBS.has(key):
		return MOBS[key].duplicate(true)

	printerr("[MobDatabase] ERRO: Mob não cadastrado no banco de dados -> '", key, "'")
	return {}
