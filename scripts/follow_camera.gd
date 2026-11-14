extends Camera3D

@export var target_path: NodePath
@export var smooth_speed: float = 6.0
@export var camera_offset: Vector3 = Vector3(0, 15.0, 10.0)
# Offset multiplier at the slime's smallest and largest size
@export var min_zoom: float = 0.85
@export var max_zoom: float = 1.35

var target: Node3D

func _ready() -> void:
	if not target_path.is_empty():
		target = get_node(target_path) as Node3D

func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		var zoom = 1.0
		if target is SlimePlayer:
			var t = inverse_lerp(SlimePlayer.START_GROWTH, SlimePlayer.MAX_GROWTH, target.current_growth)
			zoom = lerpf(min_zoom, max_zoom, t)
		var target_pos = target.global_position + camera_offset * zoom
		global_position = global_position.lerp(target_pos, smooth_speed * delta)
		look_at(target.global_position + Vector3(0, 0.5, 0), Vector3.UP)
