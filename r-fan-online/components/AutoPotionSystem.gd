extends Node
class_name AutoPotionSystem

class PotConfig:
	var item_id: String = ""
	var threshold_pct: float = 0.5
	var last_use_time: int = 0
	var is_active: bool = false

var hp_config = PotConfig.new()
var sp_config = PotConfig.new()
var fp_config = PotConfig.new()

var cooldown_ms: int = 1000

@onready var player = get_parent()
var vitals: VitalsComponent = null
var inventory: InventoryManager = null

func _ready() -> void:
	# Aguarda um frame para garantir que os componentes foram inicializados no Player
	await get_tree().process_frame
	vitals = player.get_node_or_null("VitalsComponent")
	inventory = player.get_node_or_null("InventoryManager")

func _process(_delta: float) -> void:
	if not vitals or not inventory: return
	if vitals.hp <= 0: return
	
	var now = Time.get_ticks_msec()
	
	_check_and_use(hp_config, vitals.hp, vitals.max_hp, "hp", now)
	_check_and_use(sp_config, vitals.sp, vitals.max_sp, "sp", now)
	_check_and_use(fp_config, vitals.fp, vitals.max_fp, "fp", now)

func _check_and_use(config: PotConfig, current: int, max_val: int, type: String, now: int) -> void:
	if config.item_id == "" or not config.is_active: return
	
	if now - config.last_use_time < cooldown_ms: return
	
	var pct = float(current) / float(max_val)
	if pct <= config.threshold_pct:
		_execute_use(config, type, now)

func _execute_use(config: PotConfig, type: String, now: int) -> void:
	# Tenta consumir
	var success = inventory.consume_item_by_id(config.item_id, 1)
	if success:
		var item_data = ItemDatabase.get_item(config.item_id)
		var valor = item_data.get("valor", 0)
		
		match type:
			"hp": vitals.restore_health(valor)
			"sp": vitals.restore_sp(valor)
			"fp": vitals.restore_fp(valor)
		
		config.last_use_time = now
	else:
		# Acabou o item
		config.item_id = ""
		config.is_active = false

func set_config(type: String, item_id: String, threshold: float):
	var config = null
	match type:
		"hp": config = hp_config
		"sp": config = sp_config
		"fp": config = fp_config
	
	if config:
		config.item_id = item_id
		config.threshold_pct = threshold
		config.is_active = (item_id != "")
