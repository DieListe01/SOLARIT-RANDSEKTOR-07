"""Original weapon and vehicle synthesis; Python standard library only."""
from pathlib import Path
import math
import random
import struct
import wave

root = Path(__file__).resolve().parents[1]
rate = 22050
random.seed(2186)
for name, seconds in [('impact', .35), ('pulse_shot', .22), ('cannon_shot', .45), ('siege_shot', .75), ('engine', 2.0)]:
    samples = []
    for i in range(int(rate * seconds)):
        t = i / rate
        noise = random.uniform(-1, 1)
        if name == 'engine':
            value = (math.sin(math.tau * 55 * t) * .27 + math.sin(math.tau * 110 * t) * .14 + noise * .07) * (.9 + .1 * math.sin(math.tau * 7 * t))
        elif name == 'pulse_shot':
            value = (math.sin(math.tau * (1250 * t - 1700 * t * t)) * .55 + noise * .07) * math.exp(-t * 22)
        elif name == 'impact':
            value = (noise * .6 + math.sin(math.tau * 140 * t) * .25) * math.exp(-t * 20)
        elif name == 'cannon_shot':
            value = (noise * .55 + math.sin(math.tau * (95 * t - 60 * t * t)) * .35) * math.exp(-t * 9)
        else:
            value = (noise * .45 + math.sin(math.tau * (60 * t - 20 * t * t)) * .5) * math.exp(-t * 5)
        samples.append(int(max(-1, min(1, value)) * 28000))
    with wave.open(str(root / 'assets' / 'audio' / f'{name}.wav'), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
