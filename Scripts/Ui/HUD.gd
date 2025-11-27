# SCRIPT: HUD.gd
# ATTACH TO: Control node (child of HUD CanvasLayer) in HUD.tscn
# LOCATION: res://scripts/ui/HUD.gd

class_name HUD
extends Control

# Health Bar
@onready var health_fill: ColorRect = $PlayerBars/HealthBar/Fill
@onready var health_label: Label = $PlayerBars/HealthBar/Label
@onready var health_background: ColorRect = $PlayerBars/HealthBar/Background

# Weapon Info
@onready var weapon_icon: ColorRect = $WeaponInfo/WeaponIcon

# Game Info
@onready var wave_label: Label = $GameInfo/WaveLabel
@onready var enemies_label: Label = $GameInfo/EnemiesLabel
@onready var score_label: Label = $GameInfo/ScoreLabel

# Crystal Display
@onready var crystal_icon: ColorRect = $CrystalDisplay/CrystalIcon
@onready var crystal_label: Label = $CrystalDisplay/CrystalLabel

# References
var player: Node2D = null
var wave_manager: Node = null
var game_manager: Node = null
var time_alive: float = 0.0

# Bar animation
var health_max_width: float = 146

# Smooth bar animation
var target_health_percent: float = 1.0
var current_health_percent: float = 1.0

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
	wave_label.text = "Wave: 0/5"
	enemies_label.text = "Enemies: 0"
	score_label.text = "Score: 0"
	crystal_label.text = "Crystals: 0"

	# Set initial health
	if player and player.stats:
		_on_player_health_changed(player.stats.current_health, player.stats.max_health)

func _process(delta):
	time_alive += delta

	# Smooth bar animations
	current_health_percent = lerp(current_health_percent, target_health_percent, 10 * delta)

	health_fill.size.x = health_max_width * current_health_percent

	# Flash low health
	if current_health_percent < 0.3:
		var flash = abs(sin(Time.get_ticks_msec() * 0.005))
		health_fill.color = Color.RED.lerp(Color.YELLOW, flash * 0.3)
		health_background.color = Color("#1a0000").lerp(Color.RED, flash * 0.2)
	else:
		health_fill.color = Color.RED
		health_background.color = Color("#1a0000")

	# Animate crystal icon
	_animate_crystal_icon()

func _on_player_health_changed(current: float, max_health: float):
	target_health_percent = current / max_health if max_health > 0 else 0.0
	health_label.text = "%d/%d" % [current, max_health]

	# Pulse animation on damage
	if target_health_percent < current_health_percent:
		_pulse_bar(health_fill)

func _on_wave_started(wave_number: int):
	wave_label.text = "Wave: %d/5" % wave_number

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
	score_label.text = "Score: %d" % new_score

	# Grow animation
	score_label.scale = Vector2(1.2, 1.2)
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
	crystal_label.text = "Crystals: %d" % current_crystals

	# Pulse animation
	crystal_label.scale = Vector2(1.3, 1.3)
	crystal_icon.scale = Vector2(1.5, 1.5)
	crystal_label.modulate = Color(0, 1, 1, 1)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(crystal_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(crystal_icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(crystal_label, "modulate", Color.WHITE, 0.5)

func _animate_crystal_icon():
	# Pulse and rotate
	var pulse = abs(sin(time_alive * 3.0)) * 0.2 + 0.8
	crystal_icon.scale = Vector2(pulse, pulse)
	crystal_icon.rotation += 0.02
