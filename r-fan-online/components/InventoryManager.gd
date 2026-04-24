extends Node
class_name InventoryManager

signal inventory_updated(slot_index: int)

var slots: Array[Dictionary] = []
var inventory_size: int = 25 # 5x5 Grid

func _ready() -> void:
	# Inicializa 25 slots vazios (guarda apenas o ID e a quantidade)
	for i in range(inventory_size):
		slots.append({"id": "", "amount": 0})

func add_item(item_id: String, amount: int) -> int:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data.is_empty(): return amount # Rejeita se não existe no DB
	
	var remaining = amount
	var max_stack = item_data.get("max_stack", 1)
	
	# 1. Tentar empilhar em slots que já possuem esse ID
	for i in range(slots.size()):
		var slot = slots[i]
		if slot["id"] == item_id:
			var space_left = max_stack - slot["amount"]
			if space_left > 0:
				var add_amount = min(space_left, remaining)
				slot["amount"] += add_amount
				remaining -= add_amount
				inventory_updated.emit(i)
				
				if remaining <= 0:
					return 0
					
	# 2. Procurar slots vazios para o que sobrou
	for i in range(slots.size()):
		var slot = slots[i]
		if slot["id"] == "":
			var add_amount = min(max_stack, remaining)
			
			slot["id"] = item_id
			slot["amount"] = add_amount
			remaining -= add_amount
			inventory_updated.emit(i)
			
			if remaining <= 0:
				return 0
				
	return remaining # Retorna o resto que não coube

func remove_item(index: int, amount: int) -> void:
	if index < 0 or index >= slots.size(): return
	var slot = slots[index]
	
	if slot["id"] != "":
		slot["amount"] -= amount
		if slot["amount"] <= 0:
			slot["id"] = ""
			slot["amount"] = 0
		inventory_updated.emit(index)

func consume_item_by_id(item_id: String, amount: int = 1) -> bool:
	var remaining = amount
	
	for i in range(slots.size()):
		var slot = slots[i]
		if slot["id"] == item_id:
			if slot["amount"] >= remaining:
				slot["amount"] -= remaining
				if slot["amount"] == 0:
					slot["id"] = ""
				inventory_updated.emit(i)
				return true
			else:
				remaining -= slot["amount"]
				slot["amount"] = 0
				slot["id"] = ""
				inventory_updated.emit(i)
				
	return remaining == 0

func swap_slots(from_index: int, to_index: int) -> void:
	if from_index == to_index: return
	if from_index < 0 or to_index < 0 or from_index >= slots.size() or to_index >= slots.size(): return
	
	var from_slot = slots[from_index]
	var to_slot = slots[to_index]
	
	# Se ambos tem o mesmo ID, tenta empilhar
	if from_slot["id"] != "" and to_slot["id"] != "":
		if from_slot["id"] == to_slot["id"]:
			var item_data = ItemDatabase.get_item(to_slot["id"])
			var max_stack = item_data.get("max_stack", 1)
			
			var space_left = max_stack - to_slot["amount"]
			if space_left > 0:
				var move_amount = min(space_left, from_slot["amount"])
				to_slot["amount"] += move_amount
				from_slot["amount"] -= move_amount
				
				if from_slot["amount"] <= 0:
					from_slot["id"] = ""
					from_slot["amount"] = 0
					
				inventory_updated.emit(from_index)
				inventory_updated.emit(to_index)
				return
				
	# Troca simples de posições
	var temp_id = to_slot["id"]
	var temp_amount = to_slot["amount"]
	
	to_slot["id"] = from_slot["id"]
	to_slot["amount"] = from_slot["amount"]
	
	from_slot["id"] = temp_id
	from_slot["amount"] = temp_amount
	
	inventory_updated.emit(from_index)
	inventory_updated.emit(to_index)

func get_total_amount(item_id: String) -> int:
	var total = 0
	for slot in slots:
		if slot["id"] == item_id:
			total += slot["amount"]
	return total
