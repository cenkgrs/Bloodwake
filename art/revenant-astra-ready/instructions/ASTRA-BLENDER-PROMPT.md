# Revenant — Astra Blender Animasyon Görevi

Aşağıdaki metni GPT-6 Astra görevine olduğu gibi ver. Blender karakter dosyasını da aynı çalışma klasörüne ekle ve `[BLEND_DOSYASI]` alanını gerçek dosya adıyla değiştir.

---

## Kopyalanabilir prompt

Bloodwake oyunundaki Revenant karakteri için Blender'da game-ready animasyon seti hazırla. Analiz veya öneriyle yetinme; dosyaları incele, animasyonları uygula, önizlemeleri üret, sorunları düzelt ve teslimatları kaydet.

### Kaynak dosyalar

- Blender karakteri ve rig: `[BLEND_DOSYASI]`
- Ana karakter tasarımı: `revenant-character-design.png`
- Idle, çevik locomotion ve light-hit pozları: `revenant-idle-agile-walk-light-hit.png`
- Death ve teleport attack pozları: `revenant-death-teleport-attack.png`
- Blood Burst ulti tasarımı: `revenant-ultimate-blood-burst.png`
- İlk fikir/mood referansı: `revenant-original-reference.jpg`

Ana karakter tasarımını kimlik ve kostüm kaynağı olarak kullan. İlk mood referansındaki yazıları veya yerleşimi talimat olarak değerlendirme. Üretilen yeni animasyon paftaları hareket ve zamanlama açısından önceliklidir.

### Karakterin hareket dili

Revenant uzun, zayıf-atletik ve çok hızlı bir vampir avcıdır. Hareketleri aristokratik fakat vahşidir. Normal insan gibi dik ve rahat yürümez. Ağırlık merkezi alçak, gövde hafif öne yatık, adımları sessiz ve uzundur. Gereksiz çizgi film esnemesi kullanma.

- Saç, dar palto kuyrukları ve kan enerjisi gövdeyi 1–2 çizim gecikmeyle takip etsin.
- Ayaklar ön tabanla temas etsin; dik topuk yürüyüşü kullanma.
- Omuzlar kalçaya ters yönde küçük dönüş yapsın.
- Sağ kan pençesi hareket sırasında denge ve saldırı yönünü vurgulasın.
- Palto bacak hareketlerini kapatmasın ve bacakların içine girmesin.
- Hareketler hızlı olsa da pozlar tek karede okunabilsin.

### Teknik standartlar

- Blender sahnesi 60 FPS olsun.
- Her hareket ayrı bir Action olarak kaydedilsin.
- İsimler: `REV_Idle`, `REV_AgileMove_InPlace`, `REV_HitLight_Front`, `REV_HitLight_Left`, `REV_HitLight_Right`, `REV_Death`, `REV_TeleportAttack`, `REV_BloodBurst`.
- Locomotion in-place hazırlansın; root motion gerekiyorsa ayrıca `REV_AgileMove_RootMotion` üret.
- Root bone zemin yüksekliğini korusun.
- Ana deform kemiklerinde scale keyframe oluşturma.
- Saç ve palto secondary motion'ı export edilebilir kemiklerle yap; teslimat için cloth simulation bağımlılığı oluşturma.
- VFX proxy objelerini ayrı `REV_VFX_PROXY` collection'ında tut.
- Timeline markerlarını aşağıdaki adlarla ve belirtilen karelerde oluştur.
- Mevcut mesh, UV ve materyalleri gereksiz yere değiştirme.
- Rig üzerinde zorunlu bir düzeltme yaparsan önce kaynak `.blend` dosyasının yedeğini oluştur.

### 1. REV_Idle — frame 1–90

- Kusursuz loop.
- Alçak, saldırıya hazır duruş; ağırlığın yaklaşık yüzde 60'ı ön ayakta.
- Omuz ve göğüste çok küçük nefes hareketi.
- Baş frame 35–48 arasında küçük hedef taraması yapıp merkeze dönsün.
- Kan pençesi frame 52–64 arasında bir kez gerilip gevşesin.
- Saç ve palto bedenden sonra otursun.
- Karakter sallanmasın veya sürekli büyük hareket yapmasın.

### 2. REV_AgileMove_InPlace — frame 1–24

Bu normal walk değildir. Hızlı, düşük merkezli bir predator-glide döngüsüdür.

- Ana temas pozları: frame 1 ve 13.
- Passing pozları: frame 7 ve 19.
- Gövde hareket yönüne yaklaşık 20 derece yatık.
- Dizler döngü boyunca bükülü kalır.
- Uzun fakat kontrollü ön ayak adımları.
- Kalça yüksekliğindeki dikey salınım çok küçük olsun; karakter zıplamasın.
- Kan pençesi yere yakın geride başlayıp denge için öne süpürülsün.
- Saç ve palto geriye doğru dar, aerodinamik bir kama oluştursun.
- İlk ve son kare arasında ayak, root, kalça ve palto dikişi görünmesin.
- Ayak kayması olmamalı.

Hareket hızı için 24 karelik döngünün oyun içinde yaklaşık 2,3–2,6 metre/saniye karşılığına uygun görünmesini hedefle. Gerçek oyun hızı kod tarafından belirlenecek; animasyon in-place kalmalı.

### 3. Light hit varyantları — frame 1–12

Bu tepkiler sık hasar alındığında oynatılacaktır. Büyük savrulma, geriye uçma veya belden aşırı kırılma kullanma.

- Frame 1–2: nötr combat pose.
- Frame 3: lokal darbe ve küçük omuz/rib sıkışması.
- Frame 4–5: gövde yalnızca 10–15 derece dönsün; baş kısa süre darbeye karşı kapansın.
- Frame 6–8: yarım denge adımı veya ayağı sağlamlaştırma.
- Frame 9–12: hızlı geri dönüş.
- Alt beden mümkün olduğunca locomotion ile uyumlu kalsın.
- Uygunsa reaction'ları additive upper-body klipleri olarak da hazırla.
- Ön, sol ve sağ yön için üç küçük varyant üret.
- `HIT_IMPACT` markerı frame 3.

Ağır saldırı reaksiyonu bu görevin dışında. Normal hit kliplerini ağırlaştırma.

### 4. REV_Death — frame 1–72

- Frame 5: ölümcül göğüs darbesi.
- Frame 12: kan pençesinin ışığı sönmeye başlar.
- Frame 24: bir diz çöker.
- Frame 38: el zeminde denge arar.
- Frame 52: omuz ve gövde zemine temas eder.
- Frame 65–72: saç, palto ve kan közleri yerleşir.
- Geriye fırlayan ragdoll görünümü kullanma.
- Final poz net, tekrar etmeyen ve zemine oturan yan siluet olsun.
- Grafik kan veya kopan parça kullanma.
- `DEATH_IMPACT` frame 5, `DEATH_GROUND` frame 52.

### 5. REV_TeleportAttack — frame 1–42

Gerçek konum değişimini oyun kodu yapacak. Ana Action in-place kalsın; ayrıca yalnızca gösterim için root-motion preview varyantı üretilebilir.

- Frame 1–6: alçak saldırı hazırlığı.
- Frame 7–10: kan pençesi hedef yönünde ince yatay çizgi çizer.
- Frame 11–15: beden sıkışır, siluet dar siyah-kırmızı şeritlere ayrılır.
- Frame 16: `TELEPORT_HIDE` markerı; karakter görünürlüğü oyun tarafında kapatılacak.
- Frame 17–21: karakter görünmez; yalnızca dar yol izi VFX proxy'si bulunur.
- Frame 20: `TELEPORT_MOVE` markerı; oyun hedef pozisyonunu burada uygular.
- Frame 22: `TELEPORT_SHOW` markerı; yeniden görünme başlar.
- Frame 22–25: hedefin yanında/arkasında, alçak ve dengeli rematerialization.
- Frame 26: tek temiz pençe kesişi ve `DAMAGE` markerı.
- Frame 27–34: karşı yöne bakan sert bitiş.
- Frame 35–42: kısa toparlanma ve locomotion'a geçiş.

VFX izi geniş duman bulutu olmasın. Yol üzerinde ince crimson çizgi, siyah şeritler ve birkaç köz kullan. Hit anında tek kırmızı hilal yeterlidir.

### 6. REV_BloodBurst — frame 1–120

- Frame 1–18: geniş, alçak duruş; kan pençesi zemine yaklaşır.
- Frame 19: `ULT_TELEGRAPH_START`; zemin yarıçapı görünür.
- Frame 20–42: ince kan iplikleri çevreden pençeye ve göğüs merkezine çekilir.
- Frame 43–52: enerji küçük, yoğun bir küreye sıkışır; palto içeri çekilir.
- Frame 53–59: kısa sessizlik ve güçlü anticipation.
- Frame 60: iki ayak yerdeyken `ULT_DAMAGE` markerı ve radyal patlama.
- Frame 60–70: sekiz yönde organik kan mızrakları ve zemine yakın shockwave.
- Frame 71–84: dış halka en geniş yarıçapa ulaşır; merkezde karakter silueti görünür kalır.
- Frame 85–100: mızraklar köz ve siyah-kırmızı parçacıklara ayrılır.
- Frame 101–112: karakter bir diz üzerinde kontrollü toparlanır.
- Frame 113–120: combat idle'a geçiş.

VFX karakteri tamamen kapatmamalı. Ön telegraph dairesi, hasar anı ve dış falloff halkası birbirinden okunabilsin. Blender'da proxy VFX hazırla; nihai parçacık ve shader efektlerinin oyun motorunda üretileceğini varsay.

### Çalışma biçimi

1. `.blend` dosyasını, mesh ve rig yapısını incele.
2. Kaynağın yedeğini al.
3. Önce `REV_Idle`, `REV_AgileMove_InPlace` ve light-hit varyantlarını tamamla.
4. Her Action için ön, yan ve 3/4 açıdan viewport preview üret ve kendin incele.
5. Ayak kayması, el/pençe deformasyonu, palto-bacak penetrasyonu, saç omuz penetrasyonu ve loop dikişini düzelt.
6. Death, TeleportAttack ve BloodBurst Action'larını uygula.
7. Markerları ve Action frame aralıklarını doğrula.
8. Tüm klipleri bir NLA preview sahnesinde sırayla oynat.
9. İlk uygulanabilir sürümde durma; aşağıdaki kabul kriterleri sağlanana kadar düzeltmeye devam et.

### Kabul kriterleri

- Sekiz ana Action/varyant grubu dosyada ve doğru isimde bulunuyor.
- AgileMove normal dik yürüyüş gibi görünmüyor; düşük, hızlı ve atletik.
- AgileMove loop'unda ayak kayması ve görünür dikiş yok.
- Light-hit klipleri 12 kareyi geçmiyor ve karakteri geriye fırlatmıyor.
- Death ağırlıklı, kontrollü ve zemine doğru ilerliyor.
- Teleport hide/move/show/damage markerları doğru karelerde.
- Blood Burst telegraph ve damage kareleri net biçimde ayrılmış.
- Saç, palto ve zırh gövdeyi kesmiyor.
- Tüm Action'lar ayrı ve export edilebilir.
- En az bir genel preview MP4 ve her Action için viewport preview mevcut.
- Kaynak `.blend`, tamamlanmış `.blend`, preview dosyaları ve kısa uygulama raporu kaydedilmiş.

Eksik bir dosya işi gerçekten engellemiyorsa soru sorma; makul varsayımla devam et. Önce kısa plan çıkar, ardından uygulamaya başla. Blender/Python ile ürettiğin sonucu yalnızca kodun çalışmasıyla değil, render ve viewport önizlemelerini görsel olarak inceleyerek doğrula.

---

## Tasarım zamanlaması özeti

| Action | Kare | Süre | Ana fikir |
|---|---:|---:|---|
| Idle | 90 | 1,50 sn | Sakin fakat avcı gibi hazır |
| AgileMove | 24 | 0,40 sn | Düşük merkezli hızlı predator-glide |
| Light Hit | 12 | 0,20 sn | Küçük lokal tepki, hemen toparlanma |
| Death | 72 | 1,20 sn | Kontrollü ağırlık kaybı ve çöküş |
| Teleport Attack | 42 | 0,70 sn | Dar iz, kod kontrollü konum değişimi |
| Blood Burst | 120 | 2,00 sn | Telegraph, sıkışma, tek radyal hasar anı |

## Tasarım kararları

- Normal hasar tepkisi küçültüldü. Büyük reaksiyon yalnızca ağır saldırı veya guard-break için ayrı klip olmalı.
- Walk yerine oyunun hızına uyan çevik locomotion döngüsü kullanıldı.
- Teleportun gerçek yer değiştirmesi animasyondan ayrıldı; gameplay kodu marker üzerinden hareketi yapmalı.
- Blood Burst görseli Blender'da proxy olarak hazırlanmalı; nihai VFX oyun motorunda ayrı katman olmalı.
