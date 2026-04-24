extends Node
class_name EquipmentManager

signal equipment_changed(slot_name: String, item_id: String)

# Slots válidos: slot_name → tipo de item aceito
const VALID_SLOTS := {
	"head":        "head",
	"body":        "body",
	"weapon":      "weapon",  # Mão esquerda por padrão
	"shield":      "shield",  # Mão direita obrigatoriamente
	"boots":       "boots",
	"accessory_1": "accessory",
	"accessory_2": "accessory",
	"accessory_3": "accessory",
	"accessory_4": "accessory"
}

# Qual mão cada slot representa (para validação extra)
const SLOT_HAND := {
	"weapon": "esquerda",
	"shield": "direita"
}

# Armazena apenas o ID do item equipado (vazio = nada equipado)
var equipped: Dictionary = {
	"head":        "",
	"body":        "",
	"weapon":      "",
	"shield":      "",
	"boots":       "",
	"accessory_1": "",
	"accessory_2": "",
	"accessory_3": "",
	"accessory_4": ""
}

var inventory_manager: InventoryManager

func setup(inv_manager: InventoryManager) -> void:
	inventory_manager = inv_manager

# Equipa um item de um slot do inventário para um slot de equipamento
# Retorna true se equipou com sucesso
func equip_item(item_id: String, equip_slot: String) -> bool:
	# 1. Valida item no banco de dados
	var item_data = ItemDatabase.get_item(item_id)
	if item_data.is_empty():
		printerr("[EquipmentManager] Item não encontrado: " + item_id)
		return false

	# 2. Valida tipo do slot
	if not VALID_SLOTS.has(equip_slot):
		printerr("[EquipmentManager] Slot inválido: " + equip_slot)
		return false

	var required_type = VALID_SLOTS[equip_slot]
	var item_slot = item_data.get("equip_slot", "")
	
	# Acessórios aceitam qualquer slot "accessory"
	if item_slot != required_type:
		print("[EquipmentManager] Item '" + item_id + "' não é compatível com slot '" + equip_slot + "'")
		return false

	# Valida restrição de mão (ex: escudo só vai na mão direita)
	var item_mao = item_data.get("mao", "")
	if item_mao != "" and item_mao != "ambas" and SLOT_HAND.has(equip_slot):
		var slot_mao = SLOT_HAND[equip_slot]
		if item_mao != slot_mao:
			print("[EquipmentManager] '" + item_data.get("nome", item_id) + "' só pode ser equipado na mão " + item_mao + ", mas o slot '" + equip_slot + "' é a mão " + slot_mao)
			return false

	# 3. Se já tem item no slot, devolve pro inventário
	var current = equipped[equip_slot]
	if current != "":
		var leftover = inventory_manager.add_item(current, 1)
		if leftover > 0:
			print("[EquipmentManager] Inventário cheio! Não é possível desequipar o item atual.")
			return false

	# 4. Remove 1 do inventário
	if not inventory_manager.consume_item_by_id(item_id, 1):
		print("[EquipmentManager] Item não encontrado no inventário.")
		return false

	# 5. Equipa
	equipped[equip_slot] = item_id
	equipment_changed.emit(equip_slot, item_id)
	print("[EquipmentManager] Equipou: " + item_id + " → " + equip_slot)
	return true

# Remove item do slot de equipamento e devolve para o inventário
func unequip_item(equip_slot: String) -> bool:
	if not VALID_SLOTS.has(equip_slot): return false

	var item_id = equipped[equip_slot]
	if item_id == "":
		return false

	# Tenta devolver ao inventário
	var leftover = inventory_manager.add_item(item_id, 1)
	if leftover > 0:
		print("[EquipmentManager] Inventário cheio! Não é possível desequipar.")
		return false

	equipped[equip_slot] = ""
	equipment_changed.emit(equip_slot, "")
	print("[EquipmentManager] Desequipou: " + item_id + " ← " + equip_slot)
	return true

# Equipa automaticamente o item no slot correto (para clique direito no inventário)
func auto_equip(item_id: String) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data.is_empty(): return false

	var item_slot = item_data.get("equip_slot", "")
	if item_slot == "": return false

	# Para acessórios, tenta o 1, 2, 3 depois o 4
	if item_slot == "accessory":
		if equipped["accessory_1"] == "":
			return equip_item(item_id, "accessory_1")
		elif equipped["accessory_2"] == "":
			return equip_item(item_id, "accessory_2")
		elif equipped["accessory_3"] == "":
			return equip_item(item_id, "accessory_3")
		elif equipped["accessory_4"] == "":
			return equip_item(item_id, "accessory_4")
		else:
			return equip_item(item_id, "accessory_1") # Substitui o 1 se todos cheios

	# Para outros slots, vai direto
	if VALID_SLOTS.has(item_slot):
		return equip_item(item_id, item_slot)

	return false
