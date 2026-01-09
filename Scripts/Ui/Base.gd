# SCRIPT: Base.gd
# ATTACH TO: Base (Control) root node in Base.tscn
# LOCATION: res://Scripts/Ui/Base.gd
# PURPOSE: Hub scene controller with modern tabbed interface

extends Control

# Tab system
var current_tab: String = "main"
var tab_buttons: Dictionary = {}
var tab_panels: Dictionary = {}

# Training row references
var training_rows: Dictionary = {}

# Loaded resources
var all_relics: Array = []

# Dynamic UI containers
var content_container: PanelContainer = null
var tab_button_container: HBoxContainer = null
var gold_display_label: Label = null
var stats_preview_label: Label = null
var enter_arena_btn: Button = null

# Animation
var _pulse_tween: Tween = null

# Training stat info (matches SaveManager.TRAINING_BONUSES)
const TRAINING_INFO = {
	"vitality": {"display_name": "Vitality", "color": Color(0.9, 0.35, 0.35), "icon": "HP", "bonus": "+15 HP"},
	"strength": {"display_name": "Strength", "color": Color(1.0, 0.6, 0.2), "icon": "DMG", "bonus": "+6% Dmg"},
	"agility": {"display_name": "Agility", "color": Color(0.35, 0.9, 0.5), "icon": "SPD", "bonus": "+5% Spd"},
	"reflexes": {"display_name": "Reflexes", "color": Color(0.4, 0.7, 1.0), "icon": "CD", "bonus": "-4% CD"},
	"fortune": {"display_name": "Fortune", "color": Color(1.0, 0.85, 0.3), "icon": "GOLD", "bonus": "+10 Gold"}
}

# Enemy info for bestiary
const ENEMY_INFO = {
	"slime": {"emoji": "", "color": Color(0.3, 0.9, 0.4), "name": "Slime", "desc": "Basic enemy"},
	"goblin_dual": {"emoji": "", "color": Color(0.6, 0.4, 0.3), "name": "Goblin Warrior", "desc": "Melee fighter"},
	"goblin_archer": {"emoji": "", "color": Color(0.5, 0.6, 0.3), "name": "Goblin Archer", "desc": "Ranged attacker"},
	"healer": {"emoji": "", "color": Color(0.3, 0.9, 0.6), "name": "Healer", "desc": "Heals allies"},
	"spawner": {"emoji": "", "color": Color(0.6, 0.3, 0.7), "name": "Spawner", "desc": "Summons minions"},
	"boss": {"emoji": "", "color": Color(0.9, 0.2, 0.2), "name": "Chaos Champion", "desc": "Arena boss"},
	"unknown": {"emoji": "?", "color": Color.GRAY, "name": "Unknown", "desc": "???"}
}

# Colors
const BG_COLOR = Color(0.06, 0.05, 0.09)
const PANEL_BG = Color(0.09, 0.07, 0.12)
const PANEL_BORDER = Color(0.25, 0.2, 0.35)
const ACCENT_COLOR = Color(0.9, 0.7, 0.3)
const TEXT_DIM = Color(0.5, 0.5, 0.55)

func _ready():
	# Connect signals
	SaveManager.gold_changed.connect(_on_gold_changed)

	# Load resources
	_load_all_relics()

	# Build the entire UI dynamically
	_build_hub_ui()

	# Start pulse animation for enter button
	_start_enter_button_pulse()

func _load_all_relics():
	var dir = DirAccess.open("res://Resources/Relics")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var relic = load("res://Resources/Relics/" + file_name)
				if relic:
					all_relics.append(relic)
			file_name = dir.get_next()
		dir.list_dir_end()

# ============================================
# BUILD UI
# ============================================

func _build_hub_ui():
	# Clear existing children from the scene
	for child in get_children():
		child.queue_free()

	# Background with gradient effect
	var bg = ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Add subtle background particles
	_add_background_effects()

	# Main margin container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_vbox)

	# === HEADER ===
	var header = _create_header()
	main_vbox.add_child(header)

	# === TAB BUTTONS ===
	tab_button_container = _create_tab_buttons()
	main_vbox.add_child(tab_button_container)

	# === CONTENT AREA ===
	content_container = PanelContainer.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content_style = _create_panel_style(PANEL_BG, PANEL_BORDER, 12)
	content_container.add_theme_stylebox_override("panel", content_style)
	main_vbox.add_child(content_container)

	# === BOTTOM BAR ===
	var bottom = _create_bottom_bar()
	main_vbox.add_child(bottom)

	# Show main tab by default
	_switch_tab("main")

func _add_background_effects():
	# Floating particles for atmosphere
	var particle_container = Control.new()
	particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(particle_container)

	for i in range(15):
		var particle = ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.color = Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, randf_range(0.05, 0.15))
		particle.position = Vector2(randf_range(0, 1280), randf_range(0, 720))
		particle_container.add_child(particle)
		_animate_bg_particle(particle)

func _animate_bg_particle(particle: ColorRect):
	var duration = randf_range(10, 18)
	var tween = create_tween().set_loops()
	tween.tween_property(particle, "position:y", particle.position.y - 150, duration)
	tween.tween_property(particle, "position:y", particle.position.y, duration)

func _create_panel_style(bg_color: Color, border_color: Color, corner_radius: int = 8) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	return style

func _create_header() -> HBoxContainer:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)

	# Left side - Title with decoration
	var title_container = HBoxContainer.new()
	title_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.add_theme_constant_override("separation", 15)
	header.add_child(title_container)

	# Decorative line left
	var line_left = ColorRect.new()
	line_left.custom_minimum_size = Vector2(40, 3)
	line_left.color = ACCENT_COLOR
	line_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_container.add_child(line_left)

	# Title
	var title = Label.new()
	title.text = "THE BASE"
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	title.add_theme_font_size_override("font_size", 42)
	title_container.add_child(title)

	# Decorative line right
	var line_right = ColorRect.new()
	line_right.custom_minimum_size = Vector2(40, 3)
	line_right.color = ACCENT_COLOR
	line_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_container.add_child(line_right)

	# Right side - Gold display panel
	var gold_panel = PanelContainer.new()
	var gold_style = _create_panel_style(Color(0.12, 0.1, 0.08), Color(0.8, 0.65, 0.2), 8)
	gold_style.content_margin_left = 15
	gold_style.content_margin_right = 15
	gold_style.content_margin_top = 8
	gold_style.content_margin_bottom = 8
	gold_panel.add_theme_stylebox_override("panel", gold_style)
	header.add_child(gold_panel)

	var gold_hbox = HBoxContainer.new()
	gold_hbox.add_theme_constant_override("separation", 8)
	gold_panel.add_child(gold_hbox)

	var gold_icon = Label.new()
	gold_icon.text = "GOLD"
	gold_icon.add_theme_font_size_override("font_size", 14)
	gold_icon.add_theme_color_override("font_color", Color(0.7, 0.55, 0.2))
	gold_hbox.add_child(gold_icon)

	gold_display_label = Label.new()
	gold_display_label.name = "GoldDisplay"
	gold_display_label.text = "%d" % SaveManager.get_gold()
	gold_display_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	gold_display_label.add_theme_font_size_override("font_size", 28)
	gold_hbox.add_child(gold_display_label)

	return header

func _create_tab_buttons() -> HBoxContainer:
	var outer_container = HBoxContainer.new()
	outer_container.alignment = BoxContainer.ALIGNMENT_CENTER

	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	outer_container.add_child(container)

	var tabs = [
		{"id": "main", "text": "Overview", "color": ACCENT_COLOR},
		{"id": "training", "text": "Training", "color": Color(1.0, 0.5, 0.2)},
		{"id": "relics", "text": "Relics", "color": Color(0.7, 0.4, 1.0)},
		{"id": "bestiary", "text": "Bestiary", "color": Color(0.9, 0.35, 0.35)},
		{"id": "stats", "text": "Statistics", "color": Color(0.4, 0.75, 1.0)}
	]

	for tab_data in tabs:
		var btn = Button.new()
		btn.text = tab_data.text
		btn.custom_minimum_size = Vector2(130, 45)
		btn.add_theme_font_size_override("font_size", 17)

		# Custom button style
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.12, 0.1, 0.15)
		normal_style.border_color = Color(0.25, 0.22, 0.3)
		normal_style.set_border_width_all(1)
		normal_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", normal_style)

		var hover_style = normal_style.duplicate()
		hover_style.bg_color = Color(0.18, 0.15, 0.22)
		hover_style.border_color = tab_data.color
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.pressed.connect(_switch_tab.bind(tab_data.id))
		container.add_child(btn)
		tab_buttons[tab_data.id] = {"button": btn, "color": tab_data.color, "normal_style": normal_style}

	return outer_container

func _create_bottom_bar() -> HBoxContainer:
	var bar = HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 40)

	# Back to Main Menu button
	var back_btn = Button.new()
	back_btn.text = "< Main Menu"
	back_btn.custom_minimum_size = Vector2(160, 55)
	back_btn.add_theme_font_size_override("font_size", 18)

	var back_style = StyleBoxFlat.new()
	back_style.bg_color = Color(0.15, 0.12, 0.18)
	back_style.border_color = Color(0.4, 0.35, 0.5)
	back_style.set_border_width_all(2)
	back_style.set_corner_radius_all(8)
	back_btn.add_theme_stylebox_override("normal", back_style)

	var back_hover = back_style.duplicate()
	back_hover.bg_color = Color(0.2, 0.17, 0.25)
	back_hover.border_color = Color(0.6, 0.5, 0.7)
	back_btn.add_theme_stylebox_override("hover", back_hover)

	back_btn.pressed.connect(_on_back_to_menu_pressed)
	bar.add_child(back_btn)

	# Enter Arena button - Main CTA
	enter_arena_btn = Button.new()
	enter_arena_btn.text = "ENTER ARENA"
	enter_arena_btn.custom_minimum_size = Vector2(280, 65)
	enter_arena_btn.add_theme_font_size_override("font_size", 26)

	var enter_style = StyleBoxFlat.new()
	enter_style.bg_color = Color(0.7, 0.25, 0.2)
	enter_style.border_color = Color(1.0, 0.5, 0.3)
	enter_style.set_border_width_all(3)
	enter_style.set_corner_radius_all(10)
	enter_arena_btn.add_theme_stylebox_override("normal", enter_style)

	var enter_hover = enter_style.duplicate()
	enter_hover.bg_color = Color(0.85, 0.3, 0.25)
	enter_hover.border_color = Color(1.0, 0.7, 0.4)
	enter_arena_btn.add_theme_stylebox_override("hover", enter_hover)

	enter_arena_btn.add_theme_color_override("font_color", Color.WHITE)
	enter_arena_btn.pressed.connect(_on_enter_arena_pressed)
	bar.add_child(enter_arena_btn)

	return bar

func _start_enter_button_pulse():
	if not enter_arena_btn:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(enter_arena_btn, "modulate", Color(1.1, 1.1, 1.1), 0.8).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(enter_arena_btn, "modulate", Color(1.0, 1.0, 1.0), 0.8).set_ease(Tween.EASE_IN_OUT)

func _on_back_to_menu_pressed():
	get_tree().change_scene_to_file("res://Scenes/Main/MainMenu.tscn")

# ============================================
# TAB SWITCHING
# ============================================

func _switch_tab(tab_id: String):
	current_tab = tab_id

	# Update button styles
	for id in tab_buttons:
		var btn_data = tab_buttons[id]
		var btn = btn_data.button
		if id == tab_id:
			# Active tab style
			var active_style = StyleBoxFlat.new()
			active_style.bg_color = Color(btn_data.color.r * 0.25, btn_data.color.g * 0.25, btn_data.color.b * 0.25)
			active_style.border_color = btn_data.color
			active_style.set_border_width_all(2)
			active_style.set_corner_radius_all(6)
			btn.add_theme_stylebox_override("normal", active_style)
			btn.add_theme_color_override("font_color", btn_data.color)
		else:
			# Inactive tab style
			btn.add_theme_stylebox_override("normal", btn_data.normal_style)
			btn.add_theme_color_override("font_color", TEXT_DIM)

	# Clear old references before freeing nodes
	training_rows.clear()
	stats_preview_label = null

	# Clear content
	for child in content_container.get_children():
		child.queue_free()

	# Wait for nodes to be freed before building new content
	await get_tree().process_frame

	# Build tab content
	match tab_id:
		"main":
			_build_main_tab()
		"training":
			_build_training_tab()
		"relics":
			_build_relics_tab()
		"bestiary":
			_build_bestiary_tab()
		"stats":
			_build_stats_tab()

# ============================================
# MAIN TAB
# ============================================

func _build_main_tab():
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 25)
	scroll.add_child(vbox)

	# Welcome section
	var welcome_panel = _create_section_panel("Welcome, Warrior!", ACCENT_COLOR)
	vbox.add_child(welcome_panel)

	var welcome_content = welcome_panel.get_child(0)
	var stats = SaveManager.get_statistics()

	# Quick stats in a horizontal layout
	var quick_stats = HBoxContainer.new()
	quick_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_stats.add_theme_constant_override("separation", 50)
	welcome_content.add_child(quick_stats)

	_add_stat_display(quick_stats, "Highest Wave", str(stats.highest_wave), Color(0.9, 0.75, 0.3))
	_add_stat_display(quick_stats, "Total Runs", str(stats.total_runs), Color(0.6, 0.6, 0.7))
	_add_stat_display(quick_stats, "Total Kills", str(stats.total_kills), Color(0.9, 0.4, 0.4))

	# Starting stats section
	var starting_panel = _create_section_panel("Your Starting Stats", Color(0.5, 0.8, 0.5))
	vbox.add_child(starting_panel)

	var starting_content = starting_panel.get_child(0)

	var base_health = 100 + SaveManager.get_training_bonus("vitality")
	var damage_bonus = SaveManager.get_training_bonus("strength") * 100
	var speed_bonus = SaveManager.get_training_bonus("agility") * 100
	var cd_reduction = SaveManager.get_training_bonus("reflexes") * 100
	var starting_gold = int(SaveManager.get_training_bonus("fortune"))

	var stats_grid = HBoxContainer.new()
	stats_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_grid.add_theme_constant_override("separation", 40)
	starting_content.add_child(stats_grid)

	_add_stat_badge(stats_grid, "HP", str(int(base_health)), TRAINING_INFO.vitality.color)
	_add_stat_badge(stats_grid, "DMG", "+%.0f%%" % damage_bonus, TRAINING_INFO.strength.color)
	_add_stat_badge(stats_grid, "SPD", "+%.0f%%" % speed_bonus, TRAINING_INFO.agility.color)
	_add_stat_badge(stats_grid, "CD", "-%.0f%%" % cd_reduction, TRAINING_INFO.reflexes.color)
	_add_stat_badge(stats_grid, "GOLD", str(starting_gold), TRAINING_INFO.fortune.color)

	# Tips section
	var tip_label = Label.new()
	tip_label.text = "Use the tabs above to train stats, unlock relics, or view your bestiary."
	tip_label.add_theme_font_size_override("font_size", 15)
	tip_label.add_theme_color_override("font_color", TEXT_DIM)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tip_label)

func _add_stat_display(parent: Control, label_text: String, value_text: String, color: Color):
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)

	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 36)
	value.add_theme_color_override("font_color", color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(value)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(label)

func _add_stat_badge(parent: Control, label_text: String, value_text: String, color: Color):
	var badge = PanelContainer.new()
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15)
	badge_style.border_color = color
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(8)
	badge_style.content_margin_left = 15
	badge_style.content_margin_right = 15
	badge_style.content_margin_top = 10
	badge_style.content_margin_bottom = 10
	badge.add_theme_stylebox_override("panel", badge_style)
	parent.add_child(badge)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	badge.add_child(vbox)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 22)
	value.add_theme_color_override("font_color", Color.WHITE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(value)

func _create_section_panel(title_text: String, title_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.1)
	style.border_color = Color(title_color.r * 0.5, title_color.g * 0.5, title_color.b * 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", title_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	return panel

# ============================================
# TRAINING TAB
# ============================================

func _build_training_tab():
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 15)
	scroll.add_child(vbox)

	# Header
	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header)

	var title = Label.new()
	title.text = "TRAINING GROUNDS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	header.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Permanently increase your starting stats with gold"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Stats preview panel
	var preview_panel = PanelContainer.new()
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.08, 0.07, 0.11)
	preview_style.border_color = Color(0.4, 0.35, 0.5)
	preview_style.set_border_width_all(1)
	preview_style.set_corner_radius_all(8)
	preview_style.content_margin_left = 20
	preview_style.content_margin_right = 20
	preview_style.content_margin_top = 12
	preview_style.content_margin_bottom = 12
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	vbox.add_child(preview_panel)

	stats_preview_label = Label.new()
	stats_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_preview_label.add_theme_font_size_override("font_size", 16)
	stats_preview_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	preview_panel.add_child(stats_preview_label)
	_update_stats_preview()

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_color_override("separation", Color(0.2, 0.18, 0.25))
	vbox.add_child(sep)

	# Training cards
	training_rows.clear()
	for stat_name in ["vitality", "strength", "agility", "reflexes", "fortune"]:
		var card = _create_training_card(stat_name)
		vbox.add_child(card)
		training_rows[stat_name] = card

	# Reset button
	var reset_container = HBoxContainer.new()
	reset_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(reset_container)

	var reset_btn = Button.new()
	reset_btn.text = "Reset All & Refund Gold"
	reset_btn.custom_minimum_size = Vector2(220, 45)
	reset_btn.add_theme_font_size_override("font_size", 16)

	var reset_style = StyleBoxFlat.new()
	reset_style.bg_color = Color(0.35, 0.1, 0.1)
	reset_style.border_color = Color(0.7, 0.25, 0.2)
	reset_style.set_border_width_all(2)
	reset_style.set_corner_radius_all(6)
	reset_btn.add_theme_stylebox_override("normal", reset_style)

	var reset_hover = reset_style.duplicate()
	reset_hover.bg_color = Color(0.5, 0.15, 0.12)
	reset_btn.add_theme_stylebox_override("hover", reset_hover)

	reset_btn.pressed.connect(_on_reset_training_pressed)
	reset_container.add_child(reset_btn)

func _create_training_card(stat_name: String) -> PanelContainer:
	var info = TRAINING_INFO[stat_name]
	var level = SaveManager.get_training_level(stat_name)
	var cost = SaveManager.get_training_cost(stat_name)

	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(info.color.r * 0.08, info.color.g * 0.08, info.color.b * 0.08)
	card_style.border_color = Color(info.color.r * 0.4, info.color.g * 0.4, info.color.b * 0.4)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(10)
	card_style.content_margin_left = 20
	card_style.content_margin_right = 20
	card_style.content_margin_top = 12
	card_style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	card.add_child(hbox)

	# Icon/indicator
	var icon_panel = PanelContainer.new()
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = info.color
	icon_style.set_corner_radius_all(6)
	icon_style.content_margin_left = 10
	icon_style.content_margin_right = 10
	icon_style.content_margin_top = 8
	icon_style.content_margin_bottom = 8
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	hbox.add_child(icon_panel)

	var icon_label = Label.new()
	icon_label.text = info.icon
	icon_label.add_theme_font_size_override("font_size", 14)
	icon_label.add_theme_color_override("font_color", Color.WHITE)
	icon_panel.add_child(icon_label)

	# Stat info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = info.display_name
	name_label.add_theme_color_override("font_color", info.color)
	name_label.add_theme_font_size_override("font_size", 20)
	info_vbox.add_child(name_label)

	var bonus_label = Label.new()
	bonus_label.text = "%s per level" % info.bonus
	bonus_label.add_theme_font_size_override("font_size", 14)
	bonus_label.add_theme_color_override("font_color", TEXT_DIM)
	info_vbox.add_child(bonus_label)

	# Level progress
	var level_container = VBoxContainer.new()
	level_container.add_theme_constant_override("separation", 5)
	hbox.add_child(level_container)

	var level_label = Label.new()
	level_label.name = "Level"
	level_label.text = "Level %d / 5" % level
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_container.add_child(level_label)

	# Level dots
	var dots_container = HBoxContainer.new()
	dots_container.add_theme_constant_override("separation", 5)
	dots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	level_container.add_child(dots_container)

	for i in range(5):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		if i < level:
			dot.color = info.color
		else:
			dot.color = Color(0.2, 0.18, 0.25)
		dots_container.add_child(dot)

	# Upgrade button
	var btn = Button.new()
	btn.name = "UpgradeBtn"
	btn.custom_minimum_size = Vector2(110, 45)
	btn.add_theme_font_size_override("font_size", 16)

	if cost < 0:
		btn.text = "MAX"
		btn.disabled = true
		var max_style = StyleBoxFlat.new()
		max_style.bg_color = Color(0.15, 0.15, 0.15)
		max_style.border_color = Color(0.3, 0.3, 0.3)
		max_style.set_border_width_all(1)
		max_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("disabled", max_style)
	else:
		btn.text = "%d G" % cost
		btn.disabled = SaveManager.get_gold() < cost

		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.2, 0.18, 0.12)
		btn_style.border_color = Color(0.7, 0.6, 0.3)
		btn_style.set_border_width_all(2)
		btn_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover = btn_style.duplicate()
		btn_hover.bg_color = Color(0.3, 0.25, 0.15)
		btn.add_theme_stylebox_override("hover", btn_hover)

	btn.pressed.connect(_on_training_upgrade.bind(stat_name))
	hbox.add_child(btn)

	return card

func _update_stats_preview():
	if not stats_preview_label or not is_instance_valid(stats_preview_label):
		return
	var base_health = 100 + SaveManager.get_training_bonus("vitality")
	var damage_bonus = SaveManager.get_training_bonus("strength") * 100
	var speed_bonus = SaveManager.get_training_bonus("agility") * 100
	var cd_reduction = SaveManager.get_training_bonus("reflexes") * 100
	var starting_gold = int(SaveManager.get_training_bonus("fortune"))

	stats_preview_label.text = "Starting: %d HP | +%.0f%% Damage | +%.0f%% Speed | -%.0f%% Cooldown | %d Gold" % [
		base_health, damage_bonus, speed_bonus, cd_reduction, starting_gold
	]

func _on_training_upgrade(stat_name: String):
	if SaveManager.upgrade_training(stat_name):
		# Rebuild the training tab to update visuals
		_switch_tab("training")

func _on_reset_training_pressed():
	var refund = SaveManager.reset_training_and_refund()
	if refund > 0:
		print("[Base] Reset training, refunded %d gold" % refund)
	_switch_tab("training")

func _update_training_buttons():
	if current_tab != "training" or training_rows.is_empty():
		return

	for stat_name in training_rows:
		var card = training_rows[stat_name]
		if not is_instance_valid(card):
			continue
		var cost = SaveManager.get_training_cost(stat_name)
		var btn = card.get_node_or_null("HBoxContainer/UpgradeBtn") if card.has_node("HBoxContainer/UpgradeBtn") else null
		if not btn:
			# Try to find button in the card
			for child in card.get_children():
				if child is HBoxContainer:
					for subchild in child.get_children():
						if subchild.name == "UpgradeBtn":
							btn = subchild
							break
		if btn and is_instance_valid(btn) and cost >= 0:
			btn.disabled = SaveManager.get_gold() < cost

# ============================================
# RELICS TAB
# ============================================

func _build_relics_tab():
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 15)
	scroll.add_child(vbox)

	# Header
	var title = Label.new()
	title.text = "RELIC SHRINE"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.7, 0.4, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Unlock relics to find them during your runs"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Relic count
	var unlocked_count = 0
	for relic in all_relics:
		if SaveManager.is_relic_unlocked(relic.id) or relic.unlock_cost == 0:
			unlocked_count += 1

	var count_label = Label.new()
	count_label.text = "Unlocked: %d / %d" % [unlocked_count, all_relics.size()]
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.8))
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(count_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Relic grid
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	for relic in all_relics:
		var card = _create_relic_card(relic)
		grid.add_child(card)

func _create_relic_card(relic: Resource) -> PanelContainer:
	var is_unlocked = SaveManager.is_relic_unlocked(relic.id) or relic.unlock_cost == 0

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 0)

	var card_style = StyleBoxFlat.new()
	if is_unlocked:
		card_style.bg_color = Color(0.1, 0.08, 0.15)
		card_style.border_color = Color(0.5, 0.4, 0.7)
	else:
		card_style.bg_color = Color(0.06, 0.05, 0.08)
		card_style.border_color = Color(0.25, 0.22, 0.3)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = 12
	card_style.content_margin_right = 12
	card_style.content_margin_top = 10
	card_style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Name row
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vbox.add_child(name_row)

	var emoji_label = Label.new()
	emoji_label.text = relic.emoji if relic.emoji != "" else "?"
	emoji_label.add_theme_font_size_override("font_size", 24)
	name_row.add_child(emoji_label)

	var name_label = Label.new()
	name_label.text = relic.relic_name if relic.relic_name else relic.id
	var relic_color = relic.get_rarity_color() if relic.has_method("get_rarity_color") else Color.WHITE
	if not is_unlocked:
		relic_color = relic_color.darkened(0.5)
	name_label.add_theme_color_override("font_color", relic_color)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)

	# Effect description
	var effect = Label.new()
	effect.text = relic.effect_description if is_unlocked else "???"
	effect.add_theme_font_size_override("font_size", 12)
	effect.add_theme_color_override("font_color", TEXT_DIM if is_unlocked else Color(0.3, 0.3, 0.35))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(effect)

	# Status or unlock button
	if is_unlocked:
		var status = Label.new()
		status.text = "UNLOCKED"
		status.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		status.add_theme_font_size_override("font_size", 12)
		vbox.add_child(status)
	else:
		var btn = Button.new()
		btn.text = "Unlock: %d G" % relic.unlock_cost
		btn.disabled = SaveManager.get_gold() < relic.unlock_cost
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_unlock_relic.bind(relic))
		vbox.add_child(btn)

	return card

func _on_unlock_relic(relic: Resource):
	if SaveManager.spend_gold(relic.unlock_cost):
		SaveManager.unlock_relic(relic.id)
		_switch_tab("relics")

# ============================================
# BESTIARY TAB
# ============================================

func _build_bestiary_tab():
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 15)
	scroll.add_child(vbox)

	# Header
	var title = Label.new()
	title.text = "BESTIARY"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Creatures you have defeated"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var bestiary = SaveManager.get_bestiary()

	if bestiary.is_empty():
		var placeholder = Label.new()
		placeholder.text = "\n\nNo enemies defeated yet.\n\nEnter the arena to begin your hunt!"
		placeholder.add_theme_color_override("font_color", TEXT_DIM)
		placeholder.add_theme_font_size_override("font_size", 16)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(placeholder)
		return

	# Total kills
	var total = SaveManager.get_total_bestiary_kills()
	var total_panel = PanelContainer.new()
	var total_style = StyleBoxFlat.new()
	total_style.bg_color = Color(0.12, 0.08, 0.08)
	total_style.border_color = Color(0.6, 0.3, 0.3)
	total_style.set_border_width_all(1)
	total_style.set_corner_radius_all(8)
	total_style.content_margin_left = 20
	total_style.content_margin_right = 20
	total_style.content_margin_top = 10
	total_style.content_margin_bottom = 10
	total_panel.add_theme_stylebox_override("panel", total_style)
	vbox.add_child(total_panel)

	var total_label = Label.new()
	total_label.text = "Total Kills: %d" % total
	total_label.add_theme_font_size_override("font_size", 22)
	total_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_panel.add_child(total_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Sort by kills
	var sorted_enemies: Array = []
	for enemy_type in bestiary:
		sorted_enemies.append({"type": enemy_type, "kills": bestiary[enemy_type]})
	sorted_enemies.sort_custom(func(a, b): return a.kills > b.kills)

	# Enemy cards
	for entry in sorted_enemies:
		var card = _create_bestiary_card(entry.type, entry.kills)
		vbox.add_child(card)

func _create_bestiary_card(enemy_type: String, kills: int) -> PanelContainer:
	var info = ENEMY_INFO.get(enemy_type, ENEMY_INFO["unknown"])

	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(info.color.r * 0.1, info.color.g * 0.1, info.color.b * 0.1)
	card_style.border_color = Color(info.color.r * 0.5, info.color.g * 0.5, info.color.b * 0.5)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = 15
	card_style.content_margin_right = 15
	card_style.content_margin_top = 10
	card_style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	card.add_child(hbox)

	# Color indicator
	var indicator = ColorRect.new()
	indicator.custom_minimum_size = Vector2(8, 40)
	indicator.color = info.color
	hbox.add_child(indicator)

	# Info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = info.name
	name_label.add_theme_color_override("font_color", info.color)
	name_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = info.desc
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", TEXT_DIM)
	info_vbox.add_child(desc_label)

	# Kill count
	var count_container = VBoxContainer.new()
	count_container.add_theme_constant_override("separation", 2)
	hbox.add_child(count_container)

	var kills_label = Label.new()
	kills_label.text = str(kills)
	kills_label.add_theme_font_size_override("font_size", 28)
	kills_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_container.add_child(kills_label)

	var kills_text = Label.new()
	kills_text.text = "kills"
	kills_text.add_theme_font_size_override("font_size", 12)
	kills_text.add_theme_color_override("font_color", TEXT_DIM)
	kills_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_container.add_child(kills_text)

	return card

# ============================================
# STATS TAB
# ============================================

func _build_stats_tab():
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(vbox)

	# Header
	var title = Label.new()
	title.text = "STATISTICS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var stats = SaveManager.get_statistics()

	# Main stats grid
	var stats_grid = HBoxContainer.new()
	stats_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_grid.add_theme_constant_override("separation", 30)
	vbox.add_child(stats_grid)

	_create_stat_card(stats_grid, "Highest Wave", str(stats.highest_wave), Color(0.9, 0.75, 0.3))
	_create_stat_card(stats_grid, "Total Runs", str(stats.total_runs), Color(0.5, 0.6, 0.8))
	_create_stat_card(stats_grid, "Total Kills", str(stats.total_kills), Color(0.9, 0.4, 0.4))
	_create_stat_card(stats_grid, "Gold Earned", str(stats.total_gold_earned), Color(1, 0.85, 0.4))

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Training levels section
	var training_title = Label.new()
	training_title.text = "Training Progress"
	training_title.add_theme_font_size_override("font_size", 20)
	training_title.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	training_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(training_title)

	var training_grid = HBoxContainer.new()
	training_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	training_grid.add_theme_constant_override("separation", 20)
	vbox.add_child(training_grid)

	for stat_name in TRAINING_INFO:
		var info = TRAINING_INFO[stat_name]
		var level = SaveManager.get_training_level(stat_name)
		_create_training_stat_display(training_grid, info.display_name, level, info.color)

func _create_stat_card(parent: Control, label_text: String, value_text: String, color: Color):
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(color.r * 0.1, color.g * 0.1, color.b * 0.1)
	card_style.border_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(10)
	card_style.content_margin_left = 25
	card_style.content_margin_right = 25
	card_style.content_margin_top = 15
	card_style.content_margin_bottom = 15
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 36)
	value.add_theme_color_override("font_color", color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(value)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

func _create_training_stat_display(parent: Control, stat_name: String, level: int, color: Color):
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)

	var name_label = Label.new()
	name_label.text = stat_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_label)

	# Level dots
	var dots = HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 4)
	container.add_child(dots)

	for i in range(5):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		if i < level:
			dot.color = color
		else:
			dot.color = Color(0.2, 0.18, 0.22)
		dots.add_child(dot)

# ============================================
# EVENT HANDLERS
# ============================================

func _on_gold_changed(new_amount: int):
	# Update gold display in header
	if gold_display_label and is_instance_valid(gold_display_label):
		gold_display_label.text = "%d" % new_amount

		# Flash animation
		var tween = create_tween()
		tween.tween_property(gold_display_label, "modulate", Color(1.5, 1.2, 0.8), 0.1)
		tween.tween_property(gold_display_label, "modulate", Color.WHITE, 0.2)

	# Update training button states without full rebuild
	_update_training_buttons()

func _on_enter_arena_pressed():
	RunManager.start_new_run()
	_give_random_starting_relic()

	# Transition effect
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)

	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://Scenes/Game/Game.tscn"))

func _give_random_starting_relic():
	var unlocked_relics: Array = []
	for relic in all_relics:
		if SaveManager.is_relic_unlocked(relic.id) or relic.unlock_cost == 0:
			unlocked_relics.append(relic)

	if unlocked_relics.size() > 0:
		var random_relic = unlocked_relics[randi() % unlocked_relics.size()]
		RunManager.add_relic(random_relic)
