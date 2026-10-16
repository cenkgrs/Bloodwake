"""Rebalance actual v4 claw/blood layers; preserve the other approved layers.
Audition only. Read v1 generator definitions without running its file writer.
"""
from pathlib import Path
import ast
import hashlib
import json
import wave
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, resample_poly

OUT = Path(__file__).resolve().parent
V1 = OUT.parent/'audio_review_e_space_v1'
V4 = OUT.parent/'audio_review_e_v4'
SR = 48000
CONTACT = 23/60

# Reuse the exact original deterministic mix and reveal its mastering gain.
# Stop before the output loop: never overwrite approved review/runtime files.
tree = ast.parse((V1/'build_previews.py').read_text())
definitions = []
for node in tree.body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='results' for t in node.targets):
        break
    if isinstance(node,ast.FunctionDef) and node.name=='make':
        ret = node.body[-1]
        assert isinstance(ret,ast.Return) and isinstance(ret.value,ast.Tuple)
        ret.value.elts.append(ast.Name(id='gain',ctx=ast.Load()))
    definitions.append(node)
module = ast.fix_missing_locations(ast.Module(body=definitions,type_ignores=[]))
ns = {'__file__':str(V1/'build_previews.py')}
exec(compile(module,str(V1/'build_previews.py'),'exec'),ns)
cast,_,_,onset,gain = ns['make']('e',CONTACT,1.55,.94)
rate,pcm = wavfile.read(V1/'e_v1_single.wav')
assert rate==SR and np.max(np.abs(cast-pcm.astype(float)/32767))<1/32767

claw = ns['fade'](ns['band'](resample_poly(ns['claw'],100,94),110,7900))
claw_timeline = np.zeros(len(cast))
ns['add'](claw_timeline,claw,onset,.66)
claw_timeline = ns['room'](claw_timeline,.7)*gain
organic = ns['fade'](ns['band'](ns['wet'][:round(.11*SR)],180,1900),.003,.06)
blood_timeline = np.zeros(len(cast))
ns['add'](blood_timeline,organic,CONTACT+.008,.055)
blood_timeline = ns['room'](blood_timeline,.7)*gain

t = np.arange(len(cast))/SR
def smooth(a,b):
    p = np.clip((t-a)/(b-a),0,1)
    return p*p*(3-2*p)
region = (smooth(.33,CONTACT)*(1-smooth(.60,.85)))[:,None]
contact_gain = json.loads((V4/'measurements.json').read_text())['contact_gain']

def transform_v4(x):
    def band(low,high):
        return sosfilt(butter(2,[low,high],fs=SR,btype='bandpass',output='sos'),x,axis=0)
    body = band(65,450)
    delta = region*(body*.85-band(2400,14000)*.38)
    grain = resample_poly(body[round(CONTACT*SR):round((CONTACT+.14)*SR)],3,2,axis=0)
    grain *= (np.sin(np.linspace(0,np.pi,len(grain)))**1.5)[:,None]
    i = round((CONTACT+.022)*SR)
    delta[i:i+len(grain)] += grain*.28
    return (x+delta)*(1+(contact_gain-1)*region)

rate,pcm = wavfile.read(V4/'e_v4_single.wav')
assert rate==SR
base = pcm.astype(float)/32768
old_claw = transform_v4(claw_timeline)
old_blood = transform_v4(blood_timeline)
remainder = base-old_claw-old_blood
claw_gain = .25
rms = lambda x: float(np.sqrt(np.mean(x*x)))
# Reverse the perceptual hierarchy: blood at 75% of old claw energy,
# claw at 25%; keep dry impact, gather, pressure and their timing unchanged.
blood_gain = .75*rms(old_claw)/rms(old_blood)
ceiling = 10**(-4/20)
def mix(): return remainder+old_claw*claw_gain+old_blood*blood_gain
candidate = mix()
while np.max(np.abs(resample_poly(candidate,4,1,axis=0)))>ceiling:
    blood_gain *= .98
    candidate = mix()
    assert blood_gain>1
new_claw,new_blood = old_claw*claw_gain,old_blood*blood_gain
assert rms(new_blood)>rms(new_claw), 'Blood must lead the claw'
assert np.max(np.abs((candidate-new_claw-new_blood)-remainder))<1e-12

ab = np.zeros((round(4.6*SR),2))
preview = np.zeros_like(ab)
for at,x in [(.30,base),(2.55,candidate)]:
    i=round(at*SR);ab[i:i+len(x)]+=x
for at in [.30,2.55]:
    i=round(at*SR);preview[i:i+len(candidate)]+=candidate

def write(name,x):
    assert np.isfinite(x).all() and np.max(np.abs(x))<1
    with wave.open(str(OUT/name),'wb') as f:
        f.setparams((2,2,SR,0,'NONE','not compressed'))
        f.writeframes(np.round(x*32768).astype('<i2').tobytes())
    return {'file':name,'seconds':len(x)/SR,
            'true_peak_dbtp':round(20*np.log10(np.max(np.abs(resample_poly(x,4,1,axis=0)))),2),
            'rms_dbfs':round(20*np.log10(rms(x)),2)}

report = {'status':'AUDITION ONLY; runtime E still v1, Q/Space unchanged',
          'base':'v4 with same sources, same timing, unchanged non-claw/non-blood layers',
          'claw_gain':claw_gain,'blood_gain':blood_gain,
          'blood_over_claw_rms_db':20*np.log10(rms(new_blood)/rms(new_claw)),
          'source_sha256':{str(p.relative_to(OUT.parent)):hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in [V1/'build_previews.py',V1/'e_v1_single.wav',V4/'e_v4_single.wav']},
          'outputs':[write('e_blood_forward_v5_preview.wav',preview),
                     write('e_v4_then_v5_comparison.wav',ab),
                     write('e_blood_forward_v5_single.wav',candidate)]}
(OUT/'measurements.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
