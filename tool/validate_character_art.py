"""Check exported character sprite strips before importing them into Flame.

Requires Pillow. Example:
    python tool/validate_character_art.py assets/images/characters/warrior

This reads images only; it never modifies artwork.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


STATES = ("idle", "run", "attack", "hit", "death")


def inspect_strip(path: Path, frame_size: int) -> list[str]:
    issues: list[str] = []
    if not path.exists():
        return [f"{path.name}: missing"]

    with Image.open(path) as image:
        if image.mode != "RGBA":
            issues.append(f"{path.name}: expected RGBA, got {image.mode}")
            image = image.convert("RGBA")
        width, height = image.size
        if height != frame_size or width % frame_size:
            issues.append(
                f"{path.name}: expected N x {frame_size} by {frame_size}, got {width}x{height}"
            )
            return issues

        frame_count = width // frame_size
        if frame_count < 2:
            issues.append(f"{path.name}: fewer than two animation frames")

        foot_rows: list[int] = []
        heights: list[int] = []
        for index in range(frame_count):
            frame = image.crop((index * frame_size, 0, (index + 1) * frame_size, height))
            alpha = frame.getchannel("A")
            bbox = alpha.point(lambda value: 255 if value >= 32 else 0).getbbox()
            if bbox is None:
                issues.append(f"{path.name} frame {index}: empty")
                continue
            heights.append(bbox[3] - bbox[1])
            foot_rows.append(bbox[3])

            # A fully transparent one-pixel guard prevents rectangular seams
            # when sheets are filtered and scaled in the game.
            edge = [alpha.getpixel((x, 0)) for x in range(frame_size)]
            edge += [alpha.getpixel((x, frame_size - 1)) for x in range(frame_size)]
            edge += [alpha.getpixel((0, y)) for y in range(frame_size)]
            edge += [alpha.getpixel((frame_size - 1, y)) for y in range(frame_size)]
            if any(value > 16 for value in edge):
                issues.append(f"{path.name} frame {index}: nontransparent frame edge")

        if foot_rows and max(foot_rows) - min(foot_rows) > 3:
            issues.append(f"{path.name}: foot baseline varies by {max(foot_rows) - min(foot_rows)} px")
        if heights and max(heights) - min(heights) > frame_size * 0.12:
            issues.append(f"{path.name}: character scale varies across frames")

    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--frame-size", type=int, default=128)
    args = parser.parse_args()

    issues = [
        issue
        for state in STATES
        for issue in inspect_strip(args.folder / f"{state}.png", args.frame_size)
    ]
    if issues:
        for issue in issues:
            print(f"FAIL {issue}")
        return 1
    print(f"PASS {args.folder}: all {len(STATES)} states passed structural checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
