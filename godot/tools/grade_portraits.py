#!/usr/bin/env python3
"""Grade the baked class plates into the menus' painted look.

The rigs come out of Godot lit but clinical. This pass gives them the palette the
UI mockups use: cool key, blood rim, crushed warm shadows, and a body that sinks
into darkness at the hem so the portrait sits on a panel without a hard cut.

    python3 tools/grade_portraits.py
"""
import pathlib

import numpy as np
from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT.parent / "art/portraits/raw"
PLATES = ROOT / "assets/ui/portraits"
CLASSES = ["warrior", "gunslinger", "mage", "assassin", "revenant"]

SHADOW = np.array([0.150, 0.055, 0.070])   # warm blood in the darks
HIGHLIGHT = np.array([0.960, 0.925, 0.880])  # bone white in the lights
RIM = np.array([0.851, 0.263, 0.290])      # #d9434a


def _curve(x, contrast=1.24, pivot=0.38):
    """A soft S around the pivot; keeps the highlights off the clip."""
    y = (x - pivot) * contrast + pivot
    return np.clip(y - 0.18 * np.sin(2 * np.pi * np.clip(y, 0, 1)) * 0.5, 0.0, 1.0)


def grade(name):
    source = Image.open(RAW / f"{name}.png").convert("RGBA")
    data = np.asarray(source).astype(np.float32) / 255.0
    rgb, alpha = data[..., :3], data[..., 3:]

    luma = rgb @ np.array([0.2126, 0.7152, 0.0722])
    # Pull most of the colour out, then paint it back with a split tone. This is
    # what turns a grey render into something that matches the panels around it.
    rgb = rgb * 0.38 + luma[..., None] * 0.62
    rgb = _curve(np.clip(rgb * 1.22, 0.0, 1.0))
    luma = np.clip(rgb @ np.array([0.2126, 0.7152, 0.0722]), 0.0, 1.0)[..., None]
    tone = SHADOW * (1.0 - luma) ** 1.4 + HIGHLIGHT * luma ** 1.1
    rgb = np.clip(rgb * 0.60 + tone * 0.58, 0.0, 1.0)

    # Rim bloom: the brightest edges bleed blood-red a few pixels outward.
    hot = np.clip((luma[..., 0] - 0.58) / 0.42, 0.0, 1.0) * alpha[..., 0]
    bloom = np.asarray(
        Image.fromarray((hot * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(9))
    ).astype(np.float32) / 255.0
    rgb = np.clip(rgb + bloom[..., None] * RIM * 0.85, 0.0, 1.0)

    height, width = alpha.shape[:2]
    ys = np.linspace(0.0, 1.0, height)[:, None]
    # The hem dissolves over the bottom fifth, and the darks there go darker still.
    hem = np.clip((ys - 0.80) / 0.20, 0.0, 1.0) ** 1.5
    alpha = alpha * (1.0 - hem)[..., None]
    rgb = rgb * (1.0 - 0.55 * hem)[..., None]

    # A vignette across the plate so the silhouette carries the eye, not the edges.
    xs = np.linspace(-1.0, 1.0, width)[None, :]
    radial = np.clip(np.sqrt((xs * 0.85) ** 2 + ((ys * 2 - 1) * 0.65) ** 2), 0.0, 1.0)
    rgb = rgb * (1.0 - 0.22 * radial ** 2)[..., None]

    out = np.concatenate([rgb, alpha], axis=-1)
    plate = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")
    # A touch of local contrast reads as brushwork rather than as a render.
    plate = plate.filter(ImageFilter.UnsharpMask(radius=3, percent=55, threshold=3))
    plate.save(PLATES / f"{name}.png")
    return plate


if __name__ == "__main__":
    PLATES.mkdir(parents=True, exist_ok=True)
    for class_id in CLASSES:
        grade(class_id)
        print("graded", class_id)
