# Bloodwake Unity devir raporu — 15 Ekim 2026

## Durum

Aktarım **tamamlanmadı**. Unity sürümü `6000.3.25f1`, açılacak oyun sahnesi
`Assets/Bloodwake/Scenes/Bloodwake.unity`. `WarriorReview.unity` yalnız eski
inceleme sahnesidir. Genel görsel hedef Godot görüntüsü değil,
`unity/ArtDirection/` altındaki kullanıcı referanslarıdır. Godot yalnız VFX
davranışı, animasyon, menü/UI ve oynanış kuralları için kaynaktır.

Kullanıcının korunmasını istediği kararlar:

- Warrior modeli `warrior_player` olarak kalacak.
- Mevcut menüler ve resimli karakter/harita girişleri korunacak.
- Referanslardaki ıslak taş, soğuk ortam/sıcak ateş dengesi, kaliteli model
  okunabilirliği ve sınıfa özgü yoğun VFX hedeflenecek.
- Yeşil testler veya çalışan build, görsel aktarım tamamlandı diye sunulmayacak.
- Kabul gerçek `Bloodwake.unity` oyun kamerasındaki hareketli görüntüyle yapılacak.

## Bu push'taki uygulanmış işler

### Karakter, saldırı ve VFX

- Revenant normal saldırıları, teleport, mark, ultimate hazırlık/temas/dağılma,
  kan hacmi, sıçrama, ölüm çözünmesi ve animation-event eşleşmeleri geliştirildi.
  Hazırlıkta kötü görünen kusursuz zemin halkaları kaldırıldı; kan ellerine
  çekilen parçacıklar ve kırık yönlü izler kullanılıyor.
- Mage'in eldeki orbu yeniden kuruldu. Orb gerçek sağ el kemiğini izliyor;
  çekirdek, dönen kabuk, enerji noktaları, mermi kuyruğu, meteor, sıçrama,
  kristal patlama ve sis katmanları var. Oyuncu/düşman Mage orbları ayrılıyor.
- Warrior `warrior_player` korunarak saldırı yayı, whirl, sıçrama, taş/toz ve
  sıcak darbe sunumu geliştirildi.
- Gunslinger namlu efekti canlı silah soketini izliyor. Önceki çift/sabit flaş
  kaldırıldı. Beşli normal atış ve dokuz yönlü ultimate temasları klip boyunca
  dağıtıldı; balistik iz, kovan, duman, kıvılcım ve yönlü kan tepkisi eklendi.
- Düşman ve boss saldırılarında gerçek hasar alanını gösteren sektör/hat
  uyarıları, temas efektleri, çağırma görünümü ve kesilebilir hazırlık akışı var.

### Oynanış ve hareket

- Düşman takip yönü gerçek yer değiştirmeden hesaplanıyor. Engel çevresindeki
  hareket için hücre maliyetli yol bulma ve görüş hattı yumuşatma kullanılıyor;
  çapraz koşup yerinde kalma sorunu azaltıldı.
- Normal vuruş geri tepmesi en kısa yakın dövüş menzilini koruyacak şekilde
  sınırlandırıldı. Büyük alan saldırıları normal düşmanları yaklaşık 0,48 m
  savurup daha uzun tepki verdiriyor; tank ve boss daha az hareket ediyor.
  Hazırlanmakta olan düşman saldırıları ağır darbeyle iptal ediliyor.
- Mage mermileri el yüksekliğinden çıktığı için düşmanı ıskalamaması amacıyla
  düşmanın dikey gövde eksenine karşı swept çarpışma kullanıyor.

### Sunum, HUD ve çevre

- URP sunumu ACES/SMAA, oda yansıma probu, ıslak taş varyasyonu ve karaktere
  özel dolgu ışığıyla geliştirildi. Modellerin malzemeleri metal/kumaş/deri
  ayrımını daha okunur kılacak şekilde güncellendi.
- Sol üst portre kırpımı sınıfa göre yüz merkezli yapıldı; sınıf değişiminde
  HUD yenilenmesi düzeltildi. Alt yetenek çerçeveleri ve ikon sunumu yenilendi.
- Kullanıcının bina, kapı, duvar, brazier, fener, sandık, fıçı ve örtülü masa
  modelleri sahneye bağlandı. Kapı kanatları ayrı pivotlarla açılıyor; eski
  siyah cargo platformları kaldırıldı ve kümeler daha düzensiz yerleştirildi.
- Kullanıcının son kuyu modeli PBR haritalarıyla eklendi, 3,35 m yüksekliğe
  normalize edildi ve `town_well_03` içindeki geçici kuyu/çatı yerine geçti.
  Tek mesh içindeki karanlık açıklığın üstüne özel, hareketli yansıma tepkili
  `WellWater` yüzeyi yerleştirildi.
- Menü müziği, savaş müziği ve geçiş/duck davranışı güncellendi. Dinleme ve
  miksaj kabulü henüz yapılmadı.

## Son doğrulama

Son izole Unity QA çalışması `exit 0` verdi:

- 66 data/asset kontrolü
- 28 Revenant olay zamanı kontrolü
- 37 Revenant çalışma kontrolü
- 14 Mage çalışma kontrolü
- 23 hareket/geri tepme kontrolü
- 13 düşman/boss VFX kontrolü
- Beş sınıf ve runtime smoke akışı

Bu testler kod/varlık sözleşmelerini ve temel akışı doğrular. GPU performansı,
Windows build'i, serbest oyuncu testi veya ArtDirection seviyesinde görsel kabul
kanıtı değildir. Kontrollü kare ve film çıktıları yerel QA klasöründeydi; büyük,
yeniden üretilebilir ham kareler depoya eklenmedi.

## Açık işler — öncelik sırası

1. **Mage VFX kalite geçişi:** Referans tasarımlarına göre orb hacmi, meteor,
   kristal çeşitliliği, kırılma, sis ve düşman temas tepkileri gerçek hareketli
   kayıtta yeniden ayarlanmalı. Mevcut efekt çalışıyor fakat hedef yoğunluğun
   ve doğallığın gerisinde.
2. **Revenant ultimate hazırlığı:** Zemin halkaları kaldırıldı; elde toplanan
   kanın akış şekli, hacmi ve animasyonla senkronu farklı kamera yönlerinde
   tekrar incelenmeli.
3. **Warrior/Gunslinger hareketli temas kontrolü:** Efektler gelişti, fakat her
   saldırı klibinin el/silah temas karesi ve ayak kayması tek tek kabul edilmedi.
4. **Düşman ve bosslar:** Tüm rol davranışlarının windup/recovery/stagger
   dengesi, kalabalık çarpışma yönlenmesi ve her saldırının özgün VFX'i tamamlanmalı.
5. **Çevre sanat geçişi:** Yeni modeller kullanılmasına rağmen bazı eski
   yapılar, boş meydanlar, düşük dekor yoğunluğu ve karanlık malzemeler sürüyor.
   Bağımsız cargo ipi modeli henüz teslim edilmedi. Kuyu sahnede çalışıyor;
   meydanın genel ışığı ve dekor kompozisyonu hâlâ kabul bekliyor.
6. **HUD/UI:** Portre ve ikonlar farklı en-boy oranları, gamepad ve yüksek DPI
   altında yeniden kontrol edilmeli. Runtime UI'nın artist-editable prefab
   yapısına taşınması açık.
7. **Ses ve performans:** Müzik/SFX miksajı kulakla kabul edilmeli; yeni shader,
   dinamik mesh, ışık ve yansıma maliyetleri gerçek GPU'da ölçülmeli.
8. **Platform:** Windows çalıştırma, grafik kalite seçenekleri, gamepad akışı ve
   gerçek kullanıcı oyun testi yapılmalı.

## Diğer bilgisayarda devam

1. Bu depoyu çek ve Unity Hub'dan **Unity 6000.3.25f1** ile `unity/` klasörünü aç.
2. Unity paket/asset importunun bitmesini bekle.
3. `Assets/Bloodwake/Scenes/Bloodwake.unity` sahnesini aç; `WarriorReview` açma.
4. İlk olarak Mage ile gerçek oyun kaydı alıp yukarıdaki birinci açık maddeyi
   ArtDirection referanslarıyla karşılaştır.
5. İthal varlıkları yeniden üretmek gerekirse Unity menüsündeki
   `Bloodwake > Build Imported Game` komutunu kullan. Bu komut sahne/prefabları
   yeniden yazabildiği için önce çalışma ağacını kontrol et.
6. Ana kaynak ve ayrıntılı teknik notlar için `unity/README.md` ve
   `unity/REVENANT_STATUS.md` dosyalarını oku.

## Önemli dosyalar

- Oyun akışı: `Assets/Bloodwake/Runtime/BloodwakeGame.cs`, `GameLoop.cs`,
  `RoomFlow.cs`
- Sınıf VFX: `RevenantVfx.cs`, `MageVfx.cs`, `ClassVfx.cs`, `CombatVfx.cs`
- Düşmanlar: `EnemyCombat.cs`, `EnemyVfx.cs`, `Navigation.cs`, `HitRecoil.cs`
- Sunum: `GameplayLighting.cs`, `RoomPresentation.cs`, `GameHUD.cs`, `GameUI.cs`
- Çevre: `EnvironmentDressing.cs`, `EnvironmentDetails.cs`, `CourtyardWell.cs`
- Testler: `Assets/Bloodwake/Editor/Tests/`
- Görsel hedefler: `unity/ArtDirection/`

