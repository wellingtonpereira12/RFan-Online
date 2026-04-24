extends Node

var damage_node_scene = preload("res://ui/hud/DamageNumber.tscn")

enum DamageType { DEALT, RECEIVED, CRITICAL, MISS, BLOCK }

func display_damage(value: Variant, type: DamageType, pos: Vector3):
	var damage_node = damage_node_scene.instantiate()
	
	# Adiciona ao mundo (cena principal) para não seguir o mob se ele morrer
	get_tree().root.add_child(damage_node)
	
	# Pequena variação aleatória para não sobrepor
	var random_offset = Vector3(randf_range(-0.5, 0.5), 1.5, randf_range(-0.5, 0.5))
	damage_node.global_position = pos + random_offset
	
	var text = str(value)
	var color = Color.WHITE
	var is_crit = false
	
	match type:
		DamageType.DEALT:
			color = Color(1, 1, 1) # Branco
		DamageType.RECEIVED:
			color = Color(1, 0.2, 0.2) # Vermelho
		DamageType.CRITICAL:
			color = Color(1, 0.9, 0.1) # Amarelo/Ouro
			text = str(value) + "!"
			is_crit = true
		DamageType.MISS:
			color = Color(0.7, 0.7, 0.7)
			text = "MISS"
		DamageType.BLOCK:
			color = Color(0.3, 0.6, 1.0)
			text = "BLOCK"

	damage_node.setup(text, color, is_crit)
