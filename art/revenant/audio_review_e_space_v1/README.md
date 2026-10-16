# Revenant E / Space — listening candidates, 16 October 2026

Status: approved by the user on 2026-10-16 and integrated in Unity. The exact
single WAVs are copied to Resources/audio as `revenant_e_blood_bomb.wav` and
`revenant_space_blood_burst.wav`. Each plays once at cast start, gain 1 / pitch 1,
stereo PCM with normalization disabled. The old generic cast/blast sounds have
been removed only from these two Revenant branches. Q is unchanged.

The build script and measurements describe the original audition snapshot.
Full mixes follow the existing real-time audio system; hit-stop/pause can
offset them from animation time. Live game verification remains pending.

- `e_v1_preview.wav`: same E twice. Tight palm contact, claw-like pressure sheet,
  short low impact, restrained organic accent. Contact at 23/60 s from cast.
- `space_v1_preview.wav`: same Space twice. Longer pressure build, lowered claw
  body, deeper impact and wider/longer tail. Contact at 50/60 s from cast.
- `*_single.wav`: one cast, with no preview lead-in.
- `*_gather_timeline.wav` and `*_impact_timeline.wav`: same cast-relative timing
  and shared gain as each single; not marker-relative stems.

Timings come from RevenantNobleImport and the current noble FBX import metadata.
Do not use the older BloodBurst timings in revenant_events.json for these clips.
Previews add 0.30 s lead-in and a pause between repeats.

Sources:

1. Existing game `audio/polished/revenant_basic_attack_c.wav`; pitched/resampled
   to 0.94x for E and 0.73x for Space. Not the rejected old generic skill sounds.
2. EZduzziteh, **Squish Sounds Effects**, **CC0**:
   https://opengameart.org/content/squish-sounds-effects
   Local source: `../audio_review_q_v2/sources/squish_03.mp3`.
   Only a quiet reversed gathering texture and short filtered contact accent;
   no wet arrival loop, dripping or slurping tail. No new downloads.
3. Original deterministic filtered-noise pressure, crack and low-body layers.

Rebuild with `python3 art/revenant/audio_review_e_space_v1/build_previews.py`.
Requires ffmpeg, NumPy and SciPy. WAVs: stereo, 48 kHz, PCM16. Measurements and
source hashes are in `measurements.json`. E peak -4.5 dBTP, Space -4 dBTP;
mono fold-down loses less than 0.04 dB. This is technical validation, not a
claim of subjective listening approval or an in-game sound test.
