extends Node3D

const IDLE_ANIM: String = "WING_PEACEIDLE_01_00"
const WALK_ANIM: String = "WING_WARWALK_01_00"
const ATTACK_ANIM: String = "WING_WARATTACK_01_00"
const DIE_ANIM: String = "WING_WARDIE_01_00"

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hull: Node3D = $Hull
@onready var body: MeshInstance3D = $Hull/Body
@onready var nose: MeshInstance3D = $Hull/Nose
@onready var cockpit: MeshInstance3D = $Hull/Cockpit
@onready var left_wing_pivot: Node3D = $Hull/LeftWingPivot
@onready var right_wing_pivot: Node3D = $Hull/RightWingPivot
@onready var propeller_pivot: Node3D = $Hull/PropellerPivot

var _time: float = 0.0
var _die_time: float = 0.0
var _base_hull_pos: Vector3 = Vector3.ZERO
var _base_hull_rot: Vector3 = Vector3.ZERO
var _base_left_rot: Vector3 = Vector3.ZERO
var _base_right_rot: Vector3 = Vector3.ZERO
var _base_propeller_rot: Vector3 = Vector3.ZERO

func _ready() -> void:
	_base_hull_pos = hull.position
	_base_hull_rot = hull.rotation
	_base_left_rot = left_wing_pivot.rotation
	_base_right_rot = right_wing_pivot.rotation
	_base_propeller_rot = propeller_pivot.rotation
	_setup_materials()
	_ensure_animation_library()
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	var current_anim: String = anim_player.current_animation.to_upper()
	if current_anim.contains("DIE"):
		_die_time += delta
	else:
		_die_time = 0.0

	hull.position = _base_hull_pos
	hull.rotation = _base_hull_rot
	left_wing_pivot.rotation = _base_left_rot
	right_wing_pivot.rotation = _base_right_rot

	if current_anim.contains("ATTACK"):
		_apply_attack_pose()
		_spin_propeller(delta, 20.0)
	elif current_anim.contains("DIE"):
		_apply_die_pose()
		_spin_propeller(delta, 6.0)
	elif current_anim.contains("WALK"):
		_apply_walk_pose()
		_spin_propeller(delta, 28.0)
	else:
		_apply_idle_pose()
		_spin_propeller(delta, 18.0)

func _setup_materials() -> void:
	var body_material: StandardMaterial3D = StandardMaterial3D.new()
	body_material.albedo_color = Color(0.47, 0.31, 0.40)
	body_material.metallic = 0.25
	body_material.roughness = 0.48

	var shell_material: StandardMaterial3D = StandardMaterial3D.new()
	shell_material.albedo_color = Color(0.82, 0.82, 0.84)
	shell_material.metallic = 0.35
	shell_material.roughness = 0.28

	var metal_material: StandardMaterial3D = StandardMaterial3D.new()
	metal_material.albedo_color = Color(0.14, 0.14, 0.16)
	metal_material.metallic = 0.75
	metal_material.roughness = 0.22

	var light_material: StandardMaterial3D = StandardMaterial3D.new()
	light_material.albedo_color = Color(0.48, 1.0, 0.84)
	light_material.emission_enabled = true
	light_material.emission = Color(0.22, 0.95, 0.78)
	light_material.emission_energy_multiplier = 1.8
	light_material.roughness = 0.08

	body.material_override = body_material
	nose.material_override = shell_material
	cockpit.material_override = shell_material
	$Hull/NoseCore.material_override = metal_material
	$Hull/LowerFin.material_override = body_material
	$Hull/PropellerPivot/RotorMast.material_override = metal_material

	var body_meshes: Array[MeshInstance3D] = [
		$Hull/LeftWingPivot/LeftWing,
		$Hull/RightWingPivot/RightWing,
		$Hull/PropellerPivot/PropellerHub
	]
	for wing_mesh: MeshInstance3D in body_meshes:
		wing_mesh.material_override = body_material

	var metal_meshes: Array[MeshInstance3D] = [
		$Hull/PropellerPivot/BladeA,
		$Hull/PropellerPivot/BladeB
	]
	for mesh_instance: MeshInstance3D in metal_meshes:
		mesh_instance.material_override = metal_material

	var light_meshes: Array[MeshInstance3D] = [
		$Hull/LeftWingPivot/LeftTip,
		$Hull/RightWingPivot/RightTip
	]
	for light_mesh: MeshInstance3D in light_meshes:
		light_mesh.material_override = light_material

func _ensure_animation_library() -> void:
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation(IDLE_ANIM, _make_animation(1.6, true))
	library.add_animation(WALK_ANIM, _make_animation(0.9, true))
	library.add_animation(ATTACK_ANIM, _make_animation(0.55, false))
	library.add_animation(DIE_ANIM, _make_animation(1.4, false))
	anim_player.add_animation_library("", library)

func _make_animation(length: float, looped: bool) -> Animation:
	var animation: Animation = Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
	return animation

func _apply_idle_pose() -> void:
	hull.position.y = _base_hull_pos.y + sin(_time * 2.2) * 0.08
	hull.rotation.z = _base_hull_rot.z + sin(_time * 1.6) * 0.03
	hull.rotation.x = _base_hull_rot.x + sin(_time * 1.1) * 0.02

func _apply_walk_pose() -> void:
	hull.position.y = _base_hull_pos.y + sin(_time * 7.0) * 0.12
	hull.rotation.z = _base_hull_rot.z + sin(_time * 4.0) * 0.05
	hull.rotation.x = _base_hull_rot.x + 0.06

func _apply_attack_pose() -> void:
	var pulse: float = sin(anim_player.current_animation_position * TAU * 2.0)
	hull.rotation.x = _base_hull_rot.x - 0.24 + pulse * 0.05
	hull.position.x = _base_hull_pos.x + 0.05
	hull.position.z = _base_hull_pos.z - 0.08

func _apply_die_pose() -> void:
	var t: float = minf(_die_time, 1.4)
	hull.rotation.z = lerp(_base_hull_rot.z, deg_to_rad(105.0), t / 1.4)
	hull.position.y = _base_hull_pos.y - (t * 0.9)
	hull.position.x = _base_hull_pos.x - (t * 0.22)

func _spin_propeller(delta: float, speed: float) -> void:
	propeller_pivot.rotation = _base_propeller_rot
	propeller_pivot.rotate_y(delta * speed)
