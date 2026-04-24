extends Node
class_name InventoryManager

signal inventory_updated(slot_index: int)

var slots: Array[Dictionary] = []
var inventory_size: int = 25 # 5x5 Grid

func _ready() -> void:
	# Inicializa 25 slots vazios
	for i in range(inventory_size):
		slots.append({"item": null, "amount": 0})

func add_item(item: ItemData, amount: int) -> int:
	var remaining = amount
	
	# 1. Tentar empilhar (stack) em slots que já possuem esse item e não estão cheios
	if item.is_stackable:
		for i in range(slots.size()):
			var slot = slots[i]
			if slot["item"] != null and slot["item"].id == item.id:
				var space_left = item.max_stack - slot["amount"]
				if space_left > 0:
					var add_amount = min(space_left, remaining)
					slot["amount"] += add_amount
					remaining -= add_amount
					inventory_updated.emit(i)
					
					if remaining <= 0:
						return 0 # Tudo adicionado com sucesso
						
	# 2. Procurar slots vazios para o que sobrou
	for i in range(slots.size()):
		var slot = slots[i]
		if slot["item"] == null:
			var add_amount = remaining
			if item.is_stackable:
				add_amount = min(item.max_stack, remaining)
			
			slot["item"] = item
			slot["amount"] = add_amount
			remaining -= add_amount
			inventory_updated.emit(i)
			
			if remaining <= 0:
				return 0 # Tudo adicionado com sucesso
				
	return remaining # Retorna o resto que não coube (inventário cheio)

func remove_item(index: int, amount: int) -> void:
	if index < 0 or index >= slots.size(): return
	var slot = slots[index]
	
	if slot["item"] != null:
		slot["amount"] -= amount
		if slot["amount"] <= 0:
			slot["item"] = null
			slot["amount"] = 0
		inventory_updated.emit(index)

func consume_item_by_id(item_id: String, amount: int = 1) -> bool:
	var remaining = amount
	
	# Percorre do último para o primeiro para consumir stacks incompletos primeiro, ou o contrário
	for i in range(slots.size()):
		var slot = slots[i]
		if slot["item"] != null and slot["item"].id == item_id:
			if slot["amount"] >= remaining:
				slot["amount"] -= remaining
				if slot["amount"] == 0:
					slot["item"] = null
				inventory_updated.emit(i)
				return true
			else:
				remaining -= slot["amount"]
				slot["amount"] = 0
				slot["item"] = null
				inventory_updated.emit(i)
				
	return remaining == 0 # Retorna true se conseguiu consumir tudo

func swap_slots(from_index: int, to_index: int) -> void:
	if from_index == to_index: return
	if from_index < 0 or to_index < 0 or from_index >= slots.size() or to_index >= slots.size(): return
	
	var from_slot = slots[from_index]
	var to_slot = slots[to_index]
	
	# Se o destino e origem tem o mesmo item e é empilhável, junta os dois
	if from_slot["item"] != null and to_slot["item"] != null:
		if from_slot["item"].id == to_slot["item"].id and from_slot["item"].is_stackable:
			var space_left = to_slot["item"].max_stack - to_slot["amount"]
			if space_left > 0:
				var move_amount = min(space_left, from_slot["amount"])
				to_slot["amount"] += move_amount
				from_slot["amount"] -= move_amount
				
				if from_slot["amount"] <= 0:
					from_slot["item"] = null
					from_slot["amount"] = 0
					
				inventory_updated.emit(from_index)
				inventory_updated.emit(to_index)
				return
				
	# Caso contrário (ou se sobrar), apenas troca as posições
	var temp_item = to_slot["item"]
	var temp_amount = to_slot["amount"]
	
	to_slot["item"] = from_slot["item"]
	to_slot["amount"] = from_slot["amount"]
	
	from_slot["item"] = temp_item
	from_slot["amount"] = temp_amount
	
	inventory_updated.emit(from_index)
	inventory_updated.emit(to_index)
