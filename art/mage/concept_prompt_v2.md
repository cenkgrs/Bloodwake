# Mage — yeni tasarım eskizi (GPT görsel prompt'u, 19 Ekim 2026)

Referans olarak `art/concepts/agile_warrior/agile_warrior_front_tpose_light_trim_v2.png`'yi de GPT'ye ekle:
aynı render dili, aynı arka plan ve aynı T-poz. Tripo'ya böyle girmesi kolay olur.
Sonra aynı sohbette arka, sol ve sağ görünümleri iste.

## Ana prompt (önden, T-poz)

```
Full-body character concept for a dark gothic action RPG, same rendering style, lighting and dark charcoal studio background as the attached reference. Front view, symmetrical T-pose, arms straight out, palms down, feet shoulder-width, whole figure in frame with margin, no props touching the body, no weapon in hand.

The character is the MAGE of a cursed, bell-haunted night city: a frost-and-void sorcerer who was once a cathedral bell-scribe. Tall, lean, severe face, pale skin with faint frostbitten blue at the fingertips and lips, glowing pale ice-blue eyes. Long dark hair partly tied back, a few strands frozen white.

Costume, layered and heavily detailed, not plain robes:
- A high-collared, floor-length black-violet coat of heavy brocade with a raised gothic tracery pattern, split at the front and back into long ragged panels that end in frayed, frost-crusted edges.
- A fitted dark leather-and-silver cuirass over the chest, engraved with bell and rune motifs, a single large pale-blue crystal set at the sternum.
- Asymmetric shoulders: the left a tarnished silver pauldron shaped like an inverted bell with chains and small hanging bells; the right covered by a short half-cape of deep violet velvet lined with frost-white fur.
- Long fingerless gauntlets with silver filigree; the right hand's fingers end in thin silver claw tips; faint violet rune lines glow along both forearms.
- A wide belt of stacked straps holding a chained grimoire on the hip, glass vials of glowing blue liquid and a small brass bell.
- Narrow trousers with wrapped shins, tall pointed boots with silver toe caps and buckles.
- Frost crystals and thin rime creep over the coat hem, shoulders and boots; three small jagged ice shards orbit lazily behind the shoulders, and a faint violet arcane glyph ring floats behind the back at waist height.

Palette: near-black, deep violet, tarnished silver, frost white and pale ice blue, with small blood-red accents (cord ties, a red ribbon on the grimoire) so the character sits in the same world as the crimson-and-black warrior reference. Dramatic but readable silhouette from a high isometric camera: strong shoulders, long flowing coat tails, clear separation between arms and body.

Highly detailed, realistic materials (brocade, velvet, fur, worn leather, scratched silver, ice), painterly game concept art, 4k, sharp, no text, no watermark, no frame.
```

## Takip prompt'ları (aynı sohbette)

```
Same character, same outfit, same T-pose and background: back view.
```
```
Same character, same outfit, same T-pose and background: left side view, then right side view.
```

## İsteğe bağlı değişiklikler

- Kadın büyücü istersen ilk paragrafa `female,` ekle, yüz tarifini `sharp elegant face` yap.
- Tripo'da yörüngedeki buz parçaları ve sırttaki halka gövdeye yapışabilir. Yapışırsa önce ikinci prompt'la
  `remove the floating ice shards and the glyph ring, keep everything else identical` dedirt. Onları oyunda VFX ile ben eklerim.
