extends Node

# Manages spawning adventuring parties with companion squad dynamics

@export var max_active_adventurers: int = 12
@export var spawn_interval: float = 14.0

var next_squad_id: int = 1
var spawn_timer: float = 0.0

var adventurer_scene: PackedScene
@onready var dungeon: DungeonBuilder = get_node("../DungeonBuilder")
@onready var player: Node3D = get_node("../Slime")

func _ready() -> void:
	adventurer_scene = load("res://scenes/adventurer.tscn")
	call_deferred("_spawn_initial_parties")

# Random corridor cell far enough from the player that spawns aren't unfair
func _far_spawn_point() -> Vector3:
	return dungeon.get_random_floor_position(player.global_position, 18.0)

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
	_spawn_party_at(dungeon.get_random_floor_position(player.global_position, 5.0, 9.0), [Adventurer.Type.ROGUE, Adventurer.Type.SQUIRE])

	# Party 1: Rogue + Squire
	_spawn_party_at(_far_spawn_point(), [Adventurer.Type.ROGUE, Adventurer.Type.SQUIRE])

	# Party 2: Mage + Rogue (Provides acid rings and speed)
	_spawn_party_at(_far_spawn_point(), [Adventurer.Type.MAGE, Adventurer.Type.ROGUE])

	# Party 3: Knight + Squire (Tougher party with heavy armor!)
	_spawn_party_at(_far_spawn_point(), [Adventurer.Type.KNIGHT, Adventurer.Type.SQUIRE])

	# Party 4: Mage + Squire
	_spawn_party_at(_far_spawn_point(), [Adventurer.Type.MAGE, Adventurer.Type.SQUIRE])

func _spawn_party() -> void:
	var spawn_pos = _far_spawn_point()
	
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
		
		var offset = Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
		adv.position = base_pos + offset
		get_parent().add_child(adv)
