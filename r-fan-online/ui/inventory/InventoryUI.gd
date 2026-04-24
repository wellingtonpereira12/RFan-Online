extends Control
class_name InventoryUI

@onready var grid_container: GridContainer = $Background/MarginContainer/GridContainer
var slot_scene = preload("res://ui/inventory/InventorySlotUI.tscn")

@onready var background: Panel = $Background

var inventory_manager: InventoryManager
var slot_uis: Array[InventorySlotUI] = []

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("inventory_ui")
	visible = false # Escondido por padrão
	background.gui_input.connect(_on_background_gui_input)
	
	# Força a posição inicial do painel para a direita no meio
	call_deferred("_setup_position")

func _setup_position() -> void:
	background.position = Vector2(size.x - background.size.x - 20, (size.y - background.size.y) / 2)

func setup(manager: InventoryManager) -> void:
	inventory_manager = manager
	inventory_manager.inventory_updated.connect(_on_inventory_updated)
	
	# Instancia as 25 casinhas visuais
	for i in range(inventory_manager.inventory_size):
		var slot_ui: InventorySlotUI = slot_scene.instantiate()
		slot_ui.slot_index = i
		grid_container.add_child(slot_ui)
		slot_uis.append(slot_ui)
		
		# Conecta os sinais de Arrastar/Soltar e Click
		slot_ui.slot_dragged.connect(_on_slot_dragged)
		slot_ui.slot_clicked.connect(_on_slot_clicked)

func _on_inventory_updated(index: int) -> void:
	var data = inventory_manager.slots[index]
	if data["id"] != "":
		var item_info = ItemDatabase.get_item(data["id"])
		slot_uis[index].set_slot(item_info, data["amount"])
	else:
		slot_uis[index].clear_slot()

func _on_slot_dragged(from_index: int, to_index: int) -> void:
	inventory_manager.swap_slots(from_index, to_index)

func _on_slot_clicked(index: int) -> void:
	var data = inventory_manager.slots[index]
	if data["id"] == "": return
	
	var item_info = ItemDatabase.get_item(data["id"])
	if item_info.is_empty(): return
	
	var tipo = item_info.get("tipo", "")
	
	# === EQUIPAMENTO: equipa automaticamente ===
	if tipo == "equipment":
		var eq_ui = get_tree().get_first_node_in_group("equipment_ui")
		if eq_ui and eq_ui.equipment_manager:
			var success = eq_ui.equipment_manager.auto_equip(data["id"])
			if not success:
				print("[Inventário] Não foi possível equipar automaticamente: ", item_info.get("nome", ""))
		return
	
	# === POÇÃO: consome e aplica efeito ===
	if tipo == "potion":
		var players = get_tree().get_nodes_in_group("players")
		if players.size() > 0:
			var player = players[0]
			if player.has_node("CombatComponent"):
				var combat = player.get_node("CombatComponent")
				combat.process_action(-1, item_info, null)
				
				# Aplica cooldown dinâmico em todos os slots do mesmo item
				var item_id = item_info.get("id", "")
				var cooldown_duration = item_info.get("cooldown_ms", 1000) / 1000.0
				for i in range(slot_uis.size()):
					var s = inventory_manager.slots[i]
					if s["id"] == item_id:
						slot_uis[i].trigger_cooldown(cooldown_duration)

func _unhandled_input(event: InputEvent) -> void:
	# Abre/Fecha o Inventário com 'I'
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			visible = !visible

func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = event.global_position - background.global_position
			# Traz o inventário pra frente caso haja outras janelas
			move_to_front()
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		background.global_position = event.global_position - drag_offset
