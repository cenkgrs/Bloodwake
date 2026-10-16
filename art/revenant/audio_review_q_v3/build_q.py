"""Q v3: keep v2 departure exactly, replace wet arrival with existing claw C.
Audition only. Does not change runtime or copy files into Unity Resources.
"""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

OUT=Path(__file__).resolve().parent
REPO=OUT.parents[2]
SR=48000
DEPARTURE=OUT.parent/'audio_review_q_v2/q_departure_v2.wav'
CLAW=REPO/'unity/Assets/Bloodwake/Resources/audio/polished/revenant_basic_attack_c.wav'

def read(path):
    rate, pcm=wavfile.read(path)
    x=pcm.astype(np.float64)/32768
    if x.ndim==1:x=np.column_stack([x,x])
    if rate!=SR:
        divisor=np.gcd(rate,SR)
        x=resample_poly(x,SR//divisor,rate//divisor,axis=0)
    return x

departure=read(DEPARTURE)
claw=read(CLAW)
# Align the existing broad claw transient, not the file's quiet leading wind-up.
mono=claw.mean(axis=1)
window=round(.015*SR)
energy=np.convolve(mono**2,np.ones(window)/window,'same')
peak_time=np.argmax(energy)/SR
claw_start=25/60-peak_time
assert claw_start>=0
claw*=.58
cast=np.zeros((round(1.25*SR),2))
cast[:len(departure)]+=departure
offset=round(claw_start*SR)
cast[offset:offset+len(claw)]+=claw
true_peak=np.max(np.abs(resample_poly(cast,4,1,axis=0)))
# Keep the previously heard departure at precisely the same level if possible.
gain=min(1,10**(-2/20)/true_peak)
assert gain==1, 'Mix exceeds headroom; rebalance claw rather than altering departure'
assert np.array_equal(cast[:offset],departure[:offset])
preview=np.zeros((round(4.1*SR),2))
for at in [.30,2.35]:
    i=round(at*SR);preview[i:i+len(cast)]+=cast

def write(name,x):
    assert np.isfinite(x).all() and np.max(np.abs(x))<1
    with wave.open(str(OUT/name),'wb') as f:
        f.setparams((2,2,SR,0,'NONE','not compressed'))
        f.writeframes(np.round(x*32767).astype('<i2').tobytes())
    return {'file':name,'duration':len(x)/SR,
            'true_peak_dbtp':round(20*np.log10(np.max(np.abs(resample_poly(x,4,1,axis=0)))),2),
            'rms_dbfs':round(20*np.log10(np.sqrt(np.mean(x*x))),2)}

report={'status':'UNAPPROVED AUDITION, no runtime changes',
        'arrival':'Existing polished revenant_basic_attack_c, original pitch and speed, gain .58; no wet arrival layers',
        'note':'Runtime currently randomly selects A/B/C, not a fixed finisher sound',
        'departure_preserved':True,'claw_start_seconds':claw_start,
        'claw_energy_peak_seconds':peak_time+claw_start,'damage_seconds':25/60,
        'outputs':[write('q_mist_claw_v3_preview.wav',preview),write('q_mist_claw_v3_single.wav',cast),
                   write('q_claw_v3.wav',claw)],
        'input_sha256':{str(p.relative_to(REPO)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [CLAW,DEPARTURE]}}
(OUT/'measurements.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
