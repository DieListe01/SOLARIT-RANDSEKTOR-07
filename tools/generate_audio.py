"""Original ASHLINE synthesis. Standard library only; no samples or borrowed melodies."""
from pathlib import Path
import math, random, wave, array

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
OUT.mkdir(parents=True, exist_ok=True)
RATE = 22050
LENGTH = 16.0  # 8 bars, 120 BPM; all stems share the same downbeat.
random.seed(78124)

def write(name, samples):
    pcm = array.array('h', (int(max(-1, min(1, x)) * 25000) for x in samples))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(pcm.tobytes())

def tone(buffer, start, length, midi, volume, style='fm'):
    freq = 440 * 2 ** ((midi - 69) / 12)
    count = int(length * RATE)
    offset = int(start * RATE)
    for i in range(count):
        if offset + i >= len(buffer): break
        t = i / RATE
        env = min(1, t / .012) * min(1, (length-t) / .09) * math.exp(-t / (length*.8))
        phase = 2 * math.pi * freq * t
        if style == 'pad': v = math.sin(phase) + .25*math.sin(phase*2.002)
        elif style == 'bass': v = math.sin(phase + 1.8*math.sin(phase*2)*math.exp(-t*12))
        else: v = math.sin(phase + .7*math.sin(phase*3))* .8 + .2*math.sin(phase*2)
        buffer[offset+i] += v * env * volume

def percussion(buffer, start, heavy=False):
    for i in range(int(.21*RATE)):
        n = int(start*RATE)+i
        if n >= len(buffer): break
        t=i/RATE
        v=math.sin(2*math.pi*(48*t+7*(1-math.exp(-t*35)))) * math.exp(-t*23)
        buffer[n] += v*(.42 if heavy else .28)

motif = [0,7,10,7,3,7,5,2,0,12,10,7,5,3,2,7]
for faction, root in [('forge',38),('drift',43),('lumen',45)]:
    for layer in ['calm','contact','battle','alarm']:
        buf=[0.0]*int(RATE*LENGTH)
        for bar in range(8):
            chord = [0,3,5,2][bar%4]
            if layer == 'calm':
                for interval in [0,7,12]: tone(buf,bar*2,1.95,root+12+chord+interval,.055,'pad')
                for beat in range(4): tone(buf,bar*2+beat*.5,.38,root+chord,.19,'bass')
                percussion(buf,bar*2)
            elif layer == 'contact':
                for step in range(8):
                    index=(bar*2+step)%16 if faction!='lumen' else (bar+step*3)%16
                    tone(buf,bar*2+step*.25,.18,root+24+motif[index],.1)
            elif layer == 'battle':
                for beat in range(4): percussion(buf,bar*2+beat*.5,True)
                for beat in [1,3]:
                    start=int((bar*2+beat*.5)*RATE)
                    for i in range(int(.14*RATE)):
                        if start+i<len(buf): buf[start+i]+=random.uniform(-1,1)*math.exp(-i/RATE*28)*.16
                for step in range(4): tone(buf,bar*2+step*.5,.43,root+24+motif[(bar*2+step)%16],.15)
            elif layer == 'alarm':
                for step in range(8): tone(buf,bar*2+step*.25,.21,root+12+[0,0,7,0,3,0,10,7][step],.18,'bass')
                for beat in range(4): percussion(buf,bar*2+beat*.5,True)
        write(f'{faction}_{layer}',buf)

for name, notes in {'select':[76,83], 'move':[64,71], 'build':[57,64,69], 'complete':[60,67,72], 'ready':[67,72,79], 'alarm':[74,62,74], 'victory':[62,69,74,77,81,86], 'defeat':[62,58,55,50], 'error':[43,42], 'save':[72,79,84]}.items():
    duration = len(notes)*(.24 if name in ['victory','defeat'] else .065)+.3
    buf=[0.0]*int(RATE*duration)
    for i,note in enumerate(notes): tone(buf,i*(.24 if name in ['victory','defeat'] else .065),.28,note,.22)
    write(name,buf)
for name,duration in [('shot',.12),('explosion',.65)]:
    buf=[]
    for i in range(int(RATE*duration)):
        t=i/RATE
        buf.append((random.uniform(-1,1)*.55 + math.sin(2*math.pi*(65 if name=='explosion' else 180)*t)*.35)*math.exp(-t*(7 if name=='explosion' else 40)))
    write(name,buf)
print('Generated 12 synchronized music stems and 12 original cues.')
