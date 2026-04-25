extends Node

# Permanece nativo e flutuando por todas as cenas (AutoLoad Singleton)
var player_name: String = "oi"
var player_race: String = "Bellato"
var player_class: String = "Warrior"

# Atalhos de compatibilidade com código antigo
func get_character_summary() -> String:
	return "[%s] %s — %s" % [player_race, player_name, player_class]
