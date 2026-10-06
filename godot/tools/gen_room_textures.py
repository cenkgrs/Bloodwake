#!/usr/bin/env python3
"""Tileable PBR textures for the grey-box rooms: albedo + normal per surface.

Every texture is periodic by construction (FFT noise, wrapped Voronoi, pattern
coordinates taken modulo the tile), so a world-space triplanar material can
repeat it across a 30 m courtyard without a seam. Palette follows the
environment boards: soot-grey stone, dark aged timber, slate, black iron,
sparse bordo cloth.

    python3 godot/tools/gen_room_textures.py
"""
import os
import numpy as np
from PIL import Image
from scipy.spatial import cKDTree

N = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "rooms")
rng = np.random.default_rng(1847)
yy, xx = np.mgrid[0:N, 0:N] / N


def noise(scale=8.0, power=2.0, aspect=(1.0, 1.0)):
    """Periodic fractal noise in [0, 1]. aspect stretches features along an axis."""
    fy = np.fft.fftfreq(N)[:, None] * N / aspect[1]
    fx = np.fft.fftfreq(N)[None, :] * N / aspect[0]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spectrum = (rng.normal(size=(N, N)) + 1j * rng.normal(size=(N, N))) / (1.0 + (f / scale) ** power) / f ** 0.5
    spectrum[0, 0] = 0
    out = np.real(np.fft.ifft2(spectrum))
    out -= out.min()
    return out / out.max()


def voronoi(count):
    """Wrapped Voronoi: F1, F2 distances and the owning cell for every pixel."""
    # A jittered grid, not uniform random: two seeds landing almost on top of each
    # other make a sliver cell that reads as a dark wedge.
    side = int(round(np.sqrt(count)))
    grid = np.stack(np.meshgrid(np.arange(side), np.arange(side)), -1).reshape(-1, 2)
    pts = ((grid + 0.5 + rng.uniform(-0.38, 0.38, grid.shape)) / side) % 1.0
    count = len(pts)
    tiles = np.concatenate([pts + [dx, dy] for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    owner = np.tile(np.arange(count), 9)
    dist, idx = cKDTree(tiles).query(np.stack([xx.ravel(), yy.ravel()], 1), k=2)
    return dist[:, 0].reshape(N, N), dist[:, 1].reshape(N, N), owner[idx[:, 0]].reshape(N, N)


def smooth(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def normal_map(height, strength):
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    n = np.stack([-dx, dy, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def tint(base, value):
    return np.clip(np.asarray(base)[None, None, :] * value[..., None], 0, 1)


def save(name, albedo, height, strength):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_albedo.png"))
    Image.fromarray(normal_map(height, strength)).save(os.path.join(OUT, name + "_normal.png"))
    print("wrote", name)


def cell_values(owner, count, low, high):
    return (low + (high - low) * rng.random(count))[owner]


def cobble():
    f1, f2, owner = voronoi(64)
    gap = f2 - f1
    # F2-F1 only approximates the distance to a joint, so the joint is kept thin
    # and the rounding gentle; a wide band smears into streaks near the corners.
    stone = smooth(0.003, 0.011, gap)
    dome = stone * (0.75 + 0.25 * smooth(0.0, 0.08, gap))
    grit = noise(48, 2.2)
    height = dome * 0.85 + grit * 0.15
    shade = cell_values(owner, 64, 0.78, 1.08) * (0.82 + 0.3 * noise(10)) * (0.9 + 0.1 * grit)
    col = tint([0.36, 0.35, 0.34], shade)
    col = col * (0.3 + 0.7 * stone[..., None])
    moss = smooth(0.62, 0.8, noise(6)) * (1 - stone)
    col = col * (1 - moss[..., None] * 0.4) + np.array([0.13, 0.14, 0.1]) * moss[..., None] * 0.4
    save("cobble", col, height, 9.0)


def courses(rows, min_w, max_w, mortar):
    """Running-bond blocks: per-pixel block id, and distance to the nearest joint."""
    row = np.floor(yy * rows).astype(int)
    v = (yy * rows) % 1.0
    block = np.zeros((N, N), int)
    edge = np.zeros((N, N))
    next_id = 0
    for r in range(rows):
        cuts = [0.0]
        while cuts[-1] < 1.0 - min_w:
            cuts.append(cuts[-1] + rng.uniform(min_w, max_w))
        cuts[-1] = 1.0
        offset = rng.random()
        mask = row == r
        u = (xx[mask] + offset) % 1.0
        k = np.searchsorted(cuts, u, side="right") - 1
        left = u - np.take(cuts, k)
        right = np.take(cuts, k + 1) - u
        block[mask] = next_id + k
        edge[mask] = np.minimum(np.minimum(left, right) * rows / 1.0 * (max_w * 0 + 1), np.minimum(v[mask], 1 - v[mask]))
        next_id += len(cuts)
    face = smooth(0.0, mortar, edge)
    return block, face, next_id


def ashlar():
    block, face, count = courses(6, 0.22, 0.42, 0.06)
    grit = noise(40, 2.0)
    chips = smooth(0.55, 0.75, noise(22)) * 0.25
    height = face * (0.8 - chips) + grit * 0.2
    shade = cell_values(block, count, 0.72, 1.05) * (0.85 + 0.25 * noise(12))
    col = tint([0.31, 0.31, 0.32], shade) * (0.4 + 0.6 * face[..., None])
    soot = smooth(0.3, 1.0, yy) * 0.25 * noise(4)
    col *= 1 - soot[..., None]
    save("ashlar", col, height, 8.0)


def planks(name, base, widths=(0.12, 0.22), gap=0.012):
    cuts = [0.0]
    while cuts[-1] < 1.0 - widths[0]:
        cuts.append(cuts[-1] + rng.uniform(*widths))
    cuts[-1] = 1.0
    k = np.searchsorted(cuts, xx, side="right") - 1
    left = xx - np.take(cuts, k)
    right = np.take(cuts, k + 1) - xx
    joint = smooth(0.0, gap, np.minimum(left, right))
    grain = noise(60, 1.6, aspect=(0.12, 1.0))
    knots = smooth(0.82, 0.95, noise(14))
    shade = (0.75 + 0.35 * rng.random(len(cuts)))[k] * (0.7 + 0.45 * grain) * (1 - knots * 0.35)
    col = tint(base, shade) * (0.3 + 0.7 * joint[..., None])
    # Butt joints across each plank, at a different height per plank.
    ends = (rng.random(len(cuts)))[k]
    across = smooth(0.0, 0.006, np.abs(((yy + ends) % 1.0) - 0.5))
    col *= (0.45 + 0.55 * across[..., None])
    height = joint * across * (0.75 + 0.25 * grain)
    save(name, col, height, 6.0)


def timber():
    """Half-timbered plaster: soot-grey render between dark posts, rails and braces."""
    plaster = 0.78 + 0.22 * noise(16) - 0.25 * smooth(0.6, 0.9, noise(5))
    beam = np.zeros((N, N))
    for x0 in (0.0, 0.5):
        beam = np.maximum(beam, smooth(0.045, 0.035, np.abs(((xx - x0 + 0.5) % 1.0) - 0.5)))
    for y0 in (0.0, 0.42):
        beam = np.maximum(beam, smooth(0.04, 0.03, np.abs(((yy - y0 + 0.5) % 1.0) - 0.5)))
    brace = np.abs(((xx % 0.5) * 2 - ((yy - 0.42) % 1.0) / 0.58) )
    in_lower = ((yy - 0.42) % 1.0) < 0.58
    beam = np.maximum(beam, smooth(0.07, 0.05, brace) * in_lower)
    grain = noise(50, 1.6, aspect=(0.2, 1.0))
    wood = tint([0.17, 0.12, 0.09], 0.75 + 0.4 * grain)
    render = tint([0.42, 0.39, 0.35], plaster)
    col = render * (1 - beam[..., None]) + wood * beam[..., None]
    height = beam * 0.8 + (1 - beam) * noise(30) * 0.25
    save("timber", col, height, 7.0)


def slate():
    rows = 10
    row = np.floor(yy * rows)
    v = (yy * rows) % 1.0
    offset = (row % 2) * 0.5 / 8
    u = ((xx + offset) * 8) % 1.0
    tile_id = (row * 8 + np.floor((xx + offset) * 8) % 8).astype(int)
    side = smooth(0.0, 0.05, np.minimum(u, 1 - u))
    lip = smooth(1.0, 0.85, v)
    height = (0.35 + 0.65 * v) * side * lip + noise(40) * 0.08
    shade = cell_values(tile_id, rows * 8 + 8, 0.7, 1.05) * (0.85 + 0.2 * noise(20))
    col = tint([0.17, 0.18, 0.2], shade) * (0.35 + 0.65 * (side * lip)[..., None]) * (0.6 + 0.4 * v[..., None])
    save("slate", col, height, 7.0)


def iron():
    base = 0.75 + 0.25 * noise(30)
    rust = smooth(0.66, 0.85, noise(9)) * 0.7
    col = tint([0.12, 0.12, 0.13], base)
    col = col * (1 - rust[..., None]) + np.array([0.26, 0.13, 0.07]) * rust[..., None] * base[..., None]
    rivets = np.zeros((N, N))
    for cy in (0.125, 0.625):
        for cx in (0.125, 0.375, 0.625, 0.875):
            d = np.hypot(((xx - cx + 0.5) % 1.0) - 0.5, ((yy - cy + 0.5) % 1.0) - 0.5)
            rivets = np.maximum(rivets, smooth(0.018, 0.008, d))
    height = rivets * 0.9 + noise(50) * 0.15
    col *= (1 + rivets[..., None] * 0.6)
    save("iron", col, height, 6.0)


def cloth():
    weave = 0.5 + 0.5 * np.sin(xx * N * np.pi / 2) * np.sin(yy * N * np.pi / 2)
    shade = (0.75 + 0.25 * noise(10)) * (0.88 + 0.12 * weave) - 0.25 * smooth(0.6, 0.85, noise(5))
    col = tint([0.36, 0.07, 0.09], shade)
    save("cloth", col, weave * 0.3 + noise(12) * 0.4, 3.0)


def crate():
    planks("crate", [0.42, 0.3, 0.2], widths=(0.24, 0.26), gap=0.01)


if __name__ == "__main__":
    cobble()
    ashlar()
    planks("wood", [0.3, 0.22, 0.16])
    crate()
    timber()
    slate()
    iron()
    cloth()
