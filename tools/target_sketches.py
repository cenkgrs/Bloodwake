#!/usr/bin/env python3
"""Target-design sketches: paint-overs on the game's own camera captures.

The capture is desaturated and dimmed; what each room should gain is drawn over it in pencil strokes and
numbered, with the legend on the right. Writes art/concepts/hedef/<room>.png.
"""
import math, random
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

ROOT = "/home/cenkargevim/Desktop/Cenk/roughlike/"
FONT = ROOT + "unity/Assets/Bloodwake/Resources/fonts/spectral.ttf"
BOLD = ROOT + "unity/Assets/Bloodwake/Resources/fonts/spectral_semibold.ttf"
INK = (236, 214, 168)
NEW = (255, 196, 110)
rnd = random.Random(7)


class Sketch:
    def __init__(self, capture, title, subtitle, cold):
        base = Image.open(capture).convert("RGB")
        base = ImageEnhance.Color(base).enhance(.25)
        base = ImageEnhance.Brightness(base).enhance(.62)
        tone = (40, 52, 78) if cold else (70, 46, 30)
        base = Image.blend(base, Image.new("RGB", base.size, tone), .18)
        self.img = Image.new("RGB", (base.width + 620, base.height), (14, 12, 13))
        self.img.paste(base, (0, 0))
        self.d = ImageDraw.Draw(self.img, "RGBA")
        self.w = base.width
        self.notes = []
        self.title, self.subtitle = title, subtitle

    # A pencil line: a few jittered passes.
    def line(self, pts, width=3, passes=3, jitter=2.2, color=INK):
        for _ in range(passes):
            p = [(x + rnd.uniform(-jitter, jitter), y + rnd.uniform(-jitter, jitter)) for x, y in pts]
            self.d.line(p, fill=color + (190,), width=width, joint="curve")

    def poly(self, pts, **k):
        self.line(pts + [pts[0]], **k)

    def ellipse(self, cx, cy, rx, ry, start=0, end=360, steps=48, **k):
        pts = [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a)))
               for a in [start + (end - start) * i / steps for i in range(steps + 1)]]
        self.line(pts, **k)

    def hatch(self, x0, y0, x1, y1, step=10, color=INK):
        for i in range(int((x1 - x0 + y1 - y0) / step)):
            a = (x0 + i * step, y0)
            b = (x0 + i * step - (y1 - y0), y1)
            self.d.line([a, b], fill=color + (70,), width=1)

    def note(self, x, y, text):
        n = len(self.notes) + 1
        self.notes.append(text)
        f = ImageFont.truetype(BOLD, 26)
        self.d.ellipse([x - 19, y - 19, x + 19, y + 19], fill=(20, 14, 10, 230), outline=NEW + (255,), width=3)
        self.d.text((x, y + 1), str(n), font=f, fill=NEW, anchor="mm")

    def save(self, path):
        d = self.d
        x = self.w + 36
        d.text((x, 40), self.title, font=ImageFont.truetype(BOLD, 40), fill=NEW)
        d.text((x, 92), self.subtitle, font=ImageFont.truetype(FONT, 22), fill=(190, 178, 160))
        y = 150
        f = ImageFont.truetype(FONT, 24)
        for i, t in enumerate(self.notes, 1):
            d.ellipse([x, y, x + 32, y + 32], outline=NEW + (255,), width=3)
            d.text((x + 16, y + 17), str(i), font=ImageFont.truetype(BOLD, 20), fill=NEW, anchor="mm")
            lines = wrap(t, f, 520)
            for j, l in enumerate(lines):
                d.text((x + 46, y + 2 + j * 30), l, font=f, fill=(232, 222, 205))
            y += 30 * len(lines) + 22
        d.text((x, self.img.height - 40), "Soluk: oyunun bugünkü hali  ·  Kalem: hedef", font=ImageFont.truetype(FONT, 20), fill=(150, 140, 125))
        self.img.save(path)


def wrap(text, font, width):
    out, cur = [], ""
    for word in text.split():
        t = (cur + " " + word).strip()
        if font.getlength(t) > width and cur:
            out.append(cur)
            cur = word
        else:
            cur = t
    return out + [cur]


def cap(room):
    return f"/tmp/bloodwake-keep-{room}-middle.png"


OUT = ROOT + "art/concepts/hedef/"

# ---------------- 1. HARİTA: Kara Çan (boss)
s = Sketch(cap("town_boss_blackbell_01"), "KARA ÇAN", "1. Harita · boss meydanı · sıcak, açık, ateş ışığı", cold=False)
# Fallen bell on its side, mouth toward the sigil.
bx, by = 1180, 300
s.ellipse(bx - 120, by + 40, 70, 95, width=4)                       # mouth rim
s.line([(bx - 120, by - 55), (bx + 90, by - 10), (bx + 130, by + 40), (bx + 90, by + 95), (bx - 120, by + 135)], width=4)
s.line([(bx + 130, by + 40), (bx + 175, by + 40)], width=4)         # crown loop
s.ellipse(bx + 190, by + 40, 18, 22, width=3)
s.line([(bx - 40, by - 30), (bx - 10, by + 30), (bx - 30, by + 70)], width=2)   # crack
s.hatch(bx - 100, by - 40, bx + 80, by + 120, step=14)
s.note(bx + 40, by - 80, "Kuleden düşmüş dev çan, yan yatmış, çatlak; ağzı meydana bakıyor (Tripo: fallen_bell)")
# Ring of candles round the sigil.
cx, cy = 840, 460
for a in range(0, 360, 20):
    x, y = cx + 360 * math.cos(math.radians(a)), cy + 185 * math.sin(math.radians(a))
    s.line([(x, y), (x, y - 26)], width=4, passes=2, color=NEW)
    s.d.ellipse([x - 4, y - 36, x + 4, y - 26], fill=NEW + (200,))
s.note(cx + 380, cy + 60, "Sembolün çevresinde mum halkası; boss arenasının sınırı ışıkla çizilir")
# Collapsed tower debris top-left.
s.poly([(120, 260), (210, 150), (300, 200), (360, 120), (470, 210), (430, 300), (260, 330)], width=4)
for x0 in (180, 260, 340):
    s.line([(x0, 300), (x0 + 120, 170)], width=5)
s.hatch(140, 160, 460, 320, step=16)
s.note(300, 100, "Çan kulesinin yıkıntısı: taş blok yığını ve kırık kirişler; oda kenarında siper")
# Bell rope hanging from the dark.
s.line([(1010, 0), (1020, 150), (1012, 260)], width=3)
s.note(1050, 170, "Yukarıdan sarkan kopuk çan ipi; kameranın tepesinde derinlik verir")
# Gravestones bottom-right.
for i, x in enumerate((1120, 1220, 1320, 1420)):
    y = 690 + (i % 2) * 30
    s.line([(x, y), (x, y - 70), (x + 18, y - 90), (x + 36, y - 70), (x + 36, y)], width=3)
s.note(1270, 820, "Meydanın köşesinde eğri mezar taşları; kasabanın gömülmemiş ölüleri")
s.save(OUT + "1_kara_can.png")

# ---------------- 1. HARİTA: Kuyu Meydanı
s = Sketch(cap("town_well_03"), "KUYU MEYDANI", "1. Harita · kasabanın kalbi", cold=False)
wx, wy = 800, 470
s.ellipse(wx, wy, 300, 155, width=4)
s.ellipse(wx, wy, 250, 128, width=2)
for a in range(0, 360, 30):
    c, si = math.cos(math.radians(a)), math.sin(math.radians(a))
    s.line([(wx + 250 * c, wy + 128 * si), (wx + 300 * c, wy + 155 * si)], width=2, passes=2)
s.note(wx + 320, wy - 40, "Kuyunun çevresinde dairesel taş döşeme (iki halka, ışınsal derz); meydanın merkezi belli olur")
s.line([(wx + 40, 300), (wx + 60, 400)], width=3)
s.poly([(wx + 45, 400), (wx + 85, 400), (wx + 80, 440), (wx + 50, 440)], width=3)
s.note(wx + 110, 300, "Makaradan sarkan zincir ve kova")
for x, y in ((wx - 200, wy + 90), (wx - 150, wy + 120), (wx + 180, wy + 100), (wx + 230, wy + 70)):
    s.line([(x, y), (x, y - 20)], width=4, color=NEW, passes=2)
s.note(wx - 230, wy + 170, "Kuyu ağzında adak mumları ve çiçek; kasabalıların kuyuya dua ettiği yer")
# Market awning wreck top-left.
s.poly([(160, 220), (420, 150), (470, 250), (210, 320)], width=4)
for x in range(180, 440, 40):
    s.line([(x, 230 - (x - 180) * .27), (x + 40, 320 - (x - 180) * .27)], width=1, passes=1)
s.line([(170, 230), (170, 380)], width=4)
s.line([(460, 250), (470, 390)], width=4)
s.note(320, 120, "Yırtık tenteli eski pazar tezgâhı, altında devrik sepetler")
# Lantern string across.
pts = [(x, 90 + 40 * math.sin(x / 1600 * math.pi)) for x in range(0, 1601, 80)]
s.line(pts, width=2)
for x, y in pts[1:-1:2]:
    s.d.ellipse([x - 9, y + 6, x + 9, y + 28], outline=NEW + (230,), width=3)
s.note(1300, 60, "Meydanın üstünden geçen fener dizisi; sıcak ışık lekeleri zemine düşer")
s.save(OUT + "2_kuyu_meydani.png")

# ---------------- 2. HARİTA: Taht Salonu
s = Sketch(cap("keep_throne_01"), "TAHT SALONU", "2. Harita · boss · soğuk, yüksek, boş", cold=True)
for x, y in ((1330, 420), (1500, 330), (1440, 560)):
    s.poly([(x - 34, y - 300), (x + 34, y - 300), (x + 34, y - 90), (x, y - 60), (x - 34, y - 90)], width=3)
    s.line([(x - 46, y - 304), (x + 46, y - 304)], width=4)
    s.hatch(x - 30, y - 290, x + 30, y - 100, step=12)
s.note(1250, 150, "Sütunların arasında yırtık bordo sancaklar, demir çubuktan sarkıyor")
cx, cy = 820, 260
s.ellipse(cx, cy, 150, 50, width=4)
s.ellipse(cx, cy, 120, 38, width=2)
s.line([(cx, 0), (cx, cy - 50)], width=3)
for a in range(0, 360, 30):
    x, y = cx + 150 * math.cos(math.radians(a)), cy + 50 * math.sin(math.radians(a))
    s.line([(x, y), (x, y - 22)], width=3, color=NEW, passes=2)
    s.line([(cx, 40), (x, y)], width=1, passes=1)
s.note(cx + 190, cy - 40, "Halının üstünde zincirle asılı büyük demir avize; mumlu, salonun tek sıcak ışığı")
s.ellipse(1080, 160, 46, 18, width=3)
s.line([(1040, 160), (1050, 125), (1065, 150), (1080, 118), (1095, 150), (1110, 125), (1120, 160)], width=3, color=NEW)
s.note(1150, 100, "Kürsünün önünde yere düşmüş kırık taç; bossun hikâyesi")
for x, y in ((330, 260), (520, 150)):
    s.poly([(x - 30, y + 60), (x + 30, y + 60), (x + 26, y - 40), (x, y - 70), (x - 26, y - 40)], width=3)
    s.line([(x, y - 70), (x, y - 120)], width=3)
s.note(430, 60, "Halı boyunca diz çökmüş taş şövalye heykelleri; boss girişine giden tören yolu")
s.save(OUT + "3_taht_salonu.png")

# ---------------- 2. HARİTA: Büyük Salon (coordinates read off a grid over the capture)
s = Sketch(cap("keep_hall_04"), "BÜYÜK SALON", "2. Harita · L biçimli ziyafet salonu", cold=True)
# Wall faces: left (40,15)-(545,215) over (40,300)-(540,475); right (600,195)-(1050,0) over (600,420)-(1100,170).
for off in (0, 22):
    s.line([(40, 15 + off), (545, 215 + off)], width=4 if off == 0 else 2)
    s.line([(600, 195 + off), (1050, 0 + off)], width=4 if off == 0 else 2)
for off in (0, -36):
    s.line([(40, 300 + off), (540, 475 + off)], width=4 if off == 0 else 2)
    s.line([(600, 420 + off), (1100, 170 + off)], width=4 if off == 0 else 2)
s.hatch(40, 264, 540, 300, step=9)
s.note(560, 540, "Duvar üstünde taş silme, dibinde kalın kaide; düz kutu duvar yerine katmanlı kale duvarı")
# Windows: pointed arch over each opening, a stone mullion down the middle.
for x0, x1, y0, y1 in ((110, 175, 85, 245), (415, 480, 210, 380), (680, 725, 125, 300), (905, 955, 20, 130)):
    cx = (x0 + x1) / 2
    s.line([(x0 - 8, y1 + 6), (x0 - 8, y0), (cx, y0 - 48), (x1 + 8, y0), (x1 + 8, y1 + 6)], width=4)
    s.line([(cx, y0 - 30), (cx, y1)], width=2)
s.note(250, 60, "Pencereler içe gömük, sivri kemerli, ortada taş dikme")
for x, y in ((250, 175), (860, 170)):
    s.ellipse(x, y, 20, 24, width=3)
    s.line([(x - 18, y - 12), (x - 52, y - 58), (x - 40, y - 86)], width=3)
    s.line([(x + 18, y - 12), (x + 52, y - 58), (x + 40, y - 86)], width=3)
s.note(890, 260, "Pencere aralarında av kupaları (boynuzlu kalkanlar)")
for x, y in ((1060, 488), (1130, 450), (1200, 410), (1268, 372)):
    s.ellipse(x, y, 20, 8, width=3, color=NEW)
    s.line([(x + 30, y - 22), (x + 30, y)], width=3, color=NEW)
s.note(1180, 560, "Masada tabak, kadeh, devrik şarap testisi; yarıda bırakılmış ziyafet")
cx, cy = 1150, 230
s.line([(cx, 0), (cx, cy - 36)], width=3)
s.ellipse(cx, cy, 120, 36, width=4)
for a in range(0, 360, 36):
    x, y = cx + 120 * math.cos(math.radians(a)), cy + 36 * math.sin(math.radians(a))
    s.line([(x, y), (x, y - 18)], width=3, color=NEW, passes=2)
s.note(cx + 160, cy - 40, "Masanın üstünde zincirle asılı ikinci büyük avize")
s.save(OUT + "4_buyuk_salon.png")
print("ok")
