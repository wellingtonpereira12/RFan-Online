extends Node3D
class_name MobSpawner

@export var mob_key: String = "bellato_guard"
@export var max_count: int = 3
@export var respawn_time: float = 10.0
@export var spawn_radius: float = 5.0

# Referência à cena base do mob avançado que criamos
var mob_scene: PackedScene = preload("res://entities/enemies/AdvancedMob.tscn")

var current_mobs: Array = []
var respawn_timer: float = 0.0

func _ready() -> void:
	# Valida o Mob Key logo no início
	var data = MobDatabase.get_mob(mob_key)
	if data.is_empty():
		printerr("[MobSpawner] Desativado! Mob key inválida: ", mob_key)
		set_process(false)
		return
		
	# Spawna a cota inicial
	for i in range(max_count):
		_spawn_mob()

func _process(delta: float) -> void:
	if current_mobs.size() < max_count:
		respawn_timer -= delta
		if respawn_timer <= 0:
			_spawn_mob()
			respawn_timer = respawn_time

func _spawn_mob() -> void:
	if not mob_scene:
		return
		
	var mob = mob_scene.instantiate() as AdvancedMob
	
	# Posição aleatória dentro do raio
	var rand_x = randf_range(-spawn_radius, spawn_radius)
	var rand_z = randf_range(-spawn_radius, spawn_radius)
	var spawn_pos = global_position + Vector3(rand_x, 0, rand_z)
	
	# Adiciona à árvore ANTES de chamar o setup
	get_parent().add_child(mob)
	mob.global_position = spawn_pos
	
	# Configura puxando os status do banco de dados oficial!
	mob.setup_from_db(mob_key)
	
	# Monitora quando ele morrer para recriar
	mob.died.connect(_on_mob_died.bind(mob))
	current_mobs.append(mob)

func _on_mob_died(mob: Node3D) -> void:
	if mob in current_mobs:
		current_mobs.erase(mob)
	
	# Inicia o timer de respawn apenas se acabamos de cair abaixo do máximo
	if current_mobs.size() == max_count - 1:
		respawn_timer = respawn_time
