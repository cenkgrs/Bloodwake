"""Revenant Q audition: CC0 wet recordings + original filtered-noise transitions.
Only writes this review directory, never Unity Resources or runtime code.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import wave
import numpy as np
from scipy.signal import butter, sosfilt, resample_poly

ROOT = Path(__file__).resolve().parent
SR = 48000
RNG = np.random.default_rng(161026)

def fade(x, attack=.003, release=.025):
    x = x.copy()
    a, r = min(len(x), round(attack * SR)), min(len(x), round(release * SR))
    if a: x[:a] *= np.linspace(0, 1, a)
    if r: x[-r:] *= np.linspace(1, 0, r)
    return x

def band(x, low, high):
    return sosfilt(butter(2, [low, high], fs=SR, btype='bandpass', output='sos'), x)

def normalized(x):
    return x / max(np.max(np.abs(x)), 1e-9)

def source(name, speed=1):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(ROOT/'sources'/name),
                                  '-f', 'f32le', '-ar', str(SR), '-ac', '1', '-'])
    x = np.frombuffer(raw, dtype='<f4').astype(float)
    active = np.flatnonzero(np.abs(x) > np.max(np.abs(x)) * .018)
    x = x[max(0, active[0]-120):min(len(x), active[-1]+720)]
    x = resample_poly(x, 100, round(speed*100))
    return fade(normalized(band(x, 60, 8500)))

def add(dst, src, at, gain=1):
    offset = round(at*SR)
    count = min(len(src), len(dst)-offset)
    if count > 0: dst[offset:offset+count] += src[:count]*gain

def noise(seconds, low, high):
    return normalized(band(RNG.normal(size=round(seconds*SR)), low, high))

def early_room(x):
    stereo = np.column_stack([x, x])
    # Centre the attack; only its short tail has width. Mono compatible.
    for channel, taps in enumerate([[(.019,.085),(.047,.045),(.083,.025)],
                                    [(.027,.08),(.059,.04),(.097,.023)]]):
        for delay, gain in taps:
            n=round(delay*SR)
            stereo[n:,channel] += x[:-n]*gain
    return stereo

wet = source('squish_03.mp3', .87)
splat = source('squishsplat_impact.mp3', .83)
slurp = source('squish_06.mp3', .94)

# Departure is referenced to the cast start. Hide=.250, move=.317, show=.350.
departure = np.zeros(round(.55*SR))
pull = resample_poly(wet[::-1], round(.235*SR), len(wet))
pull *= np.linspace(.08, 1, len(pull))**1.5
add(departure, fade(band(pull, 110, 4300), .018, .006), .015, .42)
swirl = noise(.27, 190, 3600)
swirl *= np.sin(np.linspace(0, np.pi, len(swirl)))**2
add(departure, swirl, .075, .15)
add(departure, fade(band(splat[:round(.07*SR)], 130, 2600), .002, .02), .250, .20)
bridge = noise(.105, 700, 5800)*np.sin(np.linspace(0,np.pi,round(.105*SR)))**2
add(departure, bridge, .264, .105)

# Arrival is a separate future marker stem, relative to DAMAGE at 25/60=.4167.
arrival = np.zeros(round(.78*SR))
add(arrival, splat, 0, .80)
add(arrival, fade(band(wet, 100, 2500), .004, .06), .012, .32)
weight = noise(.16, 48, 260)
weight *= np.exp(-np.arange(len(weight))/SR*27)
add(arrival, fade(weight, .006, .04), .003, .40)
add(arrival, fade(band(slurp, 240, 5900), .007, .12), .047, .25)
# Small irregular recorded droplets, not oscillator chirps.
for at, gain, start in [(.14,.095,.09),(.205,.055,.17),(.284,.038,.24)]:
    grain=slurp[round(start*SR):round((start+.065)*SR)]
    add(arrival, fade(band(grain, 800, 7000), .003, .025), at, gain)
arrival=fade(arrival,.001,.09)

# Round isolated spikes so the wet body remains audible at a comfortable peak.
departure=np.tanh(departure*2.4)/2.4
arrival=np.tanh(arrival*2.4)/2.4
depart_stereo=early_room(departure)
arrive_stereo=early_room(arrival)
cast = np.zeros((round(1.25*SR),2))
add(cast, depart_stereo, 0)
add(cast, arrive_stereo, 25/60)
cast -= np.mean(cast,axis=0)
# Shared gain preserves the balance of stems if later approved for marker playback.
true_peak=np.max(np.abs(resample_poly(cast,4,1,axis=0)))
gain=10**(-4/20)/true_peak
cast*=gain;depart_stereo*=gain;arrive_stereo*=gain
preview=np.zeros((round(4.1*SR),2))
add(preview,cast,.30);add(preview,cast,2.35)

def write(name, samples):
    assert np.isfinite(samples).all() and np.max(np.abs(samples))<.95
    with wave.open(str(ROOT/name),'wb') as f:
        f.setparams((2,2,SR,0,'NONE','not compressed'))
        f.writeframes(np.round(samples*32767).astype('<i2').tobytes())
    return {'file':name,'seconds':round(len(samples)/SR,3),
            'peak_dbfs':round(20*np.log10(np.max(np.abs(samples))),2),
            'true_peak_dbtp':round(20*np.log10(np.max(np.abs(resample_poly(samples,4,1,axis=0)))),2),
            'rms_dbfs':round(20*np.log10(np.sqrt(np.mean(samples**2))),2)}

results=[write('q_bloodstep_v2_preview.wav',preview),write('q_bloodstep_v2_single.wav',cast),
         write('q_departure_v2.wav',depart_stereo),write('q_arrival_v2.wav',arrive_stereo)]
mono=cast.mean(axis=1)
report={'status':'AUDITION ONLY — not approved, not integrated',
        'hide_seconds':.25,'arrival_damage_seconds':25/60,'outputs':results,
        'mono_to_stereo_rms_db':float(20*np.log10(np.sqrt(np.mean(mono**2))/np.sqrt(np.mean(cast**2)))),
        'sources_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'sources').glob('*.mp3'))}}
(ROOT/'measurements.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
