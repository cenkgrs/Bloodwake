# Mage — gerçekçi eskiz (GPT görsel prompt'u, 20 Ekim 2026)

v2 konsepti boyalı (painterly) bir dille, dramatik ışıkla ve havada süzülen efektlerle çizilmişti; 3D üretici
(Tripo vb.) bunları dokuya gömüyor ya da yanlış geometriye çeviriyor. v3 aynı tasarımı **gerçek bir film kostümünün
stüdyo fotoğrafı** gibi istiyor: düz eşit ışık, efekt yok, temiz T-poz, açık gri fon. Işığı ve efektleri oyun ekler.

Kullanım:
1. Yeni bir GPT sohbeti aç, istersen `output/mage-turnaround/mage-front.png`'yi tasarım referansı olarak ekle
   ("use only for the costume design, not for the rendering style" diye belirt).
2. Ana prompt'u yapıştır. Beğenene kadar aynı sohbette düzelttir.
3. Aynı sohbette takip prompt'larıyla arka ve yan görünümleri al (aynı kişi, aynı kostüm kalsın diye aynı sohbette).
4. 3D üreticiye çoklu görüntü olarak ver (önden + yanlar + arka). FBX/GLB, PBR açık, 4K indir; `art/mage/` altına bırak.

## Ana prompt (önden, T-poz)

```
Photorealistic full-body studio photograph of a costumed actress for a dark fantasy film, shot like a professional costume reference photo for a 3D scanning session. Front view, straight-on, eye level, orthographic-looking (long lens, no perspective distortion). Symmetrical T-pose: arms straight out to the sides at shoulder height, palms facing down, fingers together and straight, feet shoulder-width apart, standing upright with a neutral relaxed posture. The whole figure in frame from the top of the head to below the boots, with margin on all sides.

Lighting: flat, even, soft, shadowless studio lighting from the front and both sides, like a photogrammetry booth. No rim light, no dramatic shadows, no glow, no bloom, no color grading. Plain seamless light neutral gray background, no floor shadow.

The character: a tall, lean woman in her early thirties, severe and beautiful face with realistic skin texture and pores, pale skin, ice-blue eyes, long dark hair tied back in a braid with a few silver-white strands, neutral expression. Realistic human proportions, not stylized, not anime.

Costume, real tailored materials, heavily detailed but physically plausible, every piece clearly attached to the body:
- A high-collared, floor-length coat of heavy black-violet brocade with a subtle woven gothic tracery pattern, split at the front and back into long panels with frayed, worn hems. The coat tails hang straight down and stay clearly separate from the legs.
- A fitted dark leather cuirass over the chest with tooled bell and rune engravings and worn silver trim, a single pale-blue faceted crystal set at the sternum (real gemstone, not glowing).
- Left shoulder: a tarnished, scratched silver pauldron shaped like an inverted bell, with two small brass bells hanging from short chains. Right shoulder: a short half-cape of deep violet velvet lined with off-white fur.
- Fingerless dark leather gauntlets with silver filigree on the forearms.
- A wide belt of stacked worn leather straps holding a leather-bound grimoire on the left hip with a red ribbon, three small glass vials of blue liquid on the right hip, and a small brass bell.
- Narrow black trousers, shins wrapped in leather strips, tall pointed black leather boots with silver toe caps and buckles.

Materials must read clearly as different surfaces: matte velvet, woven brocade, worn leather with scuffs, scratched tarnished silver, brass, glass, fur, skin. Palette: near-black, deep violet, tarnished silver, brass, off-white fur, pale ice blue, small blood-red accents.

No floating objects, no magic effects, no particles, no glowing runes, no frost effects, no weapon, nothing held in the hands. Ultra sharp focus, 8k photo detail, no text, no watermark, no frame.
```

## Son hal (20 Ekim): paltosuz

Aynı sohbette sonradan şu değişiklikler yaptırıldı: uzun palto kaldırıldı (dar deri kostüm; Mixamo rig'i ve
animasyon için uzun etek panellerinden çok daha temiz), saç arkada at kuyruğu, bacaklarda mor rün şeritleri,
kolluklarda rün çemberleri, metal kaplı büyük grimoire. Grimoire **sol** kalçada, mavi şişeler ve pirinç çan **sağ** kalçada;
bronz çan omuzluk sol omuzda, kürklü mor yarım pelerin sağ omuzda. Takip prompt'ları bu son hale göre:

## Takip prompt'ları (aynı sohbette)

Arka:
```
Same actress, same outfit, same studio, same flat shadowless lighting and blue-gray background, same T-pose. Now photographed from directly behind (back view), eye level, orthographic-looking. Keep every detail consistent with the front view: the ponytail, the bronze bell pauldron on her left shoulder, the fur-lined violet half-cape on her right shoulder, the crossed belts with the metal-bound grimoire on her left hip and the blue vials and brass bell on her right hip, the violet rune stripes down the legs, the strapped boots.
```

Sol yan:
```
Same actress, same outfit, same studio, same flat shadowless lighting and blue-gray background, same T-pose. Now photographed from her left side (exact 90-degree profile), eye level, orthographic-looking. The bronze bell pauldron and the grimoire face the camera. Keep every detail consistent with the front and back views.
```

Sağ yan:
```
Same actress, same outfit, same studio, same flat shadowless lighting and blue-gray background, same T-pose. Now photographed from her right side (exact 90-degree profile), eye level, orthographic-looking. The fur-lined half-cape and the blue vials face the camera. Keep every detail consistent with the other views.
```

## Düzeltme ipuçları

- Işık hâlâ dramatik geliyorsa: `Even flatter lighting, like an overcast day, no shadows on the face or under the arms.`
- Kollar aşağı düşüyorsa: `Arms exactly horizontal at shoulder height, like a capital T.`
- Etek bacaklara yapışıyorsa: `Leave a clear gap between the coat panels and the legs, the coat hangs straight and does not touch the boots.`
- Kostüm fazla siyah, oyunda okunmuyorsa: `Make the coat brocade a richer, more visible deep violet, keep everything else the same.`
- Çizim gibi duruyorsa: `It must look like a real photograph of a real person in a real costume, not a painting or a 3D render.`
