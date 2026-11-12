extends Label3D

var velocity: Vector3 = Vector3(0, 1.8, 0)
var lifetime: float = 1.2
var timer: float = 0.0

func setup(p_text: String, p_color: Color = Color.WHITE, p_size: int = 36, p_velocity: Vector3 = Vector3(0, 2.0, 0)) -> void:
	text = p_text
	modulate = p_color
	font_size = p_size
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	outline_size = 8
	outline_modulate = Color(0, 0, 0, 0.8)
	velocity = p_velocity + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.5), randf_range(-0.5, 0.5))

func _process(delta: float) -> void:
	timer += delta
	position += velocity * delta
	velocity.y = maxf(0.3, velocity.y - 1.5 * delta)
	
	# Fade out near end of lifetime
	if timer > lifetime * 0.6:
		var alpha = 1.0 - ((timer - lifetime * 0.6) / (lifetime * 0.4))
		modulate.a = clampf(alpha, 0.0, 1.0)
		outline_modulate.a = clampf(alpha * 0.8, 0.0, 1.0)
	
	if timer >= lifetime:
		queue_free()
