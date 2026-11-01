#!/usr/bin/env python3
"""Packs tool/aarna_sprites/frames/<shot>/*.png into looping animated WebP (Flutter's Image plays these natively)
and still PNG posters, written to assets/3d/renders/."""
import glob, json, os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "3d", "renders")
os.makedirs(OUT, exist_ok=True)
cfg = json.load(open(os.path.join(HERE, "shots.json")))

for s in cfg["shots"]:
    paths = sorted(glob.glob(os.path.join(HERE, "frames", s["name"], "*.png")))
    imgs = [Image.open(p).convert("RGBA") for p in paths]
    if s.get("still"):
        dst = os.path.join(OUT, s["name"] + ".png")
        imgs[0].save(dst, optimize=True)
    else:
        dst = os.path.join(OUT, s["name"] + ".webp")
        imgs[0].save(dst, save_all=True, append_images=imgs[1:], duration=round(1000 / s["fps"]), loop=0,
                     quality=s.get("q", 82), method=6, lossless=False)
    print(f"{os.path.basename(dst)}: {len(imgs)} frames, {os.path.getsize(dst) / 1024:.0f} KB")
