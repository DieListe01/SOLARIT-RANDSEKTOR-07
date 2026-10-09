"""Move repeated Blender GLB PBR images to the shared industrial texture set.

Blender's GLB exporter embeds a fresh copy of each common map in every model.
This repacks geometry-only buffer views and points GLB images at the canonical
PNG under assets/models/textures/industrial, so Godot can share one import.
"""
from __future__ import annotations

import json
import os
import struct
from pathlib import Path


MAGIC = b"glTF"
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
ROOT = Path(__file__).resolve().parents[1]
TEXTURES = ROOT / "assets" / "models" / "textures" / "industrial"


def externalize(source: Path, target: Path | None = None) -> int:
    target = target or source
    data = source.read_bytes()
    if len(data) < 20:
        raise ValueError(f"Not a GLB file: {source}")
    magic, version, declared_length = struct.unpack_from("<4sII", data)
    if magic != MAGIC or version != 2 or declared_length != len(data):
        raise ValueError(f"Invalid GLB header: {source}")
    offset = 12
    document = None
    binary = b""
    while offset < len(data):
        size, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset : offset + size]
        if len(chunk) != size:
            raise ValueError(f"Truncated GLB chunk: {source}")
        offset += size
        if chunk_type == JSON_CHUNK:
            document = json.loads(chunk.decode("utf-8"))
        elif chunk_type == BIN_CHUNK:
            binary = chunk
    if document is None:
        raise ValueError(f"GLB is missing its JSON chunk: {source}")
    buffer_views = document.get("bufferViews", [])
    image_view_ids: set[int] = set()
    externalized = 0
    for image in document.get("images", []):
        view_id = image.pop("bufferView", None)
        if view_id is None:
            continue
        name = Path(image.get("name", "")).name
        map_name = name if name.lower().endswith(".png") else f"{name}.png"
        texture_path = TEXTURES / map_name
        if not texture_path.is_file():
            raise FileNotFoundError(f"No canonical PBR texture for {source.name}: {map_name}")
        image["uri"] = Path(os.path.relpath(texture_path, target.parent)).as_posix()
        image_view_ids.add(int(view_id))
        externalized += 1

    if not externalized:
        if source.resolve() != target.resolve():
            target.write_bytes(data)
        return 0

    remap: dict[int, int] = {}
    packed = bytearray()
    kept_views = []
    for old_id, view in enumerate(buffer_views):
        if old_id in image_view_ids:
            continue
        start = int(view.get("byteOffset", 0))
        end = start + int(view["byteLength"])
        if end > len(binary):
            raise ValueError(f"GLB buffer view outside binary data: {source}")
        while len(packed) % 4:
            packed.append(0)
        view = dict(view)
        view["byteOffset"] = len(packed)
        remap[old_id] = len(kept_views)
        packed.extend(binary[start:end])
        kept_views.append(view)

    for accessor in document.get("accessors", []):
        if "bufferView" in accessor:
            accessor["bufferView"] = remap[accessor["bufferView"]]
    document["bufferViews"] = kept_views
    if document.get("buffers"):
        document["buffers"][0]["byteLength"] = len(packed)

    json_chunk = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_chunk += b" " * (-len(json_chunk) % 4)
    while len(packed) % 4:
        packed.append(0)
    chunks = struct.pack("<II", len(json_chunk), JSON_CHUNK) + json_chunk
    chunks += struct.pack("<II", len(packed), BIN_CHUNK) + packed
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(struct.pack("<4sII", MAGIC, 2, 12 + len(chunks)) + chunks)
    return externalized


def externalize_directory(directory: Path) -> None:
    for model in sorted(directory.glob("*.glb")):
        count = externalize(model)
        print(f"Externalized {count} shared PBR maps: {model.name} ({model.stat().st_size:,} bytes)")


if __name__ == "__main__":
    for asset_group in ("buildings", "vehicles"):
        externalize_directory(ROOT / "assets" / "models" / asset_group)
