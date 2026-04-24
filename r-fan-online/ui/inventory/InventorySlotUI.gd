extends Panel
class_name InventorySlotUI

@onready var icon_rect: TextureRect = $IconRect
@onready var amount_label: Label = $AmountLabel

var slot_index: int = -1
var item_data: Dictionary = {}
var item_amount: int = 0
var is_dragging: bool = false
var confirm_dialog: ConfirmationDialog = null

signal slot_dragged(from_index: int, to_index: int)
signal slot_clicked(index: int)

func _ready() -> void:
	clear_slot()

func set_slot(item: Dictionary, amount: int) -> void:
	item_data = item
	item_amount = amount
	
	if not item.is_empty():
		# Define a tooltip para mostrar nome e descrição quando passar o mouse
		tooltip_text = item.get("nome", "Item Desconhecido")
		if item.has("descricao"):
			tooltip_text += "\n" + item["descricao"]
			
		if item.has("icon") and item["icon"] != null:
			icon_rect.texture = item["icon"]
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
	item_data = {}
	item_amount = 0
	icon_rect.texture = null
	icon_rect.modulate = Color(1, 1, 1, 0) # Transparente quando vazio
	amount_label.visible = false
	tooltip_text = "" # Remove a tooltip quando vazio

# --- Drag & Drop Lógica Nativa ---
func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_data.is_empty(): return null
	
	var preview_icon = TextureRect.new()
	if item_data.has("icon") and item_data["icon"] != null:
		preview_icon.texture = item_data["icon"]
	else:
		var preview_lbl = Label.new()
		preview_lbl.text = item_data.get("nome", "Item")
		preview_icon.add_child(preview_lbl)
		
	preview_icon.custom_minimum_size = size
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.modulate = Color(1, 1, 1, 0.7) # Translúcido
	
	var ctrl = Control.new()
	ctrl.add_child(preview_icon)
	preview_icon.position = -size / 2
	set_drag_preview(ctrl)
	
	is_dragging = true
	
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if is_dragging:
			is_dragging = false
			if not get_viewport().gui_is_drag_successful():
				_ask_drop_item()

func _ask_drop_item() -> void:
	if confirm_dialog == null:
		confirm_dialog = ConfirmationDialog.new()
		confirm_dialog.dialog_text = "Deseja derrubar o item no chão?"
		confirm_dialog.title = "Atenção"
		confirm_dialog.confirmed.connect(_on_drop_confirmed)
		add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _on_drop_confirmed() -> void:
	var player = get_tree().get_first_node_in_group("players")
	if player and player.has_method("drop_item_on_ground"):
		player.drop_item_on_ground(item_data, item_amount)
	
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui and inv_ui.inventory_manager:
		inv_ui.inventory_manager.remove_item(slot_index, item_amount)
