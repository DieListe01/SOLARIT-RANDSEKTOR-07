from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"test-output"
FACTIONS=[("forge","KOBALT · KONSORTIUM"),("drift","WANDERPAKT"),("lumen","PRISMA-KONKLAVE")]
ROLES=[("scout","SPÄHER"),("raider","STURMJÄGER"),("tank","KAMPFPANZER"),("siege","BELAGERER"),("harvester","SAMMLER"),("lancer","LANZIERER"),("scorcher","FLAMMENWERFER"),("bulwark","DURCHBRUCHPANZER")]
CW,CH,HEAD,SIZE=530,212,78,176
W,H=CW*3,HEAD+CH*len(ROLES)
font_path=Path("C:/Windows/Fonts/arial.ttf")
font_bold=ImageFont.truetype(str(font_path),22)
font_small=ImageFont.truetype(str(font_path),16)
sheet=Image.new("RGBA",(W,H),(20,25,26,255)); draw=ImageDraw.Draw(sheet)
for col,(faction,title) in enumerate(FACTIONS):
    x=col*CW
    draw.rectangle((x,0,x+CW-2,HEAD-3),fill=(38,47,47,255),outline=(129,111,82,255),width=2)
    draw.text((x+18,20),title,font=font_bold,fill=(235,221,188,255))
for row,(kind,role) in enumerate(ROLES):
    y=HEAD+row*CH
    for col,(faction,_) in enumerate(FACTIONS):
        x=col*CW
        bg=(35,40,39,255) if row%2==0 else (29,34,34,255)
        draw.rectangle((x,y,x+CW-2,y+CH-2),fill=bg,outline=(83,76,64,255),width=1)
        draw.text((x+16,y+10),role,font=font_small,fill=(228,175,96,255))
        p=OUT/f"faction_contact_{faction}_{kind}.png"
        if not p.exists(): raise FileNotFoundError(p)
        art=Image.open(p).convert("RGBA")
        # Preserve the exact cache render and uniformly scale all factions/roles
        # into identical comparison cells, just above the usual 82px world icon.
        art=art.resize((SIZE,SIZE),Image.Resampling.LANCZOS)
        sheet.alpha_composite(art,(x+(CW-SIZE)//2,y+28))
color=sheet.convert("RGB")
color.save(OUT/"faction_vehicle_contact_sheet.png",quality=95)
gray=ImageOps.grayscale(color).convert("RGB")
gray.save(OUT/"faction_vehicle_contact_sheet_grayscale.png",quality=95)
print(OUT/"faction_vehicle_contact_sheet.png")
print(OUT/"faction_vehicle_contact_sheet_grayscale.png")
