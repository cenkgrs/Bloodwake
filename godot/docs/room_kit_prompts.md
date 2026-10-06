# Bloodwake oda kiti: GLB üretim promptları

Oyundaki odalar artık dokulu gri kutu (taş, ahşap, arduvaz, demir, kumaş) olarak
kuruluyor. Bu listedeki her parça bir GLB olarak teslim edildiğinde, o parçanın
kutusu **bütün odalarda** otomatik olarak modelle değişir; kod değişmez.

Teslim yeri: `godot/assets/rooms/kit/<dosya>.glb` — dosya adları
`godot/data/room_kit.json` ile birebir aynı olmalı. Bir parçanın birden fazla
varyantı varsa (`house_a/b/c`) oyun her yerleşimde rastgele birini seçer.

## Teslim kuralları (her parça için)

- Birim metre. Model, aşağıdaki tablodaki ölçüye yakın üretilsin; oyun yine de
  ölçüye oturtur (`footprint`: oranı koruyarak tabana sığdırır, `stretch`: tam
  kutuya esnetir).
- Ön yüz Blender'da **−Y** yönüne baksın (glTF/Godot'ta +Z). Orijin taban
  merkezinde, zemin Z=0'da.
- Tek GLB, gömülü PBR dokular (BaseColor, Normal, Roughness/Metallic). 1K–2K doku
  yeterli. Transformlar uygulanmış.
- Üçgen bütçesi: küçük prop 1–4K, ev/kapı 6–15K, kule/istasyon 20–40K.
- Işık, sis, zemin plakası, karakter, yazı ya da ok **koyma**. Sadece obje.

## Ortak stil bloğu

Her promptun başına bunu ekle:

```
Dark-fantasy cursed frontier town, isometric action game asset, Diablo-like
readability. Weathered soot-grey stone, old dark oak timber, black wrought iron,
slate roofs, sparse deep-burgundy cloth, small warm amber lanterns. Grim, worn,
hand-crafted, no modern elements. Physically based materials with baked
roughness variation, clean silhouette readable from a 45-degree top-down camera.
Single object on empty background, no ground plane, no text, no characters.
```

## Parçalar

| Dosya | Ölçü G×Y×D (m) | Uyum | Not |
| --- | --- | --- | --- |
| `wall_tall_4m.glb` | 4 × 3.2 × 1 | stretch | Uzak duvarlar (kuzey, batı). Döşenerek tekrar eder |
| `wall_low_4m.glb` | 4 × 1.0 × 1 | stretch | Kamera tarafı alçak duvar |
| `gate_frame.glb` | 7.8 × 4.2 × 1.2 | stretch | Kanatsız kapı çerçevesi, 6 m net açıklık |
| `gate_frame_grand.glb` | 7.8 × 5.2 × 1.2 | stretch | İstasyon ve boss çıkışı için gösterişli çerçeve |
| `gate_leaf.glb` | 3 × 3 × 0.15 | stretch | **Sol** kanat; orijin menteşede (sol kenar). Sağ kanat aynası |
| `house_a/b/c.glb` | 6 × 6.5 × 4.5 | footprint | Duvar arkasındaki cepheler |
| `cargo_island_a/b.glb` | 6 × 1.4 × 4 | footprint | Alçak yük adası (sandık, varil, el arabası) |
| `market_stall.glb` | 2 × 2.6 × 3 | footprint | Kuyulu Meydan ve Gece Pazarı tezgâhı |
| `well.glb` | 4.4 × 2.6 × 4.4 | footprint | Kuyu ve taban 3 m yarıçapı aşmasın |
| `trough.glb` | 1 × 0.8 × 3.6 | footprint | Ahır yemliği / suluk |
| `stable_divider.glb` | 1.2 × 2.2 × 13 | stretch | Ahır avlularını ayıran kısa duvar, iki yanında yemlik |
| `broken_plinth.glb` | 1.9 × 1.1 × 1.9 | footprint | Boss arenası kırık kaide; 1,2 m'yi geçmesin |
| `hearth.glb` | 4 × 1.6 × 1.4 | footprint | Safehouse ocağı |
| `war_table.glb` | 2.6 × 0.95 × 1.5 | footprint | Safehouse harita masası |
| `reward_pedestal.glb` | 1.2 × 0.85 × 1.2 | footprint | Ödül kaidesi; üstündeki mor kristali oyun ekliyor |
| `bell_tower.glb` | 11 × 24 × 7 | footprint | Kara Çan kulesi, kuzey duvarın arkasında |
| `station_facade.glb` | 22 × 11 × 4 | footprint | Brackwell İstasyonu cephesi |
| `rail_wagon.glb` | 3.2 × 3 × 9 | footprint | Doğu sınırına gömülü vagon |
| `cargo_crane.glb` | 3 × 8 × 7 | footprint | Batı sınırındaki yük vinci |

### wall_tall_4m

```
A 4 metre long, 3.2 metre high, 1 metre thick town wall segment of rough-cut
grey ashlar blocks with dark mortar, soot staining near the top, a slightly
overhanging stone coping course, a few chipped blocks and creeping moss at the
base. Both short ends are flat and clean so segments tile seamlessly side by side.
```

### wall_low_4m

```
A 4 metre long, 1 metre high, 1 metre thick low stone parapet wall of grey ashlar
with a flat stone cap, worn edges and soot stains. Both short ends flat for
seamless tiling.
```

### gate_frame

```
A town gate frame without doors: two square stone pillars 0.9 m wide and 4.2 m
tall standing 6 metres apart, joined by a heavy stone lintel with a carved
keystone. Iron hinge brackets on the inner faces of both pillars, a small amber
lantern on top of each pillar. The 6 metre opening between the pillars is empty.
```

### gate_frame_grand

```
A grand stone gateway without doors: two tall buttressed pillars 5.2 m high
standing 6 metres apart, a thick arched lintel with a carved bell emblem, a
worn deep-burgundy banner hanging from the lintel, iron hinge brackets and two
iron lanterns. The 6 metre opening is empty.
```

### gate_leaf

```
One leaf of a wrought-iron town gate: 3 metres wide, 3 metres tall, made of
vertical black iron bars with spear-point tops, two horizontal rails, rivets and
a little rust. Hinge pins on the left edge.
```
Blender'da orijini sol alt köşeye, menteşe eksenine taşı.

### house_a / house_b / house_c

```
A narrow two-storey cursed-town house facade block, 6 m wide, 4.5 m deep, 6.5 m
to the eaves: a grey stone ground floor with a heavy oak door and iron studs,
a half-timbered upper floor with dark oak beams and soot-grey plaster, two small
warmly lit windows with shutters, a steep slate roof with a stone chimney.
```
Varyantlar: (b) çıkma üst kat ve dış merdiven; (c) atölye vitrini, bordo bez tente, duvara asılı fener.

### cargo_island_a / cargo_island_b

```
A low cluster of cargo on a worn wooden pallet base, 6 m by 4 m, no taller than
1.4 m: stacked wooden crates with iron corner bands, several oak barrels, coiled
rope, a tarp half thrown over one stack. Compact, walkable around, nothing tall.
```
(b) varyantı: bir el arabası, çuvallar ve sandıklar.

### market_stall

```
A small market stall 2 m by 3 m: a worn wooden counter 1.1 m high, four thin
posts holding a sagging deep-burgundy cloth canopy at 2.5 m, a few jars, sacks
and a hanging amber lantern.
```

### well

```
A low round stone town well, 4 metre outer diameter including its stone base
ring, 0.95 m high wall, dark water inside, a simple timber frame with a winch,
rope and wooden bucket. No roof.
```

### trough

```
A long wooden horse trough, 3.6 m long, 1 m wide, 0.8 m high, iron bands, murky
water, straw scattered at its foot.
```

### stable_divider

```
A short stable courtyard dividing wall, 13 m long, 1.2 m thick, 2.2 m high, grey
stone with a timber cap rail, wooden feed troughs running along both sides at
knee height, hay and tack hooks.
```

### broken_plinth

```
A broken square stone statue plinth 1.9 m wide, at most 1.1 m tall in total, its
statue snapped off at the knees, carved cursed sigils on the sides, rubble at
its base.
```

### hearth

```
A wide stone hearth 4 m long, 1.6 m high, 1.4 m deep with a soot-black firebox,
glowing embers, iron fire-dogs, a blackened kettle hook and stacked firewood.
```

### war_table

```
A heavy oak war table 2.6 m by 1.5 m, waist high, an old parchment map of a
cursed town spread on it, iron pins, candles in brass holders, a dagger stuck
into the map.
```

### reward_pedestal

```
A short octagonal stone pedestal 1.2 m wide and 0.85 m tall with a recessed
bowl on top, faint violet runes carved around its side, cracked edges.
```

### bell_tower

```
A massive dark stone bell tower 11 m wide, 7 m deep, 24 m tall: a buttressed
stone base with an arched gateway at ground level, an open belfry holding a
huge cracked black iron bell, tattered deep-burgundy banners hanging from the
belfry, a steep slate spire with an iron finial, amber lanterns at the gate.
```

### station_facade

```
A grim railway station facade 22 m wide, 11 m tall, 4 m deep: stone ground floor
with arched windows lit amber, a central entrance under a wooden sign board
(blank, no text), timber and plaster upper floor, a long slate roof with small
dormers and two chimneys.
```

### rail_wagon

```
An old wooden rail goods wagon 9 m long, 3.2 m wide, 3 m tall, dark planked
sides with iron straps, a sliding door, rusted wheels and couplings, a slate-grey
curved roof.
```

### cargo_crane

```
A tall timber dockyard cargo crane 8 m high on a stone footing, a diagonal boom
with an iron pulley, rope and a hanging hook, a wooden winch drum at its base.
```

## Oda promptlarındaki ölçüler güncellendi

Haritalar %30 küçültüldü. Blender'a verdiğin oda promptlarında bu iç ölçüleri kullan:

| Oda | Eski | Yeni |
| --- | --- | --- |
| town_gateyard_01 | 36 × 32 | 25 × 22 |
| town_cargo_02 | 40 × 34 | 28 × 24 |
| town_well_03 | 38 × 38 | 27 × 27 |
| town_stables_04 | 44 × 34 | 31 × 24 |
| town_station_05 | 46 × 40 | 32 × 28 |
| town_boss_blackbell_01 | 52 × 48 | 36 × 34 |
| town_night_market | 26 × 20 | 18 × 14 |

Kapı net açıklığı 6 m ve EntrySpawn'ın girişten 4 m içeride olması değişmedi.
Odaların içindeki adalar ve marker konumları `data/rooms.json`'da.
