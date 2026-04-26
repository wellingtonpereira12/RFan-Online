extends Node3D

var tree_scene = load("res://levels/props/MeshyDesertTree.tscn")

func _ready():
	# 1. Spawnar Árvores (espalhadas pelo deserto)
	# Vamos concentrar mais árvores perto do Arid Cave e Ancient Altar
	if tree_scene:
		for i in range(120):
			var pos = Vector3(randf_range(-1000, 1000), 0, randf_range(-1000, 1000))
			_spawn_prop(tree_scene, pos)

	# 2. Criar MARCOS GEOGRÁFICOS baseados no mapa do usuário
	# Escala aproximada: HQ está no "Sudoeste", Port no "Centro", etc.
	
	_create_landmark("ACCRETIA HQ", Vector3(-600, 0, 400), Color(0.8, 0.4, 0.1))
	_create_landmark("ACCRETIA PORT", Vector3(100, 0, 50), Color(0.2, 0.6, 0.8))
	_create_landmark("CRATER DESERT", Vector3(-50, 0, -400), Color(0.5, 0.5, 0.5))
	_create_landmark("ARID CAVE", Vector3(-550, 0, -100), Color(0.3, 0.2, 0.1))
	_create_landmark("ANCIENT ALTAR", Vector3(700, 0, -600), Color(0.9, 0.9, 0.7))
	_create_landmark("SNATCHER SHRINE", Vector3(600, 0, 300), Color(0.7, 0.2, 0.2))
	_create_landmark("RAMBLER LAND", Vector3(400, 0, -450), Color(0.4, 0.5, 0.2))

func _spawn_prop(scene, pos):
	if not scene: return
	var instance = scene.instantiate()
	add_child(instance)
	instance.global_position = pos
	instance.scale *= randf_range(0.8, 2.0)
	instance.rotation.y = randf_range(0, TAU)

func _create_landmark(label_text, pos, color):
	# Criar uma base visual para o local
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(50, 2, 50) # Tamanho da base do local
	mesh_instance.mesh = box
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.8
	mat.roughness = 0.2
	mesh_instance.material_override = mat
	
	add_child(mesh_instance)
	mesh_instance.global_position = pos
	
	# Criar o texto 3D flutuante
	var label = Label3D.new()
	label.text = label_text
	label.font_size = 72
	label.outline_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_instance.add_child(label)
	label.position = Vector3(0, 10, 0) # Texto flutuando alto
	
	# Adicionar algumas colunas ou detalhes tecnológicos se for o HQ ou Port
	if "HQ" in label_text or "PORT" in label_text:
		for i in range(4):
			var col = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 2
			cyl.bottom_radius = 2
			cyl.height = 20
			col.mesh = cyl
			col.material_override = mat
			mesh_instance.add_child(col)
			var angle = i * PI/2
			col.position = Vector3(cos(angle)*20, 10, sin(angle)*20)
