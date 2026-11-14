extends Node

# Global game state manager for Gelatinous Cube demo

signal score_updated(score: int, high_score: int)
signal buff_gained(buff_name: String, description: String, icon: String)
signal digestion_started(duration: float, prey_name: String)
signal digestion_progress(ratio: float, time_left: float)
signal digestion_finished(loot_data: Dictionary)
signal player_hp_changed(hp: float, max_hp: float)
signal game_over_triggered(final_score: int, is_new_record: bool, stats: Dictionary)
signal powerup_choices_offered(choices: Array)

const CHOICE_COUNT: int = 3

# id -> display info. max = how many times it can be picked.
const POWERUPS = {
	"boots": { "name": "Boots of Elvenkind", "desc": "+20% Movement Speed", "icon": "👟", "max": 5 },
	"gauntlets": { "name": "Gauntlets of Ogre Power", "desc": "Can now engulf Armored Knights!", "icon": "🥊", "max": 1 },
	"acid_ring": { "name": "Ring of Bile Acid", "desc": "-25% Digestion Time", "icon": "💍", "max": 3 },
	"vitality": { "name": "Amulet of Vitality", "desc": "+25 Max Slime Mass & Full Heal", "icon": "💚", "max": 99 },
	"regen": { "name": "Regenerating Ooze", "desc": "+1.5 HP per second", "icon": "🫧", "max": 5 },
	"hide": { "name": "Rubbery Membrane", "desc": "-15% Damage Taken", "icon": "🛡", "max": 4 },
	"glutton": { "name": "Gluttonous Maw", "desc": "+50% Score from Digestion", "icon": "👄", "max": 5 },
	"reach": { "name": "Sticky Pseudopods", "desc": "+25% Engulf Reach", "icon": "🦑", "max": 4 },
	"absorb": { "name": "Nutrient Absorption", "desc": "Heal 15 HP per digestion", "icon": "🍖", "max": 5 },
}

# Loot type carried by prey -> power-up guaranteed in the offer
const LOOT_TO_POWERUP = {
	"boots": "boots",
	"gauntlets": "gauntlets",
	"acid_ring": "acid_ring",
	"heart_amulet": "vitality",
}

var powerup_levels: Dictionary = {}

var current_score: int = 0
var high_score: int = 0
var adventurers_digested: int = 0
var is_game_over: bool = false

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
	powerup_levels.clear()
	contained_loot.clear()
	emit_signal("score_updated", current_score, high_score)
	get_tree().paused = false
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
	add_score(get_score_value(loot))
	emit_signal("digestion_finished", loot)
	offer_powerups(LOOT_TO_POWERUP.get(loot.get("type", ""), ""))

func get_score_value(loot: Dictionary) -> int:
	return int(loot.get("score_value", 100) * (1.0 + level("glutton") * 0.5))

func level(id: String) -> int:
	return powerup_levels.get(id, 0)

# Pauses the game and asks the HUD to show a pick-one-of-three choice.
# The prey's own loot power-up (if any and not maxed) is always one of the options.
func offer_powerups(guaranteed: String = "") -> void:
	var pool: Array = []
	for id in POWERUPS:
		if level(id) < POWERUPS[id]["max"] and id != guaranteed:
			pool.append(id)
	pool.shuffle()
	if guaranteed != "" and level(guaranteed) < POWERUPS[guaranteed]["max"]:
		pool.push_front(guaranteed)
	var choices = pool.slice(0, CHOICE_COUNT)
	if choices.is_empty():
		return
	get_tree().paused = true
	emit_signal("powerup_choices_offered", choices)

func choose_powerup(id: String) -> void:
	powerup_levels[id] = level(id) + 1
	var info = POWERUPS[id]
	var desc = info["desc"]
	if info["max"] > 1:
		desc += " (x%d)" % level(id)
	emit_signal("buff_gained", info["name"], desc, info["icon"])
	get_tree().paused = false

func get_speed_multiplier() -> float:
	return 1.0 + (level("boots") * 0.20)

func get_digestion_duration_multiplier() -> float:
	# Each acid ring decreases digestion time by 25% (min 0.25x at max stacks)
	return 1.0 - level("acid_ring") * 0.25

func get_damage_taken_multiplier() -> float:
	return 1.0 - level("hide") * 0.15

func get_bonus_max_hp() -> float:
	return level("vitality") * 25.0

func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	var is_new_record = (current_score >= high_score and current_score > 0)
	var stats = {
		"adventurers_digested": adventurers_digested,
		"boots_count": level("boots"),
		"has_gauntlets": level("gauntlets") > 0,
		"acid_rings": level("acid_ring"),
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
