#!/usr/bin/env python3
"""Render the Tom OS Plymouth splash and progress-bar textures."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math

OUT = Path(__file__).parent
W, H = 1920, 1080
img = Image.new("RGB", (W, H), (2, 2, 10))
px = img.load()
for y in range(H):
    for x in range(W):
        glow = max(0.0, 1.0 - math.sqrt(((x-W/2)/(W*.8))**2 + ((y-H*.48)/(H*.85))**2))
        px[x, y] = (int(2+7*glow), int(3+5*glow), int(12+32*glow))
# Soft purple/cyan halo behind the badge.
halo = Image.new("RGBA", (W,H), (0,0,0,0))
hd = ImageDraw.Draw(halo)
hd.ellipse((W//2-340, 80, W//2+340, 760), fill=(35, 15, 130, 100))
halo = halo.filter(ImageFilter.GaussianBlur(85))
img = Image.alpha_composite(img.convert("RGBA"), halo)
d = ImageDraw.Draw(img)
cx, cy = W//2, 390
# Circular brand badge with violet/cyan rim.
for box, color, width in [
    ((cx-310,cy-310,cx+310,cy+310),(100,45,255,255),7),
    ((cx-292,cy-292,cx+292,cy+292),(0,205,255,230),3),
    ((cx-265,cy-265,cx+265,cy+265),(130,70,255,200),3),
]:
    d.ellipse(box, outline=color, width=width)
d.ellipse((cx-220,cy-220,cx+220,cy+220), fill=(26,20,82,255))
# Monogram: elegant italic TTS lettering, rendered with a serif italic font.
font_paths = [
 "/usr/share/fonts/truetype/dejavu/DejaVuSerifCondensed-Italic.ttf",
 "/usr/share/fonts/truetype/liberation2/LiberationSerif-Italic.ttf",
 "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
]
font = next((ImageFont.truetype(p, 168) for p in font_paths if Path(p).exists()), ImageFont.load_default())
text = "TTS"
bbox = d.textbbox((0,0), text, font=font, stroke_width=1)
tw, th = bbox[2]-bbox[0], bbox[3]-bbox[1]
d.text((cx-tw/2, cy-th/2-bbox[1]), text, font=font, fill=(255,255,255,255), stroke_width=1)
# Curved brand wording represented as clean, readable title text.
small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf", 28) if Path("/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf").exists() else ImageFont.load_default()
brand = "TOMS TECHNOLOGY SUPPORT"
brand_w = d.textlength(brand, font=small)
d.text((cx-brand_w/2, cy-270), brand, font=small, fill=(191,112,255,255))
# Title and progress track; the fill is drawn live by Plymouth's script.
title_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 80) if Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf").exists() else ImageFont.load_default()
title = "TOM OS"
title_w = d.textlength(title, font=title_font)
d.text((cx-title_w/2, 710), title, font=title_font, fill=(75,205,255,255), stroke_width=1, stroke_fill=(125,40,255,255))
img.convert("RGB").save(OUT/"tomos-splash.png", quality=95)
# A rounded transparent track; progress fill is rendered by Plymouth.
bar = Image.new("RGBA", (760, 18), (0,0,0,0))
bd = ImageDraw.Draw(bar)
bd.rounded_rectangle((1,1,758,16), radius=8, outline=(135,65,255,255), width=3, fill=(7,5,25,220))
bar.save(OUT/"tomos-progress-track.png")
fill = Image.new("RGBA", (760, 12), (0,0,0,0))
fd = ImageDraw.Draw(fill)
for x in range(760):
    t=x/759
    fd.line((x,0,x,11), fill=(int(190*(1-t)),int(45+185*t),255,255))
fill.save(OUT/"tomos-progress-fill.png")
