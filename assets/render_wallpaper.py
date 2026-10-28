#!/usr/bin/env python3
"""Generate an original Tom OS-inspired violet neon mountain/lake wallpaper."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from pathlib import Path
import math, random

W, H = 1920, 1080
random.seed(26)
out = Path(__file__).with_name("neon-punk.png")
img = Image.new("RGB", (W, H))
px = img.load()
for y in range(H):
    for x in range(W):
        glow = max(0.0, 1.0 - math.sqrt(((x-W*.53)/(W*.78))**2 + ((y-H*.46)/(H*.9))**2))
        px[x,y] = (int(3+10*glow), int(5+5*glow), int(22+36*glow))
art = Image.new("RGBA", (W,H), (0,0,0,0))
d = ImageDraw.Draw(art)
# Glowing violet planet and cyan rim.
d.ellipse((650,70,1270,690), fill=(24,12,79,220), outline=(183,60,255,245), width=8)
d.ellipse((670,90,1250,670), outline=(0,210,255,190), width=3)
d.ellipse((710,130,1210,630), outline=(118,60,255,160), width=3)
# Layered mountain silhouettes.
r1=[(0,620),(100,530),(170,575),(270,420),(345,510),(450,460),(550,575),(650,490),(740,570),(830,445),(945,560),(1050,470),(1160,590),(1280,450),(1390,550),(1490,420),(1600,545),(1710,470),(1810,555),(1920,430),(1920,800),(0,800)]
d.polygon(r1,fill=(31,20,87,255))
d.line(r1[:20],fill=(180,65,255,220),width=4)
r2=[(0,700),(130,610),(220,670),(360,540),(470,655),(600,580),(720,690),(850,570),(980,675),(1110,590),(1230,700),(1370,565),(1510,690),(1640,590),(1770,685),(1880,575),(1920,620),(1920,850),(0,850)]
d.polygon(r2,fill=(12,20,58,255))
d.line(r2[:18],fill=(55,120,255,175),width=3)
# Dark pine forest at the shoreline.
for x in range(-10,W+20,24):
    y=720+random.randint(-30,65)
    h=random.randint(35,105)
    d.polygon([(x,y-h),(x-13,y+15),(x-5,y+8),(x-20,y+35),(x+17,y+35),(x+6,y+7),(x+15,y+15)],fill=(5,10,29,245))
# Reflective neon lake.
d.rectangle((0,770,W,H),fill=(5,12,38,235))
for i in range(30):
    y=790+i*10
    inset=int(abs(math.sin(i*.24))*180)
    d.line([(inset,y),(W-inset,y)],fill=(50,65+int(30*math.sin(i)),205,max(25,125-i*3)),width=2)
for x in range(80,W,90):
    d.line([(x,795),(x+random.randint(-40,40),H)],fill=(125,35,255,random.randint(20,65)),width=2)
# Central TS badge and title, echoing the supplied desktop artwork.
cx,cy=960,400
d.ellipse((cx-215,cy-215,cx+215,cy+215),fill=(9,7,37,235),outline=(159,65,255,240),width=5)
d.ellipse((cx-190,cy-190,cx+190,cy+190),outline=(0,215,255,180),width=2)
d.ellipse((cx-145,cy-145,cx+145,cy+145),fill=(27,16,86,250),outline=(115,57,235,220),width=3)
try:
    font_logo=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerifCondensed-Italic.ttf",112)
    font_title=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",78)
    font_sub=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",24)
except OSError:
    font_logo=font_title=font_sub=ImageFont.load_default()
d.text((cx,cy-10),"TS",font=font_logo,fill=(250,244,255,255),anchor="mm",stroke_width=1,stroke_fill=(158,95,255,255))
d.text((cx,735),"T O M   O S",font=font_title,fill=(232,218,255,255),anchor="mm",stroke_width=1,stroke_fill=(125,55,255,255))
d.line((610,790,1310,790),fill=(190,70,255,245),width=5)
d.line((680,800,1240,800),fill=(0,215,255,200),width=2)
d.text((cx,835),"P O W E R E D   B Y   O M A R C H Y   L I N U X",font=font_sub,fill=(222,218,255,255),anchor="mm")
glow=art.filter(ImageFilter.GaussianBlur(16))
img=Image.alpha_composite(img.convert("RGBA"),glow)
img=Image.alpha_composite(img,art)
img.convert("RGB").save(out,quality=95)
print(f"Created {out}")
