extends Node

# Permanece nativo e flutuando por todas as cenas (AutoLoad Singleton)
var player_name: String = ""
var player_race: String = ""
var player_class: String = ""

# Atalhos de compatibilidade com código antigo
func get_character_summary() -> String:
	return "[%s] %s — %s" % [player_race, player_name, player_class]
