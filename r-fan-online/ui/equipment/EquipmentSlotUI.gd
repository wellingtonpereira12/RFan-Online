extends Panel
class_name EquipmentSlotUI

@onready var icon_rect: TextureRect = $IconRect
@onready var slot_label: Label = $SlotLabel
@onready var border: ReferenceRect = $Border

var slot_name: String = ""
var item_id: String = ""
var equipment_manager: EquipmentManager

# Parâmetros de setup guardados até _ready() ser chamado
var _pending_label: String = ""
var _pending_manager: EquipmentManager = null

signal slot_clicked_right(slot_name: String)

func _ready() -> void:
	# Aplica os parâmetros que foram guardados antes do _ready
	if _pending_label != "":
		slot_label.text = _pending_label
		tooltip_text = _pending_label + "\n(vazio)"
	clear_slot()

func setup(s_name: String, label: String, eq_manager: EquipmentManager) -> void:
	slot_name = s_name
	equipment_manager = eq_manager
	_pending_label = label
	_pending_manager = eq_manager
	# Se já estiver na árvore, aplica na hora; senão _ready() vai aplicar
	if is_inside_tree() and slot_label != null:
		slot_label.text = label
		tooltip_text = label + "\n(vazio)"
		clear_slot()

func set_item(id: String) -> void:
	item_id = id
	if id == "":
		clear_slot()
		return

	var item_data = ItemDatabase.get_item(id)
	if item_data.is_empty():
		clear_slot()
		return

	# Exibe o nome no label
	icon_rect.modulate = Color(0.9, 0.7, 0.2, 1)
	slot_label.text = item_data.get("nome", id)
	
	# Monta tooltip com nome, descrição e restrição de mão
	var tt = item_data.get("nome", id)
	tt += "\n" + item_data.get("descricao", "")
	var mao = item_data.get("mao", "")
	if mao != "":
		var mao_label = {"esquerda": "🤜 Mão Esquerda", "direita": "🤛 Mão Direita", "ambas": "🤜🤛 Ambas as Mãos"}.get(mao, mao)
		tt += "\n" + mao_label
	tooltip_text = tt
	border.border_color = Color(0.9, 0.7, 0.2, 1)

func clear_slot() -> void:
	item_id = ""
	icon_rect.modulate = Color(1, 1, 1, 0)
	border.border_color = Color(0.4, 0.4, 0.4, 1)
	tooltip_text = slot_name + "\n(vazio)"
	# Restaura o nome original do slot (ex: "Botas", "Escudo")
	if slot_label != null:
		slot_label.text = _pending_label if _pending_label != "" else slot_name

# --- Drag & Drop ---
func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id == "": return null

	var preview = Label.new()
	var item_data = ItemDatabase.get_item(item_id)
	preview.text = item_data.get("nome", item_id)
	var ctrl = Control.new()
	ctrl.add_child(preview)
	preview.position = Vector2(-30, -15)
	set_drag_preview(ctrl)

	return {"type": "equipment_slot", "from_slot": slot_name, "item_id": item_id}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("type"): return false
	
	if data["type"] == "inventory_slot":
		# Valida se o item do inventário é compatível com este slot
		var item_data = ItemDatabase.get_item(data["data"].get("id", ""))
		if item_data.is_empty(): return false
		return _is_item_compatible(item_data)
		
	if data["type"] == "equipment_slot":
		# Não permite soltar no mesmo slot
		if data["from_slot"] == slot_name: return false
		# Valida se o item arrastado é compatível com ESTE slot destino
		var item_data = ItemDatabase.get_item(data["item_id"])
		if item_data.is_empty(): return false
		return _is_item_compatible(item_data)
		
	return false

# Função central de validação de compatibilidade
func _is_item_compatible(item_data: Dictionary) -> bool:
	var required_type = EquipmentManager.VALID_SLOTS.get(slot_name, "")
	var item_slot = item_data.get("equip_slot", "")
	
	# Tipo do slot deve bater
	if item_slot != required_type: return false
	
	# Valida restrição de mão
	var item_mao = item_data.get("mao", "")
	if item_mao != "" and item_mao != "ambas" and EquipmentManager.SLOT_HAND.has(slot_name):
		var slot_mao = EquipmentManager.SLOT_HAND[slot_name]
		if item_mao != slot_mao: return false
	
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data["type"] == "inventory_slot":
		var item_data = data["data"]
		equipment_manager.equip_item(item_data.get("id", ""), slot_name)
	elif data["type"] == "equipment_slot":
		# Troca dois slots de equipamento
		var other_slot = data["from_slot"]
		var other_id = data["item_id"]
		var my_id = item_id

		equipment_manager.equipped[other_slot] = my_id
		equipment_manager.equipped[slot_name] = other_id
		equipment_manager.equipment_changed.emit(other_slot, my_id)
		equipment_manager.equipment_changed.emit(slot_name, other_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and item_id != "":
			slot_clicked_right.emit(slot_name)
