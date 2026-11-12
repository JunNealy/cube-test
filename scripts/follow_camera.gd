extends Camera3D

@export var target_path: NodePath
@export var smooth_speed: float = 6.0
@export var camera_offset: Vector3 = Vector3(0, 15.0, 10.0)

var target: Node3D

func _ready() -> void:
	if not target_path.is_empty():
		target = get_node(target_path) as Node3D

func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		var target_pos = target.global_position + camera_offset
		global_position = global_position.lerp(target_pos, smooth_speed * delta)
		look_at(target.global_position + Vector3(0, 0.5, 0), Vector3.UP)
