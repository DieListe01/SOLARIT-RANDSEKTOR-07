from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
import json

ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/"test-output/faction_building_contact.json").read_text(encoding="utf-8"))
roles=manifest["roles"]; factions=manifest["factions"]; cell=512
try: font=ImageFont.truetype("C:/Windows/Fonts/arial.ttf",32)
except OSError: font=ImageFont.load_default()
try: small=ImageFont.truetype("C:/Windows/Fonts/arial.ttf",24)
except OSError: small=ImageFont.load_default()
labels={"forge":"KOBALT","drift":"WANDERPAKT","lumen":"PRISMA"}
header_height=82
for gray in (False,True):
    sheet=Image.new("RGB",(3*cell, header_height+len(roles)*cell),(20,24,25)); draw=ImageDraw.Draw(sheet)
    for c,faction in enumerate(factions):
        x=c*cell
        draw.rectangle((x+1,1,x+cell-2,header_height-2),outline=(89,77,62),width=2)
        draw.text((x+20,20),labels[faction],font=font,fill=(236,196,127))
    for r,role in enumerate(roles):
        for c,faction in enumerate(factions):
            img=Image.open(manifest["captures"][f"{faction}_{role}"]).convert("RGBA")
            if gray:
                alpha=img.getchannel("A")
                img=ImageOps.grayscale(img.convert("RGB")).convert("RGBA")
                img.putalpha(alpha)
            x,y=c*cell,header_height+r*cell
            alpha=img.getchannel("A")
            bounds=alpha.point(lambda value:255 if value>10 else 0).getbbox()
            if bounds:
                left,top,right,bottom=bounds
                padding=14
                crop=img.crop((max(0,left-padding),max(0,top-padding),min(cell,right+padding),min(cell,bottom+padding)))
                crop.thumbnail((390,355),Image.Resampling.LANCZOS)
                cell_layer=Image.new("RGBA",(cell,cell),(20,24,25,255))
                cell_layer.alpha_composite(crop,((cell-crop.width)//2,(cell-crop.height)//2+22))
                sheet.paste(cell_layer.convert("RGB"),(x,y))
            draw.rectangle((x+1,y+1,x+cell-2,y+cell-2),outline=(64,66,63),width=1)
            draw.text((x+18,y+14),role.upper(),font=small,fill=(235,199,135))
    out=ROOT/f"test-output/faction_building_contact_sheet{'_grayscale' if gray else ''}.png"
    sheet.save(out)
    print(out)
