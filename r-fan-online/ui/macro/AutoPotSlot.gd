extends Panel
class_name AutoPotSlot

var icon_rect: TextureRect
var amount_label: Label

var item_id: String = ""
var pot_type: String = "hp" # "hp", "sp", "fp"

signal item_changed(new_item_id: String)

func _ready() -> void:
	custom_minimum_size = Vector2(50, 50)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.6, 1.0)
	add_theme_stylebox_override("panel", style)

	icon_rect = get_node_or_null("IconRect")
	amount_label = get_node_or_null("AmountLabel")
	
	if not icon_rect:
		icon_rect = TextureRect.new()
		icon_rect.name = "IconRect"
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon_rect)
		
	if not amount_label:
		amount_label = Label.new()
		amount_label.name = "AmountLabel"
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		amount_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		amount_label.offset_right = -3
		amount_label.add_theme_font_size_override("font_size", 12)
		amount_label.add_theme_color_override("font_outline_color", Color.BLACK)
		amount_label.add_theme_constant_override("outline_size", 4)
		add_child(amount_label)
	
	clear_slot()

func set_item(id: String) -> void:
	item_id = id
	if item_id == "":
		clear_slot()
		return
	
	var data = ItemDatabase.get_item(item_id)
	if data.is_empty():
		clear_slot()
		return
	
	if icon_rect:
		if data.has("icon") and data["icon"] != null:
			icon_rect.texture = data["icon"]
			icon_rect.modulate = Color(1, 1, 1, 1)
		else:
			icon_rect.texture = null
			icon_rect.modulate = Color(0.2, 0.6, 1, 1)
	
	item_changed.emit(item_id)
	_update_amount()

func clear_slot() -> void:
	item_id = ""
	if icon_rect:
		icon_rect.texture = null
		icon_rect.modulate = Color(1, 1, 1, 0)
	if amount_label:
		amount_label.text = ""
	item_changed.emit("")

func _update_amount() -> void:
	if item_id == "": return
	var inv = get_tree().get_first_node_in_group("inventory_manager")
	if inv:
		var total = inv.get_total_amount(item_id)
		if amount_label:
			amount_label.text = str(total)
		if total <= 0:
			clear_slot()

# --- Drag & Drop com Validação de Tipo de Potion ---
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("type") != "inventory_slot":
		return false
	
	var item = data.get("data", {})
	
	# 1. Deve ser do tipo "potion"
	if item.get("tipo") != "potion":
		return false
	
	# 2. Valida o efeito contra o tipo do slot
	var efeito = item.get("efeito", "")
	
	# Lógica de permissão:
	# Se a poção é híbrida (hp_sp), aceita em HP ou SP
	# Se for específica, só aceita no seu respectivo slot
	match pot_type:
		"hp":
			return efeito == "hp" or efeito == "hp_sp"
		"sp":
			return efeito == "sp" or efeito == "hp_sp"
		"fp":
			return efeito == "fp"
			
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var id = data.get("data", {}).get("id", "")
	set_item(id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			clear_slot()
