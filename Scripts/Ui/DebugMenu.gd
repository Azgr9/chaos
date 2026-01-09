# SCRIPT: DebugMenu.gd
# ATTACH TO: DebugMenu (CanvasLayer) root node
# LOCATION: res://Scripts/Ui/DebugMenu.gd
# PURPOSE: Debug menu for testing - pause waves, spawn enemies, kill all, heal all

class_name DebugMenu
extends CanvasLayer

# ============================================
# ENEMY SCENES FOR SPAWNING
# ============================================
const ENEMY_SCENES = {
	"Slime": preload("res://Scenes/Enemies/Slime.tscn"),
	"GoblinArcher": preload("res://Scenes/Enemies/GoblinArcher.tscn"),
	"GoblinDual": preload("res://Scenes/Enemies/GoblinDual.tscn"),
	"GoblinMage": preload("res://Scenes/Enemies/GoblinMage.tscn"),
	"Golem": preload("res://Scenes/Enemies/Golem.tscn"),
	"Healer": preload("res://Scenes/Enemies/Healer.tscn"),
	"Spawner": preload("res://Scenes/Enemies/Spawner.tscn"),
	"Boss": preload("res://Scenes/Enemies/Boss.tscn")
}

# ============================================
# HAZARD SCENES FOR SPAWNING
# ============================================
const HAZARD_SCENES = {
	"FireGrate": preload("res://Scenes/hazards/FireGrate.tscn"),
	"FloorSpikes": preload("res://Scenes/hazards/FloorSpikes.tscn"),
	"SpikeWall": preload("res://Scenes/hazards/SpikeWall.tscn"),
	"Crusher": preload("res://Scenes/hazards/Crusher.tscn")
}

# ============================================
# STATE
# ============================================
var is_open: bool = false
var is_dragging_enemy: bool = false
var is_dragging_hazard: bool = false
var dragging_enemy_type: String = ""
var dragging_hazard_type: String = ""
var drag_preview: ColorRect = null
var wave_manager: WaveManager = null
var player_reference: Node2D = null
var was_wave_active: bool = false
var enemies_frozen: bool = true  # Toggle for freezing enemies

# UI References
var panel: PanelContainer = null
var enemy_buttons: Dictionary = {}
var hazard_buttons: Dictionary = {}
var freeze_button: Button = null
var gold_label: Label = null
var hitbox_toggle_button: Button = null

# Hitbox visualization
var show_hitboxes: bool = false
var hitbox_visualizers: Array = []

# ============================================
# SIGNALS
# ============================================
signal debug_mode_changed(is_active: bool)

func _ready():
	# Start hidden
	visible = false
	layer = 100  # On top of everything

	# Build the UI
	_build_debug_ui()

	# Find references
	_find_references()

func _find_references():
	# Find wave manager
	wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if not wave_manager:
		var wm = get_node_or_null("/root/Game/WaveManager")
		if wm:
			wave_manager = wm

	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_reference = players[0]

func _input(event):
	# Toggle debug menu with O key
	if event is InputEventKey and event.pressed and event.keycode == KEY_O:
		toggle_debug_menu()
		get_viewport().set_input_as_handled()
		return

	# Handle drag and drop for enemy/hazard spawning
	if is_open and (is_dragging_enemy or is_dragging_hazard):
		if event is InputEventMouseMotion:
			if drag_preview:
				drag_preview.global_position = get_viewport().get_mouse_position() - Vector2(20, 20)

		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:  # Mouse released
				if is_dragging_enemy:
					_spawn_enemy_at_mouse()
				elif is_dragging_hazard:
					_spawn_hazard_at_mouse()
				_end_drag()

func toggle_debug_menu():
	if is_open:
		close_debug_menu()
	else:
		open_debug_menu()

func open_debug_menu():
	is_open = true
	visible = true
	enemies_frozen = true  # Start with enemies frozen

	# Re-find references in case they changed
	_find_references()

	# Pause wave manager
	if wave_manager:
		was_wave_active = wave_manager.wave_active
		wave_manager.wave_active = false
		wave_manager.set_process(false)

	# Pause enemy movement but keep them visible
	_set_enemies_frozen(true)

	# Update button text
	_update_freeze_button()

	# Update gold display
	_update_gold_display()

	debug_mode_changed.emit(true)
	print("[DEBUG] Debug menu opened - waves paused, enemies frozen")

func close_debug_menu():
	is_open = false
	visible = false

	# Cancel any drag
	_end_drag()

	# Clear hitbox visualizers when closing
	show_hitboxes = false
	_clear_hitbox_visualizers()
	_update_hitbox_button()

	# Resume wave manager
	if wave_manager:
		wave_manager.wave_active = was_wave_active
		wave_manager.set_process(true)

	# Resume enemy movement (always unfreeze when closing)
	_set_enemies_frozen(false)

	debug_mode_changed.emit(false)
	print("[DEBUG] Debug menu closed - waves resumed")

func _set_enemies_frozen(frozen: bool):
	enemies_frozen = frozen
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(not frozen)
			# Also pause/unpause timers on enemies (like Spawner's spawn timer, Healer's heal timer)
			_set_enemy_timers_paused(enemy, frozen)

func _set_enemy_timers_paused(enemy: Node, paused: bool):
	# Find all Timer children and pause/unpause them
	for child in enemy.get_children():
		if child is Timer:
			child.paused = paused

func _update_freeze_button():
	if freeze_button:
		if enemies_frozen:
			freeze_button.text = "Unfreeze Enemies"
		else:
			freeze_button.text = "Freeze Enemies"

# ============================================
# BUILD UI
# ============================================
func _build_debug_ui():
	# Main panel on right side - use most of screen height
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_height = viewport_size.y - 40  # 20px margin top and bottom

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, panel_height)
	panel.position = Vector2(viewport_size.x - 280, 20)
	add_child(panel)

	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.8, 0.2, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	# Add ScrollContainer for scrollable content
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "DEBUG MENU"
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Press O to close"
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# === GOLD CONTROLS ===
	var gold_section_label = Label.new()
	gold_section_label.text = "GOLD"
	gold_section_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	gold_section_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(gold_section_label)

	# Gold display
	gold_label = Label.new()
	gold_label.text = "Gold: 0"
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(gold_label)

	# Gold buttons row
	var gold_hbox = HBoxContainer.new()
	gold_hbox.add_theme_constant_override("separation", 5)
	vbox.add_child(gold_hbox)

	var add_10_btn = _create_small_button("+10", Color(0.2, 0.8, 0.2))
	add_10_btn.pressed.connect(_on_add_gold.bind(10))
	gold_hbox.add_child(add_10_btn)

	var add_50_btn = _create_small_button("+50", Color(0.3, 0.9, 0.3))
	add_50_btn.pressed.connect(_on_add_gold.bind(50))
	gold_hbox.add_child(add_50_btn)

	var add_100_btn = _create_small_button("+100", Color(0.4, 1.0, 0.4))
	add_100_btn.pressed.connect(_on_add_gold.bind(100))
	gold_hbox.add_child(add_100_btn)

	# Open Shop button
	var shop_btn = _create_button("Open Shop", Color(1.0, 0.85, 0.0))
	shop_btn.pressed.connect(_on_open_shop_pressed)
	vbox.add_child(shop_btn)

	vbox.add_child(HSeparator.new())

	# === ACTION BUTTONS ===
	var actions_label = Label.new()
	actions_label.text = "ACTIONS"
	actions_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	actions_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(actions_label)

	# Kill All button
	var kill_btn = _create_button("Kill All Enemies", Color(0.9, 0.2, 0.2))
	kill_btn.pressed.connect(_on_kill_all_pressed)
	vbox.add_child(kill_btn)

	# Heal All button
	var heal_btn = _create_button("Heal All Enemies", Color(0.2, 0.8, 0.4))
	heal_btn.pressed.connect(_on_heal_all_pressed)
	vbox.add_child(heal_btn)

	# Heal Player button
	var heal_player_btn = _create_button("Heal Player", Color(0.4, 0.6, 0.9))
	heal_player_btn.pressed.connect(_on_heal_player_pressed)
	vbox.add_child(heal_player_btn)

	# Skip Wave button
	var skip_btn = _create_button("Skip Wave", Color(0.9, 0.6, 0.2))
	skip_btn.pressed.connect(_on_skip_wave_pressed)
	vbox.add_child(skip_btn)

	vbox.add_child(HSeparator.new())

	# === ENEMY CONTROL ===
	var control_label = Label.new()
	control_label.text = "ENEMY CONTROL"
	control_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	control_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(control_label)

	# Freeze/Unfreeze toggle button
	freeze_button = _create_button("Unfreeze Enemies", Color(0.4, 0.7, 0.9))
	freeze_button.pressed.connect(_on_freeze_toggle_pressed)
	vbox.add_child(freeze_button)

	vbox.add_child(HSeparator.new())

	# === VISUALIZATION ===
	var vis_label = Label.new()
	vis_label.text = "VISUALIZATION"
	vis_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.9))
	vis_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(vis_label)

	# Show Hitboxes toggle button
	hitbox_toggle_button = _create_button("Show Weapon Hitboxes", Color(0.9, 0.4, 0.9))
	hitbox_toggle_button.pressed.connect(_on_hitbox_toggle_pressed)
	vbox.add_child(hitbox_toggle_button)

	vbox.add_child(HSeparator.new())

	# === SPAWN ENEMIES ===
	var spawn_label = Label.new()
	spawn_label.text = "SPAWN ENEMIES"
	spawn_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	spawn_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(spawn_label)

	var spawn_hint = Label.new()
	spawn_hint.text = "Click & drag to arena"
	spawn_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	spawn_hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(spawn_hint)

	# Enemy spawn buttons (2 columns)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	vbox.add_child(grid)

	var enemy_colors = {
		"Slime": Color(0.0, 0.8, 0.0),
		"GoblinArcher": Color(0.3, 0.5, 0.2),
		"GoblinDual": Color(0.5, 0.4, 0.2),
		"GoblinMage": Color(0.3, 0.8, 0.3),
		"Golem": Color(0.5, 0.4, 0.35),
		"Healer": Color(0.2, 0.8, 0.4),
		"Spawner": Color(0.6, 0.3, 0.8),
		"Boss": Color(0.9, 0.1, 0.1)
	}

	for enemy_name in ENEMY_SCENES.keys():
		var btn = _create_spawn_button(enemy_name, enemy_colors.get(enemy_name, Color.WHITE))
		btn.pressed.connect(_on_spawn_button_pressed.bind(enemy_name))
		grid.add_child(btn)
		enemy_buttons[enemy_name] = btn

	vbox.add_child(HSeparator.new())

	# === SPAWN HAZARDS ===
	var hazard_label = Label.new()
	hazard_label.text = "SPAWN HAZARDS"
	hazard_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	hazard_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(hazard_label)

	var hazard_hint = Label.new()
	hazard_hint.text = "Click & drag to arena"
	hazard_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hazard_hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hazard_hint)

	# Hazard spawn buttons (2 columns)
	var hazard_grid = GridContainer.new()
	hazard_grid.columns = 2
	hazard_grid.add_theme_constant_override("h_separation", 5)
	hazard_grid.add_theme_constant_override("v_separation", 5)
	vbox.add_child(hazard_grid)

	var hazard_colors = {
		"FireGrate": Color(1.0, 0.5, 0.1),
		"FloorSpikes": Color(0.5, 0.5, 0.6),
		"SpikeWall": Color(0.6, 0.6, 0.7),
		"Crusher": Color(0.4, 0.3, 0.5)
	}

	for hazard_name in HAZARD_SCENES.keys():
		var btn = _create_spawn_button(hazard_name, hazard_colors.get(hazard_name, Color.WHITE))
		btn.pressed.connect(_on_hazard_button_pressed.bind(hazard_name))
		hazard_grid.add_child(btn)
		hazard_buttons[hazard_name] = btn

	# Clear All Hazards button
	var clear_hazards_btn = _create_button("Clear All Hazards", Color(0.8, 0.3, 0.3))
	clear_hazards_btn.pressed.connect(_on_clear_hazards_pressed)
	vbox.add_child(clear_hazards_btn)

	vbox.add_child(HSeparator.new())

	# === INFO ===
	var info_label = Label.new()
	info_label.text = "Waves are PAUSED"
	info_label.add_theme_color_override("font_color", Color(1, 0.5, 0.2))
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

func _create_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 35)

	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = color * 0.3
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color * 0.5
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = color * 0.7
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn

func _create_small_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(65, 30)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = color * 0.3
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color * 0.5
	btn.add_theme_stylebox_override("hover", hover_style)

	return btn

func _create_spawn_button(enemy_name: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = enemy_name
	btn.custom_minimum_size = Vector2(105, 30)
	btn.add_theme_font_size_override("font_size", 12)

	var style = StyleBoxFlat.new()
	style.bg_color = color * 0.25
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color * 0.4
	btn.add_theme_stylebox_override("hover", hover_style)

	return btn

# ============================================
# BUTTON HANDLERS
# ============================================
func _on_kill_all_pressed():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.die()
			count += 1
	print("[DEBUG] Killed %d enemies" % count)

func _on_heal_all_pressed():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.current_health = enemy.max_health
			enemy.health_changed.emit(enemy.current_health, enemy.max_health)
			count += 1
	print("[DEBUG] Healed %d enemies" % count)

func _on_heal_player_pressed():
	if player_reference and player_reference.stats:
		player_reference.stats.current_health = player_reference.stats.max_health
		player_reference.health_changed.emit(player_reference.stats.current_health, player_reference.stats.max_health)
		print("[DEBUG] Player healed to full")

func _on_skip_wave_pressed():
	# Kill all and let wave manager handle next wave
	_on_kill_all_pressed()
	print("[DEBUG] Wave skipped")

func _on_freeze_toggle_pressed():
	_set_enemies_frozen(not enemies_frozen)
	_update_freeze_button()
	if enemies_frozen:
		print("[DEBUG] Enemies frozen")
	else:
		print("[DEBUG] Enemies unfrozen - they can move now")

func _on_add_gold(amount: int):
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("add_gold"):
		game_manager.add_gold(amount)
		_update_gold_display()
		print("[DEBUG] Added %d gold" % amount)

func _on_open_shop_pressed():
	# Close debug menu first
	close_debug_menu()

	# Find and open upgrade menu
	var upgrade_menu = get_tree().get_first_node_in_group("upgrade_menu")
	if not upgrade_menu:
		upgrade_menu = get_node_or_null("/root/Game/UI/UpgradeMenu")
	if not upgrade_menu:
		# Try to find it anywhere in the scene
		for node in get_tree().current_scene.get_children():
			if node.name == "UpgradeMenu" or node is CanvasLayer and node.has_method("show_upgrades"):
				upgrade_menu = node
				break

	if upgrade_menu and upgrade_menu.has_method("show_upgrades"):
		if player_reference:
			upgrade_menu.show_upgrades(player_reference)
			print("[DEBUG] Opened shop")
	else:
		print("[DEBUG] Could not find UpgradeMenu")

func _update_gold_display():
	if not gold_label:
		return
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("get_gold"):
		gold_label.text = "Gold: %d" % game_manager.get_gold()
	else:
		gold_label.text = "Gold: N/A"

# ============================================
# DRAG AND DROP SPAWNING
# ============================================
func _on_spawn_button_pressed(enemy_name: String):
	is_dragging_enemy = true
	dragging_enemy_type = enemy_name

	# Create drag preview
	drag_preview = ColorRect.new()
	drag_preview.size = Vector2(40, 40)
	drag_preview.color = Color(0.8, 0.4, 0.8, 0.7)
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drag_preview)
	drag_preview.global_position = get_viewport().get_mouse_position() - Vector2(20, 20)

	# Add label to preview
	var label = Label.new()
	label.text = enemy_name[0]  # First letter
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(40, 40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.add_child(label)

	print("[DEBUG] Dragging %s - release to spawn" % enemy_name)

func _spawn_enemy_at_mouse():
	if dragging_enemy_type == "" or not ENEMY_SCENES.has(dragging_enemy_type):
		return

	var mouse_pos = get_viewport().get_mouse_position()

	# Get camera offset to convert screen position to world position
	var camera = get_viewport().get_camera_2d()
	var world_pos = mouse_pos
	if camera:
		world_pos = camera.get_screen_center_position() - get_viewport().get_visible_rect().size / 2 + mouse_pos

	# Spawn the enemy
	var enemy_scene = ENEMY_SCENES[dragging_enemy_type]
	var enemy = enemy_scene.instantiate()
	enemy.global_position = world_pos

	# Add to game scene
	var game_scene = get_tree().current_scene
	game_scene.add_child(enemy)

	# Set player reference
	if player_reference and enemy.has_method("set_player_reference"):
		enemy.set_player_reference(player_reference)

	# Respect current freeze state
	enemy.set_physics_process(not enemies_frozen)

	# Also pause timers if frozen (need to wait a frame for timers to be ready)
	if enemies_frozen:
		await get_tree().process_frame
		_set_enemy_timers_paused(enemy, true)

	print("[DEBUG] Spawned %s at %s (frozen: %s)" % [dragging_enemy_type, world_pos, enemies_frozen])

func _end_drag():
	is_dragging_enemy = false
	is_dragging_hazard = false
	dragging_enemy_type = ""
	dragging_hazard_type = ""
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

# ============================================
# HAZARD SPAWNING
# ============================================
func _on_hazard_button_pressed(hazard_name: String):
	is_dragging_hazard = true
	dragging_hazard_type = hazard_name

	# Create drag preview
	drag_preview = ColorRect.new()
	drag_preview.size = Vector2(40, 40)

	# Color based on hazard type
	var preview_colors = {
		"FireGrate": Color(1.0, 0.5, 0.1, 0.7),
		"FloorSpikes": Color(0.5, 0.5, 0.6, 0.7),
		"SpikeWall": Color(0.6, 0.6, 0.7, 0.7),
		"Crusher": Color(0.4, 0.3, 0.5, 0.7)
	}
	drag_preview.color = preview_colors.get(hazard_name, Color(0.8, 0.4, 0.4, 0.7))
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drag_preview)
	drag_preview.global_position = get_viewport().get_mouse_position() - Vector2(20, 20)

	# Add label to preview
	var label = Label.new()
	label.text = hazard_name[0]  # First letter
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(40, 40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.add_child(label)

	print("[DEBUG] Dragging %s hazard - release to spawn" % hazard_name)

func _spawn_hazard_at_mouse():
	if dragging_hazard_type == "" or not HAZARD_SCENES.has(dragging_hazard_type):
		return

	var mouse_pos = get_viewport().get_mouse_position()

	# Get camera offset to convert screen position to world position
	var camera = get_viewport().get_camera_2d()
	var world_pos = mouse_pos
	if camera:
		world_pos = camera.get_screen_center_position() - get_viewport().get_visible_rect().size / 2 + mouse_pos

	# Spawn the hazard
	var hazard_scene = HAZARD_SCENES[dragging_hazard_type]
	var hazard = hazard_scene.instantiate()
	hazard.global_position = world_pos

	# Add to game scene
	var game_scene = get_tree().current_scene
	game_scene.add_child(hazard)

	print("[DEBUG] Spawned %s hazard at %s" % [dragging_hazard_type, world_pos])

func _on_clear_hazards_pressed():
	var hazards = get_tree().get_nodes_in_group("hazards")
	var count = 0
	for hazard in hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()
			count += 1
	print("[DEBUG] Cleared %d hazards" % count)

# ============================================
# HITBOX VISUALIZATION (CONE HITBOX)
# ============================================
func _on_hitbox_toggle_pressed():
	show_hitboxes = not show_hitboxes
	_update_hitbox_button()

	if show_hitboxes:
		_create_cone_visualizer()
		print("[DEBUG] Showing weapon cone hitboxes")
	else:
		_clear_hitbox_visualizers()
		print("[DEBUG] Hiding weapon hitboxes")

func _update_hitbox_button():
	if hitbox_toggle_button:
		if show_hitboxes:
			hitbox_toggle_button.text = "Hide Weapon Hitboxes"
		else:
			hitbox_toggle_button.text = "Show Weapon Hitboxes"

func _clear_hitbox_visualizers():
	for viz in hitbox_visualizers:
		if is_instance_valid(viz):
			viz.queue_free()
	hitbox_visualizers.clear()

func _create_cone_visualizer():
	_clear_hitbox_visualizers()

	if not player_reference:
		_find_references()
		if not player_reference:
			return

	# Create a Node2D to draw the cone
	var cone_drawer = ConeHitboxDrawer.new()
	cone_drawer.player_ref = player_reference
	get_tree().current_scene.add_child(cone_drawer)
	hitbox_visualizers.append(cone_drawer)

func _physics_process(_delta):
	# Cone visualizer updates itself via _draw()
	if show_hitboxes:
		# Recreate if needed
		if hitbox_visualizers.is_empty():
			_create_cone_visualizer()

		# Force redraw on all visualizers
		for viz in hitbox_visualizers:
			if is_instance_valid(viz) and viz.has_method("queue_redraw"):
				viz.queue_redraw()

# ============================================
# CONE HITBOX DRAWER CLASS
# Shows the ACTUAL hitbox - follows weapon rotation during swing
# Also shows staff beam hitbox and skill hitboxes
# ============================================
class ConeHitboxDrawer extends Node2D:
	var player_ref: Node2D = null

	func _ready():
		z_index = 100  # Draw on top

	func _draw():
		if not is_instance_valid(player_ref):
			return

		var origin = player_ref.global_position

		# Get current weapon (melee)
		var melee_weapon = null
		if player_ref.get("current_weapon"):
			melee_weapon = player_ref.current_weapon

		# Get current staff (magic weapon)
		var staff_weapon = null
		if player_ref.get("current_staff"):
			staff_weapon = player_ref.current_staff

		# Draw melee weapon cone hitbox
		if is_instance_valid(melee_weapon):
			_draw_melee_hitbox(origin, melee_weapon)

		# Draw staff beam hitbox
		if is_instance_valid(staff_weapon):
			_draw_staff_hitbox(origin, staff_weapon)

		# Draw active skill hitboxes (AoE circles, etc.)
		_draw_skill_hitboxes()

	func _draw_melee_hitbox(origin: Vector2, weapon: Node2D):
		# Get cone parameters from weapon
		var attack_range: float = weapon.get("attack_range") if weapon.get("attack_range") else 100.0
		var cone_angle: float = weapon.get("attack_cone_angle") if weapon.get("attack_cone_angle") else 90.0
		var inner_radius: float = weapon.get("attack_inner_radius") if weapon.get("attack_inner_radius") else 0.0

		# Check if weapon is in active frames
		var is_active = weapon.get("_is_in_active_frames") if weapon.get("_is_in_active_frames") != null else false

		# Get the attack direction based on state
		var attack_angle: float
		var attack_direction: Vector2

		if is_active:
			var stored_direction = weapon.get("current_attack_direction")
			attack_direction = stored_direction if stored_direction else Vector2.RIGHT
			attack_angle = attack_direction.angle()
		else:
			var mouse_pos = get_global_mouse_position()
			attack_direction = (mouse_pos - origin).normalized()
			if attack_direction == Vector2.ZERO:
				attack_direction = Vector2.RIGHT
			attack_angle = attack_direction.angle()

		var half_cone = deg_to_rad(cone_angle / 2.0)

		# Draw cone
		var cone_color: Color
		if is_active:
			cone_color = Color(1.0, 0.2, 0.2, 0.5)  # Bright red when active
		else:
			cone_color = Color(0.2, 0.6, 1.0, 0.2)  # Faint blue when inactive

		# Draw filled cone
		var segments = 32
		var points: PackedVector2Array = []

		if inner_radius > 0:
			for i in range(segments + 1):
				var angle = attack_angle - half_cone + (half_cone * 2.0 * i / segments)
				var point = origin + Vector2.from_angle(angle) * attack_range
				points.append(point)
			for i in range(segments, -1, -1):
				var angle = attack_angle - half_cone + (half_cone * 2.0 * i / segments)
				var point = origin + Vector2.from_angle(angle) * inner_radius
				points.append(point)
		else:
			points.append(origin)
			for i in range(segments + 1):
				var angle = attack_angle - half_cone + (half_cone * 2.0 * i / segments)
				var point = origin + Vector2.from_angle(angle) * attack_range
				points.append(point)

		if points.size() >= 3:
			draw_colored_polygon(points, cone_color)

		# Draw outline
		var outline_color = Color(1.0, 0.3, 0.3, 0.9) if is_active else Color(0.5, 0.8, 1.0, 0.4)
		var line_width = 3.0 if is_active else 1.0

		var prev_point = origin + Vector2.from_angle(attack_angle - half_cone) * attack_range
		for i in range(1, segments + 1):
			var angle = attack_angle - half_cone + (half_cone * 2.0 * i / segments)
			var point = origin + Vector2.from_angle(angle) * attack_range
			draw_line(prev_point, point, outline_color, line_width)
			prev_point = point

		var left_end = origin + Vector2.from_angle(attack_angle - half_cone) * attack_range
		var right_end = origin + Vector2.from_angle(attack_angle + half_cone) * attack_range

		if inner_radius > 0:
			var left_inner = origin + Vector2.from_angle(attack_angle - half_cone) * inner_radius
			var right_inner = origin + Vector2.from_angle(attack_angle + half_cone) * inner_radius
			draw_line(left_inner, left_end, outline_color, line_width)
			draw_line(right_inner, right_end, outline_color, line_width)
			prev_point = origin + Vector2.from_angle(attack_angle - half_cone) * inner_radius
			for i in range(1, segments + 1):
				var angle = attack_angle - half_cone + (half_cone * 2.0 * i / segments)
				var point = origin + Vector2.from_angle(angle) * inner_radius
				draw_line(prev_point, point, outline_color, line_width)
				prev_point = point
		else:
			draw_line(origin, left_end, outline_color, line_width)
			draw_line(origin, right_end, outline_color, line_width)

		# Draw center direction line
		var center_end = origin + attack_direction * attack_range
		var center_color = Color(1.0, 0.5, 0.0, 0.8) if is_active else Color(1.0, 1.0, 0.0, 0.5)
		draw_line(origin, center_end, center_color, 2.0 if is_active else 1.5)

		# Draw range circle
		draw_arc(origin, attack_range, 0, TAU, 64, Color(1.0, 1.0, 1.0, 0.15), 1.0)

		# Draw weapon info
		var weapon_name = str(weapon.name) if weapon else "Unknown"
		var status = "ACTIVE" if is_active else "Preview"
		var info_text = "%s | %s | Range: %.0f | Angle: %.0f°" % [weapon_name, status, attack_range, cone_angle]
		draw_string(ThemeDB.fallback_font, origin + Vector2(-100, -attack_range - 20), info_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)

	func _draw_staff_hitbox(origin: Vector2, staff: Node2D):
		# Get beam parameters from staff
		var beam_range: float = staff.get("beam_range") if staff.get("beam_range") else 800.0
		var beam_width: float = staff.get("beam_width") if staff.get("beam_width") else 32.0

		# Check if staff is using skill (beam active)
		var is_using_skill = staff.get("is_using_skill") if staff.get("is_using_skill") != null else false

		# Get beam direction (toward mouse)
		var mouse_pos = get_global_mouse_position()
		var beam_direction = (mouse_pos - origin).normalized()
		if beam_direction == Vector2.ZERO:
			beam_direction = Vector2.RIGHT

		# Draw beam rectangle hitbox
		var beam_color: Color
		if is_using_skill:
			beam_color = Color(1.0, 0.8, 0.2, 0.4)  # Yellow when active
		else:
			beam_color = Color(0.8, 0.4, 1.0, 0.15)  # Faint purple preview

		# Calculate beam rectangle corners
		var perpendicular = beam_direction.rotated(PI / 2)
		var half_width = beam_width / 2.0
		var beam_end = origin + beam_direction * beam_range

		var p1 = origin + perpendicular * half_width
		var p2 = origin - perpendicular * half_width
		var p3 = beam_end - perpendicular * half_width
		var p4 = beam_end + perpendicular * half_width

		# Draw filled beam area
		var beam_points: PackedVector2Array = [p1, p2, p3, p4]
		draw_colored_polygon(beam_points, beam_color)

		# Draw outline
		var outline_color = Color(1.0, 0.8, 0.2, 0.8) if is_using_skill else Color(0.8, 0.4, 1.0, 0.4)
		var line_width = 2.0 if is_using_skill else 1.0
		draw_line(p1, p2, outline_color, line_width)
		draw_line(p2, p3, outline_color, line_width)
		draw_line(p3, p4, outline_color, line_width)
		draw_line(p4, p1, outline_color, line_width)

		# Draw center line
		draw_line(origin, beam_end, Color(1.0, 0.6, 0.0, 0.6), 1.5)

		# Draw staff info
		var staff_name = str(staff.name) if staff else "Unknown Staff"
		var status = "BEAM ACTIVE" if is_using_skill else "Beam Preview"
		var info_text = "%s | %s | Range: %.0f | Width: %.0f" % [staff_name, status, beam_range, beam_width]
		draw_string(ThemeDB.fallback_font, origin + Vector2(-100, 40), info_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.8, 0.6, 1.0))

	func _draw_skill_hitboxes():
		# Find active skill nodes and draw their hitboxes
		var tree = get_tree()
		if not tree:
			return

		# Draw BasicSwordSkill (spin slash) - circular AoE
		for node in tree.get_nodes_in_group("skill_hitbox"):
			if is_instance_valid(node):
				_draw_circular_hitbox(node.global_position, 100.0, Color(0.2, 1.0, 0.2, 0.3), "Skill")

		# Find any Area2D children that are skill hitboxes
		var skills_to_check = [
			"BasicSwordSkill", "ExecutionersAxeSkill", "VolcanoSkill",
			"BlizzardSkill", "BlackHoleSkill", "ChainLightningSkill",
			"DarkConversionSkill", "ArcaneBeamSkill", "FireZone"
		]

		for skill_name in skills_to_check:
			var skill_nodes = tree.get_nodes_in_group(skill_name.to_lower())
			for skill in skill_nodes:
				if is_instance_valid(skill):
					_draw_skill_area(skill, skill_name)

		# Also check for any node with "Skill" in its name
		_find_and_draw_skill_nodes(tree.current_scene)

	func _find_and_draw_skill_nodes(node: Node):
		if not is_instance_valid(node):
			return

		var node_name = node.name.to_lower()

		# Check if this is a skill node
		if "skill" in node_name or "zone" in node_name or "pool" in node_name:
			if node is Node2D:
				# Try to get radius from the node
				var radius = 100.0
				if node.get("volcano_radius"):
					radius = node.get("volcano_radius")
				elif node.get("radius"):
					radius = node.get("radius")
				elif node.get("effect_radius"):
					radius = node.get("effect_radius")

				# Check for HitBox child
				var hitbox = node.get_node_or_null("HitBox")
				if hitbox and hitbox is Area2D:
					var collision = hitbox.get_node_or_null("CollisionShape2D")
					if collision and collision.shape:
						if collision.shape is CircleShape2D:
							radius = collision.shape.radius
						elif collision.shape is RectangleShape2D:
							radius = max(collision.shape.size.x, collision.shape.size.y) / 2

				var skill_color = _get_skill_color(node_name)
				_draw_circular_hitbox(node.global_position, radius, skill_color, node.name)

		# Recursively check children
		for child in node.get_children():
			_find_and_draw_skill_nodes(child)

	func _draw_skill_area(skill: Node2D, skill_name: String):
		var radius = 100.0
		var color = Color(0.2, 1.0, 0.2, 0.3)

		# Get skill-specific radius
		match skill_name:
			"VolcanoSkill":
				radius = skill.get("volcano_radius") if skill.get("volcano_radius") else 150.0
				color = Color(1.0, 0.4, 0.1, 0.3)
			"BlizzardSkill":
				radius = skill.get("blizzard_radius") if skill.get("blizzard_radius") else 200.0
				color = Color(0.3, 0.7, 1.0, 0.3)
			"BlackHoleSkill":
				radius = skill.get("pull_radius") if skill.get("pull_radius") else 250.0
				color = Color(0.5, 0.0, 0.8, 0.3)
			"FireZone":
				radius = skill.get("zone_radius") if skill.get("zone_radius") else 100.0
				color = Color(1.0, 0.5, 0.0, 0.3)
			"BasicSwordSkill", "ExecutionersAxeSkill":
				# Try to get from HitBox collision shape
				var hitbox = skill.get_node_or_null("HitBox")
				if hitbox:
					var collision = hitbox.get_node_or_null("CollisionShape2D")
					if collision and collision.shape and collision.shape is CircleShape2D:
						radius = collision.shape.radius
				color = Color(0.2, 1.0, 0.4, 0.3)

		_draw_circular_hitbox(skill.global_position, radius, color, skill_name)

	func _draw_circular_hitbox(pos: Vector2, radius: float, color: Color, label: String):
		# Draw filled circle
		draw_circle(pos, radius, color)

		# Draw outline
		var outline_color = Color(color.r, color.g, color.b, 0.8)
		draw_arc(pos, radius, 0, TAU, 64, outline_color, 2.0)

		# Draw label
		draw_string(ThemeDB.fallback_font, pos + Vector2(-40, -radius - 10), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, outline_color)

	func _get_skill_color(skill_name: String) -> Color:
		if "fire" in skill_name or "volcano" in skill_name or "inferno" in skill_name:
			return Color(1.0, 0.4, 0.1, 0.3)
		elif "ice" in skill_name or "frost" in skill_name or "blizzard" in skill_name:
			return Color(0.3, 0.7, 1.0, 0.3)
		elif "void" in skill_name or "black" in skill_name or "dark" in skill_name:
			return Color(0.5, 0.0, 0.8, 0.3)
		elif "lightning" in skill_name or "electric" in skill_name or "chain" in skill_name:
			return Color(1.0, 1.0, 0.3, 0.3)
		elif "necro" in skill_name or "death" in skill_name:
			return Color(0.4, 0.8, 0.3, 0.3)
		else:
			return Color(0.2, 1.0, 0.4, 0.3)
