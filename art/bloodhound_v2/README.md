# Bloodhound v2 — inceleme sürümü, üretime hazır değil

Kaynak: `source/gunslinger_original.glb`; kullanıcının verdiği yeni Tripo GLB'sinin
değiştirilmemiş kopyası. Bulut üretimi veya ücretli Tripo işlemi kullanılmadı.

## Yapılan çalışma

- Model 1,8 metre yüksekliğe normalize edildi; UV ve kaynak materyaller korundu.
- Yerel Blender işlemiyle 48 kemikli iskelet oluşturuldu: gövde, uzuvlar,
  parmaklar, sekiz palto kemiği, iki atkı kemiği ve iki silah bağlantısı.
- Ağırlıklar vücut/kıyafet bölgelerine göre atandı, yüzey komşulukları boyunca
  yumuşatıldı ve en fazla dört etkiye indirildi.
- İstenen yedi `BH_*` Action 60 FPS'de kare kare oluşturuldu.
- Idle ve walk ilk/son poz matris farkı sıfır. Bu ölçüm oyun hızındaki ayak
  kaymasını veya bütün kıyafet kesişmelerini doğrulamaz.
- Beşli atış event'leri 10/14/18/22/26; bomba event'i 20. karede.
- Ölüm geçişindeki palto/zemin kesişmeleri deforme mesh üzerinden bulunup
  palto kemiklerinde düzeltildi. Sayısal sonuçlar `qa/measurements.json` içinde.
- GLB Godot'ta tekrar açıldı. Yalnız klip isimleri değil, örneklenen karelerde
  gerçek eklem konumlarının değiştiği ölçüldü.
- Yeni karakter `godot/assets/models/bloodhound_player.glb` üzerinden gerçek
  oyuncuya bağlandı. Önceki `bloodbound.glb` silinmedi.
- Beşli atış artık tek kısa saldırıya sıkıştırılmıyor. 10/14/18/22/26. karelerde
  beş tetik eventi, son event'te iki namlu çalışıyor. Ortalama DPS korunuyor.
- Bomba 20. kareye kadar bekliyor; eldeki obje ile ayrı parabolik uçuş VFX'i var.
  Ultimate 30–78. karelerde dokuz farklı yöne gerçek mermi çıkarıyor.
- GLB'nin ilk örneği sıfır saniyeye kaydırıldı; event zamanı `(kare-1)/60`.
- Godot'ta iki ayağın basış fazındaki dünya konumu <3 mm toleransla test edildi.
  Yürüme hızı gerçek hareket hızı ve karakter ölçeğiyle eşleştiriliyor.
- Normal atış/Ricochet sırasında hareket kesilmiyor: `bloodhound_stride.gd`
  alt gövdeye walk pozlarını uygularken üst gövdenin atış pozunu koruyor.
  Geri yürüyüşte kalçayı 180 derece bükmek yerine çevrim ters oynatılıyor.
- İki yeni **inceleme build'i** üretildi: `godot/builds/linux/Bloodwake-Bloodhound-Review.x86_64`
  ve `godot/builds/windows/Bloodwake-Bloodhound-Review.exe`. Eski build'ler korunuyor.

## İnceleme dosyaları

- `work/Bloodhound_Rig_WIP.blend`: düzenlenebilir kaynak ve yedi Action.
- `work/Bloodhound_Rig_WIP.glb`: Godot incelemesi için export.
- `qa/BH_*.mp4`: 30 FPS önizlemeler; her iki kaynak kareden biri örneklendiği
  için kliplerin gerçek oynatma hızı korunur.
- `qa/godot/BH_*.png`: motorun gerçek OpenGL görüntüleyicisinde ön/yan/3/4
  açıdan sekiz zaman örneği.
- `qa/godot/runtime_review.json`: Godot'ta eklem hareketi ölçümleri.
- `qa/Bloodhound_Gameplay_Review.mp4`: gerçek BWWorld sahnesinde hareket, saldırı,
  hasar, bomba, ultimate ve ölüm kaydı. `qa/gameplay/events.json` event kaydıdır.

## Action ve event dökümü

| Action | Kare | Event |
|---|---:|---|
| BH_Idle | 1–72 | Loop |
| BH_Walk_InPlace | 1–32 | Loop; kök sabit |
| BH_GetHit | 1–18 | — |
| BH_Death | 1–60 | — |
| BH_FiveShot | 1–42 | FIRE_01…05: 10, 14, 18, 22, 26 |
| BH_BombThrow | 1–50 | THROW_RELEASE: 20 |
| BH_Ultimate_BloodWake | 1–108 | ULT_FIRE_01…09: 30, 36, 42, 48, 54, 60, 66, 72, 78 |

Ricochet yeteneği için Godot, FiveShot'ın yalnız ilk geri tepmesini içeren kısa
bir `BH_Ricochet` varyantı oluşturur; bu kaynak yedi Action'dan ayrı motor varyantıdır.

## Çalıştırılan testler

- `bloodhound_animation_test.gd`: yedi eşleme, 48 kemik, socket'ler, iki loop,
  dünya uzayında ayak teması, yeteneklerin saldırıyla kesilmemesi — geçti.
- `bloodhound_gameplay_test.gd`: 38 kontrol, 0 hata.
- `class_kit_test.gd`: 110 kontrol, 0 hata.
- `combat_flow_test.gd`: 58 kontrol, 0 hata.
- `test_suite.gd`: 198 kontrol, 0 hata.

Bu testler görsel kabulün yerine geçmez. Test süiti çıkışında mevcut kaynak/obje
yaşam süresi uyarıları görülebiliyor; bunlar sıfır test hatası sayısından ayrıdır.
Paketlenmiş Linux oyunu editör dışında, `/tmp` çalışma dizininden açıldı ve
`--smoke` oyun akışını tamamlayarak 0 koduyla kapandı. Paket testi sırasında
bulunan ham TTF yolu problemi `ui_kit.gd` içinde paketli font verisiyle giderildi.

## Kabulü engelleyen açık işler

1. Eldeki revolverler geçici, yerel üretilmiş prop geometrisidir. Kaynak mesh'te
   kılıflardaki silahlar hâlâ gövdeyle birleşiktir. Nihai iki silah düzeni için
   bu parçaların ayrıştırılması ve el/kılıf geçişinin tamamlanması gerekir.
2. Yedi klip için örnek görüntüler ve hareket ölçümleri alınmıştır; kıyafet–beden
   kesişmelerinin bütün ara karelerde giderildiği henüz sertifikalanmamıştır.
3. Basış ayağının kayması sayısal olarak kontrol edildi, fakat oyunun 5 m/s tam
   hareket hızı bu ağır walk çevrimini belirgin hızlandırıyor. Yüksek hız için
   ayrı koşu animasyonu veya hareket tasarımı değerlendirmesi hâlâ gerekli.
4. Şapka ölümde kafada kalıyor; ayrı düşen şapka animasyonu üretilmedi.
5. Windows build'i üretildi, fakat bu Linux ortamında Windows'ta çalıştırılmadı.

Durum: **IN_REVIEW_NOT_PRODUCTION_READY**. Testlerin geçmesi nedeniyle bu açık
sanat/mesh konuları kapatılmış veya teslimat tamamlanmış sayılmamalıdır.

## Yeniden üretim

```sh
blender -b -t 4 --python art/bloodhound_v2/build.py
blender -b -t 4 art/bloodhound_v2/work/Bloodhound_Rig_WIP.blend --python art/bloodhound_v2/qa.py
godot --path godot --rendering-method gl_compatibility --resolution 512x512 --script tools/bloodhound_v2_review.gd
```

Motor inceleme aracı yeni GLB'yi doğrudan açar; `assets/models/bloodbound.glb`
dosyasını değiştirmez. Görüntülü inceleme için çalışan ekran oturumu gereklidir.
