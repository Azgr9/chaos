# SCRIPT: WaveShop.gd
# Combined shop + healer shown between waves
# Uses Coliseum Tickets for items, Gold for healing
# LOCATION: res://Scripts/Ui/WaveShop.gd

class_name WaveShop
extends Control

# ============================================
# SIGNALS
# ============================================
signal shop_closed()
signal item_purchased(item_id: String, item_type: String)

# ============================================
# CONFIGURATION
# ============================================
const CHOICES_COUNT: int = 3
const REROLL_COST: int = 1
const FREE_HEAL_PERCENT: float = 0.30
const FULL_HEAL_TICKET_COST: int = 1  # Full heal costs 1 ticket

const RARITY_WEIGHTS = {
	"common": 50,
	"uncommon": 30,
	"rare": 15,
	"legendary": 5
}

# ============================================
# SHOP ITEMS DATABASE
# ============================================
const SHOP_WEAPONS = {
	"dagger": {
		"name": "Dagger",
		"type": "melee",
		"scene": "res://Scenes/Weapons/Dagger/Dagger.tscn",
		"rarity": "common",
		"description": "Fast close-range strikes",
		"emoji": "🗡️"
	},
	"katana": {
		"name": "Katana",
		"type": "melee",
		"scene": "res://Scenes/Weapons/Katana/Katana.tscn",
		"rarity": "common",
		"description": "Fast slashing blade",
		"emoji": "⚔️"
	},
	"rapier": {
		"name": "Rapier",
		"type": "melee",
		"scene": "res://Scenes/Weapons/Rapier/Rapier.tscn",
		"rarity": "uncommon",
		"description": "Quick thrust attacks",
		"emoji": "🤺"
	},
	"spear": {
		"name": "Spear",
		"type": "melee",
		"scene": "res://Scenes/Weapons/Spear/Spear.tscn",
		"rarity": "uncommon",
		"description": "Long reach piercing",
		"emoji": "🔱"
	},
	"axe": {
		"name": "Executioner's Axe",
		"type": "melee",
		"scene": "res://Scenes/Weapons/ExecutionersAxe/ExecutionersAxe.tscn",
		"rarity": "rare",
		"description": "Heavy cleaving damage",
		"emoji": "🪓"
	},
	"warhammer": {
		"name": "Warhammer",
		"type": "melee",
		"scene": "res://Scenes/Weapons/Warhammer/Warhammer.tscn",
		"rarity": "rare",
		"description": "Devastating slam attacks",
		"emoji": "🔨"
	},
	"scythe": {
		"name": "Scythe",
		"type": "melee",
		"scene": "res://Scenes/Weapons/Scythe/Scythe.tscn",
		"rarity": "legendary",
		"description": "Wide sweeping death arcs",
		"emoji": "⚰️"
	},
	"lightning_staff": {
		"name": "Lightning Staff",
		"type": "staff",
		"scene": "res://Scenes/Weapons/LightningStaff/LightningStaff.tscn",
		"rarity": "common",
		"description": "Chain lightning magic",
		"emoji": "⚡"
	},
	"frost_staff": {
		"name": "Frost Staff",
		"type": "staff",
		"scene": "res://Scenes/Weapons/FrostStaff/FrostStaff.tscn",
		"rarity": "common",
		"description": "Freezing ice magic",
		"emoji": "❄️"
	},
	"inferno_staff": {
		"name": "Inferno Staff",
		"type": "staff",
		"scene": "res://Scenes/Weapons/InfernoStaff/InfernoStaff.tscn",
		"rarity": "uncommon",
		"description": "Burning fire magic",
		"emoji": "🔥"
	},
	"earth_staff": {
		"name": "Earth Staff",
		"type": "staff",
		"scene": "res://Scenes/Weapons/EarthStaff/EarthStaff.tscn",
		"rarity": "uncommon",
		"description": "Rock and earth magic",
		"emoji": "🪨"
	},
	"holy_staff": {
		"name": "Holy Staff",
		"type": "staff",
		"scene": "res://Scenes/Weapons/HolyStaff/HolyStaff.tscn",
		"rarity": "rare",
		"description": "Divine healing light",
		"emoji": "✨"
	},
	"void_staff": {
		"name": "Void Staff",
		"type": "staff",
		"scene": "res://Scenes/Weapons/VoidStaff/VoidStaff.tscn",
		"rarity": "rare",
		"description": "Dark void energy",
		"emoji": "🌀"
	},
	"necro_staff": {
		"name": "Necro Staff",
		"type": "staff",
		"scene": "res://Scenes/Weapons/NecroStaff/NecroStaff.tscn",
		"rarity": "legendary",
		"description": "Summon undead minions",
		"emoji": "💀"
	}
}

const RELICS_PATH = "res://Resources/Relics/"

const SHOP_RELICS = {
	"iron_ring": {"rarity": "common"},
	"chipped_fang": {"rarity": "common"},
	"trolls_heart": {"rarity": "common"},
	"thiefs_anklet": {"rarity": "common"},
	"iron_skin": {"rarity": "common"},
	"cracked_knuckle": {"rarity": "common"},
	"vampiric_fang": {"rarity": "uncommon"},
	"swift_boots": {"rarity": "uncommon"},
	"clockwork_gear": {"rarity": "uncommon"},
	"burning_heart": {"rarity": "uncommon"},
	"frozen_heart": {"rarity": "uncommon"},
	"crystal_shard": {"rarity": "uncommon"},
	"storm_conduit": {"rarity": "uncommon"},
	"fencing_medal": {"rarity": "uncommon"},
	"merchants_coin": {"rarity": "uncommon"},
	"arcane_focus": {"rarity": "uncommon"},
	"phoenix_feather": {"rarity": "rare"},
	"golden_idol": {"rarity": "rare"},
	"blood_rage": {"rarity": "rare"},
	"vampiric_essence": {"rarity": "rare"},
	"void_shard": {"rarity": "rare"},
	"soul_vessel": {"rarity": "rare"},
	"titans_grip": {"rarity": "rare"},
	"bloodthirst": {"rarity": "rare"},
	"death_mark": {"rarity": "rare"},
	"parry_charm": {"rarity": "rare"},
	"cyclone_pendant": {"rarity": "rare"},
	"phantom_cloak": {"rarity": "rare"},
	"ember_crown": {"rarity": "legendary"},
	"vortex_core": {"rarity": "legendary"},
	"shield_emblem": {"rarity": "legendary"},
	"guardian_angel": {"rarity": "legendary"},
	"ticket_collector": {"rarity": "legendary"},
	"merchants_blessing": {"rarity": "legendary"},
	"lucky_charm": {"rarity": "legendary"}
}

const SHOP_CONSUMABLES = {
	"heal_50": {
		"name": "Health Potion",
		"type": "consumable",
		"rarity": "common",
		"description": "Heal 50% of max HP",
		"emoji": "🧪"
	},
	"heal_full": {
		"name": "Full Restore",
		"type": "consumable",
		"rarity": "uncommon",
		"description": "Fully restore HP",
		"emoji": "💊"
	}
}

const RARITY_COLORS = {
	"common": Color(0.7, 0.7, 0.7),
	"uncommon": Color(0.3, 0.8, 0.3),
	"rare": Color(0.3, 0.5, 1.0),
	"legendary": Color(1.0, 0.6, 0.1)
}

# ============================================
# STATE
# ============================================
var current_choices: Array = []
var purchased_this_wave: Array = []
var purchased_weapons: Array = []
var purchased_relics: Array = []
var player_reference: Node2D = null
var current_tickets: int = 0
var reroll_count: int = 0
var free_reroll: bool = false
var free_heal_used: bool = false
var loaded_relics: Dictionary = {}

# ============================================
# UI REFERENCES
# ============================================
@onready var background: ColorRect = $Background
@onready var title_label: Label = $CenterContainer/MainContainer/TitleLabel
@onready var tickets_label: Label = $CenterContainer/MainContainer/TicketsLabel
@onready var choice_container: HBoxContainer = $CenterContainer/MainContainer/ChoiceContainer
@onready var reroll_button: Button = $CenterContainer/MainContainer/BottomContainer/RerollButton
@onready var continue_button: Button = $CenterContainer/MainContainer/BottomContainer/ContinueButton

# Healer UI
@onready var healer_section: PanelContainer = $CenterContainer/MainContainer/HealerSection
@onready var health_label: Label = $CenterContainer/MainContainer/HealerSection/HealerHBox/HealthDisplay/HealthLabel
@onready var free_heal_button: Button = $CenterContainer/MainContainer/HealerSection/HealerHBox/FreeHealButton
@onready var full_heal_button: Button = $CenterContainer/MainContainer/HealerSection/HealerHBox/FullHealButton

var choice_panels: Array = []
var _weapon_scenes: Dictionary = {}

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	_load_relics()
	_setup_ui()

func _load_relics():
	var dir = DirAccess.open(RELICS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var relic_path = RELICS_PATH + file_name
				var relic = load(relic_path) as RelicResource
				if relic:
					loaded_relics[relic.id] = relic
			file_name = dir.get_next()
		dir.list_dir_end()
	print("[WaveShop] Loaded %d relics" % loaded_relics.size())

func _setup_ui():
	# Setup choice panels
	choice_panels.clear()
	for i in range(CHOICES_COUNT):
		var panel = choice_container.get_node_or_null("Choice%d" % i)
		if panel:
			choice_panels.append(panel)
			_style_panel(panel)
			var buy_btn = panel.get_node_or_null("VBox/BuyButton")
			if buy_btn:
				buy_btn.pressed.connect(_on_buy_pressed.bind(i))
				_style_button(buy_btn, Color(0.3, 0.2, 0.5))

	# Setup bottom buttons
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_pressed)
		_style_button(reroll_button, Color(0.5, 0.3, 0.6))

	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		_style_button(continue_button, Color(0.3, 0.5, 0.3))

	# Setup healer section
	_style_healer_section()
	if free_heal_button:
		free_heal_button.pressed.connect(_on_free_heal_pressed)
		_style_button(free_heal_button, Color(0.2, 0.6, 0.2))
	if full_heal_button:
		full_heal_button.pressed.connect(_on_full_heal_pressed)
		_style_button(full_heal_button, Color(0.6, 0.5, 0.2))

func _style_panel(panel: PanelContainer):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

func _style_healer_section():
	if not healer_section:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.1, 0.9)
	style.border_color = Color(0.3, 0.6, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	healer_section.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, base_color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = base_color
	style.border_color = base_color * 1.3
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = base_color * 1.2
	button.add_theme_stylebox_override("hover", hover)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = base_color * 0.8
	button.add_theme_stylebox_override("pressed", pressed_style)

	var disabled = style.duplicate()
	disabled.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	disabled.border_color = Color(0.3, 0.3, 0.3)
	button.add_theme_stylebox_override("disabled", disabled)

# ============================================
# PUBLIC API
# ============================================
func open_shop(player: Node2D, _gold: int = 0):
	player_reference = player
	purchased_this_wave.clear()
	reroll_count = 0

	if RunManager:
		current_tickets = RunManager.get_tickets()
		RunManager.on_shop_entered()
		current_tickets = RunManager.get_tickets()

	free_reroll = RunManager.has_special_effect("free_reroll") if RunManager else false

	_generate_choices()
	_update_ui()

	visible = true
	get_tree().paused = true

	if continue_button:
		continue_button.grab_focus()

func close_shop():
	visible = false
	get_tree().paused = false
	shop_closed.emit()

func reset_healer_for_new_wave():
	free_heal_used = false

func reset_for_new_run():
	purchased_weapons.clear()
	purchased_relics.clear()
	purchased_this_wave.clear()
	current_choices.clear()
	reroll_count = 0
	current_tickets = 0
	free_reroll = false
	free_heal_used = false

# ============================================
# RANDOM SELECTION
# ============================================
func _generate_choices():
	current_choices.clear()
	var all_items: Array = []

	for weapon_id in SHOP_WEAPONS:
		if weapon_id not in purchased_weapons:
			var item = SHOP_WEAPONS[weapon_id].duplicate()
			item["id"] = weapon_id
			all_items.append(item)

	for relic_id in SHOP_RELICS:
		if relic_id not in purchased_relics and loaded_relics.has(relic_id):
			var relic = loaded_relics[relic_id]
			var shop_data = SHOP_RELICS[relic_id]
			var item = {
				"id": relic_id,
				"name": relic.relic_name,
				"type": "relic",
				"rarity": shop_data.rarity,
				"description": relic.effect_description,
				"emoji": relic.emoji,
				"relic_resource": relic
			}
			all_items.append(item)

	for consumable_id in SHOP_CONSUMABLES:
		var item = SHOP_CONSUMABLES[consumable_id].duplicate()
		item["id"] = consumable_id
		all_items.append(item)

	for i in range(CHOICES_COUNT):
		if all_items.is_empty():
			break
		var chosen = _weighted_random_select(all_items)
		current_choices.append(chosen)
		if chosen["type"] in ["melee", "staff", "relic"]:
			all_items.erase(chosen)

func _weighted_random_select(items: Array) -> Dictionary:
	var total_weight = 0.0
	for item in items:
		var rarity = item.get("rarity", "common")
		total_weight += RARITY_WEIGHTS.get(rarity, 50)

	var roll = randf() * total_weight
	var cumulative = 0.0

	for item in items:
		var rarity = item.get("rarity", "common")
		cumulative += RARITY_WEIGHTS.get(rarity, 50)
		if roll <= cumulative:
			return item

	return items[0] if items.size() > 0 else {}

# ============================================
# UI UPDATES
# ============================================
func _update_ui():
	_update_tickets_display()
	_update_choices_display()
	_update_button_states()
	_update_healer_display()

func _update_tickets_display():
	if tickets_label:
		tickets_label.text = "Coliseum Tickets: %d" % current_tickets

func _update_choices_display():
	for i in range(CHOICES_COUNT):
		if i >= choice_panels.size():
			continue
		var panel = choice_panels[i]

		if i < current_choices.size():
			var item = current_choices[i]
			_update_choice_panel(panel, item)
			panel.visible = true
		else:
			panel.visible = false

func _update_choice_panel(panel: PanelContainer, item: Dictionary):
	var vbox = panel.get_node_or_null("VBox")
	if not vbox:
		return

	var rarity = item.get("rarity", "common")
	var rarity_color = RARITY_COLORS.get(rarity, Color.WHITE)

	var rarity_bar = vbox.get_node_or_null("RarityBar")
	if rarity_bar:
		rarity_bar.color = rarity_color

	var icon_label = vbox.get_node_or_null("IconLabel")
	if icon_label:
		icon_label.text = item.get("emoji", "?")

	var name_label = vbox.get_node_or_null("NameLabel")
	if name_label:
		name_label.text = item.get("name", "Unknown")
		name_label.add_theme_color_override("font_color", rarity_color)

	var type_label = vbox.get_node_or_null("TypeLabel")
	if type_label:
		type_label.text = item.get("type", "unknown").to_upper()

	var desc_label = vbox.get_node_or_null("DescLabel")
	if desc_label:
		desc_label.text = item.get("description", "")

	var buy_btn = vbox.get_node_or_null("BuyButton")
	if buy_btn:
		var cost = _get_item_cost(item)
		buy_btn.text = "BUY - %d Ticket%s" % [cost, "s" if cost > 1 else ""]

	var style = panel.get_theme_stylebox("panel").duplicate()
	style.border_color = rarity_color * 0.8
	panel.add_theme_stylebox_override("panel", style)

func _get_item_cost(item: Dictionary) -> int:
	var rarity = item.get("rarity", "common")
	if RunManager:
		return RunManager.get_ticket_cost(rarity)
	match rarity:
		"common": return 1
		"uncommon": return 2
		"rare": return 3
		"legendary": return 4
	return 2

func _update_button_states():
	for i in range(current_choices.size()):
		if i >= choice_panels.size():
			break
		var panel = choice_panels[i]
		var item = current_choices[i]
		var vbox = panel.get_node_or_null("VBox")
		if not vbox:
			continue
		var buy_btn = vbox.get_node_or_null("BuyButton")
		if not buy_btn:
			continue
		var cost = _get_item_cost(item)
		var item_id = item.get("id", "")

		if item_id in purchased_this_wave:
			buy_btn.disabled = true
			buy_btn.text = "SOLD"
		elif current_tickets < cost:
			buy_btn.disabled = true
			buy_btn.text = "NEED %d" % cost
		else:
			buy_btn.disabled = false
			buy_btn.text = "BUY - %d Ticket%s" % [cost, "s" if cost > 1 else ""]

	if reroll_button:
		var reroll_cost = _get_reroll_cost()
		if free_reroll:
			reroll_button.text = "REROLL (FREE)"
			reroll_button.disabled = false
		else:
			reroll_button.text = "REROLL (%d Ticket%s)" % [reroll_cost, "s" if reroll_cost > 1 else ""]
			reroll_button.disabled = current_tickets < reroll_cost

func _get_reroll_cost() -> int:
	if free_reroll:
		return 0
	return REROLL_COST + reroll_count

# ============================================
# HEALER FUNCTIONS
# ============================================
func _update_healer_display():
	if not player_reference:
		return

	var current_hp = player_reference.stats.current_health if player_reference.stats else 0.0
	var max_hp = player_reference.stats.max_health if player_reference.stats else 100.0

	if health_label:
		health_label.text = "HP: %d / %d" % [int(current_hp), int(max_hp)]
		var health_percent = current_hp / max_hp if max_hp > 0 else 0.0
		if health_percent > 0.6:
			health_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		elif health_percent > 0.3:
			health_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
		else:
			health_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	_update_heal_buttons(current_hp, max_hp)

func _update_heal_buttons(current_hp: float, max_hp: float):
	# Free heal button
	if free_heal_button:
		if free_heal_used:
			free_heal_button.disabled = true
			free_heal_button.text = "Free Heal (Used)"
		elif current_hp >= max_hp:
			free_heal_button.disabled = true
			free_heal_button.text = "Free Heal (Full HP)"
		else:
			free_heal_button.disabled = false
			free_heal_button.text = "Free Heal (30%)"

	# Full heal button - costs tickets
	if full_heal_button:
		if current_hp >= max_hp:
			full_heal_button.disabled = true
			full_heal_button.text = "Full Heal (Full HP)"
		elif current_tickets < FULL_HEAL_TICKET_COST:
			full_heal_button.disabled = true
			full_heal_button.text = "Need %d Tickets" % FULL_HEAL_TICKET_COST
		else:
			full_heal_button.disabled = false
			full_heal_button.text = "Full Heal (%d Tickets)" % FULL_HEAL_TICKET_COST

func _on_free_heal_pressed():
	if not player_reference or free_heal_used:
		return

	var max_hp = player_reference.stats.max_health if player_reference.stats else 100.0
	var current_hp = player_reference.stats.current_health if player_reference.stats else 0.0

	if current_hp >= max_hp:
		return

	var heal_amount = max_hp * FREE_HEAL_PERCENT
	_apply_heal(heal_amount)
	free_heal_used = true
	_show_heal_effect(heal_amount)
	_update_healer_display()

func _on_full_heal_pressed():
	if not player_reference:
		return

	if current_tickets < FULL_HEAL_TICKET_COST:
		return

	var max_hp = player_reference.stats.max_health if player_reference.stats else 100.0
	var current_hp = player_reference.stats.current_health if player_reference.stats else 0.0

	if current_hp >= max_hp:
		return

	# Spend tickets for full heal
	if RunManager:
		RunManager.spend_tickets(FULL_HEAL_TICKET_COST)
		current_tickets = RunManager.get_tickets()

	var heal_amount = max_hp - current_hp
	_apply_heal(heal_amount)
	_show_heal_effect(heal_amount)
	_update_ui()  # Update everything including ticket display

func _apply_heal(amount: float):
	if player_reference and player_reference.has_method("heal"):
		player_reference.heal(amount)

func _show_heal_effect(heal_amount: float):
	var heal_label = Label.new()
	heal_label.text = "+%d HP" % int(heal_amount)
	heal_label.add_theme_font_size_override("font_size", 28)
	heal_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	add_child(heal_label)
	heal_label.position = Vector2(size.x / 2 - 50, size.y / 2)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(heal_label, "position:y", heal_label.position.y - 80, 1.0)
	tween.tween_property(heal_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(heal_label.queue_free)

# ============================================
# INPUT HANDLERS
# ============================================
func _on_buy_pressed(index: int):
	if index >= current_choices.size():
		return

	var item = current_choices[index]
	var cost = _get_item_cost(item)
	var item_id = item.get("id", "")

	if current_tickets < cost:
		return
	if item_id in purchased_this_wave:
		return

	if RunManager:
		RunManager.spend_tickets(cost)
		current_tickets = RunManager.get_tickets()

	_apply_item(item)

	purchased_this_wave.append(item_id)
	if item["type"] in ["melee", "staff"]:
		purchased_weapons.append(item_id)
		if RunManager:
			RunManager.add_weapon_collected()
	elif item["type"] == "relic":
		purchased_relics.append(item_id)
		if SaveManager and item.has("relic_resource"):
			SaveManager.discover_relic(item["relic_resource"].id)

	item_purchased.emit(item_id, item["type"])
	_update_ui()

func _on_reroll_pressed():
	var cost = _get_reroll_cost()

	if not free_reroll and current_tickets < cost:
		return

	if not free_reroll:
		if RunManager:
			RunManager.spend_tickets(cost)
			current_tickets = RunManager.get_tickets()

	reroll_count += 1
	_generate_choices()
	_update_ui()

func _on_continue_pressed():
	close_shop()

# ============================================
# ITEM APPLICATION
# ============================================
func _apply_item(item: Dictionary):
	if not player_reference:
		return

	var item_type = item.get("type", "")

	match item_type:
		"melee":
			_add_melee_weapon(item)
		"staff":
			_add_staff_weapon(item)
		"relic":
			_add_relic(item)
		"consumable":
			_apply_consumable(item)

func _add_melee_weapon(item: Dictionary):
	var scene_path = item.get("scene", "")
	var item_id = item.get("id", "")

	if not _weapon_scenes.has(item_id):
		_weapon_scenes[item_id] = load(scene_path)

	var weapon_scene = _weapon_scenes[item_id]
	if not weapon_scene:
		return

	var weapon_holder = player_reference.get_node_or_null("WeaponPivot/WeaponHolder")
	if not weapon_holder:
		return

	var new_weapon = weapon_scene.instantiate()
	weapon_holder.add_child(new_weapon)
	new_weapon.position = Vector2.ZERO

	player_reference.weapon_inventory.append(new_weapon)

	if new_weapon.has_signal("attack_finished"):
		new_weapon.attack_finished.connect(player_reference._on_attack_finished)

	new_weapon.visible = false
	player_reference.switch_to_weapon(player_reference.weapon_inventory.size() - 1)

func _add_staff_weapon(item: Dictionary):
	var scene_path = item.get("scene", "")
	var item_id = item.get("id", "")

	if not _weapon_scenes.has(item_id):
		_weapon_scenes[item_id] = load(scene_path)

	var weapon_scene = _weapon_scenes[item_id]
	if not weapon_scene:
		return

	var staff_holder = player_reference.get_node_or_null("StaffPivot/StaffHolder")
	if not staff_holder:
		return

	var new_staff = weapon_scene.instantiate()
	staff_holder.add_child(new_staff)
	new_staff.position = Vector2.ZERO

	player_reference.staff_inventory.append(new_staff)
	new_staff.visible = false
	player_reference.switch_to_staff(player_reference.staff_inventory.size() - 1)

func _add_relic(item: Dictionary):
	var relic_resource = item.get("relic_resource")
	if not relic_resource:
		return

	if RunManager:
		RunManager.add_relic(relic_resource)
		print("[WaveShop] Added relic: %s" % relic_resource.relic_name)

func _apply_consumable(item: Dictionary):
	var item_id = item.get("id", "")

	match item_id:
		"heal_50":
			if player_reference and player_reference.stats:
				var heal_amount = player_reference.stats.max_health * 0.50
				player_reference.heal(heal_amount)
		"heal_full":
			if player_reference and player_reference.stats:
				player_reference.heal(player_reference.stats.max_health)

func _input(event):
	if not visible:
		return

	if event.is_action_pressed("interact"):
		close_shop()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()
