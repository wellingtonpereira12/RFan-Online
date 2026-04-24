extends Panel
class_name InventorySlotUI

@onready var icon_rect: TextureRect = $IconRect
@onready var amount_label: Label = $AmountLabel
@onready var name_label: Label = $NameLabel
@onready var cooldown_overlay: ColorRect = $CooldownOverlay
@onready var cooldown_label: Label = $CooldownLabel

var slot_index: int = -1
var item_data: Dictionary = {}
var item_amount: int = 0
var is_dragging: bool = false
var confirm_dialog: ConfirmationDialog = null

var is_on_cooldown: bool = false
var max_cooldown: float = 0.0
var current_cooldown: float = 0.0

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
			self_modulate = Color(1, 1, 1, 1)
			name_label.visible = false
		else:
			# Sem ícone: pinta o painel de uma cor diferente por tipo
			icon_rect.texture = null
			icon_rect.modulate = Color(1, 1, 1, 0) # Esconde o TextureRect vazio
			
			var tipo = item.get("tipo", "")
			match tipo:
				"potion":    self_modulate = Color(0.2, 0.55, 1.0, 1)   # Azul
				"equipment": self_modulate = Color(0.9, 0.65, 0.1, 1)   # Dourado
				_:           self_modulate = Color(0.3, 0.3, 0.3, 1)    # Cinza
			
			# Mostra nome curto no label central
			var short_name = item.get("nome", "?")
			if short_name.length() > 8:
				short_name = short_name.substr(0, 7) + "."
			name_label.text = short_name
			name_label.visible = true

		self_modulate = Color(1, 1, 1, 1) if item.has("icon") and item["icon"] != null else self_modulate
		
		# Sempre lida com a quantidade (agora mostra '1' também se você quiser)
		if amount >= 1:
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
	icon_rect.modulate = Color(1, 1, 1, 0)
	amount_label.visible = false
	name_label.visible = false
	tooltip_text = ""
	self_modulate = Color(1, 1, 1, 1) # Volta ao padrão do tema (fundo do Panel normal)
	is_on_cooldown = false
	current_cooldown = 0.0
	cooldown_overlay.anchor_top = 1.0
	cooldown_label.visible = false

func trigger_cooldown(duration: float) -> void:
	is_on_cooldown = true
	max_cooldown = duration
	current_cooldown = duration
	cooldown_overlay.anchor_top = 0.0
	cooldown_label.visible = true

func _process(delta: float) -> void:
	if is_on_cooldown:
		current_cooldown -= delta
		if current_cooldown <= 0.0:
			is_on_cooldown = false
			current_cooldown = 0.0
			cooldown_overlay.anchor_top = 1.0
			cooldown_label.visible = false
		else:
			cooldown_overlay.anchor_top = 1.0 - (current_cooldown / max_cooldown)
			cooldown_label.text = str(snapped(current_cooldown, 0.1))

# --- Drag & Drop Lógica Nativa ---
func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_data.is_empty() or is_on_cooldown: return null
	
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
	if typeof(data) != TYPE_DICTIONARY or not data.has("type"): return false
	return data["type"] == "inventory_slot" or data["type"] == "equipment_slot"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data["type"] == "inventory_slot":
		var from_idx = data["from_index"]
		if from_idx != slot_index:
			slot_dragged.emit(from_idx, slot_index)
	elif data["type"] == "equipment_slot":
		# Desequipa o item e devolve ao inventário (no slot que ele foi solto)
		var eq_manager = get_tree().get_first_node_in_group("equipment_ui")
		if eq_manager:
			var real_manager = eq_manager.equipment_manager
			if real_manager:
				real_manager.unequip_item(data["from_slot"])

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled() # Impede que o Player.gd capture o mouse ao clicar na UI
		if not event.pressed:
			if not is_on_cooldown:
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
