extends Node

# Permanece nativo e flutuando por todas as cenas (AutoLoad Singleton)
var player_name: String = "oi"
var player_race: String = "Bellato"
var player_class: String = "Warrior"

var current_map_id: String = "novus_hq"
var current_map_name: String = "Quartel General Novus"

func _ready():
	# Para testes rápidos, cada instância terá um número único
	if player_name == "oi":
		randomize()
		player_name = "oi_" + str(randi() % 99)
	print("[GameManager] Logado como: ", player_name)

# Atalhos de compatibilidade com código antigo
func get_character_summary() -> String:
	return "[%s] %s — %s" % [player_race, player_name, player_class]
