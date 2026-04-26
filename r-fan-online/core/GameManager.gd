extends Node

# Permanece nativo e flutuando por todas as cenas (AutoLoad Singleton)
var player_name: String = "oi"
var player_race: String = "Bellato"
var player_class: String = "Warrior"

var current_map_id: String = "novus_hq"
var current_map_name: String = "Quartel General Novus"
var is_safe_zone: bool = false

func _ready():
	# Para testes rápidos, cada instância terá um número único
	if player_name == "oi":
		randomize()
		player_name = "oi_" + str(randi() % 99)
	print("[GameManager] Logado como: ", player_name)

# Atalhos de compatibilidade com código antigo
func get_character_summary() -> String:
	return "[%s] %s — %s" % [player_race, player_name, player_class]

func update_map_status(map_id: String):
	current_map_id = map_id
	var map_data = MapDatabase.get_map(map_id)
	if not map_data.is_empty():
		current_map_name = map_data.get("nome", map_id)
		is_safe_zone = map_data.get("safe_zone", false)
		print("[GameManager] Mapa atualizado: ", current_map_name, " | SafeZone: ", is_safe_zone)
