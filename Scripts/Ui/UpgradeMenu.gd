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
@onready var skip_button: Button = $Control/SkipButton

# MELEE WEAPONS
const KATANA_SCENE = preload("res://Scenes/Weapons/Katana.tscn")
const KATANA_PRICE = 10
const EXECUTIONERS_AXE_SCENE = preload("res://Scenes/Weapons/ExecutionersAxe.tscn")
const AXE_PRICE = 15
const RAPIER_SCENE = preload("res://Scenes/Weapons/Rapier.tscn")
const RAPIER_PRICE = 12
const WARHAMMER_SCENE = preload("res://Scenes/Weapons/Warhammer.tscn")
const WARHAMMER_PRICE = 18

# STAFFS
const LIGHTNING_STAFF_SCENE = preload("res://Scenes/Weapons/LightningStaff.tscn")
const STAFF_PRICE = 10
const INFERNO_STAFF_SCENE = preload("res://Scenes/Weapons/InfernoStaff.tscn")
const INFERNO_STAFF_PRICE = 12
const FROST_STAFF_SCENE = preload("res://Scenes/Weapons/FrostStaff.tscn")
const FROST_STAFF_PRICE = 11
const VOID_STAFF_SCENE = preload("res://Scenes/Weapons/VoidStaff.tscn")
const VOID_STAFF_PRICE = 16

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

func show_upgrades(player: Node2D):
	player_reference = player

	# CRITICAL: Clean up all active animations and effects BEFORE pausing
	_cleanup_active_effects()

	# Update weapon shop buttons
	_update_weapon_shop_button()
	_update_axe_shop_button()
	_update_rapier_shop_button()
	_update_warhammer_shop_button()
	_update_staff_shop_button()
	_update_inferno_staff_button()
	_update_frost_staff_button()
	_update_void_staff_button()

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
