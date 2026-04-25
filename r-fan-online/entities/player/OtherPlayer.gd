extends CharacterBody3D

@onready var label = $NameTag
var player_id = ""

func setup(id: String, p_name: String):
	player_id = id
	$NameTag.text = p_name

func update_position(new_pos: Vector3):
	# Movimento suave (interpolação)
	var tween = create_tween()
	tween.tween_property(self, "global_position", new_pos, 0.1)
