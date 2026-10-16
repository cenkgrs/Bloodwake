"""E v3: sample-based detonation body, no claw or procedural pop.
Only writes audition assets in this directory, never Unity Resources.
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
SOURCES = [OUT/'sources/explosion1.ogg', OUT/'sources/muffled_distant_explosion.wav',
           OUT.parent/'audio_review_q_v2/sources/squishsplat_impact.mp3']


def read(path):
    raw = subprocess.check_output(['ffmpeg','-v','error','-i',str(path),
                                   '-ar',str(SR),'-ac','2','-f','f32le','-'])
    x = np.frombuffer(raw,dtype='<f4').astype(float).reshape(-1,2)
    # Keep the actual attack; trim only the quiet pre-roll.
    active = np.flatnonzero(np.max(np.abs(x),axis=1)>np.max(np.abs(x))*.025)
    return x[max(0,active[0]-96):active[-1]+1]


def band(x, low, high):
    return sosfilt(butter(2,[low,high],fs=SR,btype='bandpass',output='sos'),x,axis=0)


def norm(x):
    return x/max(np.max(np.abs(x)),1e-9)


def fade(x, attack=.003, release=.20):
    x = x.copy()
    a,r = min(len(x),round(attack*SR)),min(len(x),round(release*SR))
    if a: x[:a] *= np.linspace(0,1,a)[:,None]
    if r: x[-r:] *= np.linspace(1,0,r)[:,None]
    return x


def add(dst,x,at,gain=1):
    i = round(at*SR)
    assert i>=0
    n = min(len(x),len(dst)-i)
    if n>0: dst[i:i+n] += x[:n]*gain


blast = read(SOURCES[0])
boom = read(SOURCES[1])
wet = read(SOURCES[2])
# Broader midrange explosion plus lower recorded/log-drum-derived resonance.
# Preserve a full second of energy rather than synthesizing a tiny snap.
blast = resample_poly(blast,100,91,axis=0)
blast = norm(band(blast[:round(1.20*SR)],65,4700))
blast = fade(np.tanh(blast*2.0)/np.tanh(2.0),.004,.26)
boom = norm(band(boom[:round(1.25*SR)],40,780))
boom = fade(np.tanh(boom*1.6)/np.tanh(1.6),.007,.32)
wet = resample_poly(wet,100,86,axis=0)
wet = fade(norm(band(wet[:round(.26*SR)],180,3000)),.006,.12)

dry = np.zeros((round(1.95*SR),2))
blood = np.zeros_like(dry)
gather = np.zeros_like(dry)
add(dry,blast,CONTACT,.82)
add(dry,boom,CONTACT,.53)
add(blood,wet,CONTACT+.025,.13)
# A quiet reverse of the source body's tail, not a separate claw/whoosh.
pull = blast[round(.18*SR):round(.38*SR)][::-1].copy()
pull *= np.linspace(0,1,len(pull))[:,None]**1.7
add(gather,fade(pull,.035,.018),.14,.12)
cast = dry+blood+gather
# Centre low end and narrow existing stereo enough to retain mono punch.
mid = cast.mean(axis=1,keepdims=True)
cast = mid+(cast-mid)*.65
peak = np.max(np.abs(resample_poly(cast,4,1,axis=0)))
gain = 10**(-4.5/20)/peak
cast *= gain
preview = np.zeros((round(5.4*SR),2))
for at in [.30,2.90]: add(preview,cast,at)


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


report = {'status':'AUDITION ONLY. E v1 remains installed. Q/Space unchanged.',
          'claw_used':False,'synthetic_pop_used':False,'contact_seconds':CONTACT,
          'sources_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCES},
          'outputs':[write('e_detonation_v3_preview.wav',preview),write('e_detonation_v3_single.wav',cast)]}
(OUT/'measurements.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
