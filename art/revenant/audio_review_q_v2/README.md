# Revenant Q — organic Blood Step, audition v2

Not approved or integrated. All files stay outside Unity Resources. Old rejected
Q/Space auditions and current runtime sounds are untouched.

Listen to `q_bloodstep_v2_preview.wav`: the same candidate plays twice, with
silence between. `q_bloodstep_v2_single.wav` is one cast. Separate departure
and arrival stems retain the same mix gain for potential later marker playback.

Timing follows current `REV_TeleportAttack`: hide .250 s, move .317 s,
show .350 s, damage .417 s. Short reverse liquid pull and textured transit,
followed by a wet arrival impact. No laser oscillator, long charge or giant
ultimate-style tail. 48 kHz stereo PCM16, approximately -4 dBTP maximum.

## Source recordings / provenance

- **EZduzziteh — Squish Sounds Effects**, CC0 as displayed on the source page:
  https://opengameart.org/content/squish-sounds-effects
- Downloaded 2026-10-16: `squish_03.mp3`, `squish_06.mp3`,
  `squishsplat_impact.mp3` from that page's file links.
- Direct URL prefix: `https://opengameart.org/sites/default/files/`.
- License: https://creativecommons.org/publicdomain/zero/1.0/
- Changes: trimmed, resampled/pitched, filtered, reversed, layered with original
  filtered-noise body/transit, short stereo reflections and shared gain.
- Original downloaded MP3s retained in `sources/`; SHA-256s and output
  measurements in `measurements.json`. No third-party speech or music used.

Regenerate with `python art/revenant/audio_review_q_v2/build_q.py` (numpy,
scipy and ffmpeg required). Technical checks do not replace the user's
listening approval; E and Space are the next separate auditions.
