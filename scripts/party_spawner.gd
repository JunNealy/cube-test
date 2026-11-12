extends Node

# Manages spawning adventuring parties with companion squad dynamics

@export var max_active_adventurers: int = 8
@export var spawn_interval: float = 16.0

var next_squad_id: int = 1
var spawn_timer: float = 0.0
var spawn_points: Array[Vector3] = []

var adventurer_scene: PackedScene

func _ready() -> void:
	adventurer_scene = load("res://scenes/adventurer.tscn")
	# Setup spawn points around the perimeter of the maze
	spawn_points = [
		Vector3(-18.0, 0.0, -18.0),
		Vector3(18.0, 0.0, -18.0),
		Vector3(-18.0, 0.0, 18.0),
		Vector3(18.0, 0.0, 18.0),
		Vector3(0.0, 0.0, -18.0),
		Vector3(0.0, 0.0, 18.0)
	]
	
	# Initial spawn: 3 parties (e.g. 7 total adventurers)
	call_deferred("_spawn_initial_parties")

func _process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	
	spawn_timer -= delta
	
	var active_count = _get_active_adventurer_count()
	# If count is low, accelerate spawn
	if active_count <= 3 and spawn_timer > 3.0:
		spawn_timer = 3.0
	
	if spawn_timer <= 0.0:
		spawn_timer = spawn_interval
		if active_count < max_active_adventurers:
			_spawn_party()

func _get_active_adventurer_count() -> int:
	var count = 0
	var nodes = get_tree().get_nodes_in_group("adventurers")
	for n in nodes:
		if is_instance_valid(n) and not n.is_engulfed:
			count += 1
	return count

func _spawn_initial_parties() -> void:
	# Intro Party near player: Rogue + Squire (great immediate test of engulf & companion reaction)
	_spawn_party_at(Vector3(6.0, 0.0, 0.0), [Adventurer.Type.ROGUE, Adventurer.Type.SQUIRE])
	
	# Party 1: Rogue + Squire
	_spawn_party_at(spawn_points[0], [Adventurer.Type.ROGUE, Adventurer.Type.SQUIRE])
	
	# Party 2: Mage + Rogue (Provides acid rings and speed)
	_spawn_party_at(spawn_points[1], [Adventurer.Type.MAGE, Adventurer.Type.ROGUE])
	
	# Party 3: Knight + Squire (Tougher party with heavy armor!)
	_spawn_party_at(spawn_points[2], [Adventurer.Type.KNIGHT, Adventurer.Type.SQUIRE])

func _spawn_party() -> void:
	var spawn_pos = spawn_points.pick_random()
	
	# Decide party composition based on game progression
	var comp: Array[Adventurer.Type] = []
	var roll = randf()
	if roll < 0.35:
		comp = [Adventurer.Type.ROGUE, Adventurer.Type.SQUIRE]
	elif roll < 0.7:
		comp = [Adventurer.Type.MAGE, Adventurer.Type.ROGUE]
	else:
		comp = [Adventurer.Type.KNIGHT, Adventurer.Type.MAGE]
	
	_spawn_party_at(spawn_pos, comp)

func _spawn_party_at(base_pos: Vector3, composition: Array[Adventurer.Type]) -> void:
	var squad = next_squad_id
	next_squad_id += 1
	
	for i in range(composition.size()):
		var adv_type = composition[i]
		var adv = adventurer_scene.instantiate() as Adventurer
		adv.adventurer_type = adv_type
		adv.squad_id = squad
		
		var offset = Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
		adv.position = base_pos + offset
		get_parent().add_child(adv)
