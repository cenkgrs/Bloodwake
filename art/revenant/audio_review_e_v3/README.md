# E v3 — sample-based blood detonation, awaiting listening approval

V2 was rejected as sounding like a balloon pop. This candidate replaces its
procedural short noise/sine transient entirely with two externally sourced
CC0 explosion effects. No claw source is used. This is not a claim that the
source effects were field recordings of real explosives: NenadSimic explicitly
describes his effect as a lowered log drum with delayed reverberation.

Sources (pages/license verified 2026-10-16):

- EZduzziteh, **Explosions**, CC0:
  https://opengameart.org/content/explosions-4
  File: https://opengameart.org/sites/default/files/explosion1_0.ogg
- NenadSimic, **Muffled Distant Explosion**, CC0:
  https://opengameart.org/content/muffled-distant-explosion
  File: https://opengameart.org/sites/default/files/NenadSimic%20-%20Muffled%20Distant%20Explosion.wav
- EZduzziteh, **Squish Sounds Effects**, CC0, previously downloaded:
  https://opengameart.org/content/squish-sounds-effects
  `../audio_review_q_v2/sources/squishsplat_impact.mp3`.

Processing: trim pre-roll, lower first explosion slightly, band-filter,
soft-saturate for body, retain 1.2 s of detonation/tail with fades, layer a
short quiet blood accent. Narrow stereo, peak-normalize to -4.5 dBTP.
Original sources retained with SHA-256s in measurements.json.

Single starts at cast time 0, detonation at E contact 23/60 s. Preview plays
the same candidate twice with silence between, at .30 and 2.90 s.
Rebuild: `python3 art/revenant/audio_review_e_v3/build_e.py`.
Requires ffmpeg/NumPy/SciPy. Technical validation is not listening approval.
No Unity files changed; runtime E remains v1. Q/Space unchanged.
