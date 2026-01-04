# SCRIPT: UpgradeMenu.gd
# ATTACH TO: UpgradeMenu (CanvasLayer) root in UpgradeMenu.tscn
# LOCATION: res://scripts/ui/UpgradeMenu.gd

class_name UpgradeMenu
extends CanvasLayer

# Nodes
@onready var control: Control = $Control
@onready var background: ColorRect = $Control/Background
@onready var container: VBoxContainer = $Control/Container
@onready var title_label: Label = $Control/Container/Title
@onready var subtitle_label: Label = $Control/Container/Subtitle
@onready var upgrade_cards: HBoxContainer = $Control/Container/UpgradeCards
@onready var weapon_shop_button: Button = $Control/WeaponShopButton
@onready var axe_shop_button: Button = $Control/AxeShopButton
@onready var rapier_shop_button: Button = $Control/RapierShopButton
@onready var warhammer_shop_button: Button = $Control/WarhammerShopButton
@onready var staff_shop_button: Button = $Control/StaffShopButton
@onready var inferno_staff_button: Button = $Control/InfernoStaffButton
@onready var frost_staff_button: Button = $Control/FrostStaffButton
@onready var void_staff_button: Button = $Control/VoidStaffButton
@onready var necro_staff_button: Button = $Control/NecroStaffButton
@onready var scythe_shop_button: Button = $Control/ScytheShopButton
@onready var spear_shop_button: Button = $Control/SpearShopButton
@onready var skip_button: Button = $Control/SkipButton
@onready var healer_container: VBoxContainer = $Control/HealerContainer

# HEALER PRICES
const FREE_HEAL_PERCENT := 0.30  # 30% free heal
const FULL_HEAL_PRICE := 50

# Healer state
var free_heal_used: bool = false

# MELEE WEAPONS
const KATANA_SCENE = preload("res://Scenes/Weapons/Katana/Katana.tscn")
const KATANA_PRICE = 10
const EXECUTIONERS_AXE_SCENE = preload("res://Scenes/Weapons/ExecutionersAxe/ExecutionersAxe.tscn")
const AXE_PRICE = 15
const RAPIER_SCENE = preload("res://Scenes/Weapons/Rapier/Rapier.tscn")
const RAPIER_PRICE = 12
const WARHAMMER_SCENE = preload("res://Scenes/Weapons/Warhammer/Warhammer.tscn")
const WARHAMMER_PRICE = 18
const SCYTHE_SCENE = preload("res://Scenes/Weapons/Scythe/Scythe.tscn")
const SCYTHE_PRICE = 20
const SPEAR_SCENE = preload("res://Scenes/Weapons/Spear/Spear.tscn")
const SPEAR_PRICE = 16

# STAFFS
const LIGHTNING_STAFF_SCENE = preload("res://Scenes/Weapons/LightningStaff/LightningStaff.tscn")
const STAFF_PRICE = 10
const INFERNO_STAFF_SCENE = preload("res://Scenes/Weapons/InfernoStaff/InfernoStaff.tscn")
const INFERNO_STAFF_PRICE = 12
const FROST_STAFF_SCENE = preload("res://Scenes/Weapons/FrostStaff/FrostStaff.tscn")
const FROST_STAFF_PRICE = 11
const VOID_STAFF_SCENE = preload("res://Scenes/Weapons/VoidStaff/VoidStaff.tscn")
const VOID_STAFF_PRICE = 16
const NECRO_STAFF_SCENE = preload("res://Scenes/Weapons/NecroStaff/NecroStaff.tscn")
const NECRO_STAFF_PRICE = 22

# Card references
var card_panels: Array = []
var card_data: Array = []
var player_reference: Node2D = null
var upgrade_system: UpgradeSystem = null
var katana_purchased: bool = false
var axe_purchased: bool = false
var rapier_purchased: bool = false
var warhammer_purchased: bool = false
var staff_purchased: bool = false
var inferno_staff_purchased: bool = false
var frost_staff_purchased: bool = false
var void_staff_purchased: bool = false
var necro_staff_purchased: bool = false
var scythe_purchased: bool = false
var spear_purchased: bool = false

# Signals
signal upgrade_selected(upgrade: Dictionary)
signal menu_closed()

func _ready():
	# Hide initially
	visible = false

	# Set to process when paused so menu works during pause
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create upgrade system instance
	upgrade_system = UpgradeSystem.new()
	add_child(upgrade_system)

	# Get card panels
	for child in upgrade_cards.get_children():
		if child is Panel:
			card_panels.append(child)

			# Connect button
			var button = child.get_node("VBox/SelectButton")
			if button:
				button.pressed.connect(_on_card_selected.bind(card_panels.size() - 1))

	# Connect skip button if it exists
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

	# Connect weapon shop buttons
	if weapon_shop_button:
		weapon_shop_button.pressed.connect(_on_weapon_shop_pressed)
	if axe_shop_button:
		axe_shop_button.pressed.connect(_on_axe_shop_pressed)
	if rapier_shop_button:
		rapier_shop_button.pressed.connect(_on_rapier_shop_pressed)
	if warhammer_shop_button:
		warhammer_shop_button.pressed.connect(_on_warhammer_shop_pressed)

	# Connect staff shop buttons
	if staff_shop_button:
		staff_shop_button.pressed.connect(_on_staff_shop_pressed)
	if inferno_staff_button:
		inferno_staff_button.pressed.connect(_on_inferno_staff_pressed)
	if frost_staff_button:
		frost_staff_button.pressed.connect(_on_frost_staff_pressed)
	if void_staff_button:
		void_staff_button.pressed.connect(_on_void_staff_pressed)
	if necro_staff_button:
		necro_staff_button.pressed.connect(_on_necro_staff_pressed)

	# Connect new melee weapon shop buttons
	if scythe_shop_button:
		scythe_shop_button.pressed.connect(_on_scythe_shop_pressed)
	if spear_shop_button:
		spear_shop_button.pressed.connect(_on_spear_shop_pressed)

	# Setup healer section
	_setup_healer_section()

func show_upgrades(player: Node2D):
	player_reference = player

	# CRITICAL: Clean up all active animations and effects BEFORE pausing
	_cleanup_active_effects()

	# Update weapon shop buttons
	_update_weapon_shop_button()
	_update_axe_shop_button()
	_update_rapier_shop_button()
	_update_warhammer_shop_button()
	_update_scythe_shop_button()
	_update_spear_shop_button()
	_update_staff_shop_button()
	_update_inferno_staff_button()
	_update_frost_staff_button()
	_update_void_staff_button()
	_update_necro_staff_button()

	# Update healer section
	_update_healer_section()

	# Get random upgrades
	card_data = upgrade_system.get_random_upgrades(3)

	# Pause game
	get_tree().paused = true

	# Show menu with animation
	visible = true
	control.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.3)

	# Animate container
	container.position.y = -50
	tween.parallel().tween_property(container, "position:y", 0, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Setup cards
	_setup_cards()

	# Animate cards appearing
	_animate_cards_in()

func _setup_cards():
	for i in range(min(card_data.size(), card_panels.size())):
		var card = card_panels[i]
		var upgrade = card_data[i]

		# Get display data (handles both UpgradeResource and Dictionary)
		var data = upgrade_system.get_upgrade_display_data(upgrade)

		# Set card info
		var icon = card.get_node("VBox/Icon")
		var name_label = card.get_node("VBox/Name")
		var desc_label = card.get_node("VBox/Description")

		if icon:
			icon.color = data.get("icon_color", Color.WHITE)
		if name_label:
			name_label.text = data.get("name", "Unknown")
		if desc_label:
			desc_label.text = data.get("description", "")

		# Style the panel
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = data.get("icon_color", Color.WHITE) * 0.8
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		card.add_theme_stylebox_override("panel", style)

func _animate_cards_in():
	var delay = 0.0
	for card in card_panels:
		card.scale = Vector2(0.8, 0.8)
		card.modulate.a = 0.0

		var tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_property(card, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(card, "modulate:a", 1.0, 0.3)

		delay += 0.1

func _on_card_selected(index: int):
	if index >= card_data.size():
		return

	var selected_upgrade = card_data[index]

	# Apply the upgrade
	if upgrade_system and player_reference:
		upgrade_system.apply_upgrade(player_reference, selected_upgrade)

	# Emit signal
	upgrade_selected.emit(selected_upgrade)

	# Animate selection
	var selected_card = card_panels[index]
	selected_card.scale = Vector2(1.1, 1.1)

	var tween = create_tween()
	tween.tween_property(selected_card, "scale", Vector2(1.2, 1.2), 0.2)
	tween.parallel().tween_property(selected_card, "modulate:a", 0.0, 0.3)

	# Fade out other cards
	for i in range(card_panels.size()):
		if i != index:
			var other_tween = create_tween()
			other_tween.tween_property(card_panels[i], "modulate:a", 0.0, 0.2)

	# Close menu after animation
	tween.tween_callback(_close_menu)

func _on_skip_pressed():
	_close_menu()

func _on_weapon_shop_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	# Check if player has enough gold
	if game_manager.get_gold() >= KATANA_PRICE:
		if game_manager.spend_gold(KATANA_PRICE):
			_swap_weapon_to_katana()
			_update_weapon_shop_button()
			_update_axe_shop_button()

func _on_axe_shop_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	# Check if player has enough gold
	if game_manager.get_gold() >= AXE_PRICE:
		if game_manager.spend_gold(AXE_PRICE):
			_swap_weapon_to_axe()
			_update_axe_shop_button()
			_update_weapon_shop_button()

func _update_weapon_shop_button():
	if not weapon_shop_button:
		return

	# Hide button if already purchased
	if katana_purchased:
		weapon_shop_button.visible = false
		return

	weapon_shop_button.visible = true
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= KATANA_PRICE:
		weapon_shop_button.disabled = false
		weapon_shop_button.text = "Katana (%d Gold)" % KATANA_PRICE
	else:
		weapon_shop_button.disabled = true
		weapon_shop_button.text = "Katana - Need %d" % KATANA_PRICE

func _update_axe_shop_button():
	if not axe_shop_button:
		return

	# Hide button if already purchased
	if axe_purchased:
		axe_shop_button.visible = false
		return

	axe_shop_button.visible = true
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= AXE_PRICE:
		axe_shop_button.disabled = false
		axe_shop_button.text = "Executioner's Axe (%d Gold)" % AXE_PRICE
	else:
		axe_shop_button.disabled = true
		axe_shop_button.text = "Axe - Need %d" % AXE_PRICE

func _swap_weapon_to_katana():
	if not player_reference:
		return

	# Verify player has weapon holder node - prevents crash if node is missing
	var weapon_holder = player_reference.get_node_or_null("WeaponPivot/WeaponHolder")
	if not weapon_holder:
		push_warning("UpgradeMenu: WeaponHolder not found on player")
		return

	# Mark as purchased
	katana_purchased = true

	# Add new katana to inventory (don't remove old weapons!)
	var new_weapon = KATANA_SCENE.instantiate()
	weapon_holder.add_child(new_weapon)
	new_weapon.position = Vector2.ZERO

	# Add to inventory
	player_reference.weapon_inventory.append(new_weapon)

	# Connect signals
	if new_weapon.has_signal("attack_finished"):
		new_weapon.attack_finished.connect(player_reference._on_attack_finished)

	# Hide the new weapon initially (current weapon stays active)
	new_weapon.visible = false

	# Switch to the new weapon
	player_reference.switch_to_weapon(player_reference.weapon_inventory.size() - 1)

func _swap_weapon_to_axe():
	if not player_reference:
		return

	# Verify player has weapon holder node - prevents crash if node is missing
	var weapon_holder = player_reference.get_node_or_null("WeaponPivot/WeaponHolder")
	if not weapon_holder:
		push_warning("UpgradeMenu: WeaponHolder not found on player")
		return

	# Mark as purchased
	axe_purchased = true

	# Add new Executioner's Axe to inventory (don't remove old weapons!)
	var new_weapon = EXECUTIONERS_AXE_SCENE.instantiate()
	weapon_holder.add_child(new_weapon)
	new_weapon.position = Vector2.ZERO

	# Add to inventory
	player_reference.weapon_inventory.append(new_weapon)

	# Connect signals
	if new_weapon.has_signal("attack_finished"):
		new_weapon.attack_finished.connect(player_reference._on_attack_finished)

	# Hide the new weapon initially (current weapon stays active)
	new_weapon.visible = false

	# Switch to the new weapon
	player_reference.switch_to_weapon(player_reference.weapon_inventory.size() - 1)

func _on_staff_shop_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	# Check if player has enough gold
	if game_manager.get_gold() >= STAFF_PRICE:
		if game_manager.spend_gold(STAFF_PRICE):
			_swap_weapon_to_staff()
			_update_staff_shop_button()

func _update_staff_shop_button():
	if not staff_shop_button:
		return

	# Hide if already purchased
	if staff_purchased:
		staff_shop_button.visible = false
		return

	staff_shop_button.visible = true

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= STAFF_PRICE:
		staff_shop_button.disabled = false
		staff_shop_button.text = "Lightning Staff (%d Gold)" % STAFF_PRICE
	else:
		staff_shop_button.disabled = true
		staff_shop_button.text = "Lightning Staff - Need %d" % STAFF_PRICE

func _on_inferno_staff_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	# Check if player has enough gold
	if game_manager.get_gold() >= INFERNO_STAFF_PRICE:
		if game_manager.spend_gold(INFERNO_STAFF_PRICE):
			_swap_weapon_to_inferno_staff()
			_update_inferno_staff_button()
			_update_staff_shop_button()

func _update_inferno_staff_button():
	if not inferno_staff_button:
		return

	# Hide if already purchased
	if inferno_staff_purchased:
		inferno_staff_button.visible = false
		return

	inferno_staff_button.visible = true

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= INFERNO_STAFF_PRICE:
		inferno_staff_button.disabled = false
		inferno_staff_button.text = "Inferno Staff (%d Gold)" % INFERNO_STAFF_PRICE
	else:
		inferno_staff_button.disabled = true
		inferno_staff_button.text = "Inferno Staff - Need %d" % INFERNO_STAFF_PRICE

func _swap_weapon_to_inferno_staff():
	if not player_reference:
		return

	# Verify player has staff holder node - prevents crash if node is missing
	var staff_holder = player_reference.get_node_or_null("StaffPivot/StaffHolder")
	if not staff_holder:
		push_warning("UpgradeMenu: StaffHolder not found on player")
		return

	# Mark as purchased
	inferno_staff_purchased = true

	# Add new inferno staff to inventory (don't remove old staffs!)
	var new_staff = INFERNO_STAFF_SCENE.instantiate()
	staff_holder.add_child(new_staff)
	new_staff.position = Vector2.ZERO

	# Add to inventory
	player_reference.staff_inventory.append(new_staff)

	# Hide the new staff initially (current staff stays active)
	new_staff.visible = false

	# Switch to the new staff
	player_reference.switch_to_staff(player_reference.staff_inventory.size() - 1)

func _swap_weapon_to_staff():
	if not player_reference:
		return

	# Verify player has staff holder node - prevents crash if node is missing
	var staff_holder = player_reference.get_node_or_null("StaffPivot/StaffHolder")
	if not staff_holder:
		push_warning("UpgradeMenu: StaffHolder not found on player")
		return

	# Mark as purchased
	staff_purchased = true

	# Add new lightning staff to inventory (don't remove old staffs!)
	var new_staff = LIGHTNING_STAFF_SCENE.instantiate()
	staff_holder.add_child(new_staff)
	new_staff.position = Vector2.ZERO

	# Add to inventory
	player_reference.staff_inventory.append(new_staff)

	# Hide the new staff initially (current staff stays active)
	new_staff.visible = false

	# Switch to the new staff
	player_reference.switch_to_staff(player_reference.staff_inventory.size() - 1)

# ============================================
# NEW WEAPONS - RAPIER
# ============================================
func _on_rapier_shop_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	if game_manager.get_gold() >= RAPIER_PRICE:
		if game_manager.spend_gold(RAPIER_PRICE):
			_swap_weapon_to_rapier()
			_update_rapier_shop_button()

func _update_rapier_shop_button():
	if not rapier_shop_button:
		return

	if rapier_purchased:
		rapier_shop_button.visible = false
		return

	rapier_shop_button.visible = true
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= RAPIER_PRICE:
		rapier_shop_button.disabled = false
		rapier_shop_button.text = "Rapier (%d Gold)" % RAPIER_PRICE
	else:
		rapier_shop_button.disabled = true
		rapier_shop_button.text = "Rapier - Need %d" % RAPIER_PRICE

func _swap_weapon_to_rapier():
	if not player_reference:
		return

	# Verify player has weapon holder node - prevents crash if node is missing
	var weapon_holder = player_reference.get_node_or_null("WeaponPivot/WeaponHolder")
	if not weapon_holder:
		push_warning("UpgradeMenu: WeaponHolder not found on player")
		return

	rapier_purchased = true

	var new_weapon = RAPIER_SCENE.instantiate()
	weapon_holder.add_child(new_weapon)
	new_weapon.position = Vector2.ZERO

	player_reference.weapon_inventory.append(new_weapon)

	if new_weapon.has_signal("attack_finished"):
		new_weapon.attack_finished.connect(player_reference._on_attack_finished)

	new_weapon.visible = false
	player_reference.switch_to_weapon(player_reference.weapon_inventory.size() - 1)

# ============================================
# NEW WEAPONS - WARHAMMER
# ============================================
func _on_warhammer_shop_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	if game_manager.get_gold() >= WARHAMMER_PRICE:
		if game_manager.spend_gold(WARHAMMER_PRICE):
			_swap_weapon_to_warhammer()
			_update_warhammer_shop_button()

func _update_warhammer_shop_button():
	if not warhammer_shop_button:
		return

	if warhammer_purchased:
		warhammer_shop_button.visible = false
		return

	warhammer_shop_button.visible = true
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= WARHAMMER_PRICE:
		warhammer_shop_button.disabled = false
		warhammer_shop_button.text = "Warhammer (%d Gold)" % WARHAMMER_PRICE
	else:
		warhammer_shop_button.disabled = true
		warhammer_shop_button.text = "Warhammer - Need %d" % WARHAMMER_PRICE

func _swap_weapon_to_warhammer():
	if not player_reference:
		return

	# Verify player has weapon holder node - prevents crash if node is missing
	var weapon_holder = player_reference.get_node_or_null("WeaponPivot/WeaponHolder")
	if not weapon_holder:
		push_warning("UpgradeMenu: WeaponHolder not found on player")
		return

	warhammer_purchased = true

	var new_weapon = WARHAMMER_SCENE.instantiate()
	weapon_holder.add_child(new_weapon)
	new_weapon.position = Vector2.ZERO

	player_reference.weapon_inventory.append(new_weapon)

	if new_weapon.has_signal("attack_finished"):
		new_weapon.attack_finished.connect(player_reference._on_attack_finished)

	new_weapon.visible = false
	player_reference.switch_to_weapon(player_reference.weapon_inventory.size() - 1)

# ============================================
# NEW STAFFS - FROST STAFF
# ============================================
func _on_frost_staff_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	if game_manager.get_gold() >= FROST_STAFF_PRICE:
		if game_manager.spend_gold(FROST_STAFF_PRICE):
			_swap_weapon_to_frost_staff()
			_update_frost_staff_button()

func _update_frost_staff_button():
	if not frost_staff_button:
		return

	if frost_staff_purchased:
		frost_staff_button.visible = false
		return

	frost_staff_button.visible = true
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= FROST_STAFF_PRICE:
		frost_staff_button.disabled = false
		frost_staff_button.text = "Frost Staff (%d Gold)" % FROST_STAFF_PRICE
	else:
		frost_staff_button.disabled = true
		frost_staff_button.text = "Frost Staff - Need %d" % FROST_STAFF_PRICE

func _swap_weapon_to_frost_staff():
	if not player_reference:
		return

	# Verify player has staff holder node - prevents crash if node is missing
	var staff_holder = player_reference.get_node_or_null("StaffPivot/StaffHolder")
	if not staff_holder:
		push_warning("UpgradeMenu: StaffHolder not found on player")
		return

	frost_staff_purchased = true

	var new_staff = FROST_STAFF_SCENE.instantiate()
	staff_holder.add_child(new_staff)
	new_staff.position = Vector2.ZERO

	player_reference.staff_inventory.append(new_staff)
	new_staff.visible = false
	player_reference.switch_to_staff(player_reference.staff_inventory.size() - 1)

# ============================================
# NEW STAFFS - VOID STAFF
# ============================================
func _on_void_staff_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	if game_manager.get_gold() >= VOID_STAFF_PRICE:
		if game_manager.spend_gold(VOID_STAFF_PRICE):
			_swap_weapon_to_void_staff()
			_update_void_staff_button()

func _update_void_staff_button():
	if not void_staff_button:
		return

	if void_staff_purchased:
		void_staff_button.visible = false
		return

	void_staff_button.visible = true
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= VOID_STAFF_PRICE:
		void_staff_button.disabled = false
		void_staff_button.text = "Void Staff (%d Gold)" % VOID_STAFF_PRICE
	else:
		void_staff_button.disabled = true
		void_staff_button.text = "Void Staff - Need %d" % VOID_STAFF_PRICE

func _swap_weapon_to_void_staff():
	if not player_reference:
		return

	# Verify player has staff holder node - prevents crash if node is missing
	var staff_holder = player_reference.get_node_or_null("StaffPivot/StaffHolder")
	if not staff_holder:
		push_warning("UpgradeMenu: StaffHolder not found on player")
		return

	void_staff_purchased = true

	var new_staff = VOID_STAFF_SCENE.instantiate()
	staff_holder.add_child(new_staff)
	new_staff.position = Vector2.ZERO

	player_reference.staff_inventory.append(new_staff)
	new_staff.visible = false
	player_reference.switch_to_staff(player_reference.staff_inventory.size() - 1)

func _close_menu():
	# Animate out
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		visible = false
		get_tree().paused = false
		menu_closed.emit()
	)

func _cleanup_active_effects():
	# Cancel all player attack animations
	if player_reference:
		# Reset all attack states
		player_reference.is_attacking = false
		player_reference.is_melee_attacking = false
		player_reference.is_magic_attacking = false

		# Cancel weapon attack animations
		if player_reference.current_weapon and player_reference.current_weapon.has_method("finish_attack"):
			player_reference.current_weapon.finish_attack()

		# Cancel staff attack animations
		if player_reference.current_staff and player_reference.current_staff.has_method("finish_attack"):
			player_reference.current_staff.finish_attack()

	# Clean up all damage numbers, projectiles, and visual effects in the scene
	_cleanup_scene_effects()

func _cleanup_scene_effects():
	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	# Remove all damage numbers (DamageNumber nodes)
	for node in scene_root.get_children():
		if node.get_script() and node.get_script().resource_path.ends_with("DamageNumber.gd"):
			node.queue_free()

	# Remove floating projectiles and effects
	# Look for common effect node types
	for node in scene_root.get_children():
		# Remove projectiles
		if node.is_in_group("projectiles"):
			node.queue_free()
		# Remove visual effects
		elif node.is_in_group("effects"):
			node.queue_free()
		# Remove any nodes with "effect" or "projectile" in name
		elif "effect" in node.name.to_lower() or "projectile" in node.name.to_lower():
			node.queue_free()

# ============================================
# HEALER SECTION
# ============================================
var free_heal_button: Button = null
var full_heal_button: Button = null
var healer_title_label: Label = null
var health_display_label: Label = null

func _setup_healer_section():
	if not healer_container:
		# Create healer container if it doesn't exist
		healer_container = VBoxContainer.new()
		healer_container.name = "HealerContainer"
		control.add_child(healer_container)
		healer_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		healer_container.position = Vector2(20, -200)

	# Clear existing children
	for child in healer_container.get_children():
		child.queue_free()

	# Create title
	healer_title_label = Label.new()
	healer_title_label.text = "⚕ HEALER"
	healer_title_label.add_theme_font_size_override("font_size", 24)
	healer_title_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	healer_container.add_child(healer_title_label)

	# Create health display
	health_display_label = Label.new()
	health_display_label.text = "HP: ???"
	health_display_label.add_theme_font_size_override("font_size", 18)
	health_display_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	healer_container.add_child(health_display_label)

	# Create free heal button (30% heal, once per visit)
	free_heal_button = Button.new()
	free_heal_button.text = "Free Heal (30%)"
	free_heal_button.custom_minimum_size = Vector2(180, 40)
	free_heal_button.pressed.connect(_on_free_heal_pressed)
	healer_container.add_child(free_heal_button)

	# Create full heal button (costs gold)
	full_heal_button = Button.new()
	full_heal_button.text = "Full Heal (%d Gold)" % FULL_HEAL_PRICE
	full_heal_button.custom_minimum_size = Vector2(180, 40)
	full_heal_button.pressed.connect(_on_full_heal_pressed)
	healer_container.add_child(full_heal_button)

	# Style the buttons
	_style_healer_button(free_heal_button, Color(0.2, 0.6, 0.2))
	_style_healer_button(full_heal_button, Color(0.6, 0.5, 0.2))

func _style_healer_button(button: Button, color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = color * 1.3
	button.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color * 1.2
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = color * 0.8
	button.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	disabled_style.border_color = Color(0.4, 0.4, 0.4)
	button.add_theme_stylebox_override("disabled", disabled_style)

func _update_healer_section():
	if not player_reference:
		return

	# Update health display
	var current_hp = player_reference.current_health if "current_health" in player_reference else 0
	var max_hp = player_reference.max_health if "max_health" in player_reference else 100

	if health_display_label:
		health_display_label.text = "HP: %d / %d" % [int(current_hp), int(max_hp)]

		# Color based on health percentage
		var health_percent = current_hp / max_hp if max_hp > 0 else 0
		if health_percent > 0.6:
			health_display_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		elif health_percent > 0.3:
			health_display_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
		else:
			health_display_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	# Update free heal button
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

	# Update full heal button
	if full_heal_button:
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		var current_gold = 0
		if game_manager:
			current_gold = game_manager.get_gold()

		if current_hp >= max_hp:
			full_heal_button.disabled = true
			full_heal_button.text = "Full Heal (Full HP)"
		elif current_gold < FULL_HEAL_PRICE:
			full_heal_button.disabled = true
			full_heal_button.text = "Full Heal - Need %d" % FULL_HEAL_PRICE
		else:
			full_heal_button.disabled = false
			full_heal_button.text = "Full Heal (%d Gold)" % FULL_HEAL_PRICE

func _on_free_heal_pressed():
	if not player_reference or free_heal_used:
		return

	# Get player health stats
	var max_hp = player_reference.max_health if "max_health" in player_reference else 100
	var current_hp = player_reference.current_health if "current_health" in player_reference else 0

	# Already at full health
	if current_hp >= max_hp:
		return

	# Calculate heal amount (30% of max health)
	var heal_amount = max_hp * FREE_HEAL_PERCENT

	# Apply heal
	if player_reference.has_method("heal"):
		player_reference.heal(heal_amount)
	else:
		player_reference.current_health = min(current_hp + heal_amount, max_hp)

	# Mark as used
	free_heal_used = true

	# Visual feedback
	_show_heal_effect(heal_amount)

	# Update display
	_update_healer_section()

func _on_full_heal_pressed():
	if not player_reference:
		return

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	# Check gold
	if game_manager.get_gold() < FULL_HEAL_PRICE:
		return

	# Get player health stats
	var max_hp = player_reference.max_health if "max_health" in player_reference else 100
	var current_hp = player_reference.current_health if "current_health" in player_reference else 0

	# Already at full health
	if current_hp >= max_hp:
		return

	# Spend gold
	if not game_manager.spend_gold(FULL_HEAL_PRICE):
		return

	# Calculate heal amount (full heal)
	var heal_amount = max_hp - current_hp

	# Apply heal
	if player_reference.has_method("heal"):
		player_reference.heal(heal_amount)
	else:
		player_reference.current_health = max_hp

	# Visual feedback
	_show_heal_effect(heal_amount)

	# Update display
	_update_healer_section()

	# Also update weapon shop buttons (gold changed)
	_update_weapon_shop_button()
	_update_axe_shop_button()
	_update_rapier_shop_button()
	_update_warhammer_shop_button()
	_update_staff_shop_button()
	_update_inferno_staff_button()
	_update_frost_staff_button()
	_update_void_staff_button()

func _show_heal_effect(heal_amount: float):
	# Create floating heal text
	var heal_label = Label.new()
	heal_label.text = "+%d HP" % int(heal_amount)
	heal_label.add_theme_font_size_override("font_size", 28)
	heal_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	control.add_child(heal_label)

	# Position near health display
	if healer_container:
		heal_label.global_position = healer_container.global_position + Vector2(50, -30)
	else:
		heal_label.position = Vector2(100, 400)

	# Animate float up and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(heal_label, "position:y", heal_label.position.y - 50, 1.0)
	tween.tween_property(heal_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(heal_label.queue_free)

func reset_healer_for_new_wave():
	# Called when entering Quarters - reset free heal availability
	free_heal_used = false

# ============================================
# NEW WEAPONS - SCYTHE
# ============================================
func _on_scythe_shop_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	if game_manager.get_gold() >= SCYTHE_PRICE:
		if game_manager.spend_gold(SCYTHE_PRICE):
			_swap_weapon_to_scythe()
			_update_scythe_shop_button()

func _update_scythe_shop_button():
	if not scythe_shop_button:
		return

	if scythe_purchased:
		scythe_shop_button.visible = false
		return

	scythe_shop_button.visible = true
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= SCYTHE_PRICE:
		scythe_shop_button.disabled = false
		scythe_shop_button.text = "Scythe (%d Gold)" % SCYTHE_PRICE
	else:
		scythe_shop_button.disabled = true
		scythe_shop_button.text = "Scythe - Need %d" % SCYTHE_PRICE

func _swap_weapon_to_scythe():
	if not player_reference:
		return

	var weapon_holder = player_reference.get_node_or_null("WeaponPivot/WeaponHolder")
	if not weapon_holder:
		push_warning("UpgradeMenu: WeaponHolder not found on player")
		return

	scythe_purchased = true

	var new_weapon = SCYTHE_SCENE.instantiate()
	weapon_holder.add_child(new_weapon)
	new_weapon.position = Vector2.ZERO

	player_reference.weapon_inventory.append(new_weapon)

	if new_weapon.has_signal("attack_finished"):
		new_weapon.attack_finished.connect(player_reference._on_attack_finished)

	new_weapon.visible = false
	player_reference.switch_to_weapon(player_reference.weapon_inventory.size() - 1)

# ============================================
# NEW WEAPONS - SPEAR
# ============================================
func _on_spear_shop_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	if game_manager.get_gold() >= SPEAR_PRICE:
		if game_manager.spend_gold(SPEAR_PRICE):
			_swap_weapon_to_spear()
			_update_spear_shop_button()

func _update_spear_shop_button():
	if not spear_shop_button:
		return

	if spear_purchased:
		spear_shop_button.visible = false
		return

	spear_shop_button.visible = true
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= SPEAR_PRICE:
		spear_shop_button.disabled = false
		spear_shop_button.text = "Spear (%d Gold)" % SPEAR_PRICE
	else:
		spear_shop_button.disabled = true
		spear_shop_button.text = "Spear - Need %d" % SPEAR_PRICE

func _swap_weapon_to_spear():
	if not player_reference:
		return

	var weapon_holder = player_reference.get_node_or_null("WeaponPivot/WeaponHolder")
	if not weapon_holder:
		push_warning("UpgradeMenu: WeaponHolder not found on player")
		return

	spear_purchased = true

	var new_weapon = SPEAR_SCENE.instantiate()
	weapon_holder.add_child(new_weapon)
	new_weapon.position = Vector2.ZERO

	player_reference.weapon_inventory.append(new_weapon)

	if new_weapon.has_signal("attack_finished"):
		new_weapon.attack_finished.connect(player_reference._on_attack_finished)

	new_weapon.visible = false
	player_reference.switch_to_weapon(player_reference.weapon_inventory.size() - 1)

# ============================================
# NEW STAFFS - NECRO STAFF
# ============================================
func _on_necro_staff_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	if game_manager.get_gold() >= NECRO_STAFF_PRICE:
		if game_manager.spend_gold(NECRO_STAFF_PRICE):
			_swap_weapon_to_necro_staff()
			_update_necro_staff_button()

func _update_necro_staff_button():
	if not necro_staff_button:
		return

	if necro_staff_purchased:
		necro_staff_button.visible = false
		return

	necro_staff_button.visible = true
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= NECRO_STAFF_PRICE:
		necro_staff_button.disabled = false
		necro_staff_button.text = "Necro Staff (%d Gold)" % NECRO_STAFF_PRICE
	else:
		necro_staff_button.disabled = true
		necro_staff_button.text = "Necro Staff - Need %d" % NECRO_STAFF_PRICE

func _swap_weapon_to_necro_staff():
	if not player_reference:
		return

	var staff_holder = player_reference.get_node_or_null("StaffPivot/StaffHolder")
	if not staff_holder:
		push_warning("UpgradeMenu: StaffHolder not found on player")
		return

	necro_staff_purchased = true

	var new_staff = NECRO_STAFF_SCENE.instantiate()
	staff_holder.add_child(new_staff)
	new_staff.position = Vector2.ZERO

	player_reference.staff_inventory.append(new_staff)
	new_staff.visible = false
	player_reference.switch_to_staff(player_reference.staff_inventory.size() - 1)
