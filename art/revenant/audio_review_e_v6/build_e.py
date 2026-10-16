"""Only volume automation on the actual v4 WAV; no stem remix or new sound.
The user identified the ending burst, not the tiny isolated organic sample.
"""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

OUT = Path(__file__).resolve().parent
SOURCE = OUT.parent/'audio_review_e_v4/e_v4_single.wav'
COMPARISON = OUT.parent/'audio_review_e_v4/e_v1_then_v4_comparison.wav'
SR, pcm = wavfile.read(SOURCE)
assert SR==48000 and pcm.dtype==np.int16 and pcm.shape[1]==2
rate, comparison_pcm = wavfile.read(COMPARISON)
assert rate==SR
assert np.array_equal(comparison_pcm[round(2.55*SR):round(2.55*SR)+len(pcm)],pcm)
base = pcm.astype(float)/32768
t = np.arange(len(base))/SR

def ramp(start,end):
    u = np.clip((t-start)/(end-start),0,1)
    return u*u*(3-2*u)

# Same sound and stereo image, just two small fader moves. Do NOT reconstruct
# or boost the isolated squish sample as in rejected v5. The whole audible
# ending burst is the target. Smooth transitions avoid introducing clicks.
early = ramp(.055,.09)*(1-ramp(.345,.395))
ending = ramp(.395,.435)*(1-ramp(.90,1.05))
volume = 1-.10*early+.25*ending
candidate = base*volume[:,None]
assert np.min(volume)>=.9 and np.max(volume)<=1.25
assert np.max(np.abs(resample_poly(candidate,4,1,axis=0)))<.95
# No EQ, filters, resampling of output, normalization, pitch or timing changes.
assert np.array_equal(candidate[:round(.055*SR)],base[:round(.055*SR)])
assert np.array_equal(candidate[round(1.05*SR):],base[round(1.05*SR):])
ab = np.zeros((round(4.6*SR),2))
preview = np.zeros_like(ab)
for at,x in [(.30,base),(2.55,candidate)]:
    i=round(at*SR);ab[i:i+len(x)] += x
for at in [.30,2.55]:
    i=round(at*SR);preview[i:i+len(candidate)] += candidate

def write(name,x):
    assert np.isfinite(x).all() and np.max(np.abs(x))<1
    with wave.open(str(OUT/name),'wb') as f:
        f.setparams((2,2,SR,0,'NONE','not compressed'))
        f.writeframes(np.round(x*32768).astype('<i2').tobytes())
    return {'file':name,'seconds':len(x)/SR,
            'true_peak_dbtp':round(20*np.log10(np.max(np.abs(resample_poly(x,4,1,axis=0)))),2),
            'rms_dbfs':round(20*np.log10(np.sqrt(np.mean(x*x))),2)}

report = {'status':'AUDITION ONLY; no Unity files changed',
          'source':'Exact second sound of e_v1_then_v4_comparison.wav; verified PCM equality',
          'change':'Volume automation only: early claw section -10%, ending burst +25%',
          'no_eq_pitch_duration_source_or_layer_changes':True,
          'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          'outputs':[write('e_v6_volume_only_preview.wav',preview),
                     write('e_v4_then_v6_comparison.wav',ab),
                     write('e_v6_volume_only_single.wav',candidate)]}
(OUT/'measurements.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
