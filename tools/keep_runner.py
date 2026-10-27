#!/usr/bin/env python3
"""The keep's runner carpet: one long woven strip that tiles seamlessly along its length.

Crimson field with stepped lozenge medallions repeating down the middle, a navy border of small rosettes,
gold guard stripes and a cream edge; weave grain, wear down the walking line. 1024 x 4096, two medallions
per tile. Writes <out>/keeprunner_albedo.png and keeprunner_normal.png (relief from the weave and motif).
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

W, H = 1024, 4096
out = sys.argv[1]
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
u = (x + .5) / W                      # across, 0..1
v = (y + .5) / H                      # along, 0..1 (tiles)

CRIMSON = np.array([118, 16, 22]); DEEP = np.array([70, 8, 14]); NAVY = np.array([24, 28, 52])
GOLD = np.array([176, 132, 58]); CREAM = np.array([206, 186, 146]); IVORY = np.array([180, 160, 122])
img = np.zeros((H, W, 3), np.float32) + CRIMSON

def band(a, b):
    return (u >= a) & (u < b) | (u > 1 - b) & (u <= 1 - a)

img[band(0, .025)] = CREAM
img[band(.025, .04)] = DEEP
img[band(.04, .055)] = GOLD
img[band(.055, .17)] = NAVY
img[band(.17, .185)] = GOLD
img[band(.185, .2)] = DEEP

# Rosettes down the navy border, every 1/16 of the tile.
bc = np.where(u < .5, .1125, .8875)
period = 1 / 16
dv = ((v + period / 2) % period - period / 2) * H / W     # in units of width
du = u - bc
r = np.sqrt(du ** 2 + dv ** 2)
ang = np.arctan2(dv, du)
petal = .032 + .012 * np.cos(ang * 6)
inborder = band(.055, .17)
img[inborder & (r < petal)] = IVORY
img[inborder & (r < .012)] = CRIMSON
# Small gold diamonds between rosettes.
dv2 = (((v) % period) - period / 2) * H / W
img[inborder & (np.abs(du) + np.abs(np.where(np.abs(dv2) < 1, dv2, 9)) < .014) & (r > petal)] = GOLD

# Field: stepped lozenges, two per tile, centred.
fu = (u - .5) / .3                    # -1..1 across the field
period = .5
fv = ((v + period / 2) % period - period / 2) / period * 2 * (H * period / W) / .6   # aspect-corrected
d = np.abs(fu) + np.abs(fv) / 2.2     # diamond distance, elongated along the strip
step = np.floor(d * 9) / 9            # stepped (woven) outline
field = (u >= .2) & (u <= .8)
def ring(a, b, col):
    m = field & (step >= a) & (step < b)
    img[m] = col
ring(0, .12, GOLD)
ring(.12, .23, NAVY)
ring(.23, .34, IVORY)
ring(.34, .46, DEEP)
ring(.46, .57, GOLD)
ring(.57, .68, CRIMSON)
ring(.68, .79, DEEP)
# A faint lattice of small diamonds over the open field.
lat = field & (step >= .79)
lu = (u - .5) * W / 64; lv = v * H / 64
cell = np.abs((lu % 1) - .5) + np.abs((lv % 1) - .5)
img[lat & (np.abs(cell - .5) < .035)] = DEEP
img[lat & (cell < .09)] = GOLD * .8
# Hooks off the medallion tips (small crosses along the axis).
tip = field & (np.abs(fu) < .05) & ((np.abs(np.abs(fv) - 1.95) < .05) | (np.abs(np.abs(fv) - 2.15) < .05))
img[tip] = GOLD
# Corner motifs between medallions: small diamonds near the field edges.
cv = ((v % period) / period - .0)
corner = field & (np.abs(np.abs(fu) - .78) + np.abs((((v + period * .5) % period) - period / 2) / period * 6) < .12)
img[corner] = IVORY

# Weave grain, slubs and wear.
rng = np.random.default_rng(3)
grain = rng.normal(0, 1, (H, W)).astype(np.float32)
grain = np.asarray(Image.fromarray(((grain * 18) + 128).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(.6)), np.float32) / 128 - 1
rows = (np.sin(y * np.pi / 3.0) * .5 + .5) * .08          # horizontal weave rows
low = np.asarray(Image.fromarray(rng.integers(0, 255, (H // 64, W // 64), dtype=np.uint8)).resize((W, H), Image.BICUBIC), np.float32) / 255
wear = 1 - .22 * np.exp(-((u - .5) / .18) ** 2) * (.6 + .4 * low)       # the walking line is faded
shade = (1 + grain * .09 - rows) * wear * (.9 + .2 * low)
img = (img * shade[..., None]).clip(0, 255)
Image.fromarray(img.astype(np.uint8)).save(out + "/keeprunner_albedo.png")

lum = np.asarray(Image.fromarray(img.astype(np.uint8)).convert("L").filter(ImageFilter.GaussianBlur(1.0)), np.float32) / 255
gy, gx = np.gradient(lum)
n = np.dstack([-gx * 5, gy * 5, np.ones_like(lum)])
n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(((n * .5 + .5) * 255).astype(np.uint8)).save(out + "/keeprunner_normal.png")
print("ok")
