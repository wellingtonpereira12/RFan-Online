extends Label3D

func setup(text_val: String, color: Color, is_critical: bool = false):
	text = text_val
	modulate = color
	outline_modulate = Color.BLACK
	outline_size = 8
	
	if is_critical:
		font_size = 48
		# Pequeno tremor inicial para críticos
		var t = create_tween()
		t.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
		t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	else:
		font_size = 32

	# Animação de "queda" para a direita
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Movimento: Sobe um pouquinho e depois cai para a direita
	# Como é um Billboard, o eixo X local é relativo à câmera
	tween.tween_property(self, "position:y", position.y - 1.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:x", position.x + 1.5, 1.2).set_trans(Tween.TRANS_LINEAR)
	
	# Desaparece (Fade Out)
	tween.tween_property(self, "modulate:a", 0.0, 1.0).set_delay(0.2)
	
	# Se auto-destrói ao acabar
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
