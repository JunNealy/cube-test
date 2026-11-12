extends OmniLight3D

var base_energy: float = 1.3
var noise_offset: float = 0.0

func _ready() -> void:
	noise_offset = randf() * 100.0

func _process(delta: float) -> void:
	var t = (Time.get_ticks_msec() * 0.006) + noise_offset
	var flicker = sin(t) * 0.15 + sin(t * 2.3) * 0.1 + (randf() - 0.5) * 0.08
	light_energy = base_energy + flicker
