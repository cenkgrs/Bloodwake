# Revenant Q / Space — in-game mix fix (16 Oct 2026)

The approved Q v3 and Space v1 files were not broken: no clipping, clean
start/end, timing aligned to DAMAGE (Q 25/60 s) and ULT_DAMAGE. They sounded
bad in game because of how the runtime layered them:

1. `DamageEnemy` played the generic `sword_hit_flesh` (-4 dB) on every Q/Space
   hit, exactly on the claw/burst transient (Q already contains the claw).
   Space also drew `enemy_death` on kills. At the damage frame the layered
   SFX were ~6 dB louder than the signature cast (see `mix_before_after.png`).
2. Both files sat ~10 dB below the SFX library (RMS -25 dBFS vs -14…-18) and
   Q's baked claw (basic attack C at 0.58) was quieter than a normal swing.
   `db` > 0 in rules.json is clamped to 1.0 by AudioSource.volume, so the
   level could not be raised from data.
3. `voices` in rules.json was ignored; with a full 32-voice pool a cast
   sound was silently dropped.

Fix: blood abilities skip the generic flesh hit; Q/Space are `priority`
voices that duck other effects by 9 dB while their body plays (25 ms
attack / ~180 ms release); voice limits are enforced with a 40 ms release;
a full pool steals the oldest ordinary voice for a signature cast. Files
received a pure linear gain (+4.0 dB Q, +3.5 dB Space; peaks -0.65/-0.54
dBFS); stereo, pitch and timing unchanged.

`mixsim.py` output here re-creates the runtime summing offline (not a Unity
capture): `*_before.wav` / `*_after.wav`, `basic_swing_ref.wav`.
