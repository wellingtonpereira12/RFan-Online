extends Node

signal status_updated

var base_stats: Dictionary = {}
var scaling_config: Dictionary = {}
var all_class_scales: Dictionary = {}
var player_class: String = "melee"

var current_total_stats: Dictionary = {}

func _ready():
	_load_player_data()
	calculate_status()
	# Conectar sinais globais de level up quando disponíveis
	if ExperienceManager:
		ExperienceManager.level_up.connect(func(_lv): calculate_status())

func _load_player_data():
	# 1. Carrega as regras globais de classe
	var class_file = "res://database/class_scaling_config.json"
	if FileAccess.file_exists(class_file):
		var file = FileAccess.open(class_file, FileAccess.READ)
		all_class_scales = JSON.parse_string(file.get_as_text())
		print("[StatusManager] Regras de classe carregadas.")

	# 2. Carrega os dados do jogador específico
	var player_file = "res://database/player_status.json"
	if FileAccess.file_exists(player_file):
		var file = FileAccess.open(player_file, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data:
			base_stats = data["base_stats"]
			player_class = data.get("class", "melee")
			
			# Seleciona o scaling baseado na classe do jogador
			if all_class_scales.has(player_class):
				scaling_config = all_class_scales[player_class]
				print("[StatusManager] Aplicando scaling para classe: ", player_class)
			
			print("[StatusManager] Dados do jogador carregados.")

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
