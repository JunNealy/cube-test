extends Control

# HUD Controller displaying health, digestion gauge, active buffs, and high score

@onready var hp_bar: ProgressBar = $TopLeft/HealthBar
@onready var hp_label: Label = $TopLeft/HealthBar/HpLabel

@onready var digestion_panel: PanelContainer = $TopCenter/DigestionPanel
@onready var digestion_label: Label = $TopCenter/DigestionPanel/VBox/StatusLabel
@onready var digestion_bar: ProgressBar = $TopCenter/DigestionPanel/VBox/ProgressBar

@onready var score_label: Label = $TopRight/VBox/ScoreLabel
@onready var high_score_label: Label = $TopRight/VBox/HighScoreLabel
@onready var timer_label: Label = $TopRight/VBox/TimerLabel
@onready var threat_label: Label = $TopRight/VBox/ThreatLabel
@onready var game_over_title: Label = $GameOverLayer/GameOverPanel/VBox/Title

@onready var buffs_container: VBoxContainer = $LeftPanel/VBox/BuffsList
@onready var stats_label: Label = $BottomBar/StatsLabel

@onready var game_over_panel: PanelContainer = $GameOverLayer/GameOverPanel
@onready var final_score_label: Label = $GameOverLayer/GameOverPanel/VBox/FinalScoreLabel
@onready var new_record_label: Label = $GameOverLayer/GameOverPanel/VBox/NewRecordLabel
@onready var stats_recap_label: Label = $GameOverLayer/GameOverPanel/VBox/StatsRecapLabel
@onready var restart_button: Button = $GameOverLayer/GameOverPanel/VBox/RestartBtn

var active_buff_cards: Dictionary = {}

func _ready() -> void:
	game_over_panel.hide()
	new_record_label.hide()
	
	GameManager.player_hp_changed.connect(_on_hp_changed)
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.digestion_started.connect(_on_digestion_started)
	GameManager.digestion_progress.connect(_on_digestion_progress)
	GameManager.digestion_finished.connect(_on_digestion_finished)
	GameManager.buff_gained.connect(_on_buff_gained)
	GameManager.game_over_triggered.connect(_on_game_over)
	
	restart_button.pressed.connect(_on_restart_pressed)
	GameManager.powerup_choices_offered.connect(_on_powerup_choices_offered)
	GameManager.run_timer_updated.connect(_on_run_timer_updated)
	GameManager.threat_increased.connect(_on_threat_increased)
	_on_run_timer_updated(GameManager.time_left, GameManager.threat_level)
	# Keep HUD alive while the tree is paused for power-up selection
	process_mode = Node.PROCESS_MODE_ALWAYS

	_set_hungry_state()
	_update_stats_footer()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		GameManager.reset_game()

func _on_hp_changed(hp: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "%d / %d HP" % [int(hp), int(max_hp)]

func _on_score_updated(score: int, high_score: int) -> void:
	score_label.text = "SCORE: %s" % _format_number(score)
	high_score_label.text = "HIGH SCORE: %s" % _format_number(high_score)
	_update_stats_footer()

func _on_digestion_started(duration: float, prey_name: String) -> void:
	digestion_panel.modulate = Color(1.0, 0.85, 0.2)
	digestion_label.text = "DIGESTING %s: EVADE COMPANIONS!" % prey_name.to_upper()
	digestion_bar.value = 0.0

func _on_digestion_progress(ratio: float, time_left: float) -> void:
	digestion_bar.value = ratio * 100.0
	digestion_label.text = "DIGESTING (%.1fs) - VULNERABLE! RUN!" % time_left

func _on_digestion_finished(_loot: Dictionary) -> void:
	_set_hungry_state()
	_update_stats_footer()

func _set_hungry_state() -> void:
	digestion_panel.modulate = Color(0.3, 1.0, 0.4)
	digestion_label.text = "HUNGRY - READY TO ENGULF PREY"
	digestion_bar.value = 100.0

func _on_buff_gained(buff_name: String, desc: String, icon: String) -> void:
	if not active_buff_cards.has(buff_name):
		var card = PanelContainer.new()
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)
		
		var icon_lbl = Label.new()
		icon_lbl.text = icon
		icon_lbl.add_theme_font_size_override("font_size", 20)
		hbox.add_child(icon_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = "%s: %s" % [buff_name, desc]
		desc_lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(desc_lbl)
		
		buffs_container.add_child(card)
		active_buff_cards[buff_name] = desc_lbl
		
		# Pop animation
		card.scale = Vector2(0.8, 0.8)
		var tw = create_tween()
		tw.tween_property(card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# Update stack count if exists
		var lbl = active_buff_cards[buff_name] as Label
		lbl.text = "%s: %s" % [buff_name, desc]

func _update_stats_footer() -> void:
	stats_label.text = "Adventurers Digested: %d  |  Loot Stored Inside Mass: %d items  |  [WASD / Arrows to Move | R to Restart]" % [
		GameManager.adventurers_digested,
		GameManager.contained_loot.size()
	]

func _on_game_over(final_score: int, is_new_record: bool, stats: Dictionary) -> void:
	game_over_panel.show()
	final_score_label.text = "FINAL SCORE: %s" % _format_number(final_score)
	new_record_label.visible = is_new_record
	
	game_over_title.text = "TIME'S UP!" if stats.get("reason") == "time" else "SLIME DISSOLVED!"
	var survived = int(stats.get("time_survived", 0.0))
	var text = "Survived: %d:%02d  (Threat Level %d)\n" % [survived / 60, survived % 60, stats.get("threat_level", 0) + 1]
	text += "Adventurers Digested: %d\n" % stats.get("adventurers_digested", 0)
	text += "Loot In Mass: %d items\n" % stats.get("loot_count", 0)
	text += "Speed Buffs (Boots): +%d%%\n" % (stats.get("boots_count", 0) * 20)
	text += "Gauntlets of Ogre Power: %s\n" % ("Unlocked" if stats.get("has_gauntlets", false) else "None")
	text += "Acid Rings: %d" % stats.get("acid_rings", 0)
	stats_recap_label.text = text

func _on_run_timer_updated(time_left: float, threat_level: int) -> void:
	var secs = int(ceilf(time_left))
	timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
	# Red and pulsing in the last 30 seconds
	if time_left <= 30.0:
		timer_label.modulate = Color(1.0, 0.3, 0.3, 0.6 + 0.4 * absf(sin(time_left * 4.0)))
	else:
		timer_label.modulate = Color.WHITE
	threat_label.text = "THREAT LEVEL %d" % (threat_level + 1)

func _on_threat_increased(threat_level: int) -> void:
	var banner = Label.new()
	banner.text = "THREAT LEVEL %d - MORE ADVENTURERS INCOMING!" % (threat_level + 1)
	banner.add_theme_font_size_override("font_size", 28)
	banner.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 8)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.position.y = 110
	add_child(banner)
	var tw = create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)
	tw.tween_callback(banner.queue_free)

func _on_powerup_choices_offered(choices: Array) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "THE CUBE GROWS... CHOOSE A MUTATION"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	for i in range(choices.size()):
		var id: String = choices[i]
		var info = GameManager.POWERUPS[id]
		var next_level = GameManager.level(id) + 1
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(220, 170)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 16)
		var lvl_text = "" if info["max"] == 1 else "\nLv %d" % next_level
		btn.text = "[%d]\n%s\n%s\n\n%s%s" % [i + 1, info["icon"], info["name"], info["desc"], lvl_text]
		btn.pressed.connect(func():
			overlay.queue_free()
			GameManager.choose_powerup(id))
		row.add_child(btn)
		# Number keys 1-3 pick a card
		var sc = Shortcut.new()
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_1 + i
		sc.events = [ev]
		btn.shortcut = sc
		if i == 0:
			btn.grab_focus.call_deferred()

func _on_restart_pressed() -> void:
	GameManager.reset_game()

func _format_number(n: int) -> String:
	var s = str(n)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res
