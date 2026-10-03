"""Reproducible combat master from checked-in originals.
No external recordings: transient shaping, low body, short tails, DC removal.
Writes a separate bank so source samples remain intact.
"""
from pathlib import Path
import wave, math, array
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'godot/assets/audio/polished'
OUT.mkdir(exist_ok=True)
for path in sorted((ROOT/'godot/assets/audio').glob('*.wav')):
    with wave.open(str(path)) as src:
        channels,width,rate,count=src.getnchannels(),src.getsampwidth(),src.getframerate(),src.getnframes()
        if width!=2: continue
        pcm=array.array('h',src.readframes(count))
    samples=[sum(pcm[i:i+channels])/channels/32768 for i in range(0,len(pcm),channels)]
    mean=sum(samples)/max(1,len(samples));samples=[v-mean for v in samples]
    hit=any(k in path.stem for k in ('hit','blast','land'))
    swing='swing' in path.stem
    if not (hit or swing or path.stem.startswith('ui_')):continue
    duration=min(len(samples)/rate,0.38 if hit else 0.30 if swing else 0.16)
    output=[];low=0.0
    for i,x in enumerate(samples[:int(duration*rate)]):
        t=i/rate;low+=0.16*(x-low)
        # Keep the source texture but tame brittle treble and overlong tails.
        y=0.72*x+0.28*low
        if hit:y+=0.22*math.sin(2*math.pi*(95*t-32*t*t))*math.exp(-t*30)
        envelope=min(1,t/0.0015)*min(1,(duration-t)/0.025)
        if hit:envelope*=math.exp(-t*3)
        output.append(math.tanh(y*1.25)*envelope)
    peak=max(abs(x) for x in output) or 1
    data=array.array('h',(int(x/peak*26000) for x in output))
    with wave.open(str(OUT/path.name),'wb') as dst:
        dst.setparams((1,2,rate,0,'NONE','not compressed'));dst.writeframes(data.tobytes())
print('Mastered combat/UI samples:',len(list(OUT.glob('*.wav'))))
