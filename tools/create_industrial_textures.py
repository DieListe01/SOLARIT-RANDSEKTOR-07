"""Generate small tileable PBR maps for SOLARIT's Blender-authored buildings.

Requires Pillow on the authoring Python only. Runtime GLBs embed these images.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models" / "textures" / "industrial"
SIZE = 512

PALETTES = {
    "ceramic": ((191, 165, 113), (220, 198, 145), (109, 88, 58)),
    "graphite": ((38, 48, 45), (61, 72, 66), (16, 23, 22)),
    "steel": ((92, 105, 96), (137, 145, 131), (48, 57, 54)),
    "enamel": ((20, 173, 153), (47, 214, 196), (8, 92, 84)),
    "safety": ((185, 119, 45), (225, 166, 73), (90, 57, 30)),
    "rubber": ((23, 29, 27), (44, 49, 43), (8, 12, 12)),
}


def lerp(a: tuple[int, ...], b: tuple[int, ...], t: float) -> tuple[int, ...]:
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def make_maps(name: str, palette: tuple[tuple[int, ...], ...]) -> None:
    rng = random.Random(4700 + sum(map(ord, name)))
    low = Image.new("L", (32, 32))
    low.putdata([rng.randrange(30, 226) for _ in range(32 * 32)])
    cloud = low.resize((SIZE, SIZE), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(7))
    fine = [rng.randrange(-8, 9) for _ in range(SIZE * SIZE)]
    cloud_px = list(cloud.getdata())
    base, highlight, shadow = palette
    rgb = Image.new("RGB", (SIZE, SIZE))
    pixels = []
    height = []
    for y in range(SIZE):
        for x in range(SIZE):
            i = y * SIZE + x
            modulation = (cloud_px[i] - 128) / 255.0 * 0.13 + fine[i] / 1024.0
            edge = min(x % 128, 127 - (x % 128), y % 128, 127 - (y % 128))
            seam = -0.14 if edge <= 1 else (0.055 if edge == 2 else 0.0)
            dust = 0.0
            if rng.random() < 0.0022:
                dust = rng.choice((-0.24, -0.13, 0.08))
            t = max(0.0, min(1.0, 0.52 + modulation + seam + dust))
            color = lerp(shadow, highlight, t)
            if name == "safety" and ((x + y * 2) % 96) < 13:
                color = lerp(color, (29, 31, 27), 0.78)
            pixels.append(color)
            h = 122 + round(modulation * 210) + (-24 if edge <= 1 else 0)
            height.append(max(0, min(255, h)))
    rgb.putdata(pixels)

    # Repeated service-panel seams, shallow fasteners, and restrained abrasion
    # make the texture legible as manufactured metal without adding mesh clutter.
    draw = ImageDraw.Draw(rgb)
    for y in range(0, SIZE + 1, 128):
        x0 = (y // 128 % 2) * 32
        for x in range(x0, SIZE, 128):
            draw.line((x, y, x + 128, y), fill=lerp(base, shadow, 0.34), width=2)
            draw.line((x, y + 2, x + 128, y + 2), fill=lerp(base, highlight, 0.25), width=1)
    for _ in range(440):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        length = rng.randrange(2, 15)
        color = lerp(base, highlight if rng.random() < 0.7 else shadow, rng.uniform(0.15, 0.55))
        draw.line((x, y, (x + length) % SIZE, (y + rng.choice((-1, 0, 1))) % SIZE), fill=color, width=1)
    for y in range(12, SIZE, 128):
        for x in range(12, SIZE, 128):
            draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill=lerp(base, highlight, 0.58))
            draw.point((x, y), fill=lerp(base, shadow, 0.25))
    rgb.save(OUT / f"{name}_albedo.png", optimize=True)

    rough = Image.new("L", (SIZE, SIZE))
    rough.putdata([round(116 + (cloud_px[i] - 128) * 0.45 + fine[i] * 0.6) for i in range(SIZE * SIZE)])
    rough.save(OUT / f"{name}_roughness.png", optimize=True)

    # Convert the same restrained panel/grit height signal to tangent-space normals.
    normals = []
    for y in range(SIZE):
        for x in range(SIZE):
            c = height[y * SIZE + x]
            dx = (height[y * SIZE + ((x + 1) % SIZE)] - height[y * SIZE + ((x - 1) % SIZE)]) / 255.0
            dy = (height[((y + 1) % SIZE) * SIZE + x] - height[((y - 1) % SIZE) * SIZE + x]) / 255.0
            nx, ny, nz = -dx * 2.1, -dy * 2.1, 1.0
            length = math.sqrt(nx * nx + ny * ny + nz * nz)
            normals.append((round((nx / length * 0.5 + 0.5) * 255), round((ny / length * 0.5 + 0.5) * 255), round((nz / length * 0.5 + 0.5) * 255)))
    normal = Image.new("RGB", (SIZE, SIZE))
    normal.putdata(normals)
    normal.save(OUT / f"{name}_normal.png", optimize=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, palette in PALETTES.items():
        make_maps(name, palette)
        print("Generated tileable PBR maps:", name)


if __name__ == "__main__":
    main()
