"""Build the deterministic eight-family Solarit crystal atlas used by the RTS renderer."""
from pathlib import Path
import math
import random
from PIL import Image, ImageDraw, ImageFilter

SCALE = 6
CELL = 32
COLUMNS = 8
ROWS = 3
atlas = Image.new("RGBA", (CELL * COLUMNS * SCALE, CELL * ROWS * SCALE), (0, 0, 0, 0))

PALETTES = [
    ((12, 88, 89), (37, 161, 151), (115, 228, 200), (218, 255, 226)),
    ((9, 77, 99), (29, 144, 174), (110, 214, 224), (224, 255, 240)),
    ((25, 94, 104), (56, 183, 161), (146, 236, 191), (238, 255, 220)),
    ((18, 69, 83), (36, 137, 150), (122, 203, 192), (220, 250, 224)),
]

def xy(point, ox, oy):
    return (round(ox + point[0] * SCALE), round(oy + point[1] * SCALE))

def paint_cell(row, column):
    rng = random.Random(9137 + row * 473 + column * 211)
    ox, oy = column * CELL * SCALE, row * CELL * SCALE
    layer = Image.new("RGBA", (CELL * SCALE, CELL * SCALE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    base, mid, light, glint = PALETTES[(column + row * 3) % len(PALETTES)]

    # An irregular mineral stain grounds each field without creating a tile-shaped halo.
    stain = [(16 + math.cos(i * math.tau / 16) * rng.uniform(9, 15),
              18 + math.sin(i * math.tau / 16) * rng.uniform(5, 10)) for i in range(16)]
    draw.polygon([xy(p, 0, 0) for p in stain], fill=(24, 60, 53, 35 + row * 7))
    draw.ellipse((5*SCALE, 18*SCALE, 27*SCALE, 29*SCALE), fill=(13, 26, 22, 54))

    count = [3, 6, 10][row] + (column % 3)
    crystals = []
    for index in range(count):
        # One readable hero shard per patch, with smaller fractured companions around it.
        x = rng.uniform(7, 25)
        y = rng.uniform(15, 26)
        height = rng.uniform(10, 17) if index == 0 else rng.uniform(5, 11)
        width = rng.uniform(2.1, 4.1) if index == 0 else rng.uniform(1.5, 3.0)
        lean = rng.uniform(-2.2, 2.2)
        crystals.append((x, y, height, width, lean, index))

    # Rear shards and dark facets sit behind the focal crystal.
    for x, y, height, width, lean, index in sorted(crystals, key=lambda c: c[1]):
        shadow = [(x-width, y+1.0), (x+width*0.8, y+0.4),
                  (x+width*2.1, y+3.1), (x-width*1.5, y+3.0)]
        draw.polygon([xy(p, 0, 0) for p in shadow], fill=(11, 31, 26, 116))
        tip = (x+lean, y-height)
        left = (x-width, y-0.2)
        right = (x+width, y-0.1)
        left_shoulder = (x-width*.55, y-height*.42)
        right_shoulder = (x+width*.47, y-height*.56)
        center = (x+lean*.17, y-height*.16)
        draw.polygon([xy(p, 0, 0) for p in [left, left_shoulder, tip, right_shoulder, right]], fill=(*mid, 255))
        draw.polygon([xy(p, 0, 0) for p in [left, left_shoulder, center, (x, y+1.0)]], fill=(*light, 255))
        draw.polygon([xy(p, 0, 0) for p in [left_shoulder, tip, right_shoulder, center]], fill=(*glint, 235))
        draw.polygon([xy(p, 0, 0) for p in [center, right_shoulder, right, (x, y+1.0)]], fill=(*base, 255))
        draw.line([xy(tip, 0, 0), xy(center, 0, 0), xy((x, y+1.0), 0, 0)], fill=(235, 255, 230, 220), width=max(1, SCALE//2))
        # Thin bevel edge and a small fractured plane keep the shard readable at RTS scale.
        draw.line([xy(left, 0, 0), xy(left_shoulder, 0, 0), xy(tip, 0, 0)], fill=(188, 255, 226, 205), width=max(1, SCALE//3))
        if index % 3 == 1:
            split = (x+lean*.42, y-height*.55)
            draw.line([xy(split, 0, 0), xy((x+width*.25, y-height*.26), 0, 0)], fill=(18, 109, 111, 220), width=max(1, SCALE//3))

    # Tiny chips and embedded glints add scale variation to richer seams.
    for _ in range(3 + row * 2):
        x, y = rng.uniform(5, 27), rng.uniform(17, 28)
        r = rng.uniform(.35, .9)
        draw.polygon([xy((x-r, y), 0, 0), xy((x, y-r), 0, 0), xy((x+r, y+.3), 0, 0)], fill=(*light, rng.randint(90, 180)))
    layer = layer.filter(ImageFilter.GaussianBlur(0.22 * SCALE))
    atlas.alpha_composite(layer, (ox, oy))

for row in range(ROWS):
    for column in range(COLUMNS):
        paint_cell(row, column)

atlas = atlas.resize((CELL * COLUMNS, CELL * ROWS), Image.Resampling.LANCZOS)
out = Path(__file__).resolve().parents[1] / "assets" / "solarit_atlas.png"
atlas.save(out, optimize=True)
print(f"{out} {atlas.size}: {COLUMNS} distinct crystal silhouettes × {ROWS} depletion stages")
