from PIL import Image, ImageDraw
from pathlib import Path
import random
scale=4
cell=32
atlas=Image.new('RGBA',(cell*4*scale,cell*3*scale),(0,0,0,0))
for row,count in enumerate((2,5,8)):
 for col in range(4):
  rng=random.Random(9137+row*73+col*211)
  ox=col*cell*scale; oy=row*cell*scale
  draw=ImageDraw.Draw(atlas,'RGBA')
  for _ in range(count):
   x=rng.randint(5,27)*scale+ox; y=rng.randint(14,28)*scale+oy
   h=rng.randint(6,14)*scale; w=rng.randint(2,5)*scale; lean=rng.randint(-2,2)*scale
   draw.polygon([(x-w,y+2*scale),(x+w,y+2*scale),(x+6*scale,y+5*scale),(x-3*scale,y+4*scale)],fill=(20,37,30,105))
   top=(x+lean,y-h)
   draw.polygon([(x-w,y),(x-w//2,top[1]+h//3),top,(x+w,y-h//3),(x+w,y),(x,y+2*scale)],fill=(61,161,151,255))
   draw.polygon([(x-w//2,top[1]+h//3),top,(x+w,y-h//3),(x+w//3,y-h//5),(x,y)],fill=(128,228,201,255))
   draw.polygon([top,(x+w,y-h//3),(x+w,y),(x,y+2*scale)],fill=(52,145,141,255))
   draw.line((x+lean,y-h+scale,x,y),fill=(228,255,226,225),width=scale)
atlas=atlas.resize((cell*4,cell*3),Image.Resampling.LANCZOS)
out=Path('assets/solarit_atlas.png'); atlas.save(out,optimize=True)
print(f'{out} {atlas.size}')
