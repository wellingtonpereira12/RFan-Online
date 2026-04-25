extends Node3D

var mob_scene = preload("res://entities/enemies/AdvancedMob.tscn")

func _ready() -> void:
	# Pequeno delay para garantir que tudo (incluindo StatusManager) esteja pronto
	await get_tree().create_timer(0.5).timeout
	spawn_initial_mobs()

func spawn_initial_mobs():
	print("[World] Spawnando Guardião Bellato inicial...")
	var mob = mob_scene.instantiate()
	add_child(mob)
	
	# Posiciona na frente do player (o player nasce em 0,0,0)
	mob.global_position = Vector3(0, 0, -5)
	
	# Configura com os dados do JSON
	if mob.has_method("setup_from_db"):
		mob.setup_from_db("bellato_guard")
