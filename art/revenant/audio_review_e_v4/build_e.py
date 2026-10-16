"""Small revision of approved E v1, NOT another replacement sound.
Only the contact body is rebalanced; original preparation and tail preserved.
"""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, resample_poly

OUT = Path(__file__).resolve().parent
SOURCE = OUT.parent/'audio_review_e_space_v1/e_v1_single.wav'
SR, pcm = wavfile.read(SOURCE)
assert SR == 48000 and pcm.dtype == np.int16 and pcm.shape[1] == 2
original = pcm.astype(float)/32768
CONTACT = 23/60
t = np.arange(len(original))/SR


def band(x, low, high):
    return sosfilt(butter(2,[low,high],fs=SR,btype='bandpass',output='sos'),x,axis=0)


def smooth(a,b):
    p = np.clip((t-a)/(b-a),0,1)
    return p*p*(3-2*p)


# Leave every sample before .33 s and after .85 s exactly as in the first E.
# Darken the scratch edge only around contact; retain its original identity.
region = (smooth(.33,CONTACT)*(1-smooth(.60,.85)))[:,None]
body = band(original,65,450)
edge = band(original,2400,14000)
delta = region*(body*.85-edge*.38)

# Extend only the existing low-mid contact by ~70 ms for a little blast body.
# No v2 pop, v3 explosion, new oscillator or replacement claw is introduced.
grain = body[round(CONTACT*SR):round((CONTACT+.14)*SR)].copy()
grain = resample_poly(grain,3,2,axis=0)
grain *= (np.sin(np.linspace(0,np.pi,len(grain)))**1.5)[:,None]
offset = round((CONTACT+.022)*SR)
delta[offset:offset+len(grain)] += grain*.28
candidate = original+delta

# Keep the original peak budget with local contact gain, never renormalize
# the entire file (which would alter the approved preparation's loudness).
ceiling = np.max(np.abs(resample_poly(original,4,1,axis=0)))
contact_gain = 1.0
while np.max(np.abs(resample_poly(candidate,4,1,axis=0)))>ceiling:
    contact_gain *= .98
    candidate = (original+delta)*(1+(contact_gain-1)*region)
    assert contact_gain>.05
assert np.array_equal(original[:round(.33*SR)],candidate[:round(.33*SR)])
assert np.array_equal(original[round(.85*SR):],candidate[round(.85*SR):])

ab = np.zeros((round(4.6*SR),2))
for at,x in [(.30,original),(2.55,candidate)]:
    i = round(at*SR)
    ab[i:i+len(x)] += x


def write(name,x):
    assert np.isfinite(x).all() and np.max(np.abs(x))<1
    with wave.open(str(OUT/name),'wb') as f:
        f.setparams((2,2,SR,0,'NONE','not compressed'))
        f.writeframes(np.round(x*32768).astype('<i2').tobytes())
    return {'file':name,'seconds':len(x)/SR,
            'true_peak_dbtp':round(20*np.log10(np.max(np.abs(resample_poly(x,4,1,axis=0)))),2),
            'rms_dbfs':round(20*np.log10(np.sqrt(np.mean(x*x))),2)}


report = {'status':'AUDITION ONLY; no runtime edits',
          'base':'Exact approved E v1 single; no v2/v3 material',
          'ab_order':['original E v1','small v4 revision'],
          'unchanged_intervals_seconds':[[0,.33],[.85,len(original)/SR]],
          'contact_seconds':CONTACT,'contact_gain':contact_gain,
          'waveform_correlation':float(np.corrcoef(original.ravel(),candidate.ravel())[0,1]),
          'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          'outputs':[write('e_v1_then_v4_comparison.wav',ab),write('e_v4_single.wav',candidate)]}
(OUT/'measurements.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
