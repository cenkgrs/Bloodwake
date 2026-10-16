"""Original procedural wooden crate fracture audition (no third-party samples).
Deterministic dry snaps, damped wooden resonances and falling-chip rattles.
"""
import math
import random
import struct
import wave
from pathlib import Path

rate = 44100
rng = random.Random(160026)
samples = [0.0] * int(rate * .82)
for onset, strength, decay in [(0, 1, .018), (.017, .8, .025), (.041, .62, .03),
                              (.073, .45, .04), (.13, .25, .025), (.21, .18, .02),
                              (.32, .12, .018), (.43, .08, .018)]:
    low = 0
    modes = [(rng.uniform(a, b), rng.uniform(0, math.tau))
             for a, b in [(150, 220), (320, 490), (720, 1050), (1600, 2300)]]
    start = int(onset * rate)
    for i in range(min(int(rate * .3), len(samples) - start)):
        t = i / rate
        noise = rng.uniform(-1, 1)
        low += .19 * (noise - low)
        crack = (noise - low) * math.exp(-t / decay)
        body = sum(math.sin(math.tau * f * t + phase) * math.exp(-t / (.023 + .018 * j))
                   for j, (f, phase) in enumerate(modes)) * .11
        attack = min(1, t / .0004)
        samples[start + i] += strength * attack * (crack * .75 + low * math.exp(-t / .08) + body)
peak = max(abs(x) for x in samples)
out = Path(__file__).resolve().parents[2] / 'unity/Assets/Bloodwake/Resources/audio/wood_break.wav'
with wave.open(str(out), 'wb') as sound:
    sound.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    sound.writeframes(b''.join(struct.pack('<h', round(x / peak * .86 * 32767)) for x in samples))
print(out)
