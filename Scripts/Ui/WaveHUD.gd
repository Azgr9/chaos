# SCRIPT: WaveHUD.gd
# ATTACH TO: WaveHUD (Control node in HUD)
# LOCATION: res://Scripts/Ui/WaveHUD.gd
# Enhanced wave information display with progress bar, enemy breakdown, and hazard warnings

class_name WaveHUD
extends Control

# ============================================
# CONFIGURATION
# ============================================
const PANEL_BG_COLOR = Color(0.05, 0.05, 0.1, 0.85)
const PANEL_BORDER_COLOR = Color(0.3, 0.5, 0.7, 0.8)
const PROGRESS_BG_COLOR = Color(0.15, 0.15, 0.2, 1.0)
const PROGRESS_FILL_SAFE = Color(0.2, 0.8, 0.3, 1.0)
const PROGRESS_FILL_WARNING = Color(0.9, 0.7, 0.1, 1.0)
const PROGRESS_FILL_DANGER = Color(0.9, 0.2, 0.2, 1.0)
const BREATHER_COLOR = Color(0.3, 0.8, 1.0, 1.0)
const HAZARD_WARNING_COLOR = Color(1.0, 0.5, 0.1, 1.0)
const ELITE_COLOR = Color(1.0, 0.85, 0.0, 1.0)

# Enemy type display names and colors
const ENEMY_DISPLAY = {
	"goblin_dual": {"name": "Goblin", "color": Color(0.5, 0.7, 0.3)},
	"slime": {"name": "Slime", "color": Color(0.3, 0.9, 0.3)},
	"goblin_archer": {"name": "Archer", "color": Color(0.7, 0.5, 0.3)},
	"goblin_mage": {"name": "Mage", "color": Color(0.4, 0.8, 0.4)},
	"golem": {"name": "Golem", "color": Color(0.5, 0.4, 0.35)},
	"healer": {"name": "Healer", "color": Color(0.3, 0.9, 0.6)},
	"spawner": {"name": "Spawner", "color": Color(0.7, 0.3, 0.9)},
	"boss": {"name": "BOSS", "color": Color(1.0, 0.2, 0.2)}
}

# ============================================
# REFERENCES
# ============================================
var wave_manager: WaveManager = null
var game_manager: GameManager = null
var hazard_manager: HazardManager = null

# ============================================
# UI NODES (created dynamically)
# ============================================
var panel: PanelContainer
var wave_label: Label
var progress_bar_bg: ColorRect
var progress_bar_fill: ColorRect
var progress_label: Label
var enemies_label: Label
var elite_label: Label
var enemy_breakdown_container: HBoxContainer
var status_label: Label
var hazard_label: Label

# ============================================
# STATE
# ============================================
var current_wave: int = 0
var total_points: int = 0
var points_spawned: int = 0
var enemies_alive: int = 0
var elite_count: int = 0
var enemies_by_type: Dictionary = {}
var is_breather: bool = false
var breather_time: float = 0.0

# Label pooling for enemy breakdown (performance optimization)
var _enemy_label_pool: Array[Label] = []
var _active_enemy_labels: int = 0
const MAX_ENEMY_LABELS: int = 10

# Hazard update throttle (don't check every frame)
var _hazard_update_timer: float = 0.0
const HAZARD_UPDATE_INTERVAL: float = 0.5

func _ready():
	# Build UI
	_build_hud()

	# Find managers
	_find_managers()

	# Connect signals
	_connect_signals()

func _find_managers():
	wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if not wave_manager:
		wave_manager = get_node_or_null("/root/Game/WaveManager")

	game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		game_manager = get_node_or_null("/root/Game/GameManager")

	# HazardManager is child of WaveManager
	if wave_manager:
		hazard_manager = wave_manager.hazard_manager

func _connect_signals():
	if wave_manager:
		if wave_manager.has_signal("wave_started"):
			wave_manager.wave_started.connect(_on_wave_started)
		if wave_manager.has_signal("wave_completed"):
			wave_manager.wave_completed.connect(_on_wave_completed)
		if wave_manager.has_signal("wave_progress_changed"):
			wave_manager.wave_progress_changed.connect(_on_wave_progress_changed)
		if wave_manager.has_signal("enemies_updated"):
			wave_manager.enemies_updated.connect(_on_enemies_updated)
		if wave_manager.has_signal("in_breather_changed"):
			wave_manager.in_breather_changed.connect(_on_breather_changed)

# ============================================
# BUILD UI
# ============================================
func _build_hud():
	# Main panel - top left corner
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.position = Vector2(20, 20)
	add_child(panel)

	# Panel style
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_BG_COLOR
	style.border_color = PANEL_BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	# Main container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# === ROW 1: Wave info + Progress bar ===
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 15)
	vbox.add_child(row1)

	# Wave label
	wave_label = Label.new()
	wave_label.text = "WAVE 1/5"
	wave_label.add_theme_font_size_override("font_size", 18)
	wave_label.add_theme_color_override("font_color", Color.WHITE)
	row1.add_child(wave_label)

	# Progress bar container
	var progress_container = Control.new()
	progress_container.custom_minimum_size = Vector2(140, 20)
	progress_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(progress_container)

	# Progress bar background
	progress_bar_bg = ColorRect.new()
	progress_bar_bg.color = PROGRESS_BG_COLOR
	progress_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	progress_container.add_child(progress_bar_bg)

	# Progress bar fill
	progress_bar_fill = ColorRect.new()
	progress_bar_fill.color = PROGRESS_FILL_SAFE
	progress_bar_fill.anchor_left = 0
	progress_bar_fill.anchor_top = 0
	progress_bar_fill.anchor_right = 0
	progress_bar_fill.anchor_bottom = 1
	progress_bar_fill.offset_right = 0
	progress_container.add_child(progress_bar_fill)

	# Progress percentage label (centered on bar)
	progress_label = Label.new()
	progress_label.text = "0%"
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.add_theme_color_override("font_color", Color.WHITE)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	progress_container.add_child(progress_label)

	# === ROW 2: Enemy count + Elite count ===
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 20)
	vbox.add_child(row2)

	enemies_label = Label.new()
	enemies_label.text = "Enemies: 0"
	enemies_label.add_theme_font_size_override("font_size", 14)
	enemies_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	row2.add_child(enemies_label)

	elite_label = Label.new()
	elite_label.text = ""
	elite_label.add_theme_font_size_override("font_size", 14)
	elite_label.add_theme_color_override("font_color", ELITE_COLOR)
	row2.add_child(elite_label)

	# === ROW 3: Enemy type breakdown ===
	enemy_breakdown_container = HBoxContainer.new()
	enemy_breakdown_container.add_theme_constant_override("separation", 10)
	vbox.add_child(enemy_breakdown_container)

	# === ROW 4: Status (breather/spawning) ===
	status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", BREATHER_COLOR)
	vbox.add_child(status_label)

	# === ROW 5: Hazard warning ===
	hazard_label = Label.new()
	hazard_label.text = ""
	hazard_label.add_theme_font_size_override("font_size", 13)
	hazard_label.add_theme_color_override("font_color", HAZARD_WARNING_COLOR)
	vbox.add_child(hazard_label)

# ============================================
# SIGNAL HANDLERS
# ============================================
func _on_wave_started(wave_number: int):
	current_wave = wave_number
	_update_wave_label()
	_animate_wave_start()

func _on_wave_completed(_wave_number: int):
	status_label.text = "WAVE COMPLETE!"
	status_label.add_theme_color_override("font_color", Color.GREEN)
	status_label.visible = true

func _on_wave_progress_changed(spawned: int, total: int):
	points_spawned = spawned
	total_points = total
	_update_progress_bar()

func _on_enemies_updated(alive: int, by_type: Dictionary, elites: int):
	enemies_alive = alive
	enemies_by_type = by_type
	elite_count = elites
	_update_enemy_display()

func _on_breather_changed(breather: bool, time_remaining: float):
	is_breather = breather
	breather_time = time_remaining
	_update_status()

# ============================================
# UPDATE FUNCTIONS
# ============================================
func _update_wave_label():
	wave_label.text = "WAVE %d/5" % current_wave

func _update_progress_bar():
	if total_points <= 0:
		progress_bar_fill.anchor_right = 0
		progress_label.text = "0%"
		return

	var progress = float(points_spawned) / float(total_points)
	progress_bar_fill.anchor_right = progress
	progress_label.text = "%d%%" % int(progress * 100)

	# Color based on progress (danger increases)
	if progress < 0.5:
		progress_bar_fill.color = PROGRESS_FILL_SAFE
	elif progress < 0.8:
		progress_bar_fill.color = PROGRESS_FILL_WARNING
	else:
		progress_bar_fill.color = PROGRESS_FILL_DANGER

func _update_enemy_display():
	# Update count labels
	enemies_label.text = "Enemies: %d" % enemies_alive

	if elite_count > 0:
		elite_label.text = "Elite: %d" % elite_count
		elite_label.visible = true
	else:
		elite_label.visible = false

	# Update breakdown
	_update_enemy_breakdown()

func _update_enemy_breakdown():
	# Hide all pooled labels first
	for i in range(_active_enemy_labels):
		if i < _enemy_label_pool.size():
			_enemy_label_pool[i].visible = false
	_active_enemy_labels = 0

	# Reuse pooled labels for each enemy type
	var label_index: int = 0
	for enemy_type in enemies_by_type.keys():
		var count = enemies_by_type[enemy_type]
		if count <= 0:
			continue

		var display = ENEMY_DISPLAY.get(enemy_type, {"name": enemy_type, "color": Color.WHITE})

		# Get or create label from pool
		var type_label: Label
		if label_index < _enemy_label_pool.size():
			type_label = _enemy_label_pool[label_index]
		else:
			# Create new label and add to pool
			type_label = Label.new()
			type_label.add_theme_font_size_override("font_size", 12)
			enemy_breakdown_container.add_child(type_label)
			_enemy_label_pool.append(type_label)

		# Update label
		type_label.text = "%s×%d" % [display["name"], count]
		type_label.add_theme_color_override("font_color", display["color"])
		type_label.visible = true

		label_index += 1
		if label_index >= MAX_ENEMY_LABELS:
			break

	_active_enemy_labels = label_index

func _update_status():
	if is_breather:
		status_label.text = "BREATHER %.1fs" % breather_time
		status_label.add_theme_color_override("font_color", BREATHER_COLOR)
		status_label.visible = true
	else:
		status_label.visible = false

func _process(delta):
	# Throttle hazard updates for performance
	_hazard_update_timer += delta
	if _hazard_update_timer >= HAZARD_UPDATE_INTERVAL:
		_hazard_update_timer = 0.0
		_update_hazard_display()

func _update_hazard_display():
	if not hazard_manager or not is_instance_valid(hazard_manager):
		hazard_label.visible = false
		return

	if not hazard_manager.has_method("get_active_hazard_count"):
		hazard_label.visible = false
		return

	var active_hazards = hazard_manager.get_active_hazard_count()

	if active_hazards > 0:
		hazard_label.text = "Hazards: %d active" % active_hazards
		hazard_label.visible = true
	else:
		hazard_label.visible = false

# ============================================
# ANIMATIONS
# ============================================
func _animate_wave_start():
	# Flash the wave label
	var original_color = wave_label.get_theme_color("font_color")
	wave_label.add_theme_color_override("font_color", Color.YELLOW)

	var tween = create_tween()
	tween.tween_property(wave_label, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(wave_label, "scale", Vector2(1.0, 1.0), 0.15)
	tween.tween_callback(func(): wave_label.add_theme_color_override("font_color", original_color))
