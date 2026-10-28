#!/usr/bin/env python3
"""Generate the PunkSway blue-neon wallpaper. Requires Pillow (python3-pil)."""
from PIL import Image, ImageDraw, ImageFilter
import math
from pathlib import Path

W, H = 1920, 1080
out = Path(__file__).with_name("neon-punk.png")
base = Image.new("RGB", (W, H))
px = base.load()
for y in range(H):
    for x in range(W):
        glow = max(0.0, 1.0 - math.sqrt(((x-1380)/1200)**2 + ((y-520)/900)**2))
        px[x, y] = (int(3+2*glow), int(7+16*glow), int(19+36*glow))
art = Image.new("RGBA", (W, H), (0,0,0,0))
d = ImageDraw.Draw(art)
# angled cyberpunk linework, concentrated on the right to leave room for windows
for i in range(22):
    x = 940 + i*54
    d.line([(x,0),(x-420,H)], fill=(0, 200+min(i*2,55), 255, 100), width=2)
for i in range(13):
    y = 80+i*78
    d.line([(860,y),(W,y-170)], fill=(0, 130, 255, 95), width=2)
# bright angular neon shards
d.line([(1130,150),(1580,380),(1330,700),(1740,900)], fill=(0,235,255,220), width=7)
d.line([(1200,120),(1650,350),(1400,670),(1810,870)], fill=(95,75,255,190), width=3)
d.line([(990,790),(1350,520),(1640,680),(1900,410)], fill=(0,190,255,180), width=4)
# central cyan ring and crosshair details
d.ellipse((1280,270,1660,650), outline=(0,225,255,130), width=3)
d.ellipse((1320,310,1620,610), outline=(100,80,255,100), width=2)
for x in range(1320,1620,30):
    d.line([(x,455),(x+8,455)], fill=(0,240,255,170), width=2)
glow = art.filter(ImageFilter.GaussianBlur(18))
base = Image.alpha_composite(base.convert("RGBA"), glow)
base = Image.alpha_composite(base, art)
base.convert("RGB").save(out, quality=95)
print(f"Created {out}")