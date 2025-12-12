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

# Gold Display (new paths)
@onready var gold_icon: ColorRect = $PlayerStatus/GoldSection/GoldIcon
@onready var gold_label: Label = $PlayerStatus/GoldSection/GoldLabel

# Relic Display (top-right, below wave info)
@onready var relic_container: HBoxContainer = $RelicSection/RelicContainer
@onready var relic_tooltip: PanelContainer = $RelicSection/RelicTooltip
@onready var tooltip_name: Label = $RelicSection/RelicTooltip/VBox/RelicName
@onready var tooltip_desc: Label = $RelicSection/RelicTooltip/VBox/RelicDesc
@onready var tooltip_flavor: Label = $RelicSection/RelicTooltip/VBox/FlavorText

# Wave Info (new paths)
@onready var wave_label: Label = $WaveInfo/WaveLabel
@onready var enemies_label: Label = $WaveInfo/EnemiesLabel

# Preload circle script (avoids runtime compilation)
const CircleProgressScript = preload("res://Scripts/Ui/CircleProgress.gd")

# Skill UI containers
@onready var sword_skill_container: Control = $SwordSkillContainer/SwordSkill
@onready var staff_skill_container: Control = $StaffSkillContainer/StaffSkill

# Circular skill UI elements (created dynamically)
var sword_outer_circle: Control = null
var sword_inner_circle: Control = null
var sword_fill_circle: Control = null
var sword_icon_label: Label = null
var sword_keybind_label: Label = null

var staff_outer_circle: Control = null
var staff_inner_circle: Control = null
var staff_fill_circle: Control = null
var staff_icon_label: Label = null
var staff_keybind_label: Label = null

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
		if wave_manager.has_signal("enemy_spawned"):
			wave_manager.enemy_spawned.connect(_on_enemy_spawned)

	# Game manager signals
	if game_manager:
		if game_manager.has_signal("gold_changed"):
			game_manager.gold_changed.connect(_on_gold_changed)

	# RunManager signals for relics
	if RunManager:
		RunManager.relic_collected.connect(_on_relic_collected)

func _initialize_ui():
	# Set initial values
	wave_label.text = "WAVE 0/5"
	enemies_label.text = "Waiting..."
	gold_label.text = "0"

	# Set initial health
	if player and player.stats:
		_on_player_health_changed(player.stats.current_health, player.stats.max_health)

	# Initialize stats display
	_update_stats_display()

	# Hide relic tooltip initially
	if relic_tooltip:
		relic_tooltip.visible = false

	# Load existing relics from RunManager
	_refresh_relic_display()

	# Create skill fill rects for bottom-to-top cooldown display
	_setup_skill_fills()

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

	# Update skill cooldowns
	_update_skill_cooldowns()

	# Update stats display periodically (every few frames for performance)
	if Engine.get_process_frames() % 10 == 0:
		_update_stats_display()

var sword_skill_was_ready: bool = false
var staff_skill_was_ready: bool = false

# Skill colors
const SWORD_SKILL_COLOR: Color = Color(1.0, 0.85, 0.3, 1.0)  # Gold/yellow
const SWORD_SKILL_READY_GLOW: Color = Color(1.0, 0.9, 0.4, 1.0)
const STAFF_SKILL_COLOR: Color = Color(0.7, 0.4, 1.0, 1.0)  # Purple
const STAFF_SKILL_READY_GLOW: Color = Color(0.8, 0.5, 1.0, 1.0)
const SKILL_GRAY: Color = Color(0.3, 0.3, 0.3, 1.0)  # Gray when on cooldown
const SKILL_SIZE: float = 64.0
const OUTER_RING_SIZE: float = 70.0
const INNER_CIRCLE_SIZE: float = 54.0

# Skill emojis
const SWORD_SKILL_EMOJI: String = "⚔️"
const STAFF_SKILL_EMOJI: String = "⚡"

func _setup_skill_fills():
	# Clear old children from containers
	for child in sword_skill_container.get_children():
		child.queue_free()
	for child in staff_skill_container.get_children():
		child.queue_free()

	# Create circular sword skill button
	_create_circular_skill(sword_skill_container, true)

	# Create circular staff skill button
	_create_circular_skill(staff_skill_container, false)

func _create_circular_skill(container: Control, is_sword: bool):
	var center = Vector2(SKILL_SIZE / 2, SKILL_SIZE / 2)
	var skill_color = SWORD_SKILL_COLOR if is_sword else STAFF_SKILL_COLOR
	var emoji = SWORD_SKILL_EMOJI if is_sword else STAFF_SKILL_EMOJI
	var keybind = "Q" if is_sword else "E"

	# Outer ring (border)
	var outer = _create_circle_control(OUTER_RING_SIZE, skill_color)
	outer.position = center - Vector2(OUTER_RING_SIZE / 2, OUTER_RING_SIZE / 2)
	container.add_child(outer)

	# Fill circle (shows cooldown progress)
	var fill = _create_circle_control(SKILL_SIZE, skill_color)
	fill.position = center - Vector2(SKILL_SIZE / 2, SKILL_SIZE / 2)
	container.add_child(fill)

	# Inner circle (dark background)
	var inner = _create_circle_control(INNER_CIRCLE_SIZE, Color(0.1, 0.1, 0.12, 1.0))
	inner.position = center - Vector2(INNER_CIRCLE_SIZE / 2, INNER_CIRCLE_SIZE / 2)
	container.add_child(inner)

	# Emoji icon in center
	var icon = Label.new()
	icon.text = emoji
	icon.add_theme_font_size_override("font_size", 28)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.size = Vector2(SKILL_SIZE, SKILL_SIZE)
	icon.position = Vector2(0, 0)
	container.add_child(icon)

	# Keybind label (bottom right)
	var key_label = Label.new()
	key_label.text = keybind
	key_label.add_theme_font_size_override("font_size", 14)
	key_label.add_theme_color_override("font_color", Color.WHITE)
	key_label.position = Vector2(SKILL_SIZE - 16, SKILL_SIZE - 20)
	container.add_child(key_label)

	# Store references
	if is_sword:
		sword_outer_circle = outer
		sword_fill_circle = fill
		sword_inner_circle = inner
		sword_icon_label = icon
		sword_keybind_label = key_label
	else:
		staff_outer_circle = outer
		staff_fill_circle = fill
		staff_inner_circle = inner
		staff_icon_label = icon
		staff_keybind_label = key_label

func _create_circle_control(diameter: float, color: Color) -> Control:
	var control = Control.new()
	control.size = Vector2(diameter, diameter)
	control.set_script(CircleProgressScript)
	control.set("circle_color", color)
	return control

func _update_skill_cooldowns():
	var pulse = (sin(time_alive * 6.0) + 1.0) / 2.0  # 0 to 1 pulse

	# Update sword skill cooldown (Q - bottom left)
	if player and player.current_weapon and player.current_weapon.has_method("get_skill_cooldown_percent"):
		var percent = player.current_weapon.get_skill_cooldown_percent()
		_update_circular_skill(percent, true, pulse)

	# Update staff skill cooldown (E - bottom right)
	if player and player.current_staff and player.current_staff.has_method("get_skill_cooldown_percent"):
		var percent = player.current_staff.get_skill_cooldown_percent()
		_update_circular_skill(percent, false, pulse)

func _update_circular_skill(percent: float, is_sword: bool, pulse: float):
	var outer = sword_outer_circle if is_sword else staff_outer_circle
	var fill = sword_fill_circle if is_sword else staff_fill_circle
	var inner = sword_inner_circle if is_sword else staff_inner_circle
	var icon = sword_icon_label if is_sword else staff_icon_label
	var skill_color = SWORD_SKILL_COLOR if is_sword else STAFF_SKILL_COLOR
	var glow_color = SWORD_SKILL_READY_GLOW if is_sword else STAFF_SKILL_READY_GLOW

	if not outer or not fill or not inner or not icon:
		return

	if percent >= 1.0:
		# Skill ready - full color, pulsing glow
		_set_circle_color(outer, glow_color.lerp(Color.WHITE, pulse * 0.4))
		_set_circle_fill(fill, skill_color, 1.0)
		_set_circle_color(inner, skill_color.darkened(0.7))
		icon.modulate = Color.WHITE.lerp(glow_color, pulse * 0.3)

		# Pulsing scale
		outer.scale = Vector2(1.0, 1.0).lerp(Vector2(1.06, 1.06), pulse * 0.5)
		fill.scale = Vector2.ONE

		# Flash when skill becomes ready
		if is_sword:
			if not sword_skill_was_ready:
				sword_skill_was_ready = true
				_flash_circular_skill_ready(outer, icon, glow_color)
		else:
			if not staff_skill_was_ready:
				staff_skill_was_ready = true
				_flash_circular_skill_ready(outer, icon, glow_color)
	else:
		# On cooldown - gray with colored fill showing progress from bottom
		if is_sword:
			sword_skill_was_ready = false
		else:
			staff_skill_was_ready = false

		# Outer ring gray
		_set_circle_color(outer, SKILL_GRAY.lightened(0.1))

		# Fill shows progress - fills from bottom to top
		_set_circle_fill(fill, skill_color, percent)

		# Inner dark
		_set_circle_color(inner, Color(0.15, 0.15, 0.18, 1.0))

		# Icon grayed out
		icon.modulate = Color(0.5, 0.5, 0.5, 1.0)

		# Reset scales
		outer.scale = Vector2.ONE
		fill.scale = Vector2.ONE

func _set_circle_color(circle: Control, color: Color):
	if circle:
		circle.set("circle_color", color)
		circle.queue_redraw()

func _set_circle_fill(circle: Control, color: Color, fill_percent: float):
	if circle:
		circle.set("circle_color", color)
		circle.set("fill_percent", fill_percent)
		circle.queue_redraw()

func _flash_circular_skill_ready(outer: Control, icon: Label, _flash_color: Color):
	# Big flash when skill becomes ready
	var tween = create_tween()
	outer.scale = Vector2(1.3, 1.3)
	outer.modulate = Color.WHITE * 2.0
	icon.modulate = Color.WHITE * 1.5
	tween.tween_property(outer, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(outer, "modulate", Color.WHITE, 0.2)
	tween.parallel().tween_property(icon, "modulate", Color.WHITE, 0.3)

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
	_update_enemies_display(enemies_remaining)

	# Green flash on kill
	enemies_label.modulate = Color.GREEN
	enemies_label.scale = Vector2(1.1, 1.1)
	var tween = create_tween()
	tween.tween_property(enemies_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(enemies_label, "modulate", Color.WHITE, 0.3)

func _on_enemy_spawned(_enemy: Node):
	if wave_manager:
		_update_enemies_display(wave_manager.enemies_alive)

func _update_enemies_display(alive_count: int):
	if alive_count == 0:
		enemies_label.text = "Clear!"
		enemies_label.modulate = Color.GREEN
	elif alive_count == 1:
		enemies_label.text = "1 enemy"
	else:
		enemies_label.text = "%d enemies" % alive_count

func _pulse_bar(bar: ColorRect):
	var original_scale = bar.scale
	bar.scale = Vector2(1.0, 1.3)
	var tween = create_tween()
	tween.tween_property(bar, "scale", original_scale, 0.2).set_trans(Tween.TRANS_ELASTIC)

func _on_gold_changed(new_gold: int):
	gold_label.text = "%d" % new_gold

	# Pulse animation
	gold_label.scale = Vector2(1.3, 1.3)
	gold_icon.scale = Vector2(1.5, 1.5)
	gold_label.modulate = Color.GOLD

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(gold_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(gold_icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(gold_label, "modulate", Color.WHITE, 0.5)

# ============================================
# RELIC DISPLAY
# ============================================

func _on_relic_collected(relic: Resource):
	_add_relic_icon(relic)

func _refresh_relic_display():
	if not relic_container:
		return

	# Clear existing icons
	for child in relic_container.get_children():
		child.queue_free()

	# Add icons for all collected relics
	var relics = RunManager.get_collected_relics()
	for relic in relics:
		_add_relic_icon(relic)

func _add_relic_icon(relic: Resource):
	if not relic_container or not relic:
		return

	# Create emoji label for relic
	var relic_label = Label.new()
	relic_label.text = relic.emoji if "emoji" in relic else "💎"
	relic_label.add_theme_font_size_override("font_size", 24)
	relic_label.mouse_filter = Control.MOUSE_FILTER_STOP

	# Store relic data for tooltip
	relic_label.set_meta("relic", relic)

	# Connect hover signals
	relic_label.mouse_entered.connect(_on_relic_hover.bind(relic_label))
	relic_label.mouse_exited.connect(_on_relic_unhover)

	relic_container.add_child(relic_label)

	# Animate entry
	relic_label.scale = Vector2(0, 0)
	relic_label.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(relic_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(relic_label, "modulate", Color.WHITE, 0.3)

func _on_relic_hover(relic_label: Label):
	var relic = relic_label.get_meta("relic")
	if not relic or not relic_tooltip:
		return

	# Set tooltip content
	var rarity_color = relic.get_rarity_color() if relic.has_method("get_rarity_color") else Color.WHITE
	tooltip_name.text = relic.emoji + " " + relic.relic_name if "relic_name" in relic else "Unknown Relic"
	tooltip_name.modulate = rarity_color
	tooltip_desc.text = relic.effect_description if "effect_description" in relic else ""
	tooltip_flavor.text = relic.flavor_text if "flavor_text" in relic else ""
	tooltip_flavor.modulate = Color(0.7, 0.7, 0.7, 1)

	# Position tooltip - show below relic section but aligned to screen
	# Reset to local position within RelicSection
	relic_tooltip.position = Vector2(0, 44)
	relic_tooltip.visible = true

	# Animate in
	relic_tooltip.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(relic_tooltip, "modulate", Color.WHITE, 0.15)

func _on_relic_unhover():
	if relic_tooltip:
		relic_tooltip.visible = false
