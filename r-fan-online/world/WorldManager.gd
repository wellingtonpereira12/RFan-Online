extends Node3D

@onready var map_container = $MapContainer
@onready var player = $Player

func _ready():
	NetworkManager.map_changed.connect(_on_map_changed)
	print("[World] WorldManager pronto. Conectado ao NetworkManager.")
	# Carrega o mapa inicial se já estiver definido
	if GameManager.current_map_id != "":
		_on_map_changed(GameManager.current_map_id)

func _on_map_changed(map_id: String):
	# Se map_id for vazio ou nulo, não faz nada
	if not map_id or map_id == "": return
	
	print("[World] Executando troca visual para: ", map_id)
	
	# Atualiza status global do mapa (SafeZone, nome, etc)
	GameManager.update_map_status(map_id)
	
	# Remove mapa antigo
	for child in map_container.get_children():
		child.queue_free()
	
	# Tenta carregar a cena do mapa
	var map_path = "res://levels/Map_" + map_id + ".tscn"
	if ResourceLoader.exists(map_path):
		var map_scene = load(map_path)
		if map_scene:
			var map_instance = map_scene.instantiate()
			map_container.add_child(map_instance)
			print("[World] Cena do mapa carregada: ", map_path)
		else:
			print("[World] ERRO CRÍTICO: Falha ao carregar arquivo da cena (Parser Error?): ", map_path)
			_create_emergency_floor()
	else:
		print("[World] ERRO: Cena do mapa não encontrada: ", map_path)
		# Cria um chão de emergência se não houver mapa
		_create_emergency_floor()

func _create_emergency_floor():
	var static_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	collision.shape = box
	static_body.add_child(collision)
	
	var mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(100, 1, 100)
	mesh.mesh = box_mesh
	static_body.add_child(mesh)
	
	map_container.add_child(static_body)
	# Posiciona no spawn do jogador
	static_body.global_position = player.global_position - Vector3(0, 0.5, 0)
