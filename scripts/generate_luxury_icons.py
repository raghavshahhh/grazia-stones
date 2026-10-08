import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_luxury_icon():
    size = 1024
    # Create RGBA canvas
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    
    # 1. Base luxury gradient (dark rich stone obsidian #151413 to #0B0A0A)
    # Radial ambient light centered at (512, 480)
    base = Image.new("RGBA", (size, size), (16, 15, 14, 255))
    draw = ImageDraw.Draw(base)
    
    cx, cy = 512, 490
    max_r = 550
    for r in range(max_r, 0, -5):
        alpha = int(35 * (1.0 - (r / max_r) ** 1.3))
        # Subtle warm champagne gold glow (#D4AF37)
        color = (212, 175, 55, alpha)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    
    # 2. Subtle luxury concentric architectural stone border ring
    ring_r = 460
    draw.ellipse(
        [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
        outline=(212, 175, 55, 30),
        width=2
    )

    # 3. Load official gold emblem
    emblem_path = 'assets/brand/grazia-emblem-gold.png'
    if not os.path.exists(emblem_path):
        emblem_path = 'assets/brand/grazia-emblem.png'
    
    emblem = Image.open(emblem_path).convert("RGBA")
    
    # Target emblem size: 540x540 inside 1024x1024 (Apple HIG safe zone)
    target_emblem_w = 540
    aspect = emblem.height / emblem.width
    target_emblem_h = int(target_emblem_w * aspect)
    
    emblem_resized = emblem.resize((target_emblem_w, target_emblem_h), Image.Resampling.LANCZOS)
    
    # Slight drop shadow for depth
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ex = (size - target_emblem_w) // 2
    ey = (size - target_emblem_h) // 2 - 10
    
    shadow_mask = emblem_resized.split()[3]
    shadow_layer = Image.new("RGBA", (target_emblem_w, target_emblem_h), (0, 0, 0, 140))
    shadow.paste(shadow_layer, (ex, ey + 18), mask=shadow_mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    
    # Composite layers
    base.alpha_composite(shadow)
    base.paste(emblem_resized, (ex, ey), mask=emblem_resized.split()[3])
    
    # Final 1024x1024 RGB image (iOS App Store rejects alpha in app icons)
    final_icon = Image.new("RGB", (size, size), (16, 15, 14))
    final_icon.paste(base, (0, 0), mask=base.split()[3])
    
    # Save master
    os.makedirs('assets/icons', exist_ok=True)
    master_path = 'assets/icons/app_icon_1024.png'
    final_icon.save(master_path, quality=100)
    print(f"Saved master icon: {master_path}")
    
    # Generate all iOS sizes
    ios_dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    ios_sizes = {
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
    }
    
    for filename, s in ios_sizes.items():
        out_p = os.path.join(ios_dir, filename)
        resized = final_icon.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(out_p, quality=100)
        print(f"Generated iOS icon: {filename} ({s}x{s})")
        
    # Generate Android sizes
    android_res = 'android/app/src/main/res'
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    
    for folder, s in android_sizes.items():
        fdir = os.path.join(android_res, folder)
        os.makedirs(fdir, exist_ok=True)
        out_p = os.path.join(fdir, 'ic_launcher.png')
        resized = final_icon.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(out_p, quality=100)
        print(f"Generated Android icon: {folder}/ic_launcher.png ({s}x{s})")

if __name__ == '__main__':
    create_luxury_icon()
