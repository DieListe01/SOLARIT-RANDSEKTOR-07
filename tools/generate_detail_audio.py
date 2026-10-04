"""Original layered stereo SFX, reproducible and independent of game RNG."""
from pathlib import Path
import math, random, struct, wave
ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'
RATE = 44100
FAMILIES = ['ballistic_light','ballistic_heavy','autocannon','artillery','missile','energy','siege','special','core']
def render(name, event, variant):
    heavy = name in ['ballistic_heavy','artillery','siege','core']
    electric = name in ['energy','special']
    duration = (0.42 if event=='shot' else 0.72) + (0.38 if heavy else 0) + (0.55 if name=='core' else 0)
    rng = random.Random(71031 + FAMILIES.index(name)*139 + variant*17 + (900 if event=='impact' else 0))
    values=[]; low=[0.,0.]; mid=[0.,0.]
    base=(46 if heavy else 115)*(1+variant*.045)
    for i in range(int(RATE*duration)):
        t=i/RATE; attack=min(1,t/.0018); release=min(1,(duration-t)/.018)
        body=math.sin(math.tau*(base*t+base*.13*(1-math.exp(-t*18))/18))*math.exp(-t*(5 if heavy else 14))
        if electric:
            phase=math.tau*(1450*t-700*t*t+(variant*45*t))
            body=math.sin(phase)*math.exp(-t*14)+.22*math.sin(phase*1.51)*math.exp(-t*20)
        row=[]
        for ch in range(2):
            noise=rng.uniform(-1,1);low[ch]=low[ch]*.975+noise*.025;mid[ch]=mid[ch]*.65+noise*.35
            snap=(noise-mid[ch])*.30*math.exp(-t*65)
            pressure=low[ch]*3.4*math.exp(-t*(4.5 if heavy else 13))
            grit=mid[ch]*.28*math.exp(-t*(7 if event=='impact' else 20))
            ring=0
            for k,freq in enumerate([427,713,1181,2039]):
                delayed=max(0,t-.014*k-.007*variant)
                if delayed>0:
                    ring+=math.sin(math.tau*(freq*(1+variant*.02)*delayed+ch*.013))*math.exp(-delayed*(11+k*7))*.055
            tail=0
            for delay,gain in [(.075,.13),(.142,.075),(.231,.035)]:
                if t>delay:
                    u=t-delay
                    tail+=gain*math.sin(math.tau*base*u)*math.exp(-u*8)
            if electric: pressure*=.12; grit*=.15; ring*=.65
            if name=='missile': grit+=mid[ch]*.24*math.exp(-t*4)
            if name=='autocannon': snap*=.8+.2*math.cos(t*210)
            value=(body*.48+snap+pressure+grit+ring+tail)*attack*release
            row.append(math.tanh(value*1.15))
        values.append(row)
    peak=max(abs(v) for row in values for v in row)
    gain=.82/max(.82,peak)
    return values,gain
def write(filename, rows, gain=1):
    data=bytearray()
    for row in rows:
        for v in row: data.extend(struct.pack('<h',round(v*gain*32767)))
    with wave.open(str(ROOT/filename),'wb') as out:
        out.setnchannels(2);out.setsampwidth(2);out.setframerate(RATE);out.writeframes(data)
for family in FAMILIES:
    for event in ['shot','impact']:
        for variant in range(3):
            rows,gain=render(family,event,variant)
            write(f'{family}_{event}'+('' if variant==0 else f'_v{variant}')+'.wav',rows,gain)
for name,duration in [('build',.55),('complete',.65),('ready',.40),('rotate',.22),('repair',.32),('explosion',1.35)]:
    if name=='explosion':
        rows,gain=render('ballistic_heavy','impact',2);write(name+'.wav',rows,gain);continue
    rng=random.Random(4100+len(name)); rows=[]; low=0
    for i in range(int(RATE*duration)):
        t=i/RATE;noise=rng.uniform(-1,1);low=low*.92+noise*.08
        value=(low*.55+noise*.07)*math.exp(-t*17)
        for j,f in enumerate(([160,320,640] if name in ['build','rotate','repair'] else [520,780,1040])):
            u=t-j*.065
            if u>=0: value+=math.sin(math.tau*f*u)*math.exp(-u*22)*(.17 if j else .22)
        value*=min(1,t/.002)*min(1,(duration-t)/.012)
        rows.append([value,value*.96])
    write(name+'.wav',rows)
print('54 family samples + 6 action cues: stereo 44.1 kHz, bounded peaks')
