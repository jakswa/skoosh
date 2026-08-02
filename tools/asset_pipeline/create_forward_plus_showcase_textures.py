#!/usr/bin/env python3
"""Generate neutral decals used by the Forward+ renderer qualification scene."""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/textures/environment/forward_plus_base_decal.png"
SIZE = 512


def main() -> None:
    image = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    draw = ImageDraw.Draw(image)
    white = (235, 250, 255, 220)
    faint = (220, 245, 255, 110)

    # Broken landing ring and inner registration circle.
    box = (42, 42, SIZE - 42, SIZE - 42)
    for start in range(8, 360, 45):
        draw.arc(box, start=start, end=start + 28, fill=white, width=12)
    draw.ellipse((150, 150, SIZE - 150, SIZE - 150), outline=faint, width=5)

    # Four approach chevrons. The texture is team-tinted by each Decal node.
    chevrons = [
        [(216, 98), (256, 130), (296, 98), (296, 120), (256, 152), (216, 120)],
        [(216, 414), (256, 382), (296, 414), (296, 392), (256, 360), (216, 392)],
        [(98, 216), (130, 256), (98, 296), (120, 296), (152, 256), (120, 216)],
        [(414, 216), (382, 256), (414, 296), (392, 296), (360, 256), (392, 216)],
    ]
    for points in chevrons:
        draw.polygon(points, fill=white)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT, optimize=True)
    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
