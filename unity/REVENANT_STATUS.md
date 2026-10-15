# Revenant aktarım kontrol kaydı — 13 Ekim 2026

Bu bir ara durum kaydıdır; tam oyun aktarımı ve görsel eşitlik onayı değildir.
Kaynak commit: e618ef9. Unity 6000.3.25f1 / Metal, Godot 4.6.3 / Compatibility.
Oyun sahnesi Bloodwake.unity. Warrior hâlâ warrior_player; menü atlasları ve
resimli karakter girişleri değiştirilmedi. Godot oyun kaynakları değiştirilmedi.

## Kaynak → uygulama → tetikleme

| Kaynak | Unity karşılığı | Tetikleme | Doğrulama |
|---|---|---|---|
| fx.gd revenant_claws + revenant_claws.glb | RevenantVfx.Claws, ClawCore/BloodWisps mesh/prefab, aynı shader denklemleri | Attack 1/2/3 DAMAGE: 10/60, 11/60, 18/60 sn; 2. saldırı ters tarama | Kaynak geometri aktarıldı. Taze render ile yön/poz eşleşti; eski Godot görüntüsü gecikmiş kareydi. |
| skills.gd blood_step | ClassSkills bloodTeleport, Gate/Travel/Burst/Claws | HIDE .25; MOVE .316667; SHOW .35; DAMAGE .416667; RECOVER .566667 | Gerçek klip olayları ve iptal/görünürlük kontrolü geçti. |
| skills.gd blood_burst + revenant_burst.glb | BloodLances/BloodVeil, Charge/Burst | TELEGRAPH .3; DAMAGE .983333; DISSIPATE 1.4 | Sütunlar, zemin deseni ve kan havuzu görüntüyle kontrol edildi; ton/parlaklık eşitliği açık. |
| skills.gd _apply_mark | ApplyRuinMark + RevenantVfx.Mark | E ve işaretli düşmanın ölümü | Hedef devri ve görselin yeni hedefe taşınması sınandı. |
| fx.gd revenant_impact | Impact, Sparks, Flash, Stain | Hasar olayı | Kaynak üçgen prizma kıvılcımları aktarıldı. Dağılım/sönüm ve parlaklık eşitliği açık. |
| fx.gd blood_splatter / _blood_stain | Splatter / Stain | Hasar, .17–.28 sn uçuş, 4–6 sn iz + 1.25 sn kuruma | Kaynak süreleri ve küre damlaları aktarıldı; dağılım eşitliği açık. |
| visual.gd _attach_blood_hands | Hands | hand_l / hand_r kemikleri | Görünürlük ve ölümle kapanır; küre parçacıkları aktarıldı. Hareketli iz incelemesi açık. |
| fx.gd revenant_death | Death | DEATH_GROUND, 51/60 sn | Klip zamanı ve görüntü kontrolü yapıldı. |
| visual.gd _start_blood_death | RevenantDissolve | 1.0 sn başlangıç, 1.55 sn çözünme | Kaynak gürültü/kesme denklemi aktarıldı; ışıklandırma eşitliği açık. |
| revenant_layers.gd | Controller “Moving attack legs” / “Upper body hit”, AvatarMask | Hareketli pençe ve alınan hafif darbe | Katman ağırlıkları ve darbenin pençe hasarını kesmemesi sınandı; ayrıntılı ayak/poz karşılaştırması açık. |
| main.gd ölüm akışı | DeathTransition + GameUI | 2 sn gövde, 2.7 sn YOU DIED, sonra sonuç | Sıra testi geçti; mevcut sonuç menüsü korundu. |
| fx.gd damage_text | RevenantVfx.DamageText | Normal/crit/darbe | Ölçek düzeltildi ve son görüntüde okunabilirliği kontrol edildi. |
| Oyuncu sunumu / yeni kullanıcı hedefi | GameplayLighting + player fill | Soğuk ana/kenar ışığı, sıcak dolgu, oda yansıması | Godot genel ışığı artık hedef değil; oyun kamerasında okunabilirlik çalışması sürüyor. |
| audio.gd music / duck | MusicBlend | Oda/menü değişimi ve ölüm | İki kaynakla 1.2 sn geçiş; .35 sn menü kısılması. Dinleme testi açık. |

## Doğrulama yöntemi ve bilinen sınırlar

- 28 kaynak animation marker, içe alınmış AnimationClip olaylarıyla saniye
  cinsinden tek tek karşılaştırılıyor. ModelImporter olay zamanı **normalize**
  edilir; AnimationClip.events zamanı saniyedir. Frame formülü `(frame-1)/60`.
- Gerçek Animator ile normal ve 2× hız, tek temas, duraklatma, hit-stop,
  teleport iptali, oda değişimi, işaret devri, ölüm sırası, hareketli bacak ve
  darbe katmanı: 34 kontrol geçti.
- 66 data/asset + mevcut 50 runtime contract, beş sınıf/oda/gece akışı geçti.
  Bu testler kapsamlı AI, görsel eşitlik veya gerçek oyuncu kabulü değildir.
- Görüntü karşılaştırması town_gateyard_01, 1600×900, ortografik dikey 9 m;
  kamera Godot (+12,14,16), Unity (-12,14,16). Karakter iki motorda -Z yönüne
  bakar. Saldırı 1/2 .3 sn, saldırı 3 .4 sn, ulti ~1.05 sn örnekleri.
- Pençe karşılaştırması yeniden ölçüldü: Godot offscreen pencere çizimi eski kareyi
  döndürüyordu. RenderingServer.force_draw(false) sonrası -Z yönü ve attack1 pozu
  Unity ile eşleşti. Godot kaynaklarına veya saldırı dönüşüne gereksiz değişiklik yapılmadı.
- Godot yalnız VFX davranışı, animasyon ve menü/UI kaynağıdır. Genel görüntü
  hedefi kullanıcının ArtDirection klasöründeki dört görselidir. Mevcut Unity
  görüntüsü bu kaliteye henüz ulaşmadı; port testleri görsel kabul değildir.
- İlk QA'da editör arama indekslemesi hata verdi; yalnız ayrı QA projesindeki
  UserSettings/Search.settings indexOnEditorStartup=false yapıldı. Oyun
  hataları filtrelenmedi. Son test turunda bu hata yok.
- Sinematik gerçek zaman kullanır; smoke testinde Time.captureDeltaTime=0
  gerekir. Sabit zaman yalnız kare karşılaştırmasına ayrıldı.

## Yeniden üretme

1. `python3 unity/export_vfx.py`: kaynak GLB'leri hash ile JSON mesh verisine
   çevirir; X aynalanır, winding ters çevrilir. Kaynak dosyalara yazmaz.
2. Unity menüsü `Bloodwake > Import Revenant VFX and Events`: mesh/materyal/
   prefab, animation event ve maskeli Revenant katmanlarını üretir.
3. `Bloodwake > Build Imported Game` de bu adımı içerir (bu kapsamlı komut
   ana sahneyi ve diğer prefabları da yeniden üretir).
4. İzole Play Mode sürücüsünden `Bloodwake.Editor.RevenantChecks.Run(game)`
   çalıştırılabilir. Test mevcut run'ı değiştirir; kişisel profilde çalıştırma.

## Warrior ve ortak efektlerde bu oturum

Warrior modeli `warrior_player` olarak korundu. Kaynak blade_arc ve combat_surface
shaderlarıyla saldırı yayı ve üç vuruşlu whirl efektleri eklendi. Sıçrama ve
war cry için kaynak zemin çatlağı, taş parçaları ve toz eklendi. Kaynak sıçrama
süresi/eğrisi ve düşman yavaşlatma oranı uygulandı. Dört saldırı, whirl, sıçrama
ve war cry Unity görüntüleri kontrol edildi. Warrior için Godot ile aynı karede
birebir karşılaştırma ve tüm temas zamanlarının olaylara taşınması henüz yapılmadı.

## Kullanıcı görsel hedefleri ve ilk uygulama

- Revenant: koyu kırmızı sıvı kan; modeli kapatmayan hacim ve sıçrama.
- Mage: mor büyü çizgileri, mavi/mor buz kristalleri, sis ve keskin parlak kenarlar.
- Warrior: mevcut warrior_player; ağır darbe, taş kırılması, toz ve sıcak kıvılcım.
- Gunslinger: mevcut Bloodhound; namlu ateşi, sıcak mermi izi, duman ve darbe.
- Ortak: ıslak taş, sıcak meşale/soğuk ortam dengesi, ayrıntısı okunabilen
  karakter, gotik çevre. Mevcut menü ve resimli geçiş tasarımları korunur.

İlk uygulama: ACES/SMAA, oda başına tek yansıma yakalama, normal/ARM dokulu
ıslak avlu taşı, meşale alevleri. Taş dokuları Poly Haven Cobblestone Floor 08,
CC0; kaynak ve hash kontrolü kaynak klasörünün SOURCE.txt dosyasındadır.
14 Ekim güncellemesi: elle yakalanan küpün normal mip zinciri kaldırıldı; oda
başına bir kez, Unity realtime ReflectionProbe / ViaScripting ile filtreli HDR
yansıma üretiliyor. Her kalite seviyesinde realtimeReflectionProbes açık. GPU
okumasında beş mip siyah olmayan enerji ve azalan varyansla doğrulandı; eski
SingleCameraRequest derinlik uyarısı kalktı. GPU kare maliyeti henüz ölçülmedi.
Çevre geometrisinin bir kısmı kullanıcı modelleriyle değiştirildi (README).

Mage meteor yolu, büyü patlaması, kristal çıkışı/sönüşü ve sis eklendi.
Frost Nova temas gecikmesi .45 sn; kristallerin .11 sn çıkış, .2 sn bekleme,
.22 sn sönüş ve .012 sn kademesi kaynak fx.gd davranışını izler.
Yeni mor/buz paleti kullanıcı hedefidir. Kristal yüzeyinde kırılma çizgileri
ve yarı saydam kenar efekti vardır; fiziksel refraction uygulanmadı.
Gunslinger için sıcak mermi, .07 sn namlu parlaması, duman, darbe ve
sağ/sol WeaponSocket çıkışı eklendi. Beşli atışın son teması iki elden çıkar.
Bu sınıfların tüm temasları henüz AnimationEvent'e taşınmadı.

Bunlar ilk görsel geçiştir. Çevre ayrıntısı, modellerin karanlık zeminden
ayrılması, kanın doğal biçimi, kristallerin çeşitliliği, performans ve bütün
kamera yönlerinde okunabilirlik hâlâ kabul bekler.

## Mage orb ve VFX geri kazanımı — son çalışma

- Kaynak `visual.gd` / `fx.gd` orb çekirdeği, dönen üç kavisli kabuk,
  enerji noktaları ve plazma izi Unity'ye aktarıldı. Oyuncu ve düşman büyücüsünün
  elde taşıdığı orb gerçek RightHand kemiğini LateUpdate ile takip eder.
- Kaynak arcane shader denklemleri `arcane_core`, `arcane_trail`,
  `arcane_flame` shaderlarına aktarıldı. Godot yeşili yerine kullanıcı hedefindeki
  mor/mavi renk kullanıldı. Düşman büyüsü pembe/kırmızıyla ayrılır.
- Normal atış, Q meteor ve alev tacı, E sıçrama izi/iniş patlaması,
  Space kristal patlaması Unity 6000.3.25f1'de ayrı görüntülerle incelendi.
  Eldeki orb ulti sırasında büyür. Yeteneğin temasları hâlâ coroutine zamanlı;
  Mage AnimationEvent geçişi ve Godot ile kare bazında hareket karşılaştırması açık.
- Elden çıkan atış, eski sabit yükseklikteki küreyi kaçırabiliyordu. Dost mermileri
  artık mermi yolunu düşmanın boyuna göre dikey gövde ekseniyle karşılaştırır;
  kaynak çarpışma yarıçapları korunur. Düşman mermi çarpışması değiştirilmedi.
- 14 Mage kontrolü: çekirdek/kabuk/halo, ele bağlanma, hareket/animasyon takibi,
  menü/hit-stop durması, görünürlük, atış/orb/iz, gerçek düşmana hasar,
  oda geçişinde tek orb, düşman orb, ölüm ve sınıf değişimi temizliği geçti.
- Oyuncu ve düşman modellerine ayrı ışık katmanında yumuşak dolgu eklendi.
  Zemin ıslaklığı düzenli dalga yerine düzensiz yamalarla dağıtıldı.
- Büyük turuncu düz yüzeyin `ExitGlow` olduğu bulundu: kaynak alpha .28,
  Unity içe alımı opaque idi. Artık kapı koşuluyla görünür, kenarları yumuşak
  saydam ışık olarak çizilir. Meşale quad'ları FBX ölçekli ebeveynlerden ayrıldı.

Görseller, efektlerin geri geldiğini gösterir; referansların ayrıntı ve kalite
seviyesine erişildiğini göstermez. Çevre geometrisi, kristallerin doğal biçimi,
efekt katmanları ve hareketli kamera okunabilirliği hâlâ geliştirme gerektirir.

## Sonraki işler

Güncel genel görsel hedef Godot değil, ArtDirection/ içindeki kullanıcı referanslarıdır.
Önce referans avlusunda malzeme/ışık/VFX kalitesi ve gerçek hareketli ayak/temas incelemesi.
Ardından diğer karakterler, düşman/boss VFX, AI windup/recovery/stagger ve
rol davranışları, çoklu silah cooldown/upgrade kuralları, kalan animasyon,
ses miksajı, farklı ekran oranları/gamepad UI, dokunmatik ve kalite profilleri.
Windows çalıştırma ve gerçek kullanıcı oyun testi yapılmadı.

## 14 Ekim ek kontrolü

Yeni HUD, ikinci Mage nova katmanları, hareket/geri tepme ve kullanıcı çevre
modelleri sonrası aynı 66/28/34/14 + 50 kontroller tekrar geçti; yeni 8 hareket
kontrolü de geçti. Unity exit 0. Sekiz odada binalar oyun alanı dışında kalıyor.
Gerçek oda görüntüleri incelendi; çevrede eski Shed/özel yapıların kalite
farkı sürüyor. Hareket kontrolleri konum/yön ve engel durumunu sınar; bütün
kliplerin ayak kayması görsel olarak onaylanmış değildir. Mage yeni kristal
biçimleri de nihai kaliteye ulaşmadı. URP depth-buffer uyarısı açık.


## 14 Ekim — kalan modeller, portre ve referans tabanlı VFX

- Kullanıcının 10 model türü artık kullanılıyor: üç bina, sandık/fıçı, duvar,
  ateşlik, fener, örtülü masa, demir kapı. İp dosyası henüz gelmedi.
- `GateModelSplit` özgün tek mesh kapıdan çerçeve ve menteşe pivotlu iki kanat
  üretir; kaynak FBX değişmez. Sekiz oda görüntülendi; savaşta kapalı ve oda
  temizlenince açık davranışı doğrulandı. Yeni duvar ve ateşlikler özgün
  engel alanlarına ölçeklenir. Bütün eski özel yapılar yenilenmiş değildir.
- Portre UV kırpımı beş sınıfa göre yüz merkezli düzeltildi; sınıf değişiminde
  HUD yenilenmesi düzeltildi. Beş sınıf gerçek Unity karelerinde incelendi.
- ImageGen built-in iki VFX faz tasarım sayfası üretti. Mage için hazırlık,
  temas, sönme kareleri alındı. Meteor/sıçrama izleri, kristal şekli/materyali,
  sis; Warrior sıcak çatlak ve Gunslinger namlu ışığı geliştirildi.
- Tasarım sayfaları ve gerçek oyun kareleri ayrı tutulur. Görsel hedef henüz
  karşılanmadı: doğal parçalanma/yoğunluk, hareketli vuruş tepkileri ve tüm
  düşman/boss efektleri açık. Yeni shaderların GPU maliyeti ölçülmedi.

Son değişikliklerle tekrar çalıştırma: 66 data/asset, 28 event zamanı, 34 Revenant,
14 Mage, 8 hareket/geri tepme, 50 davranış ve beş sınıf smoke geçti; exit 0.
Ana proje ile izole QA C# ve shader dosyaları birebir eşleşiyor.


## Referans karşılaştırması v5

- Mage: 52 farklı ölçek/açılı buz levhası, zemin kırığı shaderı, düşük yayılan sis;
  düzenli radyal çizgiler azaltıldı. Hazırlık ve sönüş şeffaflığı düzenlendi.
- Warrior: kaynak taş materyalli parçalar, artan toz hacmi, kısa sıcak temas ışığı.
- Revenant: 25 ince kan kolu, 55 balistik damla, kaynak enerji katmanı azaltıldı.
- Gunslinger: sivrilen ince mermi izi, daha görünür duman.
- Görsel darbe pozu 0.28 s içinde toparlanır, root konumuna etki etmez.
  11 hareket/geri tepme kontrolü geçti.
- Alt yetenek yuvaları ImageGen built-in şeffaf çerçeve kullanıyor.
- Sokak/duvar dibi küçük sandık ve fıçılar da kullanıcı modelleriyle değişiyor.
- Dört sınıfın 30 fps kontrollü Unity savaş kaydı alındı. Buz/kan şekillerinin
  doğallığı, çevre çeşitliliği, bütün düşman/boss efektleri ve GPU maliyeti hâlâ açık.
- Disk dolması v5 ilk çekimini kesti. Kullanıcının yer açma izniyle kullanımda
  olmayan iPhone 26.6.1 Xcode cihaz sembol önbelleği temizlendi (~10 GB).
  Kaynak modeller, kişisel dosyalar, Xcode projeleri ve arşivler korundu;
  aynı çekim tekrar çalıştırılarak exit 0 ile tamamlandı.

Son v5 kaynaklarıyla kontrol tekrarı: 66 veri/asset, 28 event zamanı, 34 Revenant,
14 Mage, 11 hareket/geri tepme, 50 davranış, beş sınıf smoke: exit 0.
Kayıtlar --burst-disable-compilation ile alındı; performans karşılaştırması değildir.
