extends Node
class_name HealthComponent

signal health_changed(new_health: int, max_health: int)
signal died()

@export var max_health: int = 100

var current_health: int

func _ready() -> void:
	current_health = max_health

func heal(amount: int) -> void:
	if current_health <= 0:
		return
		
	current_health = clampi(current_health + amount, 0, max_health)
	health_changed.emit(current_health, max_health)

func take_damage(amount: int, type = -1) -> void:
	if current_health <= 0:
		return
		
	current_health = clampi(current_health - amount, 0, max_health)
	health_changed.emit(current_health, max_health)
	
	# Exibir Texto de Dano
	var final_type = type
	if final_type == -1:
		final_type = DamageTextManager.DamageType.DEALT
		if get_parent().is_in_group("players"):
			final_type = DamageTextManager.DamageType.RECEIVED
	
	DamageTextManager.display_damage(amount, final_type, get_parent().global_position)
	
	if current_health == 0:
		died.emit()
