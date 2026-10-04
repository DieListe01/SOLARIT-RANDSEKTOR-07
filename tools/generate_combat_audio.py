"""Original family-specific combat audio synthesis. No gameplay edits."""
from pathlib import Path
import math,random,struct,wave
names=['ballistic_light','ballistic_heavy','autocannon','artillery','missile','energy','siege','special']
for index,name in enumerate(names+['core']):
 for event in ['shot','impact']:
  seconds=(.22+index*.055) if event=='shot' else (.38+index*.075)
  rng=random.Random(2186+index*37+(100 if event=='impact' else 0))
  values=[]; low=0.; rate=22050
  for i in range(int(rate*seconds)):
   t=i/rate; noise=rng.uniform(-1,1);low=low*.91+noise*.09
   freq=70+index*13
   tone=math.sin(math.tau*(freq*t-20*t*t))
   if name in ['energy','special']: tone=math.sin(math.tau*(1350*t-900*t*t));noise*=.15
   envelope=math.exp(-t*(6 if index>=6 else 12))
   value=(tone*.40+noise*.20+low*.8)*envelope
   if name=='autocannon': value*=.7+.3*math.sin(t*160)
   if name=='core': value+=math.sin(math.tau*42*t)*math.exp(-t*3)*.20
   values.append(int(max(-1,min(1,value))*28000))
  with wave.open(str(Path('assets/audio')/(name+'_'+event+'.wav')),'wb') as out:
   out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate);out.writeframes(struct.pack('<'+'h'*len(values),*values))
