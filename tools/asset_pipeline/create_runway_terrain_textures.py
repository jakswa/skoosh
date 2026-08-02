"""Generate deterministic terrain detail maps for the Compatibility renderer."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/textures/terrain/runway"
SIZE = 256
SEED = 73021


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(SEED)
    height = Image.new("L", (SIZE, SIZE))
    roughness = Image.new("L", (SIZE, SIZE))
    hp = height.load()
    rp = roughness.load()
    phases = [rng.random() * math.tau for _ in range(4)]
    for y in range(SIZE):
        for x in range(SIZE):
            broad = (
                math.sin(x * 0.047 + phases[0]) * 13.0
                + math.sin(y * 0.063 + phases[1]) * 10.0
                + math.sin((x + y) * 0.025 + phases[2]) * 8.0
                + math.sin((x - y) * 0.081 + phases[3]) * 4.0
            )
            grain = rng.gauss(0.0, 5.0)
            value = max(0, min(255, round(128 + broad + grain)))
            hp[x, y] = value
            rp[x, y] = max(0, min(255, round(218 - broad * 0.32 + abs(grain))))
    height = height.filter(ImageFilter.GaussianBlur(radius=0.7))
    hp = height.load()

    normal = Image.new("RGB", (SIZE, SIZE), (128, 128, 255))
    np = normal.load()
    strength = 1.8
    for y in range(SIZE):
        for x in range(SIZE):
            dx = (hp[(x + 1) % SIZE, y] - hp[(x - 1) % SIZE, y]) / 255.0 * strength
            dy = (hp[x, (y + 1) % SIZE] - hp[x, (y - 1) % SIZE]) / 255.0 * strength
            nz = 1.0 / math.sqrt(dx * dx + dy * dy + 1.0)
            np[x, y] = (
                round((-dx * nz * 0.5 + 0.5) * 255),
                round((-dy * nz * 0.5 + 0.5) * 255),
                round((nz * 0.5 + 0.5) * 255),
            )

    # Neutral detail multiplier; terrain hue/value remains controlled by vertex color.
    albedo = Image.merge("RGB", (height, height, height))
    albedo.save(OUTPUT / "runway_detail_albedo.png")
    normal.save(OUTPUT / "runway_detail_normal.png")
    roughness.save(OUTPUT / "runway_detail_roughness.png")
    print(f"Generated terrain maps in {OUTPUT}")


if __name__ == "__main__":
    main()
