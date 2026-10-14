"""Regenerates every logo / icon asset from the real Grazia logo.

Source: tool/brand/mask_*.png (alpha masks extracted at 300 dpi from the client's 'New Grazia company profile.pdf' cover).
Run:  python3 tool/make_brand_assets.py   (needs Pillow + numpy)
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tool', 'brand')
GOLD_TOP, GOLD_MID, GOLD_BOT = (244, 218, 128), (212, 175, 55), (160, 120, 30)
BG_CENTER, BG_EDGE = (44, 35, 24), (12, 10, 7)


def mask(name):
    return Image.open(os.path.join(SRC, f'mask_{name}.png')).convert('L')


def fit(img, w=None, h=None):
    r = (w / img.width) if w else (h / img.height)
    return img.resize((max(1, round(img.width * r)), max(1, round(img.height * r))), Image.LANCZOS)


def gradient(size, stops, vertical=True):
    w, h = size
    n = h if vertical else w
    t = np.linspace(0, 1, n)
    cols = np.zeros((n, 3))
    for c in range(3):
        cols[:, c] = np.interp(t, [0, 0.5, 1], [stops[0][c], stops[1][c], stops[2][c]])
    arr = np.repeat(cols[:, None, :], w, axis=1) if vertical else np.repeat(cols[None, :, :], h, axis=0)
    return Image.fromarray(arr.astype('uint8'), 'RGB')


def colorize(m, kind):
    if kind == 'gold':
        img = gradient(m.size, (GOLD_TOP, GOLD_MID, GOLD_BOT)).convert('RGBA')
    else:
        rgb = {'white': (255, 255, 255), 'dark': (27, 23, 18)}[kind]
        img = Image.new('RGBA', m.size, rgb + (255,))
    img.putalpha(m)
    return img


def radial_bg(size):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h * 0.46) / (h / 2)) ** 2).clip(0, 1)
    arr = np.zeros((h, w, 3))
    for c in range(3):
        arr[:, :, c] = BG_CENTER[c] + (BG_EDGE[c] - BG_CENTER[c]) * d
    return Image.fromarray(arr.astype('uint8'), 'RGB').convert('RGBA')


def save(img, rel, **kw):
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p, optimize=True, **kw)


emblem, word, lock = mask('emblem'), mask('wordmark'), mask('logo')

# 1. in-app brand images (same file names the app already references)
for kind in ('gold', 'white', 'dark'):
    save(colorize(fit(emblem, h=640), kind), f'assets/brand/grazia-emblem-{kind}.png')
    save(colorize(fit(word, w=1200), kind), f'assets/brand/grazia-wordmark-{kind}.png')
    save(colorize(fit(lock, w=1100), kind), f'assets/brand/grazia-logo-{kind}.png')
save(colorize(fit(emblem, h=640), 'gold'), 'assets/brand/grazia-emblem.png')
save(colorize(fit(lock, w=1100), 'dark'), 'assets/brand/grazia-logo.png')


def icon_master(px, emblem_frac=0.52, with_bg=True):
    bg = radial_bg((px, px)) if with_bg else Image.new('RGBA', (px, px), (0, 0, 0, 0))
    e = colorize(fit(emblem, h=round(px * emblem_frac)), 'gold')
    # soft glow under the emblem for depth
    glow = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    glow.paste((212, 175, 55, 70), ((px - e.width) // 2, (px - e.height) // 2 + round(px * 0.01)), e.getchannel('A'))
    if with_bg:
        bg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(px * 0.018)))
    bg.alpha_composite(e, ((px - e.width) // 2, (px - e.height) // 2))
    return bg


# 2. Android adaptive + legacy icons
densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for d, s in densities.items():
    fg = round(108 * s)
    save(icon_master(fg, 0.46, with_bg=False), f'android/app/src/main/res/mipmap-{d}/ic_launcher_foreground.png')
    mono = Image.new('RGBA', (fg, fg), (0, 0, 0, 0))
    em = colorize(fit(emblem, h=round(fg * 0.46)), 'white')
    mono.alpha_composite(em, ((fg - em.width) // 2, (fg - em.height) // 2))
    save(mono, f'android/app/src/main/res/mipmap-{d}/ic_launcher_monochrome.png')
    legacy = round(48 * s)
    master = icon_master(legacy * 4, 0.56)
    r = Image.new('L', master.size, 0)
    ImageDraw.Draw(r).rounded_rectangle((0, 0, master.width - 1, master.height - 1), radius=master.width // 5, fill=255)
    master.putalpha(r)
    save(master.resize((legacy, legacy), Image.LANCZOS), f'android/app/src/main/res/mipmap-{d}/ic_launcher.png')

# 3. iOS app icon: full-bleed, no alpha (Apple rounds it)
big = icon_master(1024, 0.54).convert('RGB')
sizes = {
    'Icon-App-20x20@1x': 20, 'Icon-App-20x20@2x': 40, 'Icon-App-20x20@3x': 60,
    'Icon-App-29x29@1x': 29, 'Icon-App-29x29@2x': 58, 'Icon-App-29x29@3x': 87,
    'Icon-App-40x40@1x': 40, 'Icon-App-40x40@2x': 80, 'Icon-App-40x40@3x': 120,
    'Icon-App-60x60@2x': 120, 'Icon-App-60x60@3x': 180,
    'Icon-App-76x76@1x': 76, 'Icon-App-76x76@2x': 152, 'Icon-App-83.5x83.5@2x': 167,
    'Icon-App-1024x1024@1x': 1024,
}
for name, px in sizes.items():
    save(big if px == 1024 else big.resize((px, px), Image.LANCZOS), f'ios/Runner/Assets.xcassets/AppIcon.appiconset/{name}.png')

# 4. Play Store listing graphics
play = icon_master(512, 0.54)
save(play, 'docs/store-listing/assets/play_icon_512.png')
fw, fh = 1024, 500
feat = radial_bg((fw, fh))
lk = colorize(fit(lock, h=330), 'gold')
feat.alpha_composite(lk, (70, (fh - lk.height) // 2))
dr = ImageDraw.Draw(feat)
try:
    from PIL import ImageFont
    f1 = ImageFont.truetype('/System/Library/Fonts/Supplemental/Georgia Bold.ttf', 44)
    f2 = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', 23)
except Exception:
    f1 = f2 = None
dr.text((520, 150), 'Natural stone,', fill=(250, 244, 230), font=f1)
dr.text((520, 205), 'on your wall.', fill=(212, 175, 55), font=f1)
dr.text((520, 290), 'Browse 35 collections and 95+ designs.', fill=(205, 196, 180), font=f2)
dr.text((520, 328), 'Calculate. Quote. Sample.', fill=(205, 196, 180), font=f2)
save(feat.convert('RGB'), 'docs/store-listing/assets/feature_graphic_1024x500.png')
print('brand assets regenerated')
