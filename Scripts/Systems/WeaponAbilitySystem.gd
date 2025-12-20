# SCRIPT: WeaponAbilitySystem.gd
# AUTOLOAD: WeaponAbilitySystem
# LOCATION: res://Scripts/Systems/WeaponAbilitySystem.gd
# PURPOSE: Unified framework for weapon skills/abilities

extends Node

# ============================================
# ABILITY DATA STRUCTURE
# ============================================

class AbilityData:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var icon_path: String = ""

	# Cooldown
	var base_cooldown: float = 5.0
	var current_cooldown: float = 0.0
	var cooldown_reduction: float = 0.0  # 0.0 to 1.0

	# Cost
	var mana_cost: float = 0.0
	var health_cost: float = 0.0
	var charges: int = -1  # -1 = infinite
	var max_charges: int = -1
	var charge_recharge_time: float = 0.0

	# Targeting
	var targeting_type: TargetingType = TargetingType.DIRECTION
	var ability_range: float = 200.0
	var radius: float = 0.0  # For AOE
	var angle: float = 0.0   # For cone

	# Damage
	var base_damage: float = 0.0
	var damage_scaling: float = 1.0  # Multiplier from weapon damage
	var damage_type: int = 0  # DamageTypes.Type
	var can_crit: bool = true

	# Effects
	var status_effects: Array = []  # Array of {type: EffectType, chance: float, duration: float, value: float}
	var knockback: float = 0.0
	var stun_duration: float = 0.0

	# Animation
	var animation_name: String = ""
	var cast_time: float = 0.0
	var channel_time: float = 0.0

	# Upgrades
	var upgrade_level: int = 0
	var max_upgrade_level: int = 3

	func is_ready() -> bool:
		return current_cooldown <= 0 and (charges < 0 or charges > 0)

	func get_effective_cooldown() -> float:
		return base_cooldown * (1.0 - cooldown_reduction)

	func get_total_damage(weapon_damage: float) -> float:
		return base_damage + (weapon_damage * damage_scaling)

enum TargetingType {
	NONE,           # Self-buff, no targeting needed
	DIRECTION,      # Fires in a direction (mouse direction)
	POINT,          # Target a point on ground
	ENEMY,          # Target a specific enemy
	SELF_AOE,       # AOE centered on self
	POINT_AOE,      # AOE at target point
	CONE,           # Cone in direction
	LINE,           # Line from player to max range
	CHAIN           # Chains between targets
}

# ============================================
# REGISTERED ABILITIES
# ============================================

var _ability_templates: Dictionary = {}  # id -> AbilityData template
var _weapon_abilities: Dictionary = {}   # weapon_instance_id -> { ability_id -> AbilityData }

# ============================================
# SIGNALS
# ============================================

signal ability_registered(ability_id: String)
signal ability_used(user: Node2D, ability: AbilityData)
signal ability_ready(user: Node2D, ability_id: String)
signal ability_cooldown_started(user: Node2D, ability_id: String, duration: float)
signal ability_hit(user: Node2D, ability: AbilityData, targets: Array)
signal ability_upgraded(user: Node2D, ability_id: String, new_level: int)

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	_register_built_in_abilities()

func _process(delta):
	_update_cooldowns(delta)

# ============================================
# ABILITY REGISTRATION
# ============================================

## Register an ability template that weapons can use
func register_ability(ability: AbilityData) -> void:
	if ability.id.is_empty():
		push_error("WeaponAbilitySystem: Cannot register ability without ID")
		return

	_ability_templates[ability.id] = ability
	ability_registered.emit(ability.id)

## Create an ability instance for a weapon from a template
func create_ability_instance(weapon: Node2D, template_id: String) -> AbilityData:
	if template_id not in _ability_templates:
		push_error("WeaponAbilitySystem: Unknown ability template '%s'" % template_id)
		return null

	var template = _ability_templates[template_id]
	var instance = _duplicate_ability(template)

	var weapon_id = weapon.get_instance_id()
	if weapon_id not in _weapon_abilities:
		_weapon_abilities[weapon_id] = {}

	_weapon_abilities[weapon_id][template_id] = instance
	return instance

## Get a weapon's ability instance
func get_ability(weapon: Node2D, ability_id: String) -> AbilityData:
	var weapon_id = weapon.get_instance_id()
	if weapon_id not in _weapon_abilities:
		return null
	return _weapon_abilities[weapon_id].get(ability_id)

## Get all abilities for a weapon
func get_weapon_abilities(weapon: Node2D) -> Array:
	var weapon_id = weapon.get_instance_id()
	if weapon_id not in _weapon_abilities:
		return []
	return _weapon_abilities[weapon_id].values()

# ============================================
# ABILITY USAGE
# ============================================

## Check if ability can be used
func can_use_ability(weapon: Node2D, ability_id: String) -> bool:
	var ability = get_ability(weapon, ability_id)
	if not ability:
		return false

	if not ability.is_ready():
		return false

	# Check mana if weapon has player reference
	if ability.mana_cost > 0:
		var player = _get_player_from_weapon(weapon)
		if player and player.has_method("get_mana"):
			if player.get_mana() < ability.mana_cost:
				return false

	return true

## Use an ability
func use_ability(weapon: Node2D, ability_id: String, target_info: Dictionary = {}) -> bool:
	if not can_use_ability(weapon, ability_id):
		return false

	var ability = get_ability(weapon, ability_id)
	var user = _get_player_from_weapon(weapon)

	# Consume resources
	if ability.mana_cost > 0 and user and user.has_method("use_mana"):
		user.use_mana(ability.mana_cost)

	if ability.health_cost > 0 and user and user.has_method("take_damage"):
		user.take_damage(ability.health_cost, Vector2.ZERO)

	if ability.charges > 0:
		ability.charges -= 1

	# Start cooldown
	ability.current_cooldown = ability.get_effective_cooldown()
	ability_cooldown_started.emit(user, ability_id, ability.current_cooldown)

	# Execute ability
	var targets = _execute_ability(weapon, ability, target_info)

	# Emit events
	ability_used.emit(user, ability)
	if CombatEventBus:
		CombatEventBus.emit_skill(user, ability_id, ability.current_cooldown)

	if targets.size() > 0:
		ability_hit.emit(user, ability, targets)

	return true

## Execute the ability logic
func _execute_ability(weapon: Node2D, ability: AbilityData, target_info: Dictionary) -> Array:
	var targets_hit: Array = []
	var user = _get_player_from_weapon(weapon)
	if not user:
		return targets_hit

	var direction = target_info.get("direction", Vector2.RIGHT)
	var target_pos = target_info.get("position", user.global_position + direction * ability.ability_range)

	match ability.targeting_type:
		TargetingType.DIRECTION:
			targets_hit = _execute_direction_ability(user, weapon, ability, direction)

		TargetingType.SELF_AOE:
			targets_hit = _execute_aoe_ability(user, weapon, ability, user.global_position)

		TargetingType.POINT_AOE:
			targets_hit = _execute_aoe_ability(user, weapon, ability, target_pos)

		TargetingType.CONE:
			targets_hit = _execute_cone_ability(user, weapon, ability, direction)

		TargetingType.LINE:
			targets_hit = _execute_line_ability(user, weapon, ability, direction)

		TargetingType.NONE:
			# Self buff, no targets
			_apply_self_effects(user, ability)

	return targets_hit

func _execute_direction_ability(user: Node2D, weapon: Node2D, ability: AbilityData, direction: Vector2) -> Array:
	# Find enemies in direction within range
	var targets: Array = []
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var to_enemy = enemy.global_position - user.global_position
		var dist = to_enemy.length()

		if dist > ability.ability_range:
			continue

		var dot = to_enemy.normalized().dot(direction)
		if dot > 0.5:  # Within ~60 degree cone
			targets.append(enemy)

	_apply_damage_to_targets(user, weapon, ability, targets)
	return targets

func _execute_aoe_ability(user: Node2D, weapon: Node2D, ability: AbilityData, center: Vector2) -> Array:
	var targets: Array = []
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var dist = enemy.global_position.distance_to(center)
		if dist <= ability.radius:
			targets.append(enemy)

	_apply_damage_to_targets(user, weapon, ability, targets)
	return targets

func _execute_cone_ability(user: Node2D, weapon: Node2D, ability: AbilityData, direction: Vector2) -> Array:
	var targets: Array = []
	var enemies = get_tree().get_nodes_in_group("enemies")
	var half_angle = deg_to_rad(ability.angle / 2)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var to_enemy = enemy.global_position - user.global_position
		var dist = to_enemy.length()

		if dist > ability.ability_range:
			continue

		var angle_to_enemy = direction.angle_to(to_enemy.normalized())
		if abs(angle_to_enemy) <= half_angle:
			targets.append(enemy)

	_apply_damage_to_targets(user, weapon, ability, targets)
	return targets

func _execute_line_ability(user: Node2D, weapon: Node2D, ability: AbilityData, direction: Vector2) -> Array:
	var targets: Array = []
	var enemies = get_tree().get_nodes_in_group("enemies")
	var line_width = 30.0  # How wide the line is

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var to_enemy = enemy.global_position - user.global_position
		var dist = to_enemy.length()

		if dist > ability.ability_range:
			continue

		# Check if enemy is within line width
		var projected = to_enemy.project(direction)
		var perpendicular = to_enemy - projected

		if perpendicular.length() <= line_width and projected.dot(direction) > 0:
			targets.append(enemy)

	_apply_damage_to_targets(user, weapon, ability, targets)
	return targets

func _apply_damage_to_targets(user: Node2D, weapon: Node2D, ability: AbilityData, targets: Array):
	var weapon_damage = weapon.damage if weapon.get("damage") else 0.0
	var total_damage = ability.get_total_damage(weapon_damage)

	for target in targets:
		if not is_instance_valid(target) or not target.has_method("take_damage"):
			continue

		# Check for crit
		var is_crit = false
		var final_damage = total_damage
		if ability.can_crit and user and user.get("stats"):
			if randf() < user.stats.crit_chance:
				is_crit = true
				final_damage *= user.stats.crit_damage

		# Apply damage
		target.take_damage(final_damage, user.global_position, ability.knockback, ability.stun_duration, user, ability.damage_type)

		# Apply status effects
		for effect_data in ability.status_effects:
			if randf() < effect_data.get("chance", 1.0):
				if StatusEffectManager:
					StatusEffectManager.apply_effect(
						target,
						effect_data.type,
						effect_data.get("duration", 3.0),
						effect_data.get("value", 0.0),
						user
					)

		# Emit combat event
		if CombatEventBus:
			CombatEventBus.emit_damage(user, target, final_damage, ability.damage_type, is_crit, false, false, ability.knockback, weapon)

func _apply_self_effects(user: Node2D, ability: AbilityData):
	for effect_data in ability.status_effects:
		if StatusEffectManager:
			StatusEffectManager.apply_effect(
				user,
				effect_data.type,
				effect_data.get("duration", 5.0),
				effect_data.get("value", 0.0),
				null
			)

# ============================================
# COOLDOWN MANAGEMENT
# ============================================

func _update_cooldowns(delta):
	for weapon_id in _weapon_abilities:
		var abilities = _weapon_abilities[weapon_id]
		var weapon = instance_from_id(weapon_id) as Node2D

		for ability_id in abilities:
			var ability = abilities[ability_id]

			if ability.current_cooldown > 0:
				ability.current_cooldown -= delta

				if ability.current_cooldown <= 0:
					ability.current_cooldown = 0
					var user = _get_player_from_weapon(weapon) if weapon else null
					ability_ready.emit(user, ability_id)

			# Recharge charges
			if ability.max_charges > 0 and ability.charges < ability.max_charges:
				ability.charge_recharge_time -= delta
				if ability.charge_recharge_time <= 0:
					ability.charges += 1
					ability.charge_recharge_time = ability.base_cooldown

## Get cooldown progress (0.0 = ready, 1.0 = just used)
func get_cooldown_progress(weapon: Node2D, ability_id: String) -> float:
	var ability = get_ability(weapon, ability_id)
	if not ability or ability.base_cooldown <= 0:
		return 0.0
	return ability.current_cooldown / ability.get_effective_cooldown()

## Get remaining cooldown time
func get_cooldown_remaining(weapon: Node2D, ability_id: String) -> float:
	var ability = get_ability(weapon, ability_id)
	if not ability:
		return 0.0
	return ability.current_cooldown

## Reset ability cooldown
func reset_cooldown(weapon: Node2D, ability_id: String):
	var ability = get_ability(weapon, ability_id)
	if ability:
		ability.current_cooldown = 0.0
		var user = _get_player_from_weapon(weapon)
		ability_ready.emit(user, ability_id)

## Reduce cooldown by amount
func reduce_cooldown(weapon: Node2D, ability_id: String, amount: float):
	var ability = get_ability(weapon, ability_id)
	if ability:
		ability.current_cooldown = max(0, ability.current_cooldown - amount)

# ============================================
# UPGRADES
# ============================================

func upgrade_ability(weapon: Node2D, ability_id: String) -> bool:
	var ability = get_ability(weapon, ability_id)
	if not ability or ability.upgrade_level >= ability.max_upgrade_level:
		return false

	ability.upgrade_level += 1

	# Apply upgrade bonuses (customize per ability)
	ability.base_damage *= 1.15  # 15% damage increase per level
	ability.base_cooldown *= 0.9  # 10% cooldown reduction per level

	var user = _get_player_from_weapon(weapon)
	ability_upgraded.emit(user, ability_id, ability.upgrade_level)
	return true

# ============================================
# BUILT-IN ABILITIES
# ============================================

func _register_built_in_abilities():
	# Sword Spin (BasicSword skill)
	var sword_spin = AbilityData.new()
	sword_spin.id = "sword_spin"
	sword_spin.name = "Whirlwind"
	sword_spin.description = "Spin in a circle, damaging all nearby enemies"
	sword_spin.base_cooldown = 8.0
	sword_spin.targeting_type = TargetingType.SELF_AOE
	sword_spin.radius = 100.0
	sword_spin.damage_scaling = 1.5
	sword_spin.knockback = 300.0
	register_ability(sword_spin)

	# Rapier Flurry
	var rapier_flurry = AbilityData.new()
	rapier_flurry.id = "rapier_flurry"
	rapier_flurry.name = "Flurry"
	rapier_flurry.description = "Rapid series of thrusts in a direction"
	rapier_flurry.base_cooldown = 4.0
	rapier_flurry.targeting_type = TargetingType.CONE
	rapier_flurry.ability_range = 150.0
	rapier_flurry.angle = 45.0
	rapier_flurry.damage_scaling = 0.4  # Per hit, 8 hits
	register_ability(rapier_flurry)

	# Katana Dash Strike
	var katana_dash = AbilityData.new()
	katana_dash.id = "katana_dash"
	katana_dash.name = "Shadow Step"
	katana_dash.description = "Dash through enemies, dealing damage"
	katana_dash.base_cooldown = 6.0
	katana_dash.targeting_type = TargetingType.LINE
	katana_dash.ability_range = 200.0
	katana_dash.damage_scaling = 2.0
	katana_dash.status_effects = [
		{"type": StatusEffectManager.EffectType.BLEED if StatusEffectManager else 0, "chance": 0.5, "duration": 3.0, "value": 2.0}
	]
	register_ability(katana_dash)

	# War Hammer Ground Slam
	var hammer_slam = AbilityData.new()
	hammer_slam.id = "hammer_slam"
	hammer_slam.name = "Ground Slam"
	hammer_slam.description = "Slam the ground, stunning nearby enemies"
	hammer_slam.base_cooldown = 10.0
	hammer_slam.targeting_type = TargetingType.SELF_AOE
	hammer_slam.radius = 120.0
	hammer_slam.damage_scaling = 2.5
	hammer_slam.stun_duration = 0.5
	hammer_slam.knockback = 400.0
	register_ability(hammer_slam)

# ============================================
# HELPERS
# ============================================

func _get_player_from_weapon(weapon: Node2D) -> Node2D:
	if weapon.get("player_reference"):
		return weapon.player_reference
	# Try to find player through tree
	var player = weapon.get_tree().get_first_node_in_group("player")
	return player

func _duplicate_ability(template: AbilityData) -> AbilityData:
	var copy = AbilityData.new()
	copy.id = template.id
	copy.name = template.name
	copy.description = template.description
	copy.icon_path = template.icon_path
	copy.base_cooldown = template.base_cooldown
	copy.cooldown_reduction = template.cooldown_reduction
	copy.mana_cost = template.mana_cost
	copy.health_cost = template.health_cost
	copy.charges = template.charges
	copy.max_charges = template.max_charges
	copy.targeting_type = template.targeting_type
	copy.ability_range = template.ability_range
	copy.radius = template.radius
	copy.angle = template.angle
	copy.base_damage = template.base_damage
	copy.damage_scaling = template.damage_scaling
	copy.damage_type = template.damage_type
	copy.can_crit = template.can_crit
	copy.status_effects = template.status_effects.duplicate(true)
	copy.knockback = template.knockback
	copy.stun_duration = template.stun_duration
	copy.animation_name = template.animation_name
	copy.cast_time = template.cast_time
	copy.channel_time = template.channel_time
	copy.upgrade_level = template.upgrade_level
	copy.max_upgrade_level = template.max_upgrade_level
	return copy

# ============================================
# CLEANUP
# ============================================

func unregister_weapon(weapon: Node2D):
	var weapon_id = weapon.get_instance_id()
	_weapon_abilities.erase(weapon_id)
