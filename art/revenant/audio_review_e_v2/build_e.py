"""Blood Bomb E v2: pressure detonation + restrained blood, NO claw sample.
Audition only; no writes into Unity. Deterministic 48 kHz stereo PCM16.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import wave
import numpy as np
from scipy.signal import butter, sosfilt, resample_poly

OUT = Path(__file__).resolve().parent
SR = 48000
CONTACT = 23/60
RNG = np.random.default_rng(16102602)
SOURCE = OUT.parent/'audio_review_q_v2/sources/squishsplat_impact.mp3'


def band(x, low, high):
    return sosfilt(butter(2, [low, high], fs=SR, btype='bandpass', output='sos'), x)


def norm(x):
    return x/max(np.max(np.abs(x)), 1e-9)


def fade(x, attack=.002, release=.04):
    x = x.copy()
    a, r = min(len(x), round(attack*SR)), min(len(x), round(release*SR))
    if a: x[:a] *= np.linspace(0, 1, a)
    if r: x[-r:] *= np.linspace(1, 0, r)
    return x


def noise(seconds, low, high):
    return norm(band(RNG.normal(size=round(seconds*SR)), low, high))


def blast(seconds, low, high, decay, attack=.002):
    x = noise(seconds, low, high)
    return fade(x*np.exp(-np.arange(len(x))/SR*decay), attack, .055)


def add(dst, x, at, gain=1):
    i = round(at*SR)
    assert i >= 0
    count = min(len(x), len(dst)-i)
    if count > 0: dst[i:i+count] += x[:count]*gain


def stereo_tail(x):
    result = np.column_stack([x, x])
    for channel, taps in enumerate([[(.024,.14),(.061,.08),(.109,.035)],
                                    [(.032,.13),(.073,.075),(.127,.03)]]):
        for delay, gain in taps:
            n = round(delay*SR)
            result[n:,channel] += x[:-n]*gain
    return result


raw = subprocess.check_output(['ffmpeg','-v','error','-i',str(SOURCE),
                               '-ar',str(SR),'-ac','1','-f','f32le','-'])
wet = np.frombuffer(raw,dtype='<f4').astype(float)
active = np.flatnonzero(np.abs(wet)>np.max(np.abs(wet))*.025)
wet = wet[max(0,active[0]-96):active[-1]+1]
wet = resample_poly(wet,100,82)

gather = np.zeros(round(1.65*SR))
dry = np.zeros_like(gather)
blood = np.zeros_like(gather)

# Brief quiet pressure pull, then a tiny vacuum before the palm contact.
# No slashing wind-up, tonal charge, or claw material.
pull = noise(.205,160,1800)*np.linspace(0,1,round(.205*SR))**1.8
add(gather,fade(pull,.04,.016),.14,.075)

# Central, nearly instantaneous air-compression front. Midrange survives small
# speakers; sub pressure supplies weight rather than a falling laser pitch.
add(dry,blast(.09,900,6800,58,.0008),CONTACT,.40)
add(dry,blast(.25,180,2300,19,.002),CONTACT,.78)
add(dry,blast(.44,55,420,11,.004),CONTACT,.95)
t = np.arange(round(.33*SR))/SR
sub = np.sin(2*np.pi*62*t)*np.exp(-t*16)
add(dry,fade(sub,.004,.08),CONTACT,.30)

# Expanding compressed-air body, darker as it dissipates. No long hiss/drips.
add(dry,blast(.42,330,2600,10,.012),CONTACT+.018,.35)
add(dry,blast(.70,45,290,6.8,.015),CONTACT+.025,.32)

# Organic blood is a subordinate, short physical spray behind the detonation.
# Crop the source so the rejected slurp/splat tail cannot return.
organic = norm(band(wet[:round(.18*SR)],230,2500))
organic *= np.exp(-np.arange(len(organic))/SR*10)
add(blood,fade(organic,.004,.06),CONTACT+.012,.22)
spray = norm(band(wet[round(.05*SR):round(.25*SR)],850,3800))
add(blood,fade(spray,.009,.09),CONTACT+.045,.085)

gather, dry, blood = [stereo_tail(x) for x in (gather,dry,blood)]
cast = gather+dry+blood
gain = 10**(-4.5/20)/np.max(np.abs(resample_poly(cast,4,1,axis=0)))
cast *= gain
gather *= gain
dry *= gain
blood *= gain
preview = np.zeros((round(4.65*SR),2))
for at in [.30,2.55]: add(preview,cast,at)


def write(name,x):
    assert np.isfinite(x).all() and np.max(np.abs(x))<.95
    assert np.max(np.abs(x[-256:]))<.0001
    with wave.open(str(OUT/name),'wb') as f:
        f.setparams((2,2,SR,0,'NONE','not compressed'))
        f.writeframes(np.round(x*32767).astype('<i2').tobytes())
    rms = np.sqrt(np.mean(x*x))
    return {'file':name,'seconds':len(x)/SR,
            'true_peak_dbtp':round(20*np.log10(np.max(np.abs(resample_poly(x,4,1,axis=0)))),2),
            'rms_dbfs':round(20*np.log10(rms),2),
            'mono_loss_db':round(20*np.log10(np.sqrt(np.mean(x.mean(axis=1)**2))/rms),3)}


report = {'status':'AUDITION ONLY; E v1 remains in game, Q and Space unchanged',
          'claw_used':False,'contact_seconds':CONTACT,
          'design':'Short pressure detonation; centered low/mid body; quiet cropped blood texture, no slash',
          'source_sha256':{SOURCE.name:hashlib.sha256(SOURCE.read_bytes()).hexdigest()},
          'outputs':[write('e_pressure_bomb_v2_preview.wav',preview),
                     write('e_pressure_bomb_v2_single.wav',cast),
                     write('e_v2_gather_timeline.wav',gather),
                     write('e_v2_pressure_timeline.wav',dry),
                     write('e_v2_blood_timeline.wav',blood)]}
(OUT/'measurements.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
