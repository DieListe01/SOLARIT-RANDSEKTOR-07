from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ATLAS_DIR = ROOT / "assets" / "rendered" / "destruction"
OUT_DIR = ROOT / "test-output"
OUT_DIR.mkdir(parents=True, exist_ok=True)

FACTIONS = (("forge", "KOBALT"), ("drift", "WANDERPAKT"), ("lumen", "PRISMA"))
VEHICLES = (
    ("scout", "SPÄHER"),
    ("raider", "STURMJÄGER"),
    ("tank", "KAMPFPANZER"),
    ("siege", "BELAGERER"),
    ("harvester", "SAMMLER"),
    ("lancer", "LANZIERER"),
    ("scorcher", "FLAMMENWERFER"),
    ("bulwark", "DURCHBRUCHPANZER"),
)
BUILDINGS = (
    ("power", "IMPULSWERK"),
    ("refinery", "RAFFINERIE"),
    ("factory", "FAHRZEUGWERFT"),
    ("tower", "WACHTGESCHÜTZ"),
    ("radar", "SIGNALSTATION"),
    ("repair", "SERVICEHANGAR"),
    ("armory", "RÜSTUNGSWERKSTATT"),
    ("core", "HAUPTGEBÄUDE"),
)
TILE = 256
CELL_W = 320
CELL_H = 220
HEADER_H = 52


def make_sheet(kind: str, rows: tuple[tuple[str, str], ...], grayscale: bool) -> Image.Image:
    sheet = Image.new("RGB", (CELL_W * 3, HEADER_H + CELL_H * len(rows)), "#141a1a")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    labels = {"forge": "KOBALT-KONSORTIUM", "drift": "WANDERPAKT", "lumen": "PRISMA-KONKLAVE"}
    for col, (faction, _) in enumerate(FACTIONS):
        x = col * CELL_W
        draw.rectangle((x, 0, x + CELL_W - 1, HEADER_H - 1), fill="#252b2a", outline="#9d896e")
        draw.text((x + 12, 18), labels[faction], fill="#e6cf9e", font=font)
        atlas = Image.open(ATLAS_DIR / f"{kind}_{faction}.png").convert("RGBA")
        expected_height = TILE * len(rows)
        assert atlas.size == (TILE * (8 if kind == "vehicles" else 4), expected_height), (faction, atlas.size)
        for row, (role, role_label) in enumerate(rows):
            y = HEADER_H + row * CELL_H
            draw.rectangle((x, y, x + CELL_W - 1, y + CELL_H - 1), fill="#1a2020", outline="#625a4d")
            draw.text((x + 10, y + 8), role_label, fill="#d5b16d", font=font)
            role_index = next(i for i, (name, _) in enumerate(rows) if name == role)
            # Keep one common heading across all factions; compare authored silhouettes.
            cell = atlas.crop((0, role_index * TILE, TILE, (role_index + 1) * TILE))
            bounds = cell.getchannel("A").getbbox()
            if bounds:
                left, top, right, bottom = bounds
                padding = 10
                cell = cell.crop((max(0, left - padding), max(0, top - padding), min(TILE, right + padding), min(TILE, bottom + padding)))
            if grayscale:
                alpha = cell.getchannel("A")
                rgb = Image.new("RGB", cell.size, "#1a2020")
                rgb.paste(cell, mask=alpha)
                cell = rgb.convert("L").convert("RGBA")
                cell.putalpha(alpha)
            scale = min((CELL_W - 24) / cell.width, (CELL_H - 44) / cell.height)
            size = (round(cell.width * scale), round(cell.height * scale))
            cell = cell.resize(size, Image.Resampling.LANCZOS)
            px = x + (CELL_W - size[0]) // 2
            py = y + 36 + (CELL_H - 40 - size[1]) // 2
            sheet.paste(cell, (px, py), cell.getchannel("A"))
    return sheet


for kind, rows in (("vehicles", VEHICLES), ("buildings", BUILDINGS)):
    for grayscale in (False, True):
        suffix = "_grayscale" if grayscale else ""
        path = OUT_DIR / f"destruction_{kind}{suffix}.png"
        make_sheet(kind, rows, grayscale).save(path)
        print(path)


def make_construction_sheet() -> Image.Image:
    phases = (("20%", 0.20), ("50%", 0.50), ("80%", 0.80), ("95%", 0.95), ("100%", 1.0))
    atlas = Image.open(OUT_DIR / "construction_phases_atlas.png").convert("RGBA")
    cell_w, cell_h, header = 270, 210, 44
    sheet = Image.new("RGB", (cell_w * len(phases), header + cell_h * len(BUILDINGS)), "#141a1a")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for col, (phase, _) in enumerate(phases):
        x = col * cell_w
        draw.rectangle((x, 0, x + cell_w - 1, header - 1), fill="#252b2a", outline="#9d896e")
        draw.text((x + 10, 15), phase, fill="#e6cf9e", font=font)
    for row, (kind, label) in enumerate(BUILDINGS):
        y = header + row * cell_h
        for col, _ in enumerate(phases):
            x = col * cell_w
            draw.rectangle((x, y, x + cell_w - 1, y + cell_h - 1), fill="#1a2020", outline="#625a4d")
            draw.text((x + 8, y + 7), label, fill="#d5b16d", font=font)
            cell = atlas.crop((col * TILE, row * TILE, (col + 1) * TILE, (row + 1) * TILE))
            bbox = cell.getchannel("A").getbbox()
            if bbox:
                l, t, r, b = bbox
                pad = 10
                bbox = (max(0, l - pad), max(0, t - pad), min(TILE, r + pad), min(TILE, b + pad))
                cell = cell.crop(bbox)
                scale = min((cell_w - 24) / cell.width, (cell_h - 40) / cell.height)
                size = (round(cell.width * scale), round(cell.height * scale))
                cell = cell.resize(size, Image.Resampling.LANCZOS)
                px = x + (cell_w - size[0]) // 2
                py = y + 32 + (cell_h - 38 - size[1]) // 2
                sheet.paste(cell, (px, py), cell.getchannel("A"))
    return sheet


construction_path = OUT_DIR / "construction_phases.png"
make_construction_sheet().save(construction_path)
print(construction_path)
