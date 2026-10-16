"""Original procedural sword-whoosh audition. No existing game audio is reused.
This is a review asset, deliberately outside Unity Resources until approved.
"""
from pathlib import Path
import wave
import numpy as np
from scipy.signal import butter, sosfilt

RATE = 48000
ROOT = Path(__file__).resolve().parent

def swing(seed, heavy=False):
    rng = np.random.default_rng(seed)
    duration = .43 if heavy else .31
    t = np.arange(int(RATE*duration))/RATE
    noise = rng.normal(size=len(t))
    low = sosfilt(butter(2, [120, 1050], btype='bandpass', fs=RATE, output='sos'), noise)
    air = sosfilt(butter(2, [1400, 7400], btype='bandpass', fs=RATE, output='sos'), noise)
    centre = duration*.34
    env = np.exp(-((t-centre)/(duration*.17))**2)
    tail = np.maximum(t-centre, 0)
    # Air displacement, brief blade edge, restrained inharmonic steel resonance.
    body = low*env*(1.15 if heavy else .72)
    edge = air*np.exp(-((t-centre-.014)/(duration*.085))**2)*.36
    metal = sum(np.sin(2*np.pi*f*t + .8*np.sin(2*np.pi*17*t))*a
                for f,a in [(1820,.014),(2940,.009),(4310,.004)])
    metal *= np.where(t>centre, np.exp(-tail/.035), 0)
    signal = body+edge+metal
    signal *= np.minimum(t/.01, 1)*np.minimum((duration-t)/.035, 1)
    signal *= .66/max(.001,np.max(np.abs(signal)))
    pan = np.linspace(-.22,.22,len(t))
    return np.column_stack((signal*np.sqrt((1-pan)/2),signal*np.sqrt((1+pan)/2)))

def save(name, heavy):
    pieces=[np.zeros((int(RATE*.25),2))]
    for seed in (16,27,38):
        pieces.extend([swing(seed,heavy),np.zeros((int(RATE*.8),2))])
    pcm=(np.concatenate(pieces)*32767).astype('<i2')
    with wave.open(str(ROOT/name),'wb') as file:
        file.setnchannels(2);file.setsampwidth(2);file.setframerate(RATE);file.writeframes(pcm.tobytes())
    print(name, 'peak',np.max(np.abs(pcm))/32767)

if __name__=='__main__':
    save('warrior-sword-dry.wav',False)
    save('warrior-sword-weighted.wav',True)
