# SCRIPT: HUD.gd
# ATTACH TO: Control node (child of HUD CanvasLayer) in HUD.tscn
# LOCATION: res://scripts/ui/HUD.gd

class_name HUD
extends Control

# Health Bar (new paths)
@onready var health_fill: ColorRect = $PlayerStatus/HealthSection/HealthBar/Fill
@onready var health_label: Label = $PlayerStatus/HealthSection/HealthBar/Label
@onready var health_background: ColorRect = $PlayerStatus/HealthSection/HealthBar/Background
@onready var health_shine: ColorRect = $PlayerStatus/HealthSection/HealthBar/Shine
@onready var health_icon: ColorRect = $PlayerStatus/HealthSection/HealthIcon

# Crystal and Score (new paths)
@onready var crystal_icon: ColorRect = $PlayerStatus/CrystalSection/CrystalIcon
@onready var crystal_label: Label = $PlayerStatus/CrystalSection/CrystalLabel
@onready var score_label: Label = $PlayerStatus/ScoreSection/ScoreLabel

# Wave Info (new paths)
@onready var wave_label: Label = $WaveInfo/WaveLabel
@onready var enemies_label: Label = $WaveInfo/EnemiesLabel

# Skill UI (Q on left, E on right)
@onready var sword_skill_cooldown: ColorRect = $SwordSkillContainer/SwordSkill/Cooldown
@onready var sword_skill_border: ColorRect = $SwordSkillContainer/SwordSkill/Border
@onready var staff_skill_cooldown: ColorRect = $StaffSkillContainer/StaffSkill/Cooldown
@onready var staff_skill_border: ColorRect = $StaffSkillContainer/StaffSkill/Border

# Stats Panel
@onready var move_speed_value: Label = $StatsPanel/MovementSpeed/Value
@onready var attack_power_value: Label = $StatsPanel/AttackPower/Value
@onready var magic_power_value: Label = $StatsPanel/MagicPower/Value
@onready var attack_speed_value: Label = $StatsPanel/AttackSpeed/Value
@onready var crit_chance_value: Label = $StatsPanel/CritChance/Value
@onready var lifesteal_value: Label = $StatsPanel/Lifesteal/Value

# References
var player: Node2D = null
var wave_manager: Node = null
var game_manager: Node = null
var time_alive: float = 0.0

# Bar animation
var health_max_width: float = 236  # Updated for new bar size (238-2=236)

# Smooth bar animation
var target_health_percent: float = 1.0
var current_health_percent: float = 1.0

# Cached stat values for change detection
var cached_move_speed: float = 0.0
var cached_melee_dmg: float = 0.0
var cached_magic_dmg: float = 0.0
var cached_attack_speed: float = 0.0
var cached_crit_chance: float = 0.0
var cached_lifesteal: float = 0.0

func _ready():
	# Find references
	_find_references()

	# Connect signals
	_connect_signals()

	# Initialize UI
	_initialize_ui()

func _find_references():
	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	# Find managers
	var game_node = get_node_or_null("/root/Game")
	if game_node:
		wave_manager = game_node.get_node_or_null("WaveManager")
		game_manager = game_node.get_node_or_null("GameManager")

func _connect_signals():
	# Player signals
	if player:
		player.health_changed.connect(_on_player_health_changed)

	# Wave manager signals
	if wave_manager:
		if wave_manager.has_signal("wave_started"):
			wave_manager.wave_started.connect(_on_wave_started)
		if wave_manager.has_signal("enemy_killed"):
			wave_manager.enemy_killed.connect(_on_enemy_killed)
		if wave_manager.has_signal("wave_completed"):
			wave_manager.wave_completed.connect(_on_wave_completed)

	# Game manager signals
	if game_manager:
		if game_manager.has_signal("score_changed"):
			game_manager.score_changed.connect(_on_score_changed)
		if game_manager.has_signal("crystals_changed"):
			game_manager.crystals_changed.connect(_on_crystals_changed)

func _initialize_ui():
	# Set initial values
	wave_label.text = "WAVE 0/5"
	enemies_label.text = "Enemies: 0"
	score_label.text = "0"
	crystal_label.text = "0"

	# Set initial health
	if player and player.stats:
		_on_player_health_changed(player.stats.current_health, player.stats.max_health)

	# Initialize stats display
	_update_stats_display()

func _process(delta):
	time_alive += delta

	# Smooth bar animations
	current_health_percent = lerp(current_health_percent, target_health_percent, 10 * delta)

	health_fill.size.x = health_max_width * current_health_percent
	health_shine.size.x = health_max_width * current_health_percent

	# Flash low health
	if current_health_percent < 0.3:
		var flash = abs(sin(Time.get_ticks_msec() * 0.005))
		health_fill.color = Color(0.85, 0.15, 0.15).lerp(Color.YELLOW, flash * 0.4)
		health_background.color = Color(0.15, 0.05, 0.05).lerp(Color(0.3, 0.1, 0.1), flash * 0.3)
		health_icon.color = Color(0.9, 0.2, 0.2).lerp(Color.YELLOW, flash * 0.5)
	else:
		health_fill.color = Color(0.85, 0.15, 0.15)
		health_background.color = Color(0.15, 0.05, 0.05)
		health_icon.color = Color(0.9, 0.2, 0.2)

	# Animate crystal icon
	_animate_crystal_icon()

	# Update skill cooldowns
	_update_skill_cooldowns()

	# Update stats display periodically (every few frames for performance)
	if Engine.get_process_frames() % 10 == 0:
		_update_stats_display()

func _update_skill_cooldowns():
	# Update sword skill cooldown (Q - bottom left)
	if player and player.current_weapon and player.current_weapon.has_method("get_skill_cooldown_percent"):
		var percent = player.current_weapon.get_skill_cooldown_percent()
		sword_skill_cooldown.size.y = 64 * (1.0 - percent)
		if percent >= 1.0:
			sword_skill_cooldown.color = Color(0.1, 0.1, 0.1, 0.0)  # Fully transparent when ready
			sword_skill_border.color = Color(0.9, 0.8, 0.4, 1)  # Glow when ready
		else:
			sword_skill_cooldown.color = Color(0.1, 0.1, 0.1, 0.7)
			sword_skill_border.color = Color(0.7, 0.6, 0.3, 1)

	# Update staff skill cooldown (E - bottom right)
	if player and player.current_staff and player.current_staff.has_method("get_skill_cooldown_percent"):
		var percent = player.current_staff.get_skill_cooldown_percent()
		staff_skill_cooldown.size.y = 64 * (1.0 - percent)
		if percent >= 1.0:
			staff_skill_cooldown.color = Color(0.1, 0.1, 0.1, 0.0)  # Fully transparent when ready
			staff_skill_border.color = Color(0.7, 0.5, 0.95, 1)  # Glow when ready
		else:
			staff_skill_cooldown.color = Color(0.1, 0.1, 0.1, 0.7)
			staff_skill_border.color = Color(0.5, 0.3, 0.7, 1)

func _update_stats_display():
	if not player or not player.stats:
		return

	var stats = player.stats

	# Movement Speed
	if stats.move_speed != cached_move_speed:
		cached_move_speed = stats.move_speed
		move_speed_value.text = "%d" % int(stats.move_speed)
		_animate_stat_change(move_speed_value)

	# Melee Damage
	if stats.melee_damage_multiplier != cached_melee_dmg:
		cached_melee_dmg = stats.melee_damage_multiplier
		attack_power_value.text = "%d%%" % int(stats.melee_damage_multiplier * 100)
		_animate_stat_change(attack_power_value)

	# Magic Damage
	if stats.magic_damage_multiplier != cached_magic_dmg:
		cached_magic_dmg = stats.magic_damage_multiplier
		magic_power_value.text = "%d%%" % int(stats.magic_damage_multiplier * 100)
		_animate_stat_change(magic_power_value)

	# Attack Speed
	if stats.attack_speed_multiplier != cached_attack_speed:
		cached_attack_speed = stats.attack_speed_multiplier
		attack_speed_value.text = "%d%%" % int(stats.attack_speed_multiplier * 100)
		_animate_stat_change(attack_speed_value)

	# Crit Chance
	if stats.crit_chance != cached_crit_chance:
		cached_crit_chance = stats.crit_chance
		crit_chance_value.text = "%d%%" % int(stats.crit_chance * 100)
		_animate_stat_change(crit_chance_value)

	# Lifesteal
	if stats.lifesteal_amount != cached_lifesteal:
		cached_lifesteal = stats.lifesteal_amount
		lifesteal_value.text = "%d" % int(stats.lifesteal_amount)
		_animate_stat_change(lifesteal_value)

func _animate_stat_change(label: Label):
	# Quick flash animation when stat changes
	label.modulate = Color.GREEN
	var tween = create_tween()
	tween.tween_property(label, "modulate", Color.WHITE, 0.5)

func _on_player_health_changed(current: float, max_health: float):
	target_health_percent = current / max_health if max_health > 0 else 0.0
	health_label.text = "%d/%d" % [int(current), int(max_health)]

	# Pulse animation on damage
	if target_health_percent < current_health_percent:
		_pulse_bar(health_fill)

func _on_wave_started(wave_number: int):
	wave_label.text = "WAVE %d/5" % wave_number

	# Animate wave start
	var original_scale = wave_label.scale
	wave_label.scale = Vector2(1.5, 1.5)
	wave_label.modulate = Color.YELLOW

	var tween = create_tween()
	tween.tween_property(wave_label, "scale", original_scale, 0.3).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(wave_label, "modulate", Color.WHITE, 0.5)

func _on_wave_completed(_wave_number: int):
	# Flash completion
	wave_label.modulate = Color.GREEN
	var tween = create_tween()
	tween.tween_property(wave_label, "modulate", Color.WHITE, 1.0)

func _on_enemy_killed(enemies_remaining: int):
	enemies_label.text = "Enemies: %d" % enemies_remaining

	# Small pulse
	enemies_label.scale = Vector2(1.1, 1.1)
	var tween = create_tween()
	tween.tween_property(enemies_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

func _on_score_changed(new_score: int):
	score_label.text = "%d" % new_score

	# Grow animation
	score_label.scale = Vector2(1.3, 1.3)
	score_label.modulate = Color.GOLD
	var tween = create_tween()
	tween.tween_property(score_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(score_label, "modulate", Color.WHITE, 0.5)

func _pulse_bar(bar: ColorRect):
	var original_scale = bar.scale
	bar.scale = Vector2(1.0, 1.3)
	var tween = create_tween()
	tween.tween_property(bar, "scale", original_scale, 0.2).set_trans(Tween.TRANS_ELASTIC)

func _on_crystals_changed(current_crystals: int, _total_collected: int):
	crystal_label.text = "%d" % current_crystals

	# Pulse animation
	crystal_label.scale = Vector2(1.3, 1.3)
	crystal_icon.scale = Vector2(1.5, 1.5)
	crystal_label.modulate = Color(0.2, 0.95, 1.0, 1)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(crystal_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(crystal_icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(crystal_label, "modulate", Color.WHITE, 0.5)

func _animate_crystal_icon():
	# Gentle pulse and rotate
	var pulse = abs(sin(time_alive * 2.5)) * 0.15 + 0.9
	crystal_icon.scale = Vector2(pulse, pulse)
	crystal_icon.rotation += 0.015
