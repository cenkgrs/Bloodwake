"""E / Space auditions, never copied into Unity until listening approval.

Uses the game's existing claw C and a restrained CC0 organic texture, with
original filtered-noise pressure layers. All timing is relative to cast start.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import wave

import numpy as np
from scipy.signal import butter, resample_poly, sosfilt

OUT = Path(__file__).resolve().parent
REPO = OUT.parents[2]
SR = 48000
RNG = np.random.default_rng(20261016)
CLAW = REPO / 'unity/Assets/Bloodwake/Resources/audio/polished/revenant_basic_attack_c.wav'
ORGANIC = OUT.parent / 'audio_review_q_v2/sources/squish_03.mp3'


def decode(path):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path),
                                   '-ar', str(SR), '-ac', '1', '-f', 'f32le', '-'])
    return np.frombuffer(raw, dtype='<f4').astype(float)


def band(x, low, high):
    return sosfilt(butter(2, [low, high], fs=SR, btype='bandpass', output='sos'), x)


def norm(x):
    return x / max(np.max(np.abs(x)), 1e-9)


def fade(x, attack=.003, release=.03):
    x = x.copy()
    a, r = min(len(x), round(attack*SR)), min(len(x), round(release*SR))
    if a: x[:a] *= np.linspace(0, 1, a)
    if r: x[-r:] *= np.linspace(1, 0, r)
    return x


def noise(seconds, low, high):
    return norm(band(RNG.normal(size=round(seconds*SR)), low, high))


def add(dst, x, at, gain=1):
    offset = round(at*SR)
    assert offset >= 0
    n = min(len(x), len(dst)-offset)
    if n > 0: dst[offset:offset+n] += x[:n]*gain


def peak_time(x):
    window = round(.015*SR)
    return np.argmax(np.convolve(x*x, np.ones(window)/window, 'same'))/SR


def weight(seconds, low, high, decay):
    x = noise(seconds, low, high)
    return fade(x*np.exp(-np.arange(len(x))/SR*decay), .006, .08)


def room(x, size):
    # Dry attack stays central. Positive delayed tails preserve mono compatibility.
    stereo = np.column_stack([x, x])
    for channel, taps in enumerate([[(.023, .12), (.061, .065), (.113, .025)],
                                    [(.031, .11), (.079, .06), (.139, .025)]]):
        for delay, gain in taps:
            n = round(delay*size*SR)
            stereo[n:, channel] += x[:-n]*gain
    return stereo


claw = decode(CLAW)
wet = decode(ORGANIC)
active = np.flatnonzero(np.abs(wet) > np.max(np.abs(wet))*.025)
wet = wet[max(0, active[0]-96):active[-1]+1]


def make(kind, contact, seconds, speed):
    gather = np.zeros(round(seconds*SR))
    impact = np.zeros_like(gather)
    heavy = kind == 'space'
    scaled = resample_poly(claw, 100, round(speed*100))
    scaled = fade(band(scaled, 65 if heavy else 110, 5600 if heavy else 7900))
    onset = contact-peak_time(scaled)
    assert onset > 0
    add(impact, scaled, onset, .75 if heavy else .66)

    # Growing pressure, no melodic rising laser/ping. Ult builds for longer.
    start = 11/60 if heavy else 7/60
    end = contact-.018
    pull = noise(end-start, 150 if heavy else 260, 1800 if heavy else 2900)
    pull *= np.linspace(0, 1, len(pull))**1.6
    add(gather, fade(pull, .045, .016), start, .18 if heavy else .12)
    # Very quiet reversed recording provides the blood character, not a slurp.
    texture = resample_poly(wet[::-1], round((end-start)*SR), len(wet))
    texture = fade(band(texture, 140, 1400), .06, .025)
    texture *= np.linspace(0, 1, len(texture))**2
    add(gather, texture, start, .065)

    # Palm contact/crack and a low non-tonal body, aligned with imported markers.
    snap = weight(.10 if heavy else .075, 700, 5800, 48)
    add(impact, snap, contact-.005, .17 if heavy else .22)
    body = weight(.52 if heavy else .29, 45 if heavy else 65, 260, 10 if heavy else 18)
    add(impact, body, contact-.007, .61 if heavy else .43)
    chest = weight(.26, 130, 650, 22)
    add(impact, chest, contact, .29 if heavy else .23)
    # Fast outward pressure sheet; E is compact, ult has a broader, falling tail.
    length = .85 if heavy else .40
    wave_tail = noise(length, 120, 2100 if heavy else 3600)
    wave_tail *= np.exp(-np.arange(len(wave_tail))/SR*(5.8 if heavy else 9.5))
    add(impact, fade(wave_tail, .018, .15), contact+.018, .22 if heavy else .14)
    # Only a brief, recessed organic accent. No separate drips/splat/slurp tail.
    organic = fade(band(wet[:round(.11*SR)], 180, 1900), .003, .06)
    add(impact, organic, contact+.008, .055)

    gather = room(gather, 1.15 if heavy else .65)
    impact = room(impact, 1.35 if heavy else .7)
    cast = gather+impact
    gain = 10**((-4 if heavy else -4.5)/20) / np.max(np.abs(resample_poly(cast, 4, 1, axis=0)))
    return cast*gain, gather*gain, impact*gain, onset


def write(name, x):
    assert np.isfinite(x).all() and np.max(np.abs(x)) < .95
    assert np.max(np.abs(x[-256:])) < .001, 'tail must finish without a cut'
    with wave.open(str(OUT/name), 'wb') as f:
        f.setparams((2, 2, SR, 0, 'NONE', 'not compressed'))
        f.writeframes(np.round(x*32767).astype('<i2').tobytes())
    mono = x.mean(axis=1)
    return {'file': name, 'seconds': len(x)/SR,
            'true_peak_dbtp': round(20*np.log10(np.max(np.abs(resample_poly(x, 4, 1, axis=0)))), 2),
            'rms_dbfs': round(20*np.log10(np.sqrt(np.mean(x*x))), 2),
            'mono_loss_db': round(20*np.log10(np.sqrt(np.mean(mono*mono)/np.mean(x*x))), 3)}


results = []
for kind, contact, seconds, speed in [('e', 23/60, 1.55, .94), ('space', 50/60, 2.30, .73)]:
    cast, gather, impact, onset = make(kind, contact, seconds, speed)
    preview = np.zeros((round((seconds*2+1.4)*SR), 2))
    for at in [.30, seconds+1.0]: add(preview, cast, at)
    outputs = [write(f'{kind}_v1_preview.wav', preview), write(f'{kind}_v1_single.wav', cast),
               write(f'{kind}_v1_gather_timeline.wav', gather), write(f'{kind}_v1_impact_timeline.wav', impact)]
    results.append({'ability': kind, 'contact_seconds': contact, 'claw_start_seconds': onset, 'outputs': outputs})

report = {'status': 'AUDITION ONLY — awaiting listening approval; no E/Space runtime changes',
          'timing_source': 'RevenantNobleImport + noble FBX import events (not old revenant_events JSON)',
          'sources_sha256': {str(p.relative_to(REPO)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [CLAW, ORGANIC]},
          'results': results}
(OUT/'measurements.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
