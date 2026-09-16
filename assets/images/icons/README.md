# Catalog icons

Looked up by `CatalogIcon` (`lib/ui/widgets/catalog_icon.dart`) via each
catalog entry's `iconAsset` getter — `assets/images/icons/upgrades/<id>.png`
for upgrades, `assets/images/icons/items/<id>.png` for shop items. A
missing file falls back to a category-tinted Material icon, so drop these
in incrementally — nothing needs a code change when a file appears.
Square images (any size — a card scales them down) work best.

## Upgrades (`assets/images/icons/upgrades/`)

| File                          | Name            |
|--------------------------------|-----------------|
| `sharpened.png`                | Sharpened        |
| `rapid_fire_stat.png`          | Rapid Fire       |
| `vitality.png`                 | Vitality         |
| `predator.png`                 | Predator         |
| `vampirism.png`                | Vampirism        |
| `swift.png`                    | Swift            |
| `unlock_rapid_rifle.png`       | Rapid Rifle (weapon unlock) |
| `unlock_shotgun.png`           | Shotgun (weapon unlock)     |
| `unlock_magic_orb.png`         | Magic Orb (weapon unlock)   |
| `unlock_lightning.png`         | Lightning (weapon unlock)   |
| `unlock_sword.png`             | Sword (weapon unlock)       |
| `chain_lightning.png`          | Chain Lightning  |

## Items (`assets/images/icons/items/`)

| File                    | Name             |
|--------------------------|------------------|
| `platinum_armor.png`    | Platinum Armor    |
| `swift_boots.png`       | Swift Boots       |
| `hunters_scope.png`     | Hunter's Scope    |
| `vampiric_amulet.png`   | Vampiric Amulet   |
| `lucky_charm.png`       | Lucky Charm       |
| `guardian_angel.png`    | Guardian Angel    |
| `gold_sword.png`        | Gold Sword        |
| `thunder_core.png`      | Thunder Core      |
