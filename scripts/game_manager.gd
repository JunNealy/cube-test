extends Node

# Global game state manager for Gelatinous Cube demo

signal score_updated(score: int, high_score: int)
signal buff_gained(buff_name: String, description: String, icon: String)
signal digestion_started(duration: float, prey_name: String)
signal digestion_progress(ratio: float, time_left: float)
signal digestion_finished(loot_data: Dictionary)
signal player_hp_changed(hp: float, max_hp: float)
signal game_over_triggered(final_score: int, is_new_record: bool, stats: Dictionary)

var current_score: int = 0
var high_score: int = 0
var adventurers_digested: int = 0
var is_game_over: bool = false

# Buff counters
var boots_count: int = 0
var has_gauntlets: bool = false
var acid_rings: int = 0
var bonus_max_hp: float = 0.0

# Contained loot inside mass
var contained_loot: Array[Dictionary] = []

const SAVE_PATH = "user://gelatinous_highscore.save"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	load_high_score()

func _setup_inputs() -> void:
	# Ensure standard WASD + Arrow controls exist
	_add_action_key("move_up", [KEY_W, KEY_UP])
	_add_action_key("move_down", [KEY_S, KEY_DOWN])
	_add_action_key("move_left", [KEY_A, KEY_LEFT])
	_add_action_key("move_right", [KEY_D, KEY_RIGHT])
	_add_action_key("restart", [KEY_R])

func _add_action_key(action_name: String, keys: Array[Key]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for k in keys:
		var ev = InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action_name, ev)

func reset_game() -> void:
	current_score = 0
	adventurers_digested = 0
	is_game_over = false
	boots_count = 0
	has_gauntlets = false
	acid_rings = 0
	bonus_max_hp = 0.0
	contained_loot.clear()
	emit_signal("score_updated", current_score, high_score)
	get_tree().reload_current_scene()

func add_score(amount: int) -> void:
	current_score += amount
	var is_new_record = false
	if current_score > high_score:
		high_score = current_score
		is_new_record = true
		save_high_score()
	emit_signal("score_updated", current_score, high_score)

func record_eaten_adventurer(loot: Dictionary) -> void:
	adventurers_digested += 1
	contained_loot.append(loot)
	add_score(loot.get("score_value", 100))
	
	# Apply buff based on loot
	var loot_type = loot.get("type", "generic")
	match loot_type:
		"boots":
			boots_count += 1
			emit_signal("buff_gained", "Boots of Elvenkind", "+20% Movement Speed (Stacks)", "👟")
		"gauntlets":
			has_gauntlets = true
			emit_signal("buff_gained", "Gauntlets of Ogre Power", "Can now engulf Armored Knights!", "🥊")
		"acid_ring":
			acid_rings += 1
			emit_signal("buff_gained", "Ring of Bile Acid", "-25% Digestion Time (Faster reset!)", "💍")
		"heart_amulet":
			bonus_max_hp += 25.0
			emit_signal("buff_gained", "Amulet of Vitality", "+25 Max Slime Mass & Full Heal", "💚")
		"crown":
			emit_signal("buff_gained", "King's Golden Crown", "+1000 Massive Royal Bounty!", "👑")
		"gem":
			emit_signal("buff_gained", "Arcane Gem", "+400 Arcane Value", "💎")
	
	emit_signal("digestion_finished", loot)

func get_speed_multiplier() -> float:
	return 1.0 + (boots_count * 0.20)

func get_digestion_duration_multiplier() -> float:
	# Each acid ring decreases digestion time by 25% (min 0.35x)
	var reduction = acid_rings * 0.25
	return clampf(1.0 - reduction, 0.35, 1.0)

func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	var is_new_record = (current_score >= high_score and current_score > 0)
	var stats = {
		"adventurers_digested": adventurers_digested,
		"boots_count": boots_count,
		"has_gauntlets": has_gauntlets,
		"acid_rings": acid_rings,
		"loot_count": contained_loot.size(),
		"contained_loot": contained_loot
	}
	emit_signal("game_over_triggered", current_score, is_new_record, stats)

func save_high_score() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		var d = { "high_score": high_score }
		f.store_string(JSON.stringify(d))

func load_high_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var txt = f.get_as_text()
			var parse = JSON.parse_string(txt)
			if parse is Dictionary and parse.has("high_score"):
				high_score = int(parse["high_score"])
	emit_signal("score_updated", current_score, high_score)
