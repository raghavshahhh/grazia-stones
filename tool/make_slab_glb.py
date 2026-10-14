"""Writes assets/3d/slab.glb: a unit cube (1x1x1) with one material and UVs.

The face (+Z) and back (-Z) map the whole texture; the four sides map a thin strip at the
texture edge so the slab body reads as stone. Per-stone size (width, height, thickness)
is applied at runtime with model-viewer's `scale`, so one GLB serves every stone.
Run: python3 tool/make_slab_glb.py
"""
import json
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "3d" / "slab.glb"

# (normal, 4 corners CCW seen from outside, 4 uvs)
H = 0.5
FACES = [
    ((0, 0, 1), [(-H, -H, H), (H, -H, H), (H, H, H), (-H, H, H)], [(0, 1), (1, 1), (1, 0), (0, 0)]),
    ((0, 0, -1), [(H, -H, -H), (-H, -H, -H), (-H, H, -H), (H, H, -H)], [(0, 1), (1, 1), (1, 0), (0, 0)]),
    ((1, 0, 0), [(H, -H, H), (H, -H, -H), (H, H, -H), (H, H, H)], [(0.98, 0.5), (1, 0.5), (1, 0.5), (0.98, 0.5)]),
    ((-1, 0, 0), [(-H, -H, -H), (-H, -H, H), (-H, H, H), (-H, H, -H)], [(0, 0.5), (0.02, 0.5), (0.02, 0.5), (0, 0.5)]),
    ((0, 1, 0), [(-H, H, H), (H, H, H), (H, H, -H), (-H, H, -H)], [(0.5, 0), (0.5, 0), (0.5, 0.02), (0.5, 0.02)]),
    ((0, -1, 0), [(-H, -H, -H), (H, -H, -H), (H, -H, H), (-H, -H, H)], [(0.5, 0.98), (0.5, 0.98), (0.5, 1), (0.5, 1)]),
]

pos, nrm, uv, idx = [], [], [], []
for n, corners, uvs in FACES:
    base = len(pos)
    pos += corners
    nrm += [n] * 4
    uv += uvs
    idx += [base, base + 1, base + 2, base, base + 2, base + 3]

pos_b = b"".join(struct.pack("<3f", *p) for p in pos)
nrm_b = b"".join(struct.pack("<3f", *n) for n in nrm)
uv_b = b"".join(struct.pack("<2f", *t) for t in uv)
idx_b = b"".join(struct.pack("<H", i) for i in idx)
blob = pos_b + nrm_b + uv_b + idx_b
blob += b"\x00" * (-len(blob) % 4)

gltf = {
    "asset": {"version": "2.0", "generator": "grazia make_slab_glb.py"},
    "scene": 0,
    "scenes": [{"nodes": [0]}],
    "nodes": [{"mesh": 0, "name": "slab"}],
    "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
    "materials": [{"name": "stone", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.85}}],
    "buffers": [{"byteLength": len(blob)}],
    "bufferViews": [
        {"buffer": 0, "byteOffset": 0, "byteLength": len(pos_b), "target": 34962},
        {"buffer": 0, "byteOffset": len(pos_b), "byteLength": len(nrm_b), "target": 34962},
        {"buffer": 0, "byteOffset": len(pos_b) + len(nrm_b), "byteLength": len(uv_b), "target": 34962},
        {"buffer": 0, "byteOffset": len(pos_b) + len(nrm_b) + len(uv_b), "byteLength": len(idx_b), "target": 34963},
    ],
    "accessors": [
        {"bufferView": 0, "componentType": 5126, "count": len(pos), "type": "VEC3", "min": [-H, -H, -H], "max": [H, H, H]},
        {"bufferView": 1, "componentType": 5126, "count": len(nrm), "type": "VEC3"},
        {"bufferView": 2, "componentType": 5126, "count": len(uv), "type": "VEC2"},
        {"bufferView": 3, "componentType": 5123, "count": len(idx), "type": "SCALAR"},
    ],
}

js = json.dumps(gltf, separators=(",", ":")).encode()
js += b" " * (-len(js) % 4)
total = 12 + 8 + len(js) + 8 + len(blob)
glb = struct.pack("<4sII", b"glTF", 2, total)
glb += struct.pack("<I4s", len(js), b"JSON") + js
glb += struct.pack("<I4s", len(blob), b"BIN\x00") + blob
OUT.write_bytes(glb)
print(f"wrote {OUT} ({len(glb)} bytes, {len(pos)} verts, {len(idx) // 3} tris)")
