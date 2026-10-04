"""Original 32-second ASHLINE title theme: 'First Signal'. No external samples."""
from pathlib import Path
import math, array, wave

RATE = 22050
buffer = [0.0] * (RATE * 32)

def note(start, length, midi, volume, kind):
    offset = round(start * RATE)
    hz = 440 * 2 ** ((midi - 69) / 12)
    for i in range(round(length * RATE)):
        if offset+i >= len(buffer): break
        t = i / RATE
        envelope = min(1, t/.04) * min(1, (length-t)/.15)
        phase = 2*math.pi*hz*t
        if kind == 'pad':
            value = (math.sin(phase) + .25*math.sin(phase*2.002)) * .6
        elif kind == 'bass':
            value = math.sin(phase + 1.1*math.sin(phase*2)*math.exp(-t*6))*math.exp(-t*2)
        else:
            value = math.sin(phase+.5*math.sin(phase*3))*math.exp(-t*2.7)
        buffer[offset+i] += value*envelope*volume

motif = [0,7,3,10,14,12,7,5,0,3,7,12,10,7,5,2]
for bar in range(16):
    root = 38 + [0,0,3,3,5,5,2,2][bar%8]
    for interval in [0,7,12]: note(bar*2,1.98,root+12+interval,.075,'pad')
    for beat in [0,1.5]: note(bar*2+beat,.46,root,.22,'bass')
    for beat in range(4):
        note(bar*2+beat*.5,.37,root+24+motif[(bar+beat)%16],.055,'bell')
    if bar%2 == 0:
        note(bar*2+.5,1.4,38+36+motif[bar],.1,'bell')

target = Path(__file__).resolve().parents[1] / 'assets' / 'audio' / 'first_signal.wav'
samples = array.array('h', (round(max(-1,min(1,value))*26000) for value in buffer))
with wave.open(str(target),'wb') as stream:
    stream.setnchannels(1); stream.setsampwidth(2); stream.setframerate(RATE)
    stream.writeframes(samples.tobytes())
print('Original title theme written: 32 seconds, 120 BPM.')
