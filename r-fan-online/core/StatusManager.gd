extends Node

signal status_updated

var base_stats: Dictionary = {}
var scaling_config: Dictionary = {}
var all_class_configs: Dictionary = {}
var player_class: String = "melee"

var current_total_stats: Dictionary = {}

# Mapeamento de Classes do Jogo -> Arquétipos do JSON
const CLASS_MAPPING = {
	"warrior": "melee",
	"ranger": "range",
	"spiritualist": "spiritualist",
	"specialist": "specialist"
}

func _ready():
	_load_player_data()
	calculate_status()
	if ExperienceManager:
		ExperienceManager.level_up.connect(func(_lv): calculate_status())

func initialize_for_player():
	print("[StatusManager] Inicializando para o jogador...")
	_load_player_data()
	calculate_status()

func _load_player_data():
	# 1. Carrega as configurações globais de classe (Base + Scaling)
	var config_file = "res://database/class_configs.json"
	if FileAccess.file_exists(config_file):
		var file = FileAccess.open(config_file, FileAccess.READ)
		all_class_configs = JSON.parse_string(file.get_as_text())
		print("[StatusManager] Configurações de classe carregadas.")

	# 2. Pega a classe atual do GameManager e traduz para o arquétipo
	var raw_class = GameManager.player_class.to_lower()
	player_class = CLASS_MAPPING.get(raw_class, "melee")
	
	# Aplica os dados da classe
	if all_class_configs.has(player_class):
		base_stats = all_class_configs[player_class]["base"]
		scaling_config = all_class_configs[player_class]["scaling"]
		print("[StatusManager] Sincronizado: Classe ", raw_class, " -> Arquétipo ", player_class)
	else:
		print("[StatusManager] Erro: Arquétipo '", player_class, "' não encontrado!")

func calculate_status():
	# 1. Começa com a Base (que pode escalar com o Level)
	var lv = 1
	if ExperienceManager: lv = ExperienceManager.current_level
	
	current_total_stats = base_stats.duplicate(true)
	
	# Escalonamento Dinâmico baseado no JSON
	for stat_key in scaling_config:
		if current_total_stats.has(stat_key):
			current_total_stats[stat_key] += (lv - 1) * scaling_config[stat_key]
	
	# 2. Somar Bônus de Equipamentos
	_apply_equipment_bonuses()
	
	# 3. Notificar o VitalsComponent do jogador para atualizar os limites
	var player = get_tree().get_first_node_in_group("players")
	if player:
		var vitals = player.get_node_or_null("VitalsComponent")
		if vitals and vitals.has_method("sync_with_status"):
			vitals.sync_with_status()
	
	status_updated.emit()

func _apply_equipment_bonuses():
	# Busca o EquipmentManager para ver o que está equipado
	var equip_manager = get_tree().get_first_node_in_group("equipment_manager")
	if not equip_manager: return
	
	# Conecta ao sinal de mudança para recalcular automaticamente se ainda não estiver conectado
	if not equip_manager.equipment_changed.is_connected(calculate_status):
		equip_manager.equipment_changed.connect(func(_slot, _id): calculate_status())
	
	var equipped_items = equip_manager.get_equipped_items_data()
	for item in equipped_items:
		if item.has("stats"):
			for stat_key in item["stats"]:
				if stat_key == "elemental":
					for el_key in item["stats"]["elemental"]:
						current_total_stats["elemental"][el_key] += item["stats"]["elemental"][el_key]
				elif current_total_stats.has(stat_key):
					current_total_stats[stat_key] += item["stats"][stat_key]

func get_total_status() -> Dictionary:
	return current_total_stats
