"""V6 ending burst +30% only; preserve its claw and all other settings."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

OUT = Path(__file__).resolve().parent
SOURCE = OUT.parent/'audio_review_e_v6/e_v6_volume_only_single.wav'
SR, pcm = wavfile.read(SOURCE)
assert SR==48000 and pcm.dtype==np.int16 and pcm.shape[1]==2
base = pcm.astype(float)/32768
t = np.arange(len(base))/SR

def ramp(start,end):
    u = np.clip((t-start)/(end-start),0,1)
    return u*u*(3-2*u)

ending = ramp(.395,.435)*(1-ramp(.90,1.05))
candidate = base*(1+.30*ending[:,None])
assert np.array_equal(candidate[ending==0],base[ending==0])
assert np.max(np.abs(resample_poly(candidate,4,1,axis=0)))<.95
preview = np.zeros((round(4.6*SR),2))
for at in [.30,2.55]:
    i=round(at*SR);preview[i:i+len(candidate)] += candidate

def write(name,x):
    assert np.isfinite(x).all() and np.max(np.abs(x))<1
    with wave.open(str(OUT/name),'wb') as f:
        f.setparams((2,2,SR,0,'NONE','not compressed'))
        f.writeframes(np.round(x*32768).astype('<i2').tobytes())
    return {'file':name,'seconds':len(x)/SR,
            'true_peak_dbtp':round(20*np.log10(np.max(np.abs(resample_poly(x,4,1,axis=0)))),2)}

report = {'status':'AUDITION ONLY; Unity unchanged',
          'change':'Existing v6 ending burst multiplied by 1.30; all other sections unchanged',
          'ending_plateau_gain_relative_to_v4':1.25*1.30,
          'claw_gain_relative_to_v4':.90,
          'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          'outputs':[write('e_v7_burst_plus30_preview.wav',preview),
                     write('e_v7_burst_plus30_single.wav',candidate)]}
(OUT/'measurements.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
