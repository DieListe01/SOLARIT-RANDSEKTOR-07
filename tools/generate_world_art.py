"""Original layered terrain decals; reproducible from the shipped mission, no external artwork."""
import json
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
mission = json.loads((ROOT / 'data/veyra.json').read_text(encoding='utf-8'))
rng = random.Random(mission['seed'])
SCALE = 2
width, height = mission['width'], mission['height']
terrain = [[0 for _ in range(width)] for _ in range(height)]
types = {'rock': 1, 'dunes': 2, 'hard_ground': 4, 'crater': 5, 'cliff': 6}
for region in mission['terrain_regions']:
    x, y, w, h = region['rect']
    for row in range(y, y+h):
        for col in range(x, x+w):
            terrain[row][col] = types[region['type']]

image = Image.new('RGBA', (width*32*SCALE, height*32*SCALE))
shadow = Image.new('RGBA', image.size)
ink = ImageDraw.Draw(image)
shade = ImageDraw.Draw(shadow)

def points(vertices):
    return [(round(x*SCALE), round(y*SCALE)) for x, y in vertices]

def stroke(vertices, color, thickness=1):
    ink.line(points(vertices), fill=color, width=max(1, round(thickness*SCALE)))

def stone(x, y, radius, cliff=False):
    vertices=[]
    for i in range(7):
        angle=i*math.tau/7
        r=radius*rng.uniform(.73,1.18)
        vertices.append((x+math.cos(angle)*r, y+math.sin(angle)*r*.62))
    shade.polygon(points([(a+radius*.45,b+radius*.5) for a,b in vertices]),fill=(36,22,15,125 if cliff else 75))
    tone=rng.randrange(-12,17)
    base=(113+tone,88+tone,62+tone,230 if cliff else 195)
    ink.polygon(points(vertices),fill=base)
    top=[vertices[0],vertices[1],(x-radius*.16,y-radius*.18),vertices[-1]]
    ink.polygon(points(top),fill=(172+tone,136+tone,89+tone,210))
    ink.polygon(points([vertices[1],vertices[2],vertices[3],(x-radius*.16,y-radius*.18)]),fill=(75+tone,54+tone,38+tone,210))
    stroke([vertices[-1],vertices[0],vertices[1]],(177,162,127,145),.6)
    if radius>6:
        stroke([(x-radius*.6,y+1),(x-radius*.1,y-2),(x+radius*.4,y+1)],(42,47,39,145),.6)

for y in range(height):
    for x in range(width):
        kind=terrain[y][x]
        ox,oy=x*32,y*32
        # Fine grit and differently sized mineral fragments, grouped rather than a repeated tile motif.
        for _ in range(5 if kind in (1,6) else 3):
            px,py=ox+rng.uniform(1,31),oy+rng.uniform(1,31)
            size=rng.uniform(.3,1.2)
            color=(34,39,31,90) if kind in (1,6) else (77,48,25,65)
            stroke([(px,py),(px+size*1.5,py-.4)],color,.6)
            stroke([(px,py-.7),(px+size,py-.9)],(217,187,131,85),.45)
        if kind==6:
            stone(ox+rng.uniform(7,27),oy+rng.uniform(5,30),rng.uniform(12,23),True)
            for _ in range(3): stone(ox+rng.uniform(0,32),oy+rng.uniform(0,32),rng.uniform(2,5),True)
        elif rng.random() < (.32 if kind==1 else .17):
            px,py=ox+rng.uniform(5,27),oy+rng.uniform(5,27)
            stone(px,py,rng.uniform(2,8))
            for _ in range(rng.randrange(2,5)):
                stone(px+rng.uniform(-12,12),py+rng.uniform(-8,9),rng.uniform(.8,2.5))
        if kind==1 and rng.random()<.21:
            px,py=ox+rng.uniform(1,20),oy+rng.uniform(1,25)
            vertices=[(px,py)]
            for i in range(5): vertices.append((px+i*5+rng.uniform(-2,2),py+rng.uniform(-5,5)))
            stroke(vertices,(24,31,26,85),.7)
            stroke([(a,b-1) for a,b in vertices],(160,150,116,55),.6)
        if kind in (0,2) and rng.random()<.28:
            px,py=ox+rng.uniform(-5,12),oy+rng.uniform(2,26)
            for row in range(3):
                vertices=[(px+i*5,py+row*2.5+math.sin(i*.45+x)*2) for i in range(9)]
                stroke(vertices,(238,184,116,65),.8)
                stroke([(a,b+1.1) for a,b in vertices],(89,52,29,45),.7)
        # Charred, dried mineral tufts punctuate open sand without adding living vegetation.
        if kind==0 and rng.random()<.11:
            px,py=ox+rng.uniform(5,26),oy+rng.uniform(5,26)
            shade.ellipse(points([(px-4,py-1),(px+6,py+3)]),fill=(20,25,18,55))
            for _ in range(7):
                dx,dy=rng.uniform(-4,4),rng.uniform(-5,1)
                stroke([(px,py),(px+dx,py+dy)],(54,45,28,160),.8)
                stroke([(px+dx,py+dy),(px+dx+1.5,py+dy-1)],(149,122,76,95),.55)

# Broad original landmarks live in the same cached art layer in both render modes.
# These are surface decals: navigation and buildability remain the mission grid's responsibility.
for cx,cy,rx,ry in [(820,1160,100,50),(1160,610,125,58),(480,960,85,42)]:
    ink.ellipse(points([(cx-rx,cy-ry),(cx+rx,cy+ry)]),fill=(57,35,22,38))
    for ring in range(3):
        vertices=[(cx+math.cos(i*math.tau/64)*(rx+ring*4),cy+math.sin(i*math.tau/64)*(ry+ring*2)) for i in range(65)]
        stroke(vertices,(223,166,95,65-ring*13),1.4)
    for i in range(9): stone(cx+rng.uniform(-rx,rx),cy+rng.uniform(-ry,ry),rng.uniform(2,7))
# Abandoned haul routes and dry channels create larger readable direction cues.
for path in [[(190,1840),(300,1660),(430,1510),(690,1440),(830,1280)],[(1240,240),(1130,430),(1090,680),(1040,810)]]:
    for side in [-1,1]:
        route=[(x+side*9,y) for x,y in path]
        stroke(route,(47,30,20,34),4.5)
        stroke([(x+2,y-1) for x,y in route],(239,181,111,38),1.1)
    for x,y in path:
        for i in range(6): stroke([(x+i*4-12,y-5),(x+i*4-12,y+8)],(41,29,22,35),.8)
# Small scrap clusters: distinct warm metal and bent conduits, no new blocking objects.
for cx,cy in [(770,1610),(480,1180),(1760,960),(1220,1330),(310,620)]:
    ink.ellipse(points([(cx-32,cy-16),(cx+37,cy+19)]),fill=(52,29,19,34))
    for i in range(10):
        x,y=cx+rng.uniform(-24,26),cy+rng.uniform(-13,14)
        vertices=[(x-6,y-2),(x+8,y-5),(x+5,y+4),(x-5,y+3)]
        shade.polygon(points([(a+3,b+3) for a,b in vertices]),fill=(32,21,15,100))
        ink.polygon(points(vertices),fill=(100+i*3,72+i,48+i,170))
        stroke([vertices[0],vertices[1]],(201,164,105,175),1)
    stroke([(cx-15,cy+8),(cx-4,cy-7),(cx+13,cy-5),(cx+21,cy+7)],(66,49,34,180),3)
    stroke([(cx-16,cy+7),(cx-5,cy-8),(cx+12,cy-6)],(176,143,98,150),.8)
# Sweeping dune contours, mineral seams and powder fans link the micro detail to the landscape.
for cx,cy in [(780,430),(1200,1660),(1630,1880)]:
    for row in range(8):
        vertices=[(cx-100+i*9,cy+row*5+math.sin(i*.14)*19) for i in range(25)]
        stroke(vertices,(236,180,108,max(15,62-row*5)),1.2)
        stroke([(x,y+2) for x,y in vertices],(72,45,28,28),.8)

# Regional landmarks are cosmetic: broad traces without adding navigation obstacles.
# An abandoned processing yard between the basin and the central pass.
cx, cy = 940, 1080
ink.polygon(points([(cx-93,cy-36),(cx+66,cy-51),(cx+100,cy+35),(cx-62,cy+58)]),fill=(51,30,18,44))
for offset in [-44, 0, 44]:
    vertices=[(cx+offset-15,cy-26),(cx+offset+16,cy-31),(cx+offset+21,cy+23),(cx+offset-12,cy+29)]
    ink.polygon(points(vertices),fill=(92,66,43,102))
    stroke([vertices[0],vertices[1],vertices[2]],(181,140,88,118),2)
    for rib in range(5): stroke([(cx+offset-12,cy-20+rib*9),(cx+offset+15,cy-24+rib*9)],(35,24,18,92),1.4)
stroke([(cx-102,cy+42),(cx-45,cy+31),(cx+25,cy+38),(cx+105,cy+20)],(84,56,35,100),6)
stroke([(cx-102,cy+40),(cx-45,cy+29),(cx+25,cy+36),(cx+105,cy+18)],(195,149,89,85),1.4)
# Windswept plateau bands around the enemy approach; no extra small stones.
for row in range(6):
    vertices=[(1380+i*22,420+row*13+math.sin(i*0.22)*24) for i in range(19)]
    stroke(vertices,(56,33,21,35),5-row*.4)
    stroke([(x,y-3) for x,y in vertices],(226,169,99,42),1.3)

image = Image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(2.2)),image)
image.save(ROOT/'assets/terrain_detail.png', optimize=True)
print('Original terrain layers generated:', image.size)
