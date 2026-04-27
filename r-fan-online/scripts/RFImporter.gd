@tool
extends Node3D

@export_file("*.json") var data_path: String = "res://wing_source/wing_data.json"
@export var trigger_import: bool = false : set = _set_trigger_import

func _set_trigger_import(val):
	if val:
		do_import()

func do_import():
	if not FileAccess.file_exists(data_path):
		printerr("Data file not found: ", data_path)
		return

	var json_text = FileAccess.get_file_as_string(data_path)
	var data = JSON.parse_string(json_text)
	if not data:
		printerr("Failed to parse JSON")
		return

	# 1. Setup Skeleton
	var skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	skeleton.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	var bones_data = data.get("skeleton", [])
	var bone_name_to_id = {}
	
	for i in range(bones_data.size()):
		var b = bones_data[i]
		var bone_name = b["name"]
		skeleton.add_bone(bone_name)
		bone_name_to_id[bone_name] = i

	for i in range(bones_data.size()):
		var b = bones_data[i]
		var parent_name = b["parent"]
		if parent_name != "NULL" and bone_name_to_id.has(parent_name):
			skeleton.set_bone_parent(i, bone_name_to_id[parent_name])
		
		# Set rest pose from world matrix
		var m = b["world_matrix"]
		var basis = Basis(
			Vector3(m[0], m[1], m[2]),
			Vector3(m[4], m[5], m[6]),
			Vector3(m[8], m[9], m[10])
		)
		var pos = Vector3(m[12], m[13], m[14])
		
		# Convert from RF (Z-up?) to Godot (Y-up)
		# This is a guestimate based on typical 3ds Max -> Godot conversions
		# We might need to adjust this.
		var transform = Transform3D(basis, pos)
		skeleton.set_bone_rest(i, transform)
		skeleton.set_bone_pose_position(i, pos)
		skeleton.set_bone_pose_rotation(i, basis.get_rotation_quaternion())

	# 2. Setup Meshes
	var base_path = data_path.get_base_dir()
	for mesh_data in data.get("meshes", []):
		if mesh_data.get("vertices", []).size() == 0: continue
		
		var mi = MeshInstance3D.new()
		mi.name = mesh_data["name"]
		add_child(mi)
		mi.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
		
		var obj_path = base_path + "/" + mesh_data["obj_file"]
		var mesh = load(obj_path)
		if mesh:
			mi.mesh = mesh
		
		# If skinned, attach to skeleton
		if mesh_data.get("bone_indices", []).size() > 0:
			mi.skeleton = skeleton.get_path()
			# Skinning in Godot requires a Skin object
			var skin = Skin.new()
			for i in range(bones_data.size()):
				skin.add_bind(i, skeleton.get_bone_rest(i).inverse())
			mi.skin = skin

	# 3. Setup Animations
	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)
	anim_player.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	
	var anim_lib = AnimationLibrary.new()
	var animations = data.get("animations", {})
	
	for anim_name in animations.keys():
		var anim = Animation.new()
		var tracks = animations[anim_name]
		
		for track_data in tracks:
			var bone_name = track_data["name"]
			var bone_idx = skeleton.find_bone(bone_name)
			if bone_idx == -1: continue
			
			var track_path = "Skeleton3D:" + bone_name
			var pos_track = anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(pos_track, track_path)
			
			var rot_track = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(rot_track, track_path)
			
			for key in track_data.get("positions", []):
				var p = key["p"]
				anim.position_track_insert_key(pos_track, key["t"], Vector3(p[0], p[1], p[2]))
				
			for key in track_data.get("rotations", []):
				var q = key["q"]
				anim.rotation_track_insert_key(rot_track, key["t"], Quaternion(q[0], q[1], q[2], q[3]))
		
		anim_lib.add_animation(anim_name, anim)
	
	anim_player.add_animation_library("", anim_lib)
	
	print("Import complete for: ", data_path)
	
	# Auto-save as scene if we are in the editor
	if Engine.is_editor_hint():
		var packed_scene = PackedScene.new()
		var result = packed_scene.pack(self)
		if result == OK:
			var save_path = base_path + "/wing.tscn"
			ResourceSaver.save(packed_scene, save_path)
			print("Saved to: ", save_path)
