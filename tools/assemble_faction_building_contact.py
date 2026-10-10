from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
import json

ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/"test-output/faction_building_contact.json").read_text(encoding="utf-8"))
roles=manifest["roles"]; factions=manifest["factions"]; cell=512
try: font=ImageFont.truetype("C:/Windows/Fonts/arial.ttf",22)
except OSError: font=ImageFont.load_default()
try: small=ImageFont.truetype("C:/Windows/Fonts/arial.ttf",17)
except OSError: small=ImageFont.load_default()
labels={"forge":"KOBALT","drift":"WANDERPAKT","lumen":"PRISMA"}
for gray in (False,True):
    sheet=Image.new("RGB",(3*cell, (len(roles)+1)*cell),(20,24,25)); draw=ImageDraw.Draw(sheet)
    for c,faction in enumerate(factions):
        draw.text((c*cell+16,8),labels[faction],font=font,fill=(225,225,225))
    for r,role in enumerate(roles):
        for c,faction in enumerate(factions):
            img=Image.open(manifest["captures"][f"{faction}_{role}"]).convert("RGBA")
            if gray: img=ImageOps.grayscale(img).convert("RGBA")
            x,y=c*cell,(r+1)*cell
            sheet.paste(img,(x,y),img)
            draw.text((x+12,y+12),role.upper(),font=small,fill=(20,20,20,255),stroke_width=1,stroke_fill=(220,210,190,255))
    out=ROOT/f"test-output/faction_building_contact_sheet{'_grayscale' if gray else ''}.png"
    sheet.save(out)
    print(out)
