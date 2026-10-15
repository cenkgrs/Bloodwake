"""Procedural audition drafts only. Never writes into Unity/Godot assets.

48 kHz stereo PCM. Deterministic seed; footsteps are dry stone/leather
sketches, abilities are layered liquid/noise sketches, not field recordings.
"""
from pathlib import Path
import json
import wave
import numpy as np
from scipy.signal import butter, sosfilt

OUT = Path(__file__).resolve().parent
RATE = 48000
rng = np.random.default_rng(151026)

def noise(seconds, low, high):
    samples = rng.normal(0, 1, int(seconds * RATE))
    filtered = sosfilt(butter(2, [low, high], btype='bandpass', fs=RATE, output='sos'), samples)
    return filtered / max(np.std(filtered), .0001)

def add(dst, src, at, gain=1):
    start = int(at * RATE)
    count = min(len(src), len(dst) - start)
    if count > 0:
        dst[start:start + count] += src[:count] * gain

def fade(x, attack=.004, release=.05):
    a, r = min(len(x), int(attack*RATE)), min(len(x), int(release*RATE))
    x = x.copy()
    if a: x[:a] *= np.linspace(0, 1, a)
    if r: x[-r:] *= np.linspace(1, 0, r)
    return x

def step(running=False):
    duration = .31 if running else .37
    t = np.arange(int(duration*RATE))/RATE
    # Rounded heel, leather body, a separate sole contact and short grit scrape.
    heel = noise(duration, 65, 390) * np.exp(-t*42) * .35
    body = np.sin(2*np.pi*(95*t-45*t*t)) * np.exp(-t*58) * .14
    sole = noise(duration, 480, 2800) * np.exp(-t*65) * .09
    scrape = noise(duration, 900, 6500) * np.exp(-((t-.08)/.043)**2) * .035
    x = heel+body+sole+scrape
    for _ in range(9):
        at = rng.uniform(.035, .17)
        grain_t = np.arange(int(.014*RATE))/RATE
        grain = noise(.014, 1300, 7000) * np.exp(-grain_t*390)
        add(x, grain, at, rng.uniform(.006, .019))
    return fade(x * (1.2 if running else 1), .0015, .05)

def liquid(seconds, force=1):
    t = np.arange(int(seconds*RATE))/RATE
    x = noise(seconds, 170, 2800) * np.exp(-t*11) * .11
    x += noise(seconds, 70, 430) * np.exp(-t*21) * .15
    for _ in range(int(20*force)):
        at = rng.uniform(.015, max(.025, seconds-.09))
        length = rng.uniform(.022, .065)
        g = np.arange(int(length*RATE))/RATE
        freq = rng.uniform(380, 1250)
        drop = np.sin(2*np.pi*(freq*g + freq*4*g*g))*np.exp(-g*rng.uniform(65, 120))
        drop += noise(length, 800, 4500)*np.exp(-g*110)*.15
        add(x, fade(drop,.001,.012), at, rng.uniform(.015,.05)*np.exp(-at*1.5))
    return fade(x, .002, .07)

def airy(seconds):
    t=np.linspace(0,1,int(seconds*RATE))
    return fade(noise(seconds,180,2200)*np.sin(np.pi*t)**2,.015,.025)

def room(x):
    stereo=np.stack([x.copy(),x.copy()],axis=1)
    # Small asymmetric early reflections; no long cavern tail.
    for channel, echoes in enumerate([[(.029,.07),(.071,.035)],[(.041,.06),(.083,.03)]]):
        for delay,gain in echoes:
            n=int(delay*RATE)
            stereo[n:,channel]+=x[:-n]*gain
    return stereo

def write(name, mono, peak_db):
    mono=mono-np.mean(mono)
    audio=room(fade(mono,.01,.1))
    peak=max(np.max(np.abs(audio)),1e-9)
    audio*=10**(peak_db/20)/peak
    pcm=np.round(audio*32767).astype('<i2')
    path=OUT/name
    with wave.open(str(path),'wb') as f:
        f.setparams((2,2,RATE,0,'NONE','not compressed'))
        f.writeframes(pcm.tobytes())
    assert np.isfinite(audio).all() and np.max(np.abs(audio))<1
    return {'file':name,'duration_seconds':round(len(audio)/RATE,3),
            'peak_dbfs':round(20*np.log10(np.max(np.abs(audio))),2),
            'rms_dbfs':round(20*np.log10(np.sqrt(np.mean(audio**2))),2)}

results=[]
for running,name,gap in [(False,'01_walk_stone_preview.wav',.55),(True,'02_run_stone_preview.wav',.33)]:
    x=np.zeros(int(5.2*RATE))
    for i,at in enumerate(np.arange(.3,4.7,gap)):
        add(x,step(running),at+rng.uniform(-.012,.012),rng.uniform(.86,1.04))
    results.append(write(name,x,-10 if running else -12))

# Q timing follows hide/move/show/contact markers; two auditions separated by silence.
q=np.zeros(int(1.15*RATE))
add(q,airy(.25),0,.11)
add(q,liquid(.30),.24,.65)
add(q,airy(.12),.30,.15)
add(q,liquid(.56),.416667,1)
q_preview=np.zeros(int(4*RATE));add(q_preview,q,.25);add(q_preview,q,2.15)
results.append(write('03_q_blood_step_preview.wav',q_preview,-6))

# Space: gathering starts .3 s; contact .9833 s; diminishing liquid fallout.
space=np.zeros(int(2.5*RATE))
charge=airy(.6833)*np.linspace(.15,1,int(.6833*RATE))
add(space,charge,.3,.14)
add(space,liquid(.45)[::-1],.5,.35)
add(space,liquid(1.1,2),.983333,1.2)
t=np.arange(int(.45*RATE))/RATE
thud=noise(.45,45,230)*np.exp(-t*15)*.25
add(space,fade(thud,.003,.08),.983333)
add(space,airy(.45),1.05,.06)
preview=np.zeros(int(6.5*RATE));add(preview,space,.25);add(preview,space,3.5)
results.append(write('04_space_blood_burst_preview.wav',preview,-4.5))
(OUT/'measurements.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
