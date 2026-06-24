#!/usr/bin/env python3
"""Generate TriggerHappy app icon at all required sizes."""

from PIL import Image, ImageDraw
import math
import os
import json

def generate_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    padding = size * 0.04
    s = size - padding * 2
    corner = s * 0.22

    # Background - warm orange base
    draw.rounded_rectangle(
        (padding, padding, padding + s, padding + s),
        radius=corner,
        fill=(255, 155, 20, 255)
    )

    # Gradient: brighter orange at top, deeper at bottom
    for i in range(int(s)):
        t = i / s
        r = int(255 - 40 * t)
        g = int(175 - 60 * t)
        b = int(30 - 15 * t)
        a = int(200 * (1 - t * 0.2))
        y = padding + i
        inset = 0
        if i < corner:
            inset = corner - math.sqrt(max(0, corner**2 - (corner - i)**2))
        elif i > s - corner:
            inset = corner - math.sqrt(max(0, corner**2 - (corner - (s - i))**2))
        x0 = padding + inset
        x1 = padding + s - inset
        if x1 > x0:
            draw.line([(x0, y), (x1, y)], fill=(r, g, b, a))

    # Lightning bolt
    cx = size / 2
    cy = size / 2
    sc = size / 512.0

    bolt = [
        (cx - 15*sc, cy - 145*sc),
        (cx + 85*sc, cy - 145*sc),
        (cx + 20*sc, cy - 10*sc),
        (cx + 80*sc, cy - 10*sc),
        (cx - 25*sc, cy + 155*sc),
        (cx + 15*sc, cy + 15*sc),
        (cx - 50*sc, cy + 15*sc),
    ]

    # Subtle shadow behind bolt
    shadow_offset = 4 * sc
    shadow_bolt = [(x + shadow_offset, y + shadow_offset) for x, y in bolt]
    draw.polygon(shadow_bolt, fill=(180, 80, 0, 60))

    # Main bolt - white
    draw.polygon(bolt, fill=(255, 255, 255, 255))

    # Slight gray shading on lower half for depth
    lower_half = [bolt[2], bolt[3], bolt[4], bolt[5]]
    draw.polygon(lower_half, fill=(235, 240, 245, 200))

    return img

def main():
    iconset_dir = "TriggerHappy/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(iconset_dir, exist_ok=True)

    sizes = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2),
    ]

    images_json = []
    for points, scale in sizes:
        pixels = points * scale
        filename = f"icon_{points}x{points}{'@2x' if scale == 2 else ''}.png"
        icon = generate_icon(pixels)
        icon.save(os.path.join(iconset_dir, filename), "PNG")
        print(f"  Generated {filename} ({pixels}x{pixels}px)")
        images_json.append({
            "filename": filename,
            "idiom": "mac",
            "scale": f"{scale}x",
            "size": f"{points}x{points}"
        })

    contents = {"images": images_json, "info": {"author": "xcode", "version": 1}}
    with open(os.path.join(iconset_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print("\nIcon set generated!")

if __name__ == "__main__":
    main()
