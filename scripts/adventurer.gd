extends CharacterBody3D

class_name Adventurer

enum Type { ROGUE, MAGE, SQUIRE, KNIGHT }
enum State { PATROL, ENRAGED_CHASE, PANICKED_FLEE, ENGULFED }

@export var adventurer_type: Type = Type.ROGUE
@export var squad_id: int = 0

var adventurer_name: String = "Rogue"
var move_speed: float = 3.5
var is_armored: bool = false
var state: State = State.PATROL
var is_engulfed: bool = false

# Combat
var attack_damage: float = 18.0
var attack_cooldown: float = 1.1
var attack_timer: float = 0.0
var attack_range: float = 1.75

# AI & Pathing
var target_player: SlimePlayer = null
var flee_timer: float = 0.0
var flee_origin: Vector3 = Vector3.ZERO
var patrol_dir: Vector3 = Vector3.FORWARD
var patrol_change_timer: float = 0.0
var speech_timer: float = 0.0

# Visual parts
var visual_root: Node3D
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var hat_mesh: MeshInstance3D
var weapon_pivot: Node3D
var status_label: Label3D

var walk_cycle: float = 0.0

var dungeon: DungeonBuilder

func _ready() -> void:
	add_to_group("adventurers")
	dungeon = get_node_or_null("../DungeonBuilder") as DungeonBuilder
	_build_visuals()
	_configure_type_stats()
	patrol_dir = _get_random_cardinal_dir()
	speech_timer = randf_range(3.0, 8.0)

func _configure_type_stats() -> void:
	match adventurer_type:
		Type.ROGUE:
			adventurer_name = "Elven Rogue"
			move_speed = 4.3
			is_armored = false
			attack_damage = 14.0
		Type.MAGE:
			adventurer_name = "Arcane Mage"
			move_speed = 3.2
			is_armored = false
			attack_damage = 16.0
		Type.SQUIRE:
			adventurer_name = "Brave Squire"
			move_speed = 3.6
			is_armored = false
			attack_damage = 18.0
		Type.KNIGHT:
			adventurer_name = "Ironclad Knight"
			move_speed = 2.8
			is_armored = true
			attack_damage = 25.0

	# Later spawns are tougher
	var threat_mult = GameManager.get_threat_multiplier()
	move_speed *= threat_mult
	attack_damage *= threat_mult

func _build_visuals() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)
	
	# Body
	body_mesh = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.2
	body_mesh.mesh = cap
	body_mesh.position.y = 0.65
	visual_root.add_child(body_mesh)
	
	# Head
	head_mesh = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = 0.28
	sph.height = 0.56
	head_mesh.mesh = sph
	head_mesh.position.y = 1.4
	visual_root.add_child(head_mesh)
	
	# Material setup based on type
	var body_mat = StandardMaterial3D.new()
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.95, 0.8, 0.68) # skin tone
	head_mesh.material_override = head_mat
	
	# Hat & Weapon
	hat_mesh = MeshInstance3D.new()
	visual_root.add_child(hat_mesh)
	
	weapon_pivot = Node3D.new()
	weapon_pivot.position = Vector3(0.42, 0.7, 0.2)
	visual_root.add_child(weapon_pivot)
	var weapon_mesh = MeshInstance3D.new()
	
	match adventurer_type:
		Type.ROGUE:
			body_mat.albedo_color = Color(0.2, 0.6, 0.3) # leather green
			var hood = SphereMesh.new()
			hood.radius = 0.32
			hood.height = 0.4
			hat_mesh.mesh = hood
			hat_mesh.position.y = 1.55
			var hood_mat = StandardMaterial3D.new()
			hood_mat.albedo_color = Color(0.15, 0.45, 0.22)
			hat_mesh.material_override = hood_mat
			
			# Dagger
			var d_mesh = BoxMesh.new()
			d_mesh.size = Vector3(0.08, 0.5, 0.08)
			weapon_mesh.mesh = d_mesh
		Type.MAGE:
			body_mat.albedo_color = Color(0.2, 0.3, 0.75) # arcane blue
			# Pointy Cone Hat
			var cone = CylinderMesh.new()
			cone.top_radius = 0.02
			cone.bottom_radius = 0.38
			cone.height = 0.6
			hat_mesh.mesh = cone
			hat_mesh.position.y = 1.8
			var hat_mat = StandardMaterial3D.new()
			hat_mat.albedo_color = Color(0.15, 0.15, 0.5)
			hat_mesh.material_override = hat_mat
			
			# Staff
			var s_mesh = CylinderMesh.new()
			s_mesh.top_radius = 0.04
			s_mesh.bottom_radius = 0.04
			s_mesh.height = 1.3
			weapon_mesh.mesh = s_mesh
		Type.SQUIRE:
			body_mat.albedo_color = Color(0.7, 0.3, 0.2) # red tunic
			# Iron Cap
			var cap_mesh = SphereMesh.new()
			cap_mesh.radius = 0.32
			cap_mesh.height = 0.32
			hat_mesh.mesh = cap_mesh
			hat_mesh.position.y = 1.6
			var cap_mat = StandardMaterial3D.new()
			cap_mat.albedo_color = Color(0.5, 0.5, 0.55)
			cap_mat.metallic = 0.8
			hat_mesh.material_override = cap_mat
			
			# Sword
			var sw_mesh = BoxMesh.new()
			sw_mesh.size = Vector3(0.1, 0.8, 0.1)
			weapon_mesh.mesh = sw_mesh
		Type.KNIGHT:
			body_mat.albedo_color = Color(0.75, 0.8, 0.85) # full silver plate
			body_mat.metallic = 0.95
			body_mat.roughness = 0.25
			
			# Horned Helmet
			var h_mesh = CylinderMesh.new()
			h_mesh.top_radius = 0.28
			h_mesh.bottom_radius = 0.3
			h_mesh.height = 0.5
			hat_mesh.mesh = h_mesh
			hat_mesh.position.y = 1.55
			var h_mat = StandardMaterial3D.new()
			h_mat.albedo_color = Color(0.9, 0.8, 0.3) # gold trim
			h_mat.metallic = 0.9
			hat_mesh.material_override = h_mat
			
			# Greatsword
			var gs_mesh = BoxMesh.new()
			gs_mesh.size = Vector3(0.15, 1.2, 0.15)
			weapon_mesh.mesh = gs_mesh
	
	body_mesh.material_override = body_mat
	
	var w_mat = StandardMaterial3D.new()
	w_mat.metallic = 0.8
	w_mat.albedo_color = Color(0.8, 0.8, 0.8)
	weapon_mesh.material_override = w_mat
	weapon_pivot.add_child(weapon_mesh)

	# X-ray silhouette so adventurers stay visible behind walls
	for mesh in [body_mesh, head_mesh, hat_mesh, weapon_mesh]:
		var mat = mesh.material_override as BaseMaterial3D
		if mat:
			mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
			mat.stencil_color = Color(1.0, 0.35, 0.25, 0.6)

	# Overhead Status / Speech Billboard
	status_label = Label3D.new()
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.font_size = 28
	status_label.position.y = 2.1
	status_label.outline_size = 6
	status_label.outline_modulate = Color(0, 0, 0, 0.8)
	status_label.text = ""
	add_child(status_label)

func _physics_process(delta: float) -> void:
	if is_engulfed or GameManager.is_game_over:
		return
	
	attack_timer = maxf(0.0, attack_timer - delta)
	
	match state:
		State.PATROL:
			_process_patrol(delta)
		State.ENRAGED_CHASE:
			_process_chase(delta)
		State.PANICKED_FLEE:
			_process_flee(delta)
	
	# Handle walking animation (bobbing and swinging)
	if velocity.length_squared() > 0.1:
		walk_cycle += delta * 12.0
		visual_root.position.y = abs(sin(walk_cycle)) * 0.12
		visual_root.rotation.z = sin(walk_cycle) * 0.08
		weapon_pivot.rotation.x = sin(walk_cycle) * 0.4
		
		# Look in direction of motion
		var look_dir = Vector2(velocity.x, velocity.z)
		if look_dir.length_squared() > 0.01:
			var target_rot = atan2(-look_dir.x, -look_dir.y)
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rot, 10.0 * delta)
	else:
		visual_root.position.y = move_toward(visual_root.position.y, 0.0, 5.0 * delta)
		visual_root.rotation.z = 0.0
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	
	move_and_slide()

func _process_patrol(delta: float) -> void:
	patrol_change_timer -= delta
	speech_timer -= delta
	
	if speech_timer <= 0.0:
		speech_timer = randf_range(7.0, 15.0)
		_show_speech(_get_patrol_bark(), Color(0.9, 0.9, 0.9), 2.2)
	
	# If bumping into a wall or timer expired, pick new direction
	if is_on_wall() or patrol_change_timer <= 0.0:
		patrol_dir = _get_random_cardinal_dir(patrol_dir if is_on_wall() else Vector3.ZERO)
		patrol_change_timer = randf_range(2.0, 5.0)
	
	velocity.x = patrol_dir.x * move_speed * 0.65
	velocity.z = patrol_dir.z * move_speed * 0.65

func _process_chase(delta: float) -> void:
	if not is_instance_valid(target_player):
		state = State.PATROL
		status_label.text = ""
		return
	
	var to_player = target_player.global_position - global_position
	to_player.y = 0.0
	var dist = to_player.length()

	# Follow the maze toward the player instead of walking into walls
	var goal = target_player.global_position
	if dungeon:
		goal = dungeon.next_waypoint(global_position, goal)
	var to_goal = goal - global_position
	to_goal.y = 0.0

	# Chase at higher speed
	var chase_speed = move_speed * 1.35
	var dir = to_goal.normalized()
	
	# If navigating maze walls, adjust if stuck
	if is_on_wall():
		# Try nudging laterally
		var perp = Vector3(-dir.z, 0, dir.x)
		dir = (dir + perp * 0.6).normalized()
	
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	
	# Enraged adventurers strike whenever in range
	if dist <= attack_range and attack_timer <= 0.0:
		_attack_player()

func _process_flee(delta: float) -> void:
	flee_timer -= delta
	if flee_timer <= 0.0:
		state = State.PATROL
		status_label.text = ""
		return
	
	# Run away from flee origin
	var away = (global_position - flee_origin)
	away.y = 0.0
	if away.length_squared() < 0.1:
		away = _get_random_cardinal_dir()
	var flee_dir = away.normalized()
	
	if is_on_wall():
		flee_dir = Vector3(-flee_dir.z, 0, flee_dir.x)
	
	var flee_speed = move_speed * 1.4
	velocity.x = flee_dir.x * flee_speed
	velocity.z = flee_dir.z * flee_speed

func _attack_player() -> void:
	attack_timer = attack_cooldown
	
	# Weapon swing animation
	var tw = create_tween()
	tw.tween_property(weapon_pivot, "rotation:x", -1.4, 0.12)
	tw.tween_property(weapon_pivot, "rotation:x", 0.0, 0.25)
	
	target_player.take_damage(attack_damage, adventurer_name + " Strike!")
	_show_speech("DIE, OOZE!", Color(1.0, 0.3, 0.3), 1.5)

func enrage_and_chase(player: SlimePlayer) -> void:
	if is_engulfed:
		return
	state = State.ENRAGED_CHASE
	target_player = player
	_show_speech(_get_enraged_bark(), Color(1.0, 0.2, 0.2), 3.0)

func panic_and_flee(duration: float, origin: Vector3) -> void:
	if is_engulfed:
		return
	state = State.PANICKED_FLEE
	flee_timer = duration
	flee_origin = origin
	_show_speech(_get_panic_bark(), Color(0.3, 0.8, 1.0), 3.0)

func be_engulfed() -> void:
	is_engulfed = true
	state = State.ENGULFED
	# Disable physics collision while digested
	$CollisionShape3D.set_deferred("disabled", true)
	hide()

func get_loot_data() -> Dictionary:
	match adventurer_type:
		Type.ROGUE:
			var is_boots = randf() < 0.65
			return {
				"name": "Boots of Elvenkind" if is_boots else "Rogue's Stolen Coin Purse",
				"type": "boots" if is_boots else "gold",
				"score_value": 200 if is_boots else 150,
				"description": "+20% Movement Speed" if is_boots else "+150 Dungeon Gold"
			}
		Type.MAGE:
			var is_ring = randf() < 0.65
			return {
				"name": "Ring of Bile Acid" if is_ring else "Arcane Crystal",
				"type": "acid_ring" if is_ring else "gem",
				"score_value": 300 if is_ring else 200,
				"description": "-25% Digestion Time" if is_ring else "+200 Arcane Value"
			}
		Type.SQUIRE:
			return {
				"name": "Gauntlets of Ogre Power",
				"type": "gauntlets",
				"score_value": 350,
				"description": "Crush armored shells! Enables eating Knights."
			}
		Type.KNIGHT:
			var is_crown = randf() < 0.5
			return {
				"name": "King's Golden Crown" if is_crown else "Amulet of Vitality",
				"type": "crown" if is_crown else "heart_amulet",
				"score_value": 1000 if is_crown else 600,
				"description": "+1000 High Score Bounty!" if is_crown else "+25 Max HP & Full Heal"
			}
	return { "name": "Loot", "type": "generic", "score_value": 100 }

func create_mini_mesh() -> Node3D:
	var mini = Node3D.new()
	var m = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 0.8
	m.mesh = cap
	m.material_override = body_mesh.material_override
	mini.add_child(m)
	return mini

func _show_speech(text: String, color: Color, duration: float) -> void:
	status_label.text = text
	status_label.modulate = color
	var tw = create_tween()
	tw.tween_interval(duration)
	tw.tween_property(status_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(Callable(self, "_clear_speech"))

func _clear_speech() -> void:
	status_label.text = ""
	status_label.modulate.a = 1.0

func _get_patrol_bark() -> String:
	var barks = [
		"Stay alert...",
		"Smells like vinegar?",
		"Keep torches lit!",
		"Watch for traps!",
		"Gold is near..."
	]
	return barks.pick_random()

func _get_enraged_bark() -> String:
	var barks = [
		"NOOO! THE JELLY!",
		"KILL THE BEAST!",
		"AVENGE OUR BROTHER!",
		"CUT IT OPEN!",
		"DIE, SLIME!"
	]
	return barks.pick_random()

func _get_panic_bark() -> String:
	var barks = [
		"IT DISSOLVED HIM!",
		"RUN FOR YOUR LIVES!",
		"RETREAT!",
		"BY THE GODS, FLEE!",
		"WE CAN'T STOP IT!"
	]
	return barks.pick_random()

func _get_random_cardinal_dir(exclude: Vector3 = Vector3.ZERO) -> Vector3:
	var dirs: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	if exclude != Vector3.ZERO:
		dirs.erase(exclude)
	return dirs.pick_random()
