# SCRIPT: SynergyManager.gd
# AUTOLOAD: SynergyManager
# LOCATION: res://Scripts/Systems/SynergyManager.gd
# PURPOSE: Manages synergies between relics, weapons, and damage types

extends Node

# ============================================
# SIGNALS
# ============================================
signal synergy_activated(synergy_id: String, description: String)
signal synergy_deactivated(synergy_id: String)
signal synergies_changed

# ============================================
# WEAPON REGISTRY - Actual weapons in the game
# ============================================
const MELEE_WEAPONS = ["BasicSword", "Katana", "Rapier", "Warhammer", "ExecutionersAxe", "Scythe", "Spear"]
const MAGIC_STAVES = ["BasicStaff", "InfernoStaff", "FrostStaff", "LightningStaff", "VoidStaff", "NecroStaff"]
const FIRE_WEAPONS = ["InfernoStaff"]
const ICE_WEAPONS = ["FrostStaff"]
const LIGHTNING_WEAPONS = ["LightningStaff"]
const VOID_WEAPONS = ["VoidStaff"]
const FAST_MELEE = ["Katana", "Rapier"]
const HEAVY_MELEE = ["Warhammer", "ExecutionersAxe", "Scythe"]

# ============================================
# SYNERGY DEFINITIONS
# ============================================
const SYNERGIES = {
	# Fire Synergies
	"inferno_mastery": {
		"name": "Inferno Mastery",
		"description": "Fire weapons deal +50% burn damage",
		"icon_color": Color(1.0, 0.4, 0.1),
		"requirements": {
			"weapon_names": ["InfernoStaff"],
			"relic_ids": ["burning_heart"]
		},
		"bonuses": {
			"burn_damage_multiplier": 1.5
		}
	},
	"spreading_flames": {
		"name": "Spreading Flames",
		"description": "Burn spreads to nearby enemies on kill",
		"icon_color": Color(1.0, 0.5, 0.0),
		"requirements": {
			"weapon_names": ["InfernoStaff"],
			"relic_ids": ["ember_crown"]
		},
		"bonuses": {
			"burn_spread_on_kill": true,
			"spread_radius": 150.0
		}
	},

	# Ice Synergies
	"permafrost": {
		"name": "Permafrost",
		"description": "Chill slows 30% more, frozen enemies take +25% damage",
		"icon_color": Color(0.6, 0.9, 1.0),
		"requirements": {
			"weapon_names": ["FrostStaff"],
			"relic_ids": ["frozen_heart"]
		},
		"bonuses": {
			"chill_slow_bonus": 0.3,
			"frozen_damage_bonus": 0.25
		}
	},
	"shatter": {
		"name": "Shatter",
		"description": "Killing frozen enemies creates ice shards",
		"icon_color": Color(0.7, 0.95, 1.0),
		"requirements": {
			"weapon_names": ["FrostStaff"],
			"relic_ids": ["crystal_shard"]
		},
		"bonuses": {
			"shatter_on_frozen_kill": true,
			"shard_count": 5,
			"shard_damage": 15.0
		}
	},

	# Lightning Synergies
	"chain_lightning": {
		"name": "Chain Lightning",
		"description": "Shock chains to +2 additional enemies",
		"icon_color": Color(0.8, 0.9, 1.0),
		"requirements": {
			"weapon_names": ["LightningStaff"],
			"relic_ids": ["storm_conduit"]
		},
		"bonuses": {
			"chain_count_bonus": 2
		}
	},
	"overcharge": {
		"name": "Overcharge",
		"description": "Crits cause lightning explosions",
		"icon_color": Color(0.9, 0.95, 1.0),
		"requirements": {
			"weapon_names": ["LightningStaff"],
			"min_crit_chance": 0.10
		},
		"bonuses": {
			"crit_lightning_explosion": true,
			"explosion_radius": 100.0,
			"explosion_damage": 25.0
		}
	},

	# Void Synergies
	"void_corruption": {
		"name": "Void Corruption",
		"description": "Enemies hit take 15% more damage for 3s",
		"icon_color": Color(0.5, 0.0, 0.8),
		"requirements": {
			"weapon_names": ["VoidStaff"],
			"relic_ids": ["void_shard"]
		},
		"bonuses": {
			"void_vulnerability": true,
			"vulnerability_amount": 0.15,
			"vulnerability_duration": 3.0
		}
	},

	# Necro Synergies
	"legion_of_undead": {
		"name": "Legion of Undead",
		"description": "Minions gain +30% damage and HP",
		"icon_color": Color(0.4, 0.8, 0.3),
		"requirements": {
			"weapon_names": ["NecroStaff"],
			"relic_ids": ["soul_vessel"]
		},
		"bonuses": {
			"minion_damage_bonus": 0.3,
			"minion_health_bonus": 0.3
		}
	},
	"soul_harvest": {
		"name": "Soul Harvest",
		"description": "Minion kills heal player for 3 HP",
		"icon_color": Color(0.5, 0.9, 0.4),
		"requirements": {
			"weapon_names": ["NecroStaff"],
			"relic_ids": ["vampiric_essence"]
		},
		"bonuses": {
			"minion_kill_heal": 3.0
		}
	},

	# Katana Synergies
	"blade_dancer": {
		"name": "Blade Dancer",
		"description": "Attack speed +15%, movement doesn't interrupt attacks",
		"icon_color": Color(0.9, 0.7, 0.9),
		"requirements": {
			"weapon_names": ["Katana"],
			"relic_ids": ["swift_boots"]
		},
		"bonuses": {
			"attack_speed_bonus": 0.15,
			"move_while_attacking": true
		}
	},
	"iaido_master": {
		"name": "Iaido Master",
		"description": "First attack after dash deals +50% damage",
		"icon_color": Color(0.95, 0.8, 0.95),
		"requirements": {
			"weapon_names": ["Katana"],
			"has_dash": true
		},
		"bonuses": {
			"dash_first_attack_bonus": 0.5
		}
	},

	# Rapier Synergies
	"duelist": {
		"name": "Duelist",
		"description": "+20% crit chance, +10% crit damage",
		"icon_color": Color(0.9, 0.85, 0.7),
		"requirements": {
			"weapon_names": ["Rapier"],
			"relic_ids": ["fencing_medal"]
		},
		"bonuses": {
			"crit_chance_bonus": 0.2,
			"crit_damage_bonus": 0.1
		}
	},
	"riposte": {
		"name": "Riposte",
		"description": "Perfect dodge triggers counter attack",
		"icon_color": Color(0.95, 0.9, 0.75),
		"requirements": {
			"weapon_names": ["Rapier"],
			"relic_ids": ["parry_charm"]
		},
		"bonuses": {
			"counter_on_dodge": true,
			"counter_damage": 25.0
		}
	},

	# Warhammer Synergies
	"earthquake": {
		"name": "Earthquake",
		"description": "Heavy attacks stun enemies for 0.5s longer",
		"icon_color": Color(0.6, 0.5, 0.4),
		"requirements": {
			"weapon_names": ["Warhammer"],
			"relic_ids": ["titans_grip"]
		},
		"bonuses": {
			"stun_duration_bonus": 0.5
		}
	},
	"armor_crusher": {
		"name": "Armor Crusher",
		"description": "Ignores 30% of enemy defense",
		"icon_color": Color(0.7, 0.55, 0.45),
		"requirements": {
			"weapon_names": ["Warhammer"],
			"relic_count": 2
		},
		"bonuses": {
			"armor_penetration": 0.3
		}
	},

	# ExecutionersAxe Synergies
	"executioner": {
		"name": "Executioner",
		"description": "Crits on enemies below 25% HP deal double damage",
		"icon_color": Color(0.8, 0.2, 0.2),
		"requirements": {
			"weapon_names": ["ExecutionersAxe"],
			"min_crit_chance": 0.10
		},
		"bonuses": {
			"execute_threshold": 0.25,
			"execute_crit_multiplier": 2.0
		}
	},
	"bloody_harvest": {
		"name": "Bloody Harvest",
		"description": "Kills restore 5% max HP",
		"icon_color": Color(0.9, 0.15, 0.15),
		"requirements": {
			"weapon_names": ["ExecutionersAxe"],
			"relic_ids": ["bloodthirst"]
		},
		"bonuses": {
			"kill_heal_percent": 0.05
		}
	},

	# Scythe Synergies
	"soul_reaper": {
		"name": "Soul Reaper",
		"description": "Attacks mark enemies, marked enemies take +20% damage",
		"icon_color": Color(0.3, 0.3, 0.35),
		"requirements": {
			"weapon_names": ["Scythe"],
			"relic_ids": ["death_mark"]
		},
		"bonuses": {
			"mark_enemies": true,
			"mark_damage_bonus": 0.2
		}
	},
	"death_spiral": {
		"name": "Death Spiral",
		"description": "Spin attack radius +25%, hits pull enemies",
		"icon_color": Color(0.35, 0.35, 0.4),
		"requirements": {
			"weapon_names": ["Scythe"],
			"relic_ids": ["vortex_core"]
		},
		"bonuses": {
			"spin_radius_bonus": 0.25,
			"spin_pulls_enemies": true
		}
	},

	# Spear Synergies
	"phalanx": {
		"name": "Phalanx",
		"description": "+15% damage reduction while attacking",
		"icon_color": Color(0.7, 0.6, 0.5),
		"requirements": {
			"weapon_names": ["Spear"],
			"relic_ids": ["shield_emblem"]
		},
		"bonuses": {
			"attack_damage_reduction": 0.15
		}
	},
	"impaler": {
		"name": "Impaler",
		"description": "Thrust attacks pierce through enemies",
		"icon_color": Color(0.75, 0.65, 0.55),
		"requirements": {
			"weapon_names": ["Spear"],
			"relic_count": 2
		},
		"bonuses": {
			"pierce_enemies": true,
			"pierce_damage_falloff": 0.2
		}
	},

	# General Melee Synergies
	"berserker": {
		"name": "Berserker",
		"description": "+20% damage when below 30% HP, attacks heal 2 HP",
		"icon_color": Color(0.9, 0.3, 0.2),
		"requirements": {
			"weapon_category": "melee",
			"relic_ids": ["blood_rage"]
		},
		"bonuses": {
			"low_health_damage_bonus": 0.2,
			"low_health_threshold": 0.3,
			"attack_heal": 2.0
		}
	},
	"whirlwind": {
		"name": "Whirlwind",
		"description": "Combo finishers hit all nearby enemies",
		"icon_color": Color(0.8, 0.8, 0.9),
		"requirements": {
			"weapon_category": "melee",
			"relic_ids": ["cyclone_pendant"]
		},
		"bonuses": {
			"finisher_aoe": true,
			"aoe_radius": 120.0
		}
	},

	# General Staff Synergies
	"arcane_mastery": {
		"name": "Arcane Mastery",
		"description": "+15% magic damage, -10% mana cost",
		"icon_color": Color(0.6, 0.5, 0.9),
		"requirements": {
			"weapon_category": "magic",
			"relic_ids": ["arcane_focus"]
		},
		"bonuses": {
			"magic_damage_bonus": 0.15,
			"mana_cost_reduction": 0.1
		}
	},

	# Speed/Dash Synergies
	"flash_step": {
		"name": "Flash Step",
		"description": "Dash resets on kill, dash attacks deal +30% damage",
		"icon_color": Color(0.7, 0.9, 1.0),
		"requirements": {
			"has_dash": true,
			"relic_ids": ["phantom_cloak"]
		},
		"bonuses": {
			"dash_reset_on_kill": true,
			"dash_attack_bonus": 0.3
		}
	},

	# Crit Synergies
	"critical_cascade": {
		"name": "Critical Cascade",
		"description": "Each crit increases next crit chance by 5% (resets on non-crit)",
		"icon_color": Color(1.0, 0.9, 0.3),
		"requirements": {
			"min_crit_chance": 0.10,
			"relic_count": 2
		},
		"bonuses": {
			"cascade_crit": true,
			"cascade_bonus": 0.05,
			"max_cascade_stacks": 10
		}
	},

	# Defense Synergies
	"iron_fortress": {
		"name": "Iron Fortress",
		"description": "+15% damage reduction, reflect 20% damage to attackers",
		"icon_color": Color(0.6, 0.6, 0.65),
		"requirements": {
			"min_damage_reduction": 0.10,
			"relic_ids": ["iron_skin"]
		},
		"bonuses": {
			"damage_reduction_bonus": 0.15,
			"thorns_percent": 0.2
		}
	},
	"second_wind": {
		"name": "Second Wind",
		"description": "After taking fatal damage, become invulnerable for 2s and heal 25% HP (once per wave)",
		"icon_color": Color(1.0, 0.8, 0.4),
		"requirements": {
			"relic_ids": ["phoenix_feather", "guardian_angel"]
		},
		"bonuses": {
			"enhanced_revive": true,
			"revive_invuln_duration": 2.0,
			"revive_heal_percent": 0.25
		}
	},

	# Gold Synergies
	"midas_touch": {
		"name": "Midas Touch",
		"description": "Enemies drop 50% more gold, gold pickups heal 1 HP",
		"icon_color": Color(1.0, 0.85, 0.2),
		"requirements": {
			"relic_ids": ["golden_idol", "merchants_coin"]
		},
		"bonuses": {
			"gold_bonus": 0.5,
			"gold_heals": 1.0
		}
	}
}

# ============================================
# STATE
# ============================================
var active_synergies: Dictionary = {}  # synergy_id -> synergy_data
var _cached_bonuses: Dictionary = {}   # Flattened bonus cache
var _player_reference: Node2D = null
var _cascade_crit_stacks: int = 0      # For critical cascade synergy

# ============================================
# LIFECYCLE
# ============================================
func _ready():
	# Connect to relevant signals
	if RunManager:
		RunManager.relic_collected.connect(_on_relic_changed)
		RunManager.stats_changed.connect(_on_stats_changed)

	if CombatEventBus:
		CombatEventBus.kill.connect(_on_enemy_killed)
		CombatEventBus.critical_hit.connect(_on_critical_hit)
		CombatEventBus.damage_dealt.connect(_on_damage_dealt)

	# Wait for player
	await get_tree().process_frame
	_player_reference = get_tree().get_first_node_in_group("player")

func _on_relic_changed(_relic: Resource):
	recalculate_synergies()

func _on_stats_changed():
	recalculate_synergies()

# ============================================
# SYNERGY CALCULATION
# ============================================
func recalculate_synergies():
	var old_synergies = active_synergies.keys()
	active_synergies.clear()
	_cached_bonuses.clear()

	# Get current state
	var current_relics = _get_current_relic_ids()
	var current_weapon = _get_current_weapon()
	var current_staff = _get_current_staff()
	var current_stats = RunManager.get_all_stats() if RunManager else {}

	# Check each synergy
	for synergy_id in SYNERGIES:
		var synergy = SYNERGIES[synergy_id]
		if _check_synergy_requirements(synergy, current_relics, current_weapon, current_staff, current_stats):
			active_synergies[synergy_id] = synergy
			_apply_synergy_bonuses(synergy)

			# Emit activation signal for new synergies
			if synergy_id not in old_synergies:
				synergy_activated.emit(synergy_id, synergy.description)

	# Emit deactivation for removed synergies
	for old_id in old_synergies:
		if old_id not in active_synergies:
			synergy_deactivated.emit(old_id)

	synergies_changed.emit()

func _check_synergy_requirements(synergy: Dictionary, relics: Array, weapon: Node2D, staff: Node2D, stats: Dictionary) -> bool:
	var reqs = synergy.requirements

	# Check specific relic IDs
	if reqs.has("relic_ids"):
		for relic_id in reqs.relic_ids:
			if relic_id not in relics:
				return false

	# Check relic count (any relics)
	if reqs.has("relic_count"):
		if relics.size() < reqs.relic_count:
			return false

	# Check weapon type (damage type)
	if reqs.has("weapon_type"):
		var has_type = false
		if weapon and weapon.get("damage_type") != null:
			has_type = _damage_type_matches(weapon.damage_type, reqs.weapon_type)
		if staff and staff.get("damage_type") != null:
			has_type = has_type or _damage_type_matches(staff.damage_type, reqs.weapon_type)
		if not has_type:
			return false

	# Check weapon category
	if reqs.has("weapon_category"):
		if reqs.weapon_category == "melee" and not weapon:
			return false
		if reqs.weapon_category == "magic" and not staff:
			return false

	# Check weapon names
	if reqs.has("weapon_names"):
		var has_weapon = false
		var weapon_name: String = ""
		var staff_name: String = ""
		if weapon:
			weapon_name = weapon.name
		if staff:
			staff_name = staff.name
		for wname in reqs.weapon_names:
			if weapon_name == wname or staff_name == wname:
				has_weapon = true
				break
		if not has_weapon:
			return false

	# Check minimum crit chance
	if reqs.has("min_crit_chance"):
		if stats.get("crit_chance", 0.0) < reqs.min_crit_chance:
			return false

	# Check minimum damage reduction
	if reqs.has("min_damage_reduction"):
		if stats.get("damage_reduction", 0.0) < reqs.min_damage_reduction:
			return false

	# Check dash requirement
	if reqs.has("has_dash") and reqs.has_dash:
		if not _player_reference or not _player_reference.get("dash_cooldown"):
			return false

	return true

func _damage_type_matches(damage_type: int, type_name: String) -> bool:
	match type_name:
		"fire": return damage_type == DamageTypes.Type.FIRE
		"ice": return damage_type == DamageTypes.Type.ICE
		"electric": return damage_type == DamageTypes.Type.ELECTRIC
		"bleed": return damage_type == DamageTypes.Type.BLEED
		"physical": return damage_type == DamageTypes.Type.PHYSICAL
	return false

func _apply_synergy_bonuses(synergy: Dictionary):
	var bonuses = synergy.bonuses
	for key in bonuses:
		_cached_bonuses[key] = bonuses[key]

# ============================================
# BONUS GETTERS
# ============================================
func get_bonus(bonus_name: String, default_value = null):
	return _cached_bonuses.get(bonus_name, default_value)

func has_bonus(bonus_name: String) -> bool:
	return bonus_name in _cached_bonuses

func get_active_synergies() -> Array:
	return active_synergies.keys()

func get_synergy_info(synergy_id: String) -> Dictionary:
	if synergy_id in active_synergies:
		return active_synergies[synergy_id]
	return {}

func get_all_active_synergy_info() -> Array:
	var result = []
	for synergy_id in active_synergies:
		var info = active_synergies[synergy_id].duplicate()
		info["id"] = synergy_id
		result.append(info)
	return result

func get_synergy_count() -> int:
	return active_synergies.size()

# ============================================
# SYNERGY EFFECT HANDLERS
# ============================================
func _on_enemy_killed(event: CombatEventBus.KillEvent):
	if not event.killer or not event.killer.is_in_group("player"):
		return

	# Flash Step - Dash reset on kill
	if has_bonus("dash_reset_on_kill"):
		if _player_reference and _player_reference.get("dash_cooldown_timer") != null:
			_player_reference.dash_cooldown_timer = 0.0

	# Spreading Flames - Burn spread on kill
	if has_bonus("burn_spread_on_kill") and event.victim:
		if event.victim.has_method("has_status_effect"):
			if event.victim.has_status_effect(StatusEffectManager.EffectType.BURN):
				_spread_burn_to_nearby(event.victim.global_position)

	# Shatter - Ice shards on frozen kill
	if has_bonus("shatter_on_frozen_kill") and event.victim:
		if event.victim.has_method("has_status_effect"):
			if event.victim.has_status_effect(StatusEffectManager.EffectType.CHILL):
				_create_ice_shards(event.victim.global_position)

	# Soul Harvest - Minion kill heal
	if has_bonus("minion_kill_heal"):
		if event.killer.is_in_group("player_minions"):
			var heal_amount = get_bonus("minion_kill_heal", 0.0)
			if _player_reference and _player_reference.has_method("heal"):
				_player_reference.heal(heal_amount)

	# Bloody Harvest - Kill heal percent
	if has_bonus("kill_heal_percent"):
		var heal_percent = get_bonus("kill_heal_percent", 0.0)
		if _player_reference and _player_reference.has_method("heal"):
			var max_hp = _player_reference.stats.max_health if _player_reference.stats else 100.0
			_player_reference.heal(max_hp * heal_percent)

func _on_critical_hit(event: CombatEventBus.DamageEvent):
	# Critical Cascade - Stack crit bonus
	if has_bonus("cascade_crit"):
		var max_stacks = get_bonus("max_cascade_stacks", 10)
		_cascade_crit_stacks = min(_cascade_crit_stacks + 1, max_stacks)

	# Overcharge - Lightning explosion on crit
	if has_bonus("crit_lightning_explosion") and event.target:
		_create_lightning_explosion(event.target.global_position)

func _on_damage_dealt(event: CombatEventBus.DamageEvent):
	# Reset cascade on non-crit
	if has_bonus("cascade_crit") and not event.is_crit:
		_cascade_crit_stacks = 0

	# Berserker - Attack heal when low health
	if has_bonus("attack_heal") and _player_reference:
		var threshold = get_bonus("low_health_threshold", 0.3)
		if _player_reference.stats and _player_reference.stats.get_health_percentage() < threshold:
			var heal = get_bonus("attack_heal", 0.0)
			_player_reference.heal(heal)

# ============================================
# SYNERGY EFFECTS
# ============================================
func _spread_burn_to_nearby(origin: Vector2):
	var radius = get_bonus("spread_radius", 150.0)
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(origin) <= radius:
			if enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect(StatusEffectManager.EffectType.BURN, _player_reference)

func _create_ice_shards(origin: Vector2):
	var shard_count = get_bonus("shard_count", 5)
	var shard_damage = get_bonus("shard_damage", 15.0)

	for i in range(shard_count):
		var angle = (TAU / shard_count) * i
		var direction = Vector2.from_angle(angle)
		_spawn_ice_shard(origin, direction, shard_damage)

func _spawn_ice_shard(origin: Vector2, direction: Vector2, damage: float):
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return

	var shard = ColorRect.new()
	shard.size = Vector2(12, 12)
	shard.color = Color(0.6, 0.9, 1.0, 0.9)
	shard.pivot_offset = shard.size / 2
	tree.current_scene.add_child(shard)
	shard.global_position = origin

	var target_pos = origin + direction * 150.0
	var tween = TweenHelper.new_tween()
	tween.tween_property(shard, "global_position", target_pos, 0.3)
	tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.3)
	tween.tween_callback(shard.queue_free)

	_check_shard_hits(origin, direction, damage)

func _check_shard_hits(origin: Vector2, direction: Vector2, damage: float):
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var to_enemy = enemy.global_position - origin
		var dot = to_enemy.dot(direction)
		if dot > 0 and dot < 150.0:
			var perp = to_enemy - direction * dot
			if perp.length() < 30.0:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, origin, 100.0, 0.1, _player_reference, DamageTypes.Type.ICE)

func _create_lightning_explosion(origin: Vector2):
	var radius = get_bonus("explosion_radius", 100.0)
	var damage = get_bonus("explosion_damage", 25.0)

	# Simple visual effect (lightning flash)
	var tree = get_tree()
	if tree and tree.current_scene:
		var flash = ColorRect.new()
		flash.size = Vector2(radius * 2, radius * 2)
		flash.color = Color(0.8, 0.9, 1.0, 0.6)
		flash.pivot_offset = flash.size / 2
		tree.current_scene.add_child(flash)
		flash.global_position = origin - flash.size / 2

		var tween = TweenHelper.new_tween()
		tween.tween_property(flash, "scale", Vector2(1.5, 1.5), 0.2)
		tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.2)
		tween.tween_callback(flash.queue_free)

	# Damage nearby enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(origin) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, origin, 150.0, 0.1, _player_reference, DamageTypes.Type.ELECTRIC)

# ============================================
# STAT MODIFIERS
# ============================================
func get_damage_multiplier(base_multiplier: float, target: Node2D = null) -> float:
	var mult = base_multiplier

	# Berserker - Low health bonus
	if has_bonus("low_health_damage_bonus") and _player_reference:
		var threshold = get_bonus("low_health_threshold", 0.3)
		if _player_reference.stats and _player_reference.stats.get_health_percentage() < threshold:
			mult *= 1.0 + get_bonus("low_health_damage_bonus", 0.0)

	# Executioner - Execute bonus
	if has_bonus("execute_threshold") and target:
		if target.get("current_health") != null and target.get("max_health") != null:
			var health_percent = target.current_health / target.max_health
			if health_percent < get_bonus("execute_threshold", 0.25):
				mult *= get_bonus("execute_crit_multiplier", 2.0)

	# Frozen damage bonus
	if has_bonus("frozen_damage_bonus") and target:
		if target.has_method("has_status_effect"):
			if target.has_status_effect(StatusEffectManager.EffectType.CHILL):
				mult *= 1.0 + get_bonus("frozen_damage_bonus", 0.0)

	# Flash Step - Dash attack bonus
	if has_bonus("dash_attack_bonus") and _player_reference:
		if _player_reference.get("is_dashing") and _player_reference.is_dashing:
			mult *= 1.0 + get_bonus("dash_attack_bonus", 0.0)

	# Mark damage bonus
	if has_bonus("mark_damage_bonus") and target:
		if target.get("is_marked"):
			mult *= 1.0 + get_bonus("mark_damage_bonus", 0.0)

	# Magic damage bonus
	if has_bonus("magic_damage_bonus"):
		mult *= 1.0 + get_bonus("magic_damage_bonus", 0.0)

	return mult

func get_crit_chance_bonus() -> float:
	var bonus = 0.0

	# Critical Cascade
	if has_bonus("cascade_crit"):
		bonus += _cascade_crit_stacks * get_bonus("cascade_bonus", 0.05)

	# Duelist
	if has_bonus("crit_chance_bonus"):
		bonus += get_bonus("crit_chance_bonus", 0.0)

	return bonus

func get_burn_damage_multiplier() -> float:
	if has_bonus("burn_damage_multiplier"):
		return get_bonus("burn_damage_multiplier", 1.0)
	return 1.0

func get_chill_slow_bonus() -> float:
	if has_bonus("chill_slow_bonus"):
		return get_bonus("chill_slow_bonus", 0.0)
	return 0.0

func get_chain_count_bonus() -> int:
	if has_bonus("chain_count_bonus"):
		return get_bonus("chain_count_bonus", 0)
	return 0

func get_minion_damage_multiplier() -> float:
	if has_bonus("minion_damage_bonus"):
		return 1.0 + get_bonus("minion_damage_bonus", 0.0)
	return 1.0

func get_minion_health_multiplier() -> float:
	if has_bonus("minion_health_bonus"):
		return 1.0 + get_bonus("minion_health_bonus", 0.0)
	return 1.0

func get_attack_damage_reduction() -> float:
	if has_bonus("attack_damage_reduction"):
		return get_bonus("attack_damage_reduction", 0.0)
	return 0.0

# ============================================
# HELPERS
# ============================================
func _get_current_relic_ids() -> Array:
	if not RunManager:
		return []
	var relics = RunManager.get_collected_relics()
	var ids = []
	for relic in relics:
		if relic and "id" in relic:
			ids.append(relic.id)
	return ids

func _get_current_weapon() -> Node2D:
	if _player_reference and _player_reference.get("current_weapon"):
		return _player_reference.current_weapon
	return null

func _get_current_staff() -> Node2D:
	if _player_reference and _player_reference.get("current_staff"):
		return _player_reference.current_staff
	return null
