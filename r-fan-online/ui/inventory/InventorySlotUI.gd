extends Panel
class_name InventorySlotUI

@onready var icon_rect: TextureRect = $IconRect
@onready var amount_label: Label = $AmountLabel

var slot_index: int = -1
var item_data: ItemData = null
var item_amount: int = 0

signal slot_dragged(from_index: int, to_index: int)
signal slot_clicked(index: int)

func _ready() -> void:
	clear_slot()

func set_slot(item: ItemData, amount: int) -> void:
	item_data = item
	item_amount = amount
	
	if item != null:
		if item.icon:
			icon_rect.texture = item.icon
			icon_rect.modulate = Color(1, 1, 1, 1)
		else:
			# Sem ícone? Pinta o TextureRect temporariamente
			icon_rect.texture = null
			icon_rect.modulate = Color(0.2, 0.6, 0.9, 1) # Azul genérico
			
		if amount > 1:
			amount_label.text = str(amount)
			amount_label.visible = true
		else:
			amount_label.visible = false
	else:
		clear_slot()

func clear_slot() -> void:
	item_data = null
	item_amount = 0
	icon_rect.texture = null
	icon_rect.modulate = Color(1, 1, 1, 0) # Transparente quando vazio
	amount_label.visible = false

# --- Drag & Drop Lógica Nativa ---
func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_data == null: return null
	
	var preview_icon = TextureRect.new()
	if item_data.icon:
		preview_icon.texture = item_data.icon
	else:
		var preview_lbl = Label.new()
		preview_lbl.text = item_data.name
		preview_icon.add_child(preview_lbl)
		
	preview_icon.custom_minimum_size = size
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.modulate = Color(1, 1, 1, 0.7) # Translúcido
	
	var ctrl = Control.new()
	ctrl.add_child(preview_icon)
	preview_icon.position = -size / 2
	set_drag_preview(ctrl)
	
	return {"type": "inventory_slot", "from_index": slot_index, "data": item_data}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "inventory_slot"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var from_idx = data["from_index"]
	if from_idx != slot_index:
		slot_dragged.emit(from_idx, slot_index)

func _gui_input(event: InputEvent) -> void:
	# Dispara evento se o usuário clicar 2 vezes ou clicar com direito (usar item no futuro)
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			slot_clicked.emit(slot_index)
