"""Visual-asset invariants for the shared Solarit field atlas."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ATLAS_PATH = ROOT / "assets" / "solarit_atlas.png"
image = Image.open(ATLAS_PATH).convert("RGBA")
assert image.size == (256, 96), f"expected 8 × 3 32px atlas cells, got {image.size}"

cell_signatures = {}
row_density = [0, 0, 0]
for row in range(3):
    for column in range(8):
        tile = image.crop((column * 32, row * 32, (column + 1) * 32, (row + 1) * 32))
        rgba = list(tile.getdata())
        density = sum(1 for pixel in rgba if pixel[3] >= 96)
        row_density[row] += density
        assert density > 90, f"depletion stage {row}, variant {column} is too faint to read"
        cell_signatures[row, column] = tile.tobytes()

for row in range(3):
    unique = len({cell_signatures[row, column] for column in range(8)})
    assert unique == 8, f"stage {row} must contain eight recognizably different cluster silhouettes"
assert row_density[0] < row_density[1] < row_density[2], f"depleted fields should visibly lose crystals: {row_density}"
print(f"SOLARIT CRYSTAL ATLAS: 24 varied cells; stage densities {row_density}; depletion ordering verified")
