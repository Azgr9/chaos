# UI Style Guide - Chaos Game

Bu dosya, oyundaki tüm text kategorilerinin stil özelliklerini tanımlar.
İleride tema/texture değiştirmek veya yeni dil eklemek için bu rehberi kullanın.

---

## Kategori Yapısı

Her kategori için:
- **Font Size**: Önerilen font boyutu
- **Font Style**: Bold, Italic, Regular
- **Alignment**: Left, Center, Right
- **Color Scheme**: Kullanılabilecek renkler
- **Background**: Arka plan özellikleri
- **Animation**: Animasyon özellikleri

---

## 📋 KATEGORI 1: MENU_TITLES (Menü Başlıkları)

**Kullanım**: Ana menü ekranlarının başlıkları
**Örnekler**: "THE BASE", "PAUSED", "VICTORY!"

| Özellik | Değer |
|---------|-------|
| Font Size | 32-48px |
| Font Style | **Bold**, UPPERCASE |
| Alignment | Center |
| Color | Gold (#FFD700), White |
| Background | Transparent veya hafif shadow |
| Animation | Fade in, Scale bounce |

**Dosya Lokasyonları**:
- `Scripts/Ui/Base.gd:120`
- `Scripts/Ui/GameOverScreen.gd:222`
- `Scenes/Ui/PauseMenu.tscn:47`

---

## 📋 KATEGORI 2: MENU_BUTTONS (Menü Butonları)

**Kullanım**: Tıklanabilir menü butonları
**Örnekler**: "RESUME", "RESTART", "SELECT"

| Özellik | Değer |
|---------|-------|
| Font Size | 16-24px |
| Font Style | **Bold** |
| Alignment | Center |
| Normal Color | White (#FFFFFF) |
| Hover Color | Gold (#FFD700) |
| Pressed Color | Darker Gold (#CC9900) |
| Disabled Color | Gray (#666666) |
| Background | Dark panel, rounded corners |
| Animation | Hover scale (1.05x), Press shrink |

**Dosya Lokasyonları**:
- `Scenes/Ui/PauseMenu.tscn:53-63`
- `Scenes/Ui/GameOverScreen.tscn:184-190`
- `Scenes/Ui/UpgradeMenu.tscn:97,134,171`

---

## 📋 KATEGORI 3: HUD_LABELS (HUD Etiketleri)

**Kullanım**: Oyun içi sabit bilgi etiketleri
**Örnekler**: "WAVE", "Relics:", "STATS"

| Özellik | Değer |
|---------|-------|
| Font Size | 12-16px |
| Font Style | Regular veya Semi-bold |
| Alignment | Left |
| Color | Light Gray (#CCCCCC) |
| Background | Semi-transparent dark |
| Animation | None (sabit) |

**Dosya Lokasyonları**:
- `Scenes/Ui/HUD.tscn:105,132,157,308`

---

## 📋 KATEGORI 4: HUD_STATS (HUD İstatistik Kısaltmaları)

**Kullanım**: Oyuncu istatistik göstergeleri
**Örnekler**: "SPD", "ATK", "CRIT"

| Özellik | Değer |
|---------|-------|
| Font Size | 10-12px |
| Font Style | **Bold**, UPPERCASE |
| Font Family | Monospace önerilir |
| Alignment | Right (değerler için) |
| Label Color | Muted (#999999) |
| Value Color | White (#FFFFFF) |
| Background | Compact dark box |

**Dosya Lokasyonları**:
- `Scenes/Ui/HUD.tscn:338-507`

---

## 📋 KATEGORI 5: GAME_MESSAGES (Oyun Mesajları)

**Kullanım**: Ekranda beliren dinamik mesajlar
**Örnekler**: "WAVE 3 COMPLETE!", "BLOODLUST!", "CRIT!"

| Özellik | Değer |
|---------|-------|
| Font Size | 24-64px (öneme göre) |
| Font Style | **Bold**, UPPERCASE |
| Alignment | Center |
| Color | Mesaj türüne göre değişir |
| - Wave Complete | Gold (#FFD700) |
| - Bloodlust | Red (#FF3333) |
| - Boss | Dark Red (#CC0000) |
| - Crit | Red (#FF0000) |
| Background | None |
| Animation | Scale in → Hold → Fade out |

**Dosya Lokasyonları**:
- `Scripts/Game/GameManager.gd:349,402`
- `Scripts/Game/WaveManager.gd:264,557`

---

## 📋 KATEGORI 6: GAME_OVER_LABELS (Oyun Sonu Etiketleri)

**Kullanım**: Oyun sonu istatistik etiketleri
**Örnekler**: "Wave Reached:", "Enemies Slain:", "Total:"

| Özellik | Değer |
|---------|-------|
| Font Size | 16-20px |
| Font Style | Regular |
| Alignment | Left (etiket), Right (değer) |
| Label Color | Light Gray (#AAAAAA) |
| Value Color | White (#FFFFFF) |
| Total Color | Gold (#FFD700) |
| Background | Semi-transparent panel |

**Dosya Lokasyonları**:
- `Scenes/Ui/GameOverScreen.tscn:65-170`

---

## 📋 KATEGORI 7: TIPS (İpuçları)

**Kullanım**: Yardımcı ipucu metinleri
**Örnekler**: "Keep moving!", "Use dash to avoid damage!"

| Özellik | Değer |
|---------|-------|
| Font Size | 14px |
| Font Style | *Italic* |
| Alignment | Center |
| Color | Muted Gray (#888888) |
| Background | None |

**Dosya Lokasyonları**:
- `Scenes/Ui/GameOverScreen.tscn:196`

---

## 📋 KATEGORI 8-9: BASE_HUB & HEALER (Hub Metinleri)

**Kullanım**: Ana üs ekranı ve iyileştirici NPC
**Örnekler**: "Welcome, Warrior!", "⚕ HEALER"

| Özellik | Değer |
|---------|-------|
| Welcome | 24px, Bold, Gold |
| Descriptions | 14px, Regular, Gray |
| Healer Title | 20px, Bold, Green |
| HP Display | 16px, Regular, White |
| Buttons | Standard button style |

**Dosya Lokasyonları**:
- `Scripts/Ui/Base.gd:228-747`
- `Scripts/Ui/UpgradeMenu.gd:841-945`

---

## 📋 KATEGORI 10-12: WEAPON (Silah Metinleri)

**Kullanım**: Silah isimleri, açıklamaları, mağaza
**Örnekler**: "Katana", "Fast attacks + Dash Slash"

### Silah İsimleri
| Özellik | Değer |
|---------|-------|
| Font Size | 16-20px |
| Font Style | **Bold** |
| Color | Rarity'e göre |
| - Common | White |
| - Uncommon | Green (#00FF00) |
| - Rare | Blue (#4444FF) |
| - Legendary | Purple (#AA00FF) |

### Silah Açıklamaları
| Özellik | Değer |
|---------|-------|
| Font Size | 12-14px |
| Font Style | *Italic* |
| Color | Gray (#999999) |

### Mağaza Butonları
| Özellik | Değer |
|---------|-------|
| Available | Green text |
| Not Enough | Red text, "Need X" format |

**Dosya Lokasyonları**:
- `Scenes/Ui/UpgradeMenu.tscn:187-395`
- `Scripts/Ui/UpgradeMenu.gd:330-1362`
- `Scenes/Ui/WeaponShop.tscn:64-79`

---

## 📋 KATEGORI 13-14: ENEMY (Düşman Metinleri)

**Kullanım**: Bestiary ve HUD düşman sayacı
**Örnekler**: "Goblin Warrior", "5 enemies"

### Düşman İsimleri
| Özellik | Değer |
|---------|-------|
| Font Size | 14-16px |
| Font Style | Regular |
| Color | Enemy type'a göre |
| - Normal | White |
| - Elite | Orange |
| - Boss | Red |

### Düşman Sayacı
| Özellik | Değer |
|---------|-------|
| Font Size | 12px |
| Clear | Green |
| Enemies | White |

**Dosya Lokasyonları**:
- `Scripts/Ui/Base.gd:620-671`
- `Scripts/Ui/HUD.gd:481-486`

---

## 📋 KATEGORI 15-17: RELIC (Kalıntı Metinleri)

**Kullanım**: Relic isimleri, efektleri, lore
**Örnekler**: "Phoenix Feather", "+50% HP revive"

### Relic İsimleri
| Özellik | Değer |
|---------|-------|
| Font Size | 16px |
| Font Style | **Bold** |
| Color | Rarity'e göre (silahlarla aynı) |

### Efekt Açıklamaları
| Özellik | Değer |
|---------|-------|
| Font Size | 12px |
| Font Style | Regular |
| Color | Effect type'a göre |
| - Damage | Red tint |
| - Defense | Blue tint |
| - Utility | Yellow tint |

### Flavor Text (Lore)
| Özellik | Değer |
|---------|-------|
| Font Size | 11px |
| Font Style | *Italic* |
| Color | Muted (#666666) |

**Dosya Lokasyonları**:
- `Resources/Relics/*.tres`
- `Scenes/Ui/HUD.tscn:182-195`

---

## 📋 KATEGORI 18-19: UPGRADE (Geliştirme Metinleri)

**Kullanım**: Wave arası upgrade kartları
**Örnekler**: "Health Boost", "+20 Max Health"

### Upgrade İsimleri
| Özellik | Değer |
|---------|-------|
| Font Size | 18px |
| Font Style | **Bold** |
| Color | Rarity'e göre |

### Upgrade Açıklamaları
| Özellik | Değer |
|---------|-------|
| Font Size | 14px |
| Font Style | Regular |
| Color | White with effect highlights |

**Dosya Lokasyonları**:
- `Scripts/Systems/UpgradeSystem.gd:18-248`
- `Scenes/Ui/UpgradeMenu.tscn:84-164`

---

## 📋 KATEGORI 20-21: TRAINING (Eğitim Metinleri)

**Kullanım**: Hub'daki eğitim sistemi
**Örnekler**: "Vitality", "+20 HP per level"

| Özellik | Değer |
|---------|-------|
| Stat Name | 16px, Bold |
| Bonus Text | 12px, Regular, Gray |
| Level Display | 14px, "Lv. X/5" format |
| Cost Button | Standard button, gold icon |

**Dosya Lokasyonları**:
- `Scripts/Ui/Base.gd:294-470`

---

## 📋 KATEGORI 22: DEBUG (Hata Ayıklama)

**Kullanım**: Sadece development - debug menüsü
**Örnekler**: "SPAWN ENEMIES", "Show Hitboxes"

| Özellik | Değer |
|---------|-------|
| Font Size | 12px |
| Font Family | Monospace |
| Color | Cyan (#00FFFF) |
| Background | Dark semi-transparent |

**Dosya Lokasyonları**:
- `Scripts/Ui/DebugMenu.gd:228-721`

---

## 📋 KATEGORI 23-24: SKILL_KEYS & ACHIEVEMENTS

### Skill Tuşları
| Özellik | Değer |
|---------|-------|
| Style | Key cap appearance |
| Size | 24x24px square |
| Font | Bold, centered |
| Background | Dark with border |

### Achievement İsimleri
| Özellik | Değer |
|---------|-------|
| Font Size | 20px |
| Font Style | **Bold** |
| Color | Gold (#FFD700) |
| Animation | Slide in, glow effect |

---

## 🎨 RENK PALETİ

### Ana Renkler
```
Primary Gold:    #FFD700
Dark Gold:       #CC9900
White:           #FFFFFF
Light Gray:      #CCCCCC
Muted Gray:      #888888
Dark Gray:       #444444
Black:           #000000
```

### Rarity Renkleri
```
Common:          #FFFFFF (White)
Uncommon:        #00FF00 (Green)
Rare:            #4444FF (Blue)
Epic:            #AA00FF (Purple)
Legendary:       #FFD700 (Gold)
```

### Efekt Renkleri
```
Damage/Attack:   #FF4444 (Red)
Defense/Armor:   #4444FF (Blue)
Speed/Utility:   #FFFF44 (Yellow)
Heal/Health:     #44FF44 (Green)
Mana/Magic:      #44FFFF (Cyan)
Fire:            #FF6600 (Orange)
Ice:             #66CCFF (Light Blue)
Lightning:       #FFFF00 (Yellow)
Void:            #660066 (Dark Purple)
```

### UI Renkleri
```
Button Normal:   #333333
Button Hover:    #444444
Button Pressed:  #222222
Button Disabled: #1A1A1A
Panel Background:#1A1A1A (90% opacity)
```

---

## 📁 DOSYA ORGANİZASYONU

```
Resources/
└── Localization/
    ├── text_catalog.gd      # Tüm textler (bu dosya)
    ├── UI_STYLE_GUIDE.md    # Stil rehberi (bu dosya)
    ├── fonts/               # Font dosyaları (ileride)
    │   ├── title.ttf
    │   ├── body.ttf
    │   └── mono.ttf
    └── themes/              # UI tema dosyaları (ileride)
        ├── default.tres
        ├── dark.tres
        └── retro.tres
```

---

## 🌍 YENİ DİL EKLEME

1. `text_catalog.gd` dosyasını açın
2. Her kategorideki dictionary'lere yeni dil kodunu ekleyin:
   ```gdscript
   "example_key": {
       "en": "English Text",
       "tr": "Türkçe Metin",
       "de": "Deutscher Text",  # Yeni dil
   }
   ```
3. `get_current_language()` fonksiyonunu ayarlardan dil okuması için güncelleyin

---

## 🎨 YENİ TEMA EKLEME

1. `Resources/Localization/themes/` klasörü oluşturun
2. Yeni `.tres` tema dosyası oluşturun
3. Bu rehberdeki renk ve font bilgilerini kullanarak tema tanımlayın
4. UI scriptlerinde tema yükleme sistemi ekleyin

---

*Son güncelleme: 2024*
