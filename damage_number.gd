extends Label

func setup(damage_amount: int):
	text = str(damage_amount)
	modulate = Color.WHITE
	
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_color", Color.RED)
	add_theme_color_override("font_shadow_color", Color.BLACK)
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)
	
	animate_damage()

func animate_damage():
	var tween = create_tween()
	
	tween.parallel().tween_property(self, "global_position", global_position + Vector2(randf_range(-20, 20), -60), 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(self, "scale", Vector2(1.2, 1.2), 0.2)
	tween.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), 0.8).set_delay(0.2)
	
	tween.tween_callback(queue_free)
