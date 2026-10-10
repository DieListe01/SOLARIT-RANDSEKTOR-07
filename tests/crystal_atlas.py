"""Visual-asset invariants for the shared Solarit field atlas."""
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
ATLAS_PATH = ROOT / "assets" / "solarit_atlas.png"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

def read_rgba_png(path):
    """Decode the atlas with the standard library so CI needs no Pillow install."""
    data = path.read_bytes()
    assert data.startswith(PNG_SIGNATURE), "crystal atlas must be a PNG"
    cursor = len(PNG_SIGNATURE)
    compressed = bytearray()
    width = height = bit_depth = color_type = None
    while cursor < len(data):
        length = struct.unpack_from(">I", data, cursor)[0]
        kind = data[cursor + 4:cursor + 8]
        chunk = data[cursor + 8:cursor + 8 + length]
        cursor += length + 12
        if kind == b"IHDR":
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", chunk)
            assert (bit_depth, color_type, compression, filtering, interlace) == (8, 6, 0, 0, 0), "expected non-interlaced 8-bit RGBA PNG"
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            break

    assert (width, height) == (256, 96), f"expected 8 × 3 32px atlas cells, got {(width, height)}"
    stride = width * 4
    packed = zlib.decompress(compressed)
    decoded = bytearray(height * stride)
    source = 0
    for y in range(height):
        filter_type = packed[source]
        source += 1
        row_start = y * stride
        for x in range(stride):
            raw = packed[source + x]
            left = decoded[row_start + x - 4] if x >= 4 else 0
            above = decoded[row_start - stride + x] if y else 0
            upper_left = decoded[row_start - stride + x - 4] if y and x >= 4 else 0
            if filter_type == 1:
                raw = (raw + left) & 255
            elif filter_type == 2:
                raw = (raw + above) & 255
            elif filter_type == 3:
                raw = (raw + ((left + above) >> 1)) & 255
            elif filter_type == 4:
                estimate = left + above - upper_left
                left_distance = abs(estimate - left)
                above_distance = abs(estimate - above)
                corner_distance = abs(estimate - upper_left)
                predictor = left if left_distance <= above_distance and left_distance <= corner_distance else above if above_distance <= corner_distance else upper_left
                raw = (raw + predictor) & 255
            else:
                assert filter_type == 0, f"unsupported PNG filter {filter_type}"
            decoded[row_start + x] = raw
        source += stride
    return width, height, decoded

width, height, pixels = read_rgba_png(ATLAS_PATH)

cell_signatures = {}
row_density = [0, 0, 0]
for row in range(3):
    for column in range(8):
        rgba = bytearray()
        for y in range(row * 32, (row + 1) * 32):
            start = (y * width + column * 32) * 4
            rgba.extend(pixels[start:start + 32 * 4])
        density = sum(1 for alpha in rgba[3::4] if alpha >= 96)
        row_density[row] += density
        assert density > 90, f"depletion stage {row}, variant {column} is too faint to read"
        cell_signatures[row, column] = bytes(rgba)

for row in range(3):
    unique = len({cell_signatures[row, column] for column in range(8)})
    assert unique == 8, f"stage {row} must contain eight recognizably different cluster silhouettes"
assert row_density[0] < row_density[1] < row_density[2], f"depleted fields should visibly lose crystals: {row_density}"
print(f"SOLARIT CRYSTAL ATLAS: 24 varied cells; stage densities {row_density}; depletion ordering verified")
