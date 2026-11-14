extends CharacterBody3D

class_name SlimePlayer

@export var base_speed: float = 6.2
@export var acceleration: float = 18.0
@export var friction: float = 14.0
@export var base_digestion_duration: float = 4.5

var max_hp: float = 100.0
var hp: float = 100.0

var is_digesting: bool = false
var digestion_timer: float = 0.0
var digestion_duration: float = 4.5
var current_prey_data: Dictionary = {}

var visual_scale: Vector3 = Vector3.ONE
var target_visual_scale: Vector3 = Vector3.ONE

# Growth: starts small, grows per digestion until it plugs a corridor.
# At MAX_GROWTH the 1.4m base collider is ~2.6m in a 3m corridor, so adventurers can't slip past.
const START_GROWTH: float = 0.5
const MAX_GROWTH: float = 1.85
const GROWTH_PER_MEAL: float = 0.12
const BASE_BODY_SIZE: float = 1.4
const BASE_ENGULF_SIZE: float = 1.7
const BASE_HEIGHT: float = 0.75
var growth_factor: float = START_GROWTH  # target
var current_growth: float = START_GROWTH # smoothed toward target

@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var engulf_shape: CollisionShape3D = $EngulfArea/CollisionShape3D

# References
@onready var visual_root: Node3D = $VisualRoot
@onready var cube_mesh: MeshInstance3D = $VisualRoot/CubeMesh
@onready var core_mesh: MeshInstance3D = $VisualRoot/CoreMesh
@onready var loot_container: Node3D = $VisualRoot/LootContainer
@onready var engulfed_container: Node3D = $VisualRoot/EngulfedContainer
@onready var acid_bubbles: CPUParticles3D = $VisualRoot/AcidBubbles
@onready var trail_particles: CPUParticles3D = $TrailParticles
@onready var engulf_area: Area3D = $EngulfArea

var slime_mat: StandardMaterial3D
var flash_timer: float = 0.0
var original_albedo: Color = Color(0.2, 0.92, 0.38, 0.55)
var digesting_albedo: Color = Color(0.5, 0.85, 0.15, 0.65)
var flash_color: Color = Color(1.0, 0.2, 0.2, 0.75)

func _ready() -> void:
	# Duplicate material to avoid sharing instance
	slime_mat = cube_mesh.get_active_material(0).duplicate() as StandardMaterial3D
	cube_mesh.set_surface_override_material(0, slime_mat)

	# Own copies so resizing never touches the cached scene resources
	body_shape.shape = body_shape.shape.duplicate()
	engulf_shape.shape = engulf_shape.shape.duplicate()
	visual_scale = Vector3.ONE * current_growth
	_apply_size()

	max_hp = 100.0 + GameManager.get_bonus_max_hp()
	hp = max_hp
	GameManager.player_hp_changed.emit(hp, max_hp)
	
	acid_bubbles.emitting = false
	engulf_area.body_entered.connect(_on_engulf_area_body_entered)
	
	GameManager.buff_gained.connect(_on_buff_gained)

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	
	_handle_growth(delta)
	_handle_movement(delta)
	_handle_digestion(delta)
	_handle_regen(delta)
	_handle_wobble_and_visuals(delta)

func _handle_growth(delta: float) -> void:
	if is_equal_approx(current_growth, growth_factor):
		return
	current_growth = move_toward(current_growth, growth_factor, 0.4 * delta)
	_apply_size()

func _apply_size() -> void:
	var body_size = BASE_BODY_SIZE * current_growth
	(body_shape.shape as BoxShape3D).size = Vector3.ONE * body_size
	body_shape.position.y = BASE_HEIGHT * current_growth
	visual_root.position.y = BASE_HEIGHT * current_growth
	var reach = BASE_ENGULF_SIZE * current_growth * (1.0 + GameManager.level("reach") * 0.25)
	(engulf_shape.shape as BoxShape3D).size = Vector3(reach, BASE_ENGULF_SIZE * current_growth, reach)
	engulf_shape.position.y = BASE_HEIGHT * current_growth

func _handle_regen(delta: float) -> void:
	var regen = GameManager.level("regen") * 1.5
	if regen > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + regen * delta)
		GameManager.player_hp_changed.emit(hp, max_hp)

func _handle_movement(delta: float) -> void:
	var move_dir = Vector3.ZERO
	if Input.is_action_pressed("move_up"):
		move_dir.z -= 1.0
	if Input.is_action_pressed("move_down"):
		move_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		move_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		move_dir.x += 1.0
	
	move_dir = move_dir.normalized()
	
	var current_speed = base_speed * GameManager.get_speed_multiplier()
	
	if move_dir.length_squared() > 0.01:
		# Accelerate
		velocity.x = move_toward(velocity.x, move_dir.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * current_speed, acceleration * delta)
		
		# Squash and stretch along movement vector
		var move_speed_ratio = velocity.length() / current_speed
		var squish_x = 1.0 + (abs(move_dir.x) * 0.18 - abs(move_dir.z) * 0.1) * move_speed_ratio
		var squish_z = 1.0 + (abs(move_dir.z) * 0.18 - abs(move_dir.x) * 0.1) * move_speed_ratio
		var squish_y = 1.0 - (0.16 * move_speed_ratio)
		target_visual_scale = Vector3(squish_x, squish_y, squish_z) * current_growth
		
		trail_particles.emitting = true
		
		# Occasional soft squish sound
		if randf() < 0.015:
			AudioManager.play_squish()
	else:
		# Decelerate / friction
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		trail_particles.emitting = false
		
		# Idle gentle breathing wobble
		var breathe = sin(Time.get_ticks_msec() * 0.003) * 0.04
		target_visual_scale = Vector3(1.0 + breathe, 1.0 - breathe, 1.0 + breathe) * current_growth
	
	# Lane assist: once big, pull the off-axis toward the corridor center so the
	# cube slides into side openings instead of snagging on wall corners.
	# Corridor centers sit on multiples of CELL_SIZE (DungeonBuilder.GRID_SIZE is odd).
	var lane_t = clampf((current_growth - 1.0) / (MAX_GROWTH - 1.0), 0.0, 1.0)
	if lane_t > 0.0 and move_dir != Vector3.ZERO:
		var cell = DungeonBuilder.CELL_SIZE
		if absf(move_dir.x) < 0.01:
			velocity.x = (snappedf(global_position.x, cell) - global_position.x) * 10.0 * lane_t
		elif absf(move_dir.z) < 0.01:
			velocity.z = (snappedf(global_position.z, cell) - global_position.z) * 10.0 * lane_t

	# Apply gravity just in case
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	
	move_and_slide()

func _handle_wobble_and_visuals(delta: float) -> void:
	# Spring smooth lerp to target visual scale
	visual_scale = visual_scale.lerp(target_visual_scale, 12.0 * delta)
	visual_root.scale = visual_scale
	
	# Gently rotate items inside
	loot_container.rotation.y += 0.4 * delta
	
	# Bobbing nucleus core
	core_mesh.position.y = sin(Time.get_ticks_msec() * 0.004) * 0.1
	
	# Handle hit flash
	if flash_timer > 0.0:
		flash_timer -= delta
		slime_mat.albedo_color = flash_color
	else:
		slime_mat.albedo_color = digesting_albedo if is_digesting else original_albedo

func _handle_digestion(delta: float) -> void:
	if not is_digesting:
		return
	
	digestion_timer -= delta
	var progress_ratio = 1.0 - clampf(digestion_timer / digestion_duration, 0.0, 1.0)
	GameManager.digestion_progress.emit(progress_ratio, maxf(0.0, digestion_timer))
	
	# Spin trapped prey inside
	if engulfed_container.get_child_count() > 0:
		var prey = engulfed_container.get_child(0)
		prey.rotation.y += 3.0 * delta
		prey.rotation.x = sin(Time.get_ticks_msec() * 0.005) * 0.3
		# Dissolving shrink near end
		var shrink = clampf(digestion_timer / (digestion_duration * 0.5), 0.15, 0.6)
		prey.scale = Vector3.ONE * shrink
	
	if digestion_timer <= 0.0:
		_complete_digestion()

func _complete_digestion() -> void:
	is_digesting = false
	acid_bubbles.emitting = false
	
	# Clear engulfed prey model
	for c in engulfed_container.get_children():
		c.queue_free()
	
	# Audio & FX
	AudioManager.play_digest_done()
	_spawn_floating_text("DIGESTED! +" + str(GameManager.get_score_value(current_prey_data)), Color(0.3, 1.0, 0.4), 40)

	# Grow in mass toward corridor-filling size
	growth_factor = minf(MAX_GROWTH, growth_factor + GROWTH_PER_MEAL)

	var absorb = GameManager.level("absorb") * 15.0
	if absorb > 0.0:
		hp = minf(max_hp, hp + absorb)
		GameManager.player_hp_changed.emit(hp, max_hp)
	
	# Spawn visual loot prop inside slime
	_spawn_loot_prop(current_prey_data)
	
	# Register loot and buffs
	GameManager.record_eaten_adventurer(current_prey_data)
	
	# Trigger panic in surviving companions
	_panic_nearby_companions()

func _panic_nearby_companions() -> void:
	AudioManager.play_panic()
	var adventurers = get_tree().get_nodes_in_group("adventurers")
	for adv in adventurers:
		if is_instance_valid(adv) and adv.has_method("panic_and_flee"):
			var dist = global_position.distance_to(adv.global_position)
			if dist < 22.0:
				adv.panic_and_flee(3.5, global_position)

func _alert_nearby_companions(squad_id: int) -> void:
	AudioManager.play_enraged()
	var adventurers = get_tree().get_nodes_in_group("adventurers")
	for adv in adventurers:
		if is_instance_valid(adv) and adv.has_method("enrage_and_chase"):
			# Enrage same squad or any adventurers close by
			if adv.squad_id == squad_id or global_position.distance_to(adv.global_position) < 14.0:
				adv.enrage_and_chase(self)

func _on_engulf_area_body_entered(body: Node3D) -> void:
	if GameManager.is_game_over:
		return
	
	if body.is_in_group("adventurers"):
		var adventurer = body as Adventurer
		if adventurer == null or adventurer.is_engulfed:
			return
		
		# If currently digesting, cannot swallow another!
		if is_digesting:
			# Player cannot eat! Adventurer will attack if enraged
			return
		
		# Check armor requirement
		if adventurer.is_armored and GameManager.level("gauntlets") == 0:
			# Bounce! Too tough to chew
			_bounce_off_armored(adventurer)
			return
		
		# Engulf the adventurer!
		_engulf_adventurer(adventurer)

func _engulf_adventurer(adventurer: Adventurer) -> void:
	is_digesting = true
	current_prey_data = adventurer.get_loot_data()
	
	# Calculate digestion duration based on acid ring buffs
	digestion_duration = base_digestion_duration * GameManager.get_digestion_duration_multiplier()
	digestion_timer = digestion_duration
	
	AudioManager.play_gulp()
	acid_bubbles.emitting = true
	
	# Notify squad companions to enrage and chase!
	_alert_nearby_companions(adventurer.squad_id)
	
	_spawn_floating_text("ENGULFED!", Color(1.0, 0.9, 0.2), 38)
	GameManager.digestion_started.emit(digestion_duration, adventurer.adventurer_name)
	
	# Create trapped visual mini inside slime
	var mini = adventurer.create_mini_mesh()
	engulfed_container.add_child(mini)
	mini.position = Vector3.ZERO
	mini.scale = Vector3.ONE * 0.6
	
	# Remove adventurer from maze
	adventurer.be_engulfed()

func _bounce_off_armored(adventurer: Adventurer) -> void:
	AudioManager.play_bounce()
	take_damage(12.0, "ARMOR CLANG!")
	_spawn_floating_text("TOO TOUGH! NEED GAUNTLETS!", Color(1.0, 0.4, 0.2), 34)
	
	# Knockback
	var bounce_dir = (global_position - adventurer.global_position).normalized()
	bounce_dir.y = 0.0
	velocity = bounce_dir * 9.0

func take_damage(amount: float, reason: String = "") -> void:
	if GameManager.is_game_over:
		return
	
	amount *= GameManager.get_damage_taken_multiplier()
	hp = maxf(0.0, hp - amount)
	flash_timer = 0.25
	AudioManager.play_hurt()
	
	_spawn_floating_text("-%d HP" % int(amount), Color(1.0, 0.2, 0.2), 36)
	GameManager.player_hp_changed.emit(hp, max_hp)
	
	if hp <= 0.0:
		_die()

func _die() -> void:
	AudioManager.play_game_over()
	_spawn_floating_text("DISSOLVED!", Color(1.0, 0.1, 0.1), 48)
	
	# Shrink out
	var tw = create_tween()
	tw.tween_property(visual_root, "scale", Vector3.ZERO, 0.8)
	tw.parallel().tween_property(slime_mat, "albedo_color:a", 0.0, 0.8)
	tw.tween_callback(Callable(GameManager, "trigger_game_over"))

func _spawn_loot_prop(loot: Dictionary) -> void:
	var prop = Node3D.new()
	var mesh_inst = MeshInstance3D.new()
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.2
	mat.metallic = 0.7
	
	var loot_type = loot.get("type", "generic")
	match loot_type:
		"boots":
			var b_mesh = BoxMesh.new()
			b_mesh.size = Vector3(0.18, 0.25, 0.28)
			mesh_inst.mesh = b_mesh
			mat.albedo_color = Color(0.9, 0.75, 0.2)
		"gauntlets":
			var g_mesh = BoxMesh.new()
			g_mesh.size = Vector3(0.24, 0.24, 0.24)
			mesh_inst.mesh = g_mesh
			mat.albedo_color = Color(0.8, 0.2, 0.1)
		"acid_ring":
			var r_mesh = CylinderMesh.new()
			r_mesh.top_radius = 0.14
			r_mesh.bottom_radius = 0.14
			r_mesh.height = 0.08
			mesh_inst.mesh = r_mesh
			mat.albedo_color = Color(0.2, 0.9, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.8, 0.3)
		"crown":
			var c_mesh = CylinderMesh.new()
			c_mesh.top_radius = 0.22
			c_mesh.bottom_radius = 0.18
			c_mesh.height = 0.18
			mesh_inst.mesh = c_mesh
			mat.albedo_color = Color(1.0, 0.85, 0.1)
		"heart_amulet":
			var h_mesh = SphereMesh.new()
			h_mesh.radius = 0.15
			h_mesh.height = 0.28
			mesh_inst.mesh = h_mesh
			mat.albedo_color = Color(0.9, 0.1, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(0.6, 0.1, 0.2)
		_:
			# Shiny gem / coin
			var s_mesh = SphereMesh.new()
			s_mesh.radius = 0.12
			s_mesh.height = 0.22
			mesh_inst.mesh = s_mesh
			mat.albedo_color = Color(0.3, 0.6, 1.0)
	
	mesh_inst.material_override = mat
	prop.add_child(mesh_inst)
	
	# Random float offset inside the 1.5m cube volume
	var offset = Vector3(
		randf_range(-0.45, 0.45),
		randf_range(-0.4, 0.4),
		randf_range(-0.45, 0.45)
	)
	prop.position = offset
	prop.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	loot_container.add_child(prop)

func _spawn_floating_text(text: String, color: Color, size: int) -> void:
	var label_script = load("res://scripts/floating_label.gd")
	var fl = Label3D.new()
	fl.set_script(label_script)
	get_parent().add_child(fl)
	fl.global_position = global_position + Vector3(0, 1.6, 0)
	fl.setup(text, color, size)

func _on_buff_gained(buff_name: String, _desc: String, _icon: String) -> void:
	AudioManager.play_buff()
	_spawn_floating_text(buff_name + "!", Color(0.2, 0.9, 1.0), 38)
	# Check if vitality increased HP
	if buff_name == GameManager.POWERUPS["vitality"]["name"]:
		max_hp = 100.0 + GameManager.get_bonus_max_hp()
		hp = max_hp
		GameManager.player_hp_changed.emit(hp, max_hp)
	# Reach may have changed
	_apply_size()
