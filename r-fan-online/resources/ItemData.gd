extends Resource
class_name ItemData

enum ItemType { POTION, EQUIPMENT, MATERIAL, QUEST }

@export var id: String = ""
@export var name: String = "Novo Item"
@export var type: ItemType = ItemType.MATERIAL
@export var icon: Texture2D
@export var max_stack: int = 99
@export var is_stackable: bool = true

# Apenas para potions/consumíveis por enquanto
@export var hp_restore: int = 0
@export var sp_restore: int = 0
@export var fp_restore: int = 0
