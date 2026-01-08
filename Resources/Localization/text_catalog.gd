# ============================================
# TEXT CATALOG - Chaos Game
# ============================================
# Bu dosya oyundaki tüm textleri kategorize eder.
# Lokalizasyon ve UI tema sistemi için kullanılır.
#
# KULLANIM:
# 1. Yeni dil eklemek için: Her kategorideki "tr" anahtarını kopyalayıp
#    yeni dil kodu ile (örn: "de", "fr", "es") değiştirin
# 2. Texture/tema değiştirmek için: İlgili kategorinin style bilgilerini kullanın
# ============================================

class_name TextCatalog
extends RefCounted

# ============================================
# CATEGORY 1: MENU_TITLES
# Ana menü başlıkları - Büyük, dikkat çekici fontlar
# Style: Bold, Large (32-48px), Center aligned
# ============================================
const MENU_TITLES := {
	"main_hub": {
		"en": "THE BASE",
		"tr": "ÜSSÜ"
	},
	"upgrade_menu": {
		"en": "CHOOSE UPGRADE",
		"tr": "GELİŞTİRME SEÇ"
	},
	"upgrade_subtitle": {
		"en": "Select one to continue",
		"tr": "Devam etmek için birini seç"
	},
	"game_over": {
		"en": "RUN COMPLETE",
		"tr": "KOŞU TAMAMLANDI"
	},
	"victory": {
		"en": "VICTORY!",
		"tr": "ZAFER!"
	},
	"paused": {
		"en": "PAUSED",
		"tr": "DURAKLATILDI"
	},
	"weapon_shop": {
		"en": "WEAPON SHOP",
		"tr": "SİLAH DÜKANI"
	},
	"training_grounds": {
		"en": "TRAINING GROUNDS",
		"tr": "EĞİTİM ALANI"
	},
	"relic_shrine": {
		"en": "RELIC SHRINE",
		"tr": "KALİNTI SUNAGI"
	},
	"bestiary": {
		"en": "BESTIARY",
		"tr": "YARATIK ANSİKLOPEDİSİ"
	},
	"statistics": {
		"en": "STATISTICS",
		"tr": "İSTATİSTİKLER"
	},
	"debug_menu": {
		"en": "DEBUG MENU",
		"tr": "HATA AYIKLAMA MENÜSÜ"
	}
}

# ============================================
# CATEGORY 2: MENU_BUTTONS
# Menü butonları - Orta boy, tıklanabilir
# Style: Medium (16-24px), Centered, Hover efektli
# ============================================
const MENU_BUTTONS := {
	"resume": {
		"en": "RESUME",
		"tr": "DEVAM ET"
	},
	"restart": {
		"en": "RESTART",
		"tr": "YENİDEN BAŞLA"
	},
	"quit": {
		"en": "QUIT",
		"tr": "ÇIKIŞ"
	},
	"select": {
		"en": "SELECT",
		"tr": "SEÇ"
	},
	"skip": {
		"en": "Skip",
		"tr": "Atla"
	},
	"close": {
		"en": "Close",
		"tr": "Kapat"
	},
	"return_to_base": {
		"en": "RETURN TO BASE",
		"tr": "ÜSSE DÖN"
	},
	"enter_arena": {
		"en": "⚔️  ENTER ARENA  ⚔️",
		"tr": "⚔️  ARENAYA GİR  ⚔️"
	},
	"reset_training": {
		"en": "Reset Training & Refund Gold",
		"tr": "Eğitimi Sıfırla & Altını İade Al"
	},
	"max_level": {
		"en": "MAX",
		"tr": "MAKS"
	}
}

# ============================================
# CATEGORY 3: HUD_LABELS
# HUD üzerindeki sabit etiketler
# Style: Small (12-16px), Compact, Daima görünür
# ============================================
const HUD_LABELS := {
	"health": {
		"en": "HP",
		"tr": "CAN"
	},
	"gold": {
		"en": "Gold",
		"tr": "Altın"
	},
	"wave": {
		"en": "WAVE",
		"tr": "DALGA"
	},
	"enemies": {
		"en": "Enemies",
		"tr": "Düşmanlar"
	},
	"relics": {
		"en": "Relics:",
		"tr": "Kalıntılar:"
	},
	"active_synergies": {
		"en": "Active Synergies:",
		"tr": "Aktif Sinerjiler:"
	},
	"stats": {
		"en": "STATS",
		"tr": "İSTATİSTİKLER"
	},
	"weapon": {
		"en": "Weapon",
		"tr": "Silah"
	},
	"staff": {
		"en": "Staff",
		"tr": "Asa"
	}
}

# ============================================
# CATEGORY 4: HUD_STATS
# HUD istatistik kısaltmaları
# Style: Very small (10-12px), Monospace, Compact
# ============================================
const HUD_STATS := {
	"spd": {
		"en": "SPD",
		"tr": "HIZ"
	},
	"atk": {
		"en": "ATK",
		"tr": "SLD"
	},
	"mag": {
		"en": "MAG",
		"tr": "SİH"
	},
	"aspd": {
		"en": "ASPD",
		"tr": "SHIZ"
	},
	"crit": {
		"en": "CRIT",
		"tr": "KRİT"
	},
	"steal": {
		"en": "STEAL",
		"tr": "ÇALMA"
	}
}

# ============================================
# CATEGORY 5: GAME_MESSAGES
# Oyun içi dinamik mesajlar - Ekranda beliren
# Style: Large (24-48px), Animated, Fade in/out
# ============================================
const GAME_MESSAGES := {
	"wave_complete": {
		"en": "WAVE %d COMPLETE!",
		"tr": "DALGA %d TAMAMLANDI!"
	},
	"portal_spawning": {
		"en": "Portal spawning...",
		"tr": "Portal açılıyor..."
	},
	"bloodlust": {
		"en": "BLOODLUST!",
		"tr": "KAN HIRSI!"
	},
	"bloodlust_bonus": {
		"en": "+%d%% DAMAGE  +%d%% GOLD",
		"tr": "+%d%% HASAR  +%d%% ALTIN"
	},
	"boss_incoming": {
		"en": "FINAL WAVE\nBOSS INCOMING!",
		"tr": "SON DALGA\nPATRON GELİYOR!"
	},
	"wave_start": {
		"en": "WAVE %d",
		"tr": "DALGA %d"
	},
	"achievement": {
		"en": "Achievement: %s",
		"tr": "Başarım: %s"
	},
	"crit": {
		"en": "CRIT!",
		"tr": "KRİTİK!"
	},
	"heal_amount": {
		"en": "+%d HP",
		"tr": "+%d CAN"
	}
}

# ============================================
# CATEGORY 6: GAME_OVER_LABELS
# Oyun sonu ekranı etiketleri
# Style: Medium (16-20px), Left-aligned stats
# ============================================
const GAME_OVER_LABELS := {
	"wave_reached": {
		"en": "Wave Reached:",
		"tr": "Ulaşılan Dalga:"
	},
	"enemies_slain": {
		"en": "Enemies Slain:",
		"tr": "Öldürülen Düşmanlar:"
	},
	"final_score": {
		"en": "Final Score:",
		"tr": "Final Skor:"
	},
	"gold_earned": {
		"en": "GOLD EARNED",
		"tr": "KAZANILAN ALTIN"
	},
	"unspent_gold": {
		"en": "Unspent Gold:",
		"tr": "Harcanmamış Altın:"
	},
	"wave_bonus": {
		"en": "Wave Bonus (x5):",
		"tr": "Dalga Bonusu (x5):"
	},
	"total": {
		"en": "Total:",
		"tr": "Toplam:"
	},
	"tip_prefix": {
		"en": "Tip:",
		"tr": "İpucu:"
	}
}

# ============================================
# CATEGORY 7: TIPS
# Oyun ipuçları - Game over ekranında gösterilen
# Style: Italic, Small (14px), Subtle color
# ============================================
const TIPS := {
	"keep_moving": {
		"en": "Keep moving!",
		"tr": "Hareket etmeye devam et!"
	},
	"use_dash": {
		"en": "Use dash to avoid damage!",
		"tr": "Hasardan kaçınmak için dash kullan!"
	},
	"combo_finisher": {
		"en": "Combo finishers deal extra damage!",
		"tr": "Kombo finişleri ekstra hasar verir!"
	},
	"collect_crystals": {
		"en": "Collect crystals for upgrades!",
		"tr": "Geliştirmeler için kristal topla!"
	}
}

# ============================================
# CATEGORY 8: BASE_HUB_TEXTS
# Ana üs (hub) ekranı metinleri
# Style: Varied - descriptions are smaller
# ============================================
const BASE_HUB_TEXTS := {
	"welcome": {
		"en": "Welcome, Warrior!",
		"tr": "Hoş geldin, Savaşçı!"
	},
	"stats_format": {
		"en": "Highest Wave: %d  |  Total Runs: %d  |  Total Kills: %d",
		"tr": "En Yüksek Dalga: %d  |  Toplam Koşu: %d  |  Toplam Öldürme: %d"
	},
	"starting_stats": {
		"en": "Your Starting Stats:",
		"tr": "Başlangıç İstatistiklerin:"
	},
	"detailed_stats": {
		"en": "❤️ %d HP  |  ⚔️ +%d%% Dmg  |  👟 +%d%% Spd  |  💰 %d Gold",
		"tr": "❤️ %d CAN  |  ⚔️ +%d%% Hasar  |  👟 +%d%% Hız  |  💰 %d Altın"
	},
	"hub_tip": {
		"en": "\nUse the tabs above to train stats, unlock relics, or view your bestiary!",
		"tr": "\nYukarıdaki sekmelerden istatistik eğit, kalıntı aç veya yaratık ansiklopedisini gör!"
	},
	"training_desc": {
		"en": "Spend gold to permanently increase your starting stats",
		"tr": "Başlangıç istatistiklerini kalıcı olarak artırmak için altın harca"
	},
	"relic_desc": {
		"en": "Unlock relics to find them during your runs",
		"tr": "Koşularında bulmak için kalıntıları aç"
	},
	"bestiary_desc": {
		"en": "Enemies you have slain",
		"tr": "Öldürdüğün düşmanlar"
	},
	"empty_bestiary": {
		"en": "\n\nNo enemies slain yet.\n\nEnter the arena to fill your bestiary!",
		"tr": "\n\nHenüz düşman öldürülmedi.\n\nAnsiklopediyi doldurmak için arenaya gir!"
	},
	"total_kills": {
		"en": "Total Kills: %d",
		"tr": "Toplam Öldürmeler: %d"
	},
	"per_level": {
		"en": "(%s per level)",
		"tr": "(seviye başına %s)"
	},
	"level_format": {
		"en": "Lv. %d/5",
		"tr": "Sv. %d/5"
	},
	"unlocked": {
		"en": "✓ UNLOCKED",
		"tr": "✓ AÇILDI"
	},
	"free": {
		"en": "✓ FREE",
		"tr": "✓ ÜCRETSİZ"
	},
	"unlock_cost": {
		"en": "Unlock: %d 💰",
		"tr": "Aç: %d 💰"
	}
}

# ============================================
# CATEGORY 9: HEALER_TEXTS
# İyileştirici NPC metinleri
# Style: Medium, Soft colors (green/white)
# ============================================
const HEALER_TEXTS := {
	"title": {
		"en": "⚕ HEALER",
		"tr": "⚕ İYİLEŞTİRİCİ"
	},
	"hp_unknown": {
		"en": "HP: ???",
		"tr": "CAN: ???"
	},
	"hp_format": {
		"en": "HP: %d / %d",
		"tr": "CAN: %d / %d"
	},
	"free_heal": {
		"en": "Free Heal (30%)",
		"tr": "Ücretsiz İyileştirme (30%)"
	},
	"free_heal_used": {
		"en": "Free Heal (Used)",
		"tr": "Ücretsiz İyileştirme (Kullanıldı)"
	},
	"free_heal_full": {
		"en": "Free Heal (Full HP)",
		"tr": "Ücretsiz İyileştirme (Tam CAN)"
	},
	"full_heal": {
		"en": "Full Heal (%d Gold)",
		"tr": "Tam İyileştirme (%d Altın)"
	},
	"full_heal_full_hp": {
		"en": "Full Heal (Full HP)",
		"tr": "Tam İyileştirme (Tam CAN)"
	},
	"full_heal_need": {
		"en": "Full Heal - Need %d",
		"tr": "Tam İyileştirme - %d Gerekli"
	}
}

# ============================================
# CATEGORY 10: WEAPON_NAMES
# Silah isimleri
# Style: Bold, Medium (16-20px), Colored by rarity
# ============================================
const WEAPON_NAMES := {
	# Melee Weapons
	"basic_sword": {
		"en": "Basic Sword",
		"tr": "Temel Kılıç"
	},
	"katana": {
		"en": "Katana",
		"tr": "Katana"
	},
	"spear": {
		"en": "Spear",
		"tr": "Mızrak"
	},
	"dagger": {
		"en": "Dagger",
		"tr": "Hançer"
	},
	"rapier": {
		"en": "Rapier",
		"tr": "Meç"
	},
	"warhammer": {
		"en": "Warhammer",
		"tr": "Savaş Çekici"
	},
	"scythe": {
		"en": "Scythe",
		"tr": "Tırpan"
	},
	"executioners_axe": {
		"en": "Executioner's Axe",
		"tr": "Cellat Baltası"
	},
	# Magic Weapons
	"basic_staff": {
		"en": "Basic Staff",
		"tr": "Temel Asa"
	},
	"inferno_staff": {
		"en": "Inferno Staff",
		"tr": "Cehennem Asası"
	},
	"frost_staff": {
		"en": "Frost Staff",
		"tr": "Buz Asası"
	},
	"lightning_staff": {
		"en": "Lightning Staff",
		"tr": "Yıldırım Asası"
	},
	"void_staff": {
		"en": "Void Staff",
		"tr": "Boşluk Asası"
	},
	"necro_staff": {
		"en": "Necro Staff",
		"tr": "Ölüm Asası"
	},
	"earth_staff": {
		"en": "Earth Staff",
		"tr": "Toprak Asası"
	},
	"holy_staff": {
		"en": "Holy Staff",
		"tr": "Kutsal Asa"
	}
}

# ============================================
# CATEGORY 11: WEAPON_DESCRIPTIONS
# Silah açıklamaları - Mağazada gösterilen
# Style: Small (12-14px), Italic, Gray
# ============================================
const WEAPON_DESCRIPTIONS := {
	"katana": {
		"en": "Fast attacks + Dash Slash skill (Q)",
		"tr": "Hızlı saldırılar + Dash Slash yeteneği (Q)"
	},
	"spear": {
		"en": "Long range thrust attacks",
		"tr": "Uzun menzilli bıçaklama saldırıları"
	},
	"dagger": {
		"en": "Very fast, can attack while moving",
		"tr": "Çok hızlı, hareket ederken saldırabilir"
	},
	"rapier": {
		"en": "Precise strikes, bonus crit chance",
		"tr": "Hassas vuruşlar, bonus kritik şansı"
	},
	"warhammer": {
		"en": "Slow but powerful, stuns enemies",
		"tr": "Yavaş ama güçlü, düşmanları sersemletir"
	},
	"scythe": {
		"en": "Wide sweeping attacks, Death Spiral skill",
		"tr": "Geniş süpürme saldırıları, Ölüm Spirali yeteneği"
	},
	"executioners_axe": {
		"en": "Execute low HP enemies instantly",
		"tr": "Düşük CAN'lı düşmanları anında öldür"
	},
	"inferno_staff": {
		"en": "Fire projectiles, burn damage over time",
		"tr": "Ateş mermileri, zamanla yanma hasarı"
	},
	"frost_staff": {
		"en": "Ice projectiles, slow and freeze enemies",
		"tr": "Buz mermileri, düşmanları yavaşlatır ve dondurur"
	},
	"lightning_staff": {
		"en": "Chain lightning jumps between enemies",
		"tr": "Zincir yıldırım düşmanlar arasında zıplar"
	},
	"void_staff": {
		"en": "Creates black holes that pull enemies",
		"tr": "Düşmanları çeken kara delikler oluşturur"
	},
	"necro_staff": {
		"en": "Convert killed enemies into minions",
		"tr": "Öldürülen düşmanları minyonlara dönüştür"
	},
	"earth_staff": {
		"en": "Rock projectiles, defensive abilities",
		"tr": "Kaya mermileri, savunma yetenekleri"
	},
	"holy_staff": {
		"en": "Healing and buff abilities",
		"tr": "İyileştirme ve güçlendirme yetenekleri"
	}
}

# ============================================
# CATEGORY 12: WEAPON_SHOP_FORMATS
# Silah mağazası format stringleri
# Style: Button text formatting
# ============================================
const WEAPON_SHOP_FORMATS := {
	"buy_available": {
		"en": "%s (%d Gold)",
		"tr": "%s (%d Altın)"
	},
	"buy_need": {
		"en": "%s - Need %d",
		"tr": "%s - %d Gerekli"
	},
	"crystals_format": {
		"en": "Chaos Crystals: %d",
		"tr": "Kaos Kristalleri: %d"
	},
	"buy_crystal": {
		"en": "Buy %s (%d Crystals)",
		"tr": "%s Satın Al (%d Kristal)"
	},
	"not_enough_crystals": {
		"en": "Not Enough Crystals (%d/%d)",
		"tr": "Yeterli Kristal Yok (%d/%d)"
	}
}

# ============================================
# CATEGORY 13: ENEMY_NAMES
# Düşman isimleri - Bestiary'de gösterilen
# Style: Medium (14-16px), Colored by type
# ============================================
const ENEMY_NAMES := {
	"goblin_dual": {
		"en": "Goblin Warrior",
		"tr": "Goblin Savaşçı"
	},
	"slime": {
		"en": "Slime",
		"tr": "Balçık"
	},
	"goblin_archer": {
		"en": "Goblin Archer",
		"tr": "Goblin Okçu"
	},
	"healer": {
		"en": "Healer",
		"tr": "İyileştirici"
	},
	"spawner": {
		"en": "Spawner",
		"tr": "Üretici"
	},
	"boss": {
		"en": "Boss",
		"tr": "Patron"
	}
}

# ============================================
# CATEGORY 14: ENEMY_COUNTER_FORMATS
# Düşman sayacı formatları
# Style: Small, HUD integrated
# ============================================
const ENEMY_COUNTER := {
	"clear": {
		"en": "Clear!",
		"tr": "Temiz!"
	},
	"one_enemy": {
		"en": "1 enemy",
		"tr": "1 düşman"
	},
	"multiple_enemies": {
		"en": "%d enemies",
		"tr": "%d düşman"
	},
	"waiting": {
		"en": "Waiting...",
		"tr": "Bekleniyor..."
	}
}

# ============================================
# CATEGORY 15: RELIC_NAMES
# Relic isimleri
# Style: Bold, Colored by rarity
# ============================================
const RELIC_NAMES := {
	"arcane_focus": {
		"en": "Arcane Focus",
		"tr": "Arkan Odak"
	},
	"bloodthirst": {
		"en": "Bloodthirst",
		"tr": "Kan Susuzluğu"
	},
	"blood_rage": {
		"en": "Blood Rage",
		"tr": "Kan Öfkesi"
	},
	"burning_heart": {
		"en": "Burning Heart",
		"tr": "Yanan Kalp"
	},
	"chipped_fang": {
		"en": "Chipped Fang",
		"tr": "Kırık Diş"
	},
	"clockwork_gear": {
		"en": "Clockwork Gear",
		"tr": "Saat Dişlisi"
	},
	"cracked_knuckle": {
		"en": "Cracked Knuckle",
		"tr": "Çatlak Yumruk"
	},
	"crystal_shard": {
		"en": "Crystal Shard",
		"tr": "Kristal Parçası"
	},
	"cyclone_pendant": {
		"en": "Cyclone Pendant",
		"tr": "Kasırga Kolyesi"
	},
	"death_mark": {
		"en": "Death Mark",
		"tr": "Ölüm İşareti"
	},
	"ember_crown": {
		"en": "Ember Crown",
		"tr": "Kor Tacı"
	},
	"fencing_medal": {
		"en": "Fencing Medal",
		"tr": "Eskrim Madalyası"
	},
	"frozen_heart": {
		"en": "Frozen Heart",
		"tr": "Donmuş Kalp"
	},
	"golden_idol": {
		"en": "Golden Idol",
		"tr": "Altın Put"
	},
	"guardian_angel": {
		"en": "Guardian Angel",
		"tr": "Koruyucu Melek"
	},
	"iron_ring": {
		"en": "Iron Ring",
		"tr": "Demir Yüzük"
	},
	"iron_skin": {
		"en": "Iron Skin",
		"tr": "Demir Deri"
	},
	"merchants_coin": {
		"en": "Merchant's Coin",
		"tr": "Tüccar Sikkesi"
	},
	"parry_charm": {
		"en": "Parry Charm",
		"tr": "Savuşturma Tılsımı"
	},
	"phantom_cloak": {
		"en": "Phantom Cloak",
		"tr": "Hayalet Pelerin"
	},
	"phoenix_feather": {
		"en": "Phoenix Feather",
		"tr": "Anka Tüyü"
	},
	"shield_emblem": {
		"en": "Shield Emblem",
		"tr": "Kalkan Arması"
	},
	"soul_vessel": {
		"en": "Soul Vessel",
		"tr": "Ruh Kabı"
	},
	"storm_conduit": {
		"en": "Storm Conduit",
		"tr": "Fırtına Kanalı"
	},
	"swift_boots": {
		"en": "Swift Boots",
		"tr": "Hızlı Çizmeler"
	},
	"thiefs_anklet": {
		"en": "Thief's Anklet",
		"tr": "Hırsız Halkası"
	},
	"titans_grip": {
		"en": "Titan's Grip",
		"tr": "Titan Tutuşu"
	},
	"trolls_heart": {
		"en": "Troll's Heart",
		"tr": "Trol Kalbi"
	},
	"vampiric_essence": {
		"en": "Vampiric Essence",
		"tr": "Vampirik Öz"
	},
	"vampiric_fang": {
		"en": "Vampiric Fang",
		"tr": "Vampir Dişi"
	},
	"void_shard": {
		"en": "Void Shard",
		"tr": "Boşluk Parçası"
	},
	"vortex_core": {
		"en": "Vortex Core",
		"tr": "Girdap Çekirdeği"
	}
}

# ============================================
# CATEGORY 16: RELIC_DESCRIPTIONS
# Relic efekt açıklamaları
# Style: Small (12px), Effect color coded
# ============================================
const RELIC_DESCRIPTIONS := {
	"arcane_focus": {
		"en": "+15% magic damage, -10% mana cost",
		"tr": "+15% sihir hasarı, -10% mana maliyeti"
	},
	"bloodthirst": {
		"en": "Kills restore 5% max HP",
		"tr": "Öldürmeler maks CAN'ın 5%'ini yeniler"
	},
	"blood_rage": {
		"en": "+20% damage when below 30% HP",
		"tr": "CAN 30% altındayken +20% hasar"
	},
	"burning_heart": {
		"en": "Fire attacks deal +10% damage",
		"tr": "Ateş saldırıları +10% hasar verir"
	},
	"chipped_fang": {
		"en": "+10% Damage",
		"tr": "+10% Hasar"
	},
	"clockwork_gear": {
		"en": "-15% Cooldowns",
		"tr": "-15% Bekleme Süreleri"
	},
	"cracked_knuckle": {
		"en": "+10% Critical Hit Chance",
		"tr": "+10% Kritik Vuruş Şansı"
	},
	"crystal_shard": {
		"en": "Frozen enemies shatter on death",
		"tr": "Donmuş düşmanlar ölümde parçalanır"
	},
	"cyclone_pendant": {
		"en": "Combo finishers hit all nearby enemies",
		"tr": "Kombo finişleri tüm yakın düşmanlara vurur"
	},
	"death_mark": {
		"en": "Marked enemies take +20% damage",
		"tr": "İşaretli düşmanlar +20% hasar alır"
	},
	"ember_crown": {
		"en": "Burn spreads to nearby enemies on kill",
		"tr": "Yanma öldürmede yakın düşmanlara yayılır"
	},
	"fencing_medal": {
		"en": "+10% Crit Chance with Rapier",
		"tr": "Meç ile +10% Kritik Şansı"
	},
	"frozen_heart": {
		"en": "Chill effects are 30% stronger",
		"tr": "Soğutma efektleri 30% daha güçlü"
	},
	"golden_idol": {
		"en": "+25% gold drops",
		"tr": "+25% altın düşüşü"
	},
	"guardian_angel": {
		"en": "Prevents one fatal blow per wave",
		"tr": "Dalga başına bir ölümcül darbeyi engeller"
	},
	"iron_ring": {
		"en": "+15 Max Health",
		"tr": "+15 Maks Can"
	},
	"iron_skin": {
		"en": "+15% damage reduction",
		"tr": "+15% hasar azaltma"
	},
	"merchants_coin": {
		"en": "+25% gold, gold pickups heal 1 HP",
		"tr": "+25% altın, altın toplamak 1 CAN iyileştirir"
	},
	"parry_charm": {
		"en": "Perfect dodge triggers counter attack",
		"tr": "Mükemmel kaçış karşı saldırı tetikler"
	},
	"phantom_cloak": {
		"en": "Dash resets on kill, dash attacks +30% damage",
		"tr": "Öldürmede dash sıfırlanır, dash saldırıları +30% hasar"
	},
	"phoenix_feather": {
		"en": "Revive once per run with 50% HP",
		"tr": "Koşu başına bir kez 50% CAN ile diril"
	},
	"shield_emblem": {
		"en": "+15% damage reduction while attacking",
		"tr": "Saldırırken +15% hasar azaltma"
	},
	"soul_vessel": {
		"en": "Minions gain +30% damage and HP",
		"tr": "Minyonlar +30% hasar ve CAN kazanır"
	},
	"storm_conduit": {
		"en": "Shock chains to +2 additional enemies",
		"tr": "Şok +2 ek düşmana zincirler"
	},
	"swift_boots": {
		"en": "+15% Movement Speed",
		"tr": "+15% Hareket Hızı"
	},
	"thiefs_anklet": {
		"en": "+8% Movement Speed",
		"tr": "+8% Hareket Hızı"
	},
	"titans_grip": {
		"en": "Heavy attacks stun 0.5s longer",
		"tr": "Ağır saldırılar 0.5sn daha uzun sersemletir"
	},
	"trolls_heart": {
		"en": "+20 Max Health",
		"tr": "+20 Maks Can"
	},
	"vampiric_essence": {
		"en": "Minion kills heal player for 3 HP",
		"tr": "Minyon öldürmeleri oyuncuyu 3 CAN iyileştirir"
	},
	"vampiric_fang": {
		"en": "3% Lifesteal",
		"tr": "3% Yaşam Çalma"
	},
	"void_shard": {
		"en": "Enemies hit take 15% more damage for 3s",
		"tr": "Vurulan düşmanlar 3sn %15 daha fazla hasar alır"
	},
	"vortex_core": {
		"en": "Spin attacks pull enemies",
		"tr": "Dönerek saldırılar düşmanları çeker"
	}
}

# ============================================
# CATEGORY 17: RELIC_FLAVOR_TEXTS
# Relic lore/flavor metinleri
# Style: Italic, Small, Muted color
# ============================================
const RELIC_FLAVOR_TEXTS := {
	"arcane_focus": {
		"en": "Channel pure magic.",
		"tr": "Saf sihri yönlendir."
	},
	"bloodthirst": {
		"en": "The hunger never ends.",
		"tr": "Açlık asla bitmez."
	},
	"blood_rage": {
		"en": "Fury fuels the blade.",
		"tr": "Öfke kılıcı besler."
	},
	"burning_heart": {
		"en": "It never stops burning.",
		"tr": "Asla yanmayı bırakmaz."
	},
	"chipped_fang": {
		"en": "Torn from a beast that bit back.",
		"tr": "Karşılık veren bir canavardan koparıldı."
	},
	"clockwork_gear": {
		"en": "Tick tock, reload.",
		"tr": "Tik tak, yeniden doldur."
	},
	"cracked_knuckle": {
		"en": "From a statue of a forgotten champion.",
		"tr": "Unutulmuş bir şampiyonun heykelinden."
	},
	"crystal_shard": {
		"en": "Shatter your enemies.",
		"tr": "Düşmanlarını paramparça et."
	},
	"cyclone_pendant": {
		"en": "Unleash the storm.",
		"tr": "Fırtınayı serbest bırak."
	},
	"death_mark": {
		"en": "They are already dead.",
		"tr": "Zaten ölüler."
	},
	"ember_crown": {
		"en": "Rule through fire.",
		"tr": "Ateşle hükmet."
	},
	"fencing_medal": {
		"en": "First place in the tournament.",
		"tr": "Turnuvada birincilik."
	},
	"frozen_heart": {
		"en": "Cold as death itself.",
		"tr": "Ölümün kendisi kadar soğuk."
	},
	"golden_idol": {
		"en": "Greed is good.",
		"tr": "Açgözlülük iyidir."
	},
	"guardian_angel": {
		"en": "You are protected.",
		"tr": "Korunuyorsun."
	},
	"iron_ring": {
		"en": "Simple. Effective.",
		"tr": "Basit. Etkili."
	},
	"iron_skin": {
		"en": "Hard as steel.",
		"tr": "Çelik kadar sert."
	},
	"merchants_coin": {
		"en": "Lucky coin.",
		"tr": "Şanslı sikke."
	},
	"parry_charm": {
		"en": "Turn defense into offense.",
		"tr": "Savunmayı saldırıya çevir."
	},
	"phantom_cloak": {
		"en": "Between worlds.",
		"tr": "Dünyalar arasında."
	},
	"phoenix_feather": {
		"en": "From ashes, rise.",
		"tr": "Küllerden yüksel."
	},
	"shield_emblem": {
		"en": "Stand your ground.",
		"tr": "Yerinde dur."
	},
	"soul_vessel": {
		"en": "Collect the souls of the fallen.",
		"tr": "Düşenlerin ruhlarını topla."
	},
	"storm_conduit": {
		"en": "Channel the tempest.",
		"tr": "Fırtınayı yönlendir."
	},
	"swift_boots": {
		"en": "Light as a feather.",
		"tr": "Tüy kadar hafif."
	},
	"thiefs_anklet": {
		"en": "Previous owner didn't run fast enough.",
		"tr": "Önceki sahibi yeterince hızlı koşamadı."
	},
	"titans_grip": {
		"en": "Strength of the ancients.",
		"tr": "Antiklerin gücü."
	},
	"trolls_heart": {
		"en": "Still beating. Barely.",
		"tr": "Hala atıyor. Zar zor."
	},
	"vampiric_essence": {
		"en": "The essence of undeath.",
		"tr": "Ölümsüzlüğün özü."
	},
	"vampiric_fang": {
		"en": "Drink deep.",
		"tr": "Derin iç."
	},
	"void_shard": {
		"en": "Gaze into the abyss.",
		"tr": "Uçuruma bak."
	},
	"vortex_core": {
		"en": "Pull them in.",
		"tr": "Onları içeri çek."
	}
}

# ============================================
# CATEGORY 18: UPGRADE_NAMES
# Upgrade (power-up) isimleri
# Style: Bold, Rarity colored
# ============================================
const UPGRADE_NAMES := {
	"health_boost_small": {
		"en": "Health Boost",
		"tr": "Can Artışı"
	},
	"health_boost_large": {
		"en": "Vitality",
		"tr": "Canlılık"
	},
	"heal_full": {
		"en": "Full Heal",
		"tr": "Tam İyileştirme"
	},
	"melee_damage_small": {
		"en": "Sharp Blade",
		"tr": "Keskin Bıçak"
	},
	"magic_damage_small": {
		"en": "Arcane Power",
		"tr": "Arkan Güç"
	},
	"all_damage": {
		"en": "Chaos Fury",
		"tr": "Kaos Öfkesi"
	},
	"move_speed_small": {
		"en": "Swift Boots",
		"tr": "Hızlı Çizmeler"
	},
	"attack_speed": {
		"en": "Berserker",
		"tr": "Çılgın Savaşçı"
	},
	"extra_projectile": {
		"en": "Multi-Shot",
		"tr": "Çoklu Atış"
	},
	"vampirism": {
		"en": "Vampirism",
		"tr": "Vampirizm"
	},
	"crit_chance_small": {
		"en": "Lucky Strike",
		"tr": "Şanslı Vuruş"
	},
	"crit_chance_large": {
		"en": "Assassin's Eye",
		"tr": "Suikastçının Gözü"
	},
	"crit_damage": {
		"en": "Deadly Precision",
		"tr": "Ölümcül Hassasiyet"
	},
	"hazard_resist_small": {
		"en": "Thick Skin",
		"tr": "Kalın Deri"
	},
	"hazard_resist_large": {
		"en": "Iron Hide",
		"tr": "Demir Post"
	},
	"fire_resist": {
		"en": "Firewalker",
		"tr": "Ateş Yürüyücü"
	},
	"fire_immunity": {
		"en": "Flame Ward",
		"tr": "Alev Koruması"
	},
	"spike_resist": {
		"en": "Spiked Boots",
		"tr": "Dikenli Çizmeler"
	},
	"spike_immunity": {
		"en": "Steel Soles",
		"tr": "Çelik Tabanlar"
	},
	"pit_immunity": {
		"en": "Feather Fall",
		"tr": "Tüy Düşüşü"
	}
}

# ============================================
# CATEGORY 19: UPGRADE_DESCRIPTIONS
# Upgrade efekt açıklamaları
# Style: Small, Gray, Effect details
# ============================================
const UPGRADE_DESCRIPTIONS := {
	"health_boost_small": {
		"en": "+20 Max Health",
		"tr": "+20 Maks Can"
	},
	"health_boost_large": {
		"en": "+50 Max Health",
		"tr": "+50 Maks Can"
	},
	"heal_full": {
		"en": "Restore all health",
		"tr": "Tüm canı yenile"
	},
	"melee_damage_small": {
		"en": "+25% Melee Damage",
		"tr": "+25% Yakın Dövüş Hasarı"
	},
	"magic_damage_small": {
		"en": "+25% Magic Damage",
		"tr": "+25% Sihir Hasarı"
	},
	"all_damage": {
		"en": "+15% All Damage",
		"tr": "+15% Tüm Hasar"
	},
	"move_speed_small": {
		"en": "+20% Move Speed",
		"tr": "+20% Hareket Hızı"
	},
	"attack_speed": {
		"en": "+30% Attack Speed",
		"tr": "+30% Saldırı Hızı"
	},
	"extra_projectile": {
		"en": "+1 Projectile per cast",
		"tr": "Atış başına +1 Mermi"
	},
	"vampirism": {
		"en": "Heal 2 HP per kill",
		"tr": "Öldürme başına 2 CAN iyileştir"
	},
	"crit_chance_small": {
		"en": "+10% Critical Hit Chance",
		"tr": "+10% Kritik Vuruş Şansı"
	},
	"crit_chance_large": {
		"en": "+20% Critical Hit Chance",
		"tr": "+20% Kritik Vuruş Şansı"
	},
	"crit_damage": {
		"en": "+50% Critical Damage",
		"tr": "+50% Kritik Hasar"
	},
	"hazard_resist_small": {
		"en": "Take 25% less damage from hazards",
		"tr": "Tehlikelerden %25 az hasar al"
	},
	"hazard_resist_large": {
		"en": "Take 50% less damage from hazards",
		"tr": "Tehlikelerden %50 az hasar al"
	},
	"fire_resist": {
		"en": "Take 50% less damage from fire",
		"tr": "Ateşten %50 az hasar al"
	},
	"fire_immunity": {
		"en": "Immune to fire damage",
		"tr": "Ateş hasarına bağışık"
	},
	"spike_resist": {
		"en": "Take 50% less damage from spikes",
		"tr": "Dikenlerden %50 az hasar al"
	},
	"spike_immunity": {
		"en": "Immune to spike damage",
		"tr": "Diken hasarına bağışık"
	},
	"pit_immunity": {
		"en": "Survive falling into pits",
		"tr": "Çukurlara düşmekten kurtul"
	}
}

# ============================================
# CATEGORY 20: TRAINING_STATS
# Eğitim sistemi istatistik isimleri
# Style: Medium, Stat icons
# ============================================
const TRAINING_STATS := {
	"vitality": {
		"en": "Vitality",
		"tr": "Canlılık"
	},
	"strength": {
		"en": "Strength",
		"tr": "Güç"
	},
	"agility": {
		"en": "Agility",
		"tr": "Çeviklik"
	},
	"reflexes": {
		"en": "Reflexes",
		"tr": "Refleksler"
	},
	"fortune": {
		"en": "Fortune",
		"tr": "Şans"
	}
}

# ============================================
# CATEGORY 21: TRAINING_BONUSES
# Eğitim bonusu açıklamaları
# Style: Small, Per-level format
# ============================================
const TRAINING_BONUSES := {
	"vitality": {
		"en": "+20 HP per level",
		"tr": "seviye başına +20 CAN"
	},
	"strength": {
		"en": "+5% damage per level",
		"tr": "seviye başına +5% hasar"
	},
	"agility": {
		"en": "+4% speed per level",
		"tr": "seviye başına +4% hız"
	},
	"reflexes": {
		"en": "-5% cooldown per level",
		"tr": "seviye başına -5% bekleme"
	},
	"fortune": {
		"en": "+10 starting gold per level",
		"tr": "seviye başına +10 başlangıç altını"
	}
}

# ============================================
# CATEGORY 22: DEBUG_TEXTS
# Debug menüsü metinleri (sadece development)
# Style: Monospace, Small
# ============================================
const DEBUG_TEXTS := {
	"press_to_close": {
		"en": "Press O to close",
		"tr": "Kapatmak için O'ya bas"
	},
	"gold_section": {
		"en": "GOLD",
		"tr": "ALTIN"
	},
	"actions_section": {
		"en": "ACTIONS",
		"tr": "EYLEMLER"
	},
	"enemy_control": {
		"en": "ENEMY CONTROL",
		"tr": "DÜŞMAN KONTROLÜ"
	},
	"visualization": {
		"en": "VISUALIZATION",
		"tr": "GÖRSELLEŞTİRME"
	},
	"spawn_enemies": {
		"en": "SPAWN ENEMIES",
		"tr": "DÜŞMAN OLUŞTUR"
	},
	"spawn_hazards": {
		"en": "SPAWN HAZARDS",
		"tr": "TEHLİKE OLUŞTUR"
	},
	"drag_instruction": {
		"en": "Click & drag to arena",
		"tr": "Tıkla ve arenaya sürükle"
	},
	"waves_paused": {
		"en": "Waves are PAUSED",
		"tr": "Dalgalar DURAKLATILDI"
	},
	"show_hitboxes": {
		"en": "Show Weapon Hitboxes",
		"tr": "Silah Hitbox'larını Göster"
	},
	"hide_hitboxes": {
		"en": "Hide Weapon Hitboxes",
		"tr": "Silah Hitbox'larını Gizle"
	},
	"freeze_enemies": {
		"en": "Freeze Enemies",
		"tr": "Düşmanları Dondur"
	},
	"unfreeze_enemies": {
		"en": "Unfreeze Enemies",
		"tr": "Düşmanları Çöz"
	}
}

# ============================================
# CATEGORY 23: SKILL_KEYS
# Yetenek tuş göstergeleri
# Style: Key cap style, Small square
# ============================================
const SKILL_KEYS := {
	"sword_skill": {
		"en": "Q",
		"tr": "Q"
	},
	"staff_skill": {
		"en": "E",
		"tr": "E"
	}
}

# ============================================
# CATEGORY 24: ACHIEVEMENT_NAMES
# Başarım isimleri
# Style: Bold, Gold colored
# ============================================
const ACHIEVEMENT_NAMES := {
	"untouchable_wave_1": {
		"en": "Untouchable Wave 1",
		"tr": "Dokunulmaz Dalga 1"
	},
	"slime_slayer": {
		"en": "Slime Slayer",
		"tr": "Balçık Avcısı"
	},
	"gold_hoarder": {
		"en": "Gold Hoarder",
		"tr": "Altın Biriktirici"
	}
}

# ============================================
# HELPER FUNCTIONS
# ============================================

## Mevcut dili döndürür (varsayılan: "en")
static func get_current_language() -> String:
	# TODO: Bu değeri ayarlardan oku
	return "en"

## Verilen kategoriden text döndürür
static func get_text(category: Dictionary, key: String, lang: String = "") -> String:
	if lang.is_empty():
		lang = get_current_language()

	if category.has(key):
		var entry = category[key]
		if entry.has(lang):
			return entry[lang]
		elif entry.has("en"):
			return entry["en"]  # Fallback to English

	return "[MISSING: %s]" % key

## Format string ile text döndürür
static func get_formatted_text(category: Dictionary, key: String, args: Array, lang: String = "") -> String:
	var text = get_text(category, key, lang)
	if args.size() > 0:
		return text % args
	return text
