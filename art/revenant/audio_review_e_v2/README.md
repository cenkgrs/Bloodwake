# Revenant E — pressure blood bomb v2

Listening candidate only. User found the approved E v1 unsuitable in the game:
the claw was unnecessary; E should resemble a sonic/pressure bomb with blood.
Q and Space remain approved and unchanged. Unity still uses E v1 until this
replacement is approved.

- **No claw sample**, sword, slicing swish or existing generic spell sample.
- Quiet pressure gathering, very short gap, broad compressed-air transient,
  centered low/mid impact and fast dark dissipation.
- Short cropped blood spray behind the pressure front; no long slurp/drips.
- Contact begins at 23/60 s from cast, matching the current noble E marker.
- Preview plays the same candidate twice, starting at .30 and 2.55 s.
- Single is one cast; the three stems retain cast-relative timing/shared gain.

Original procedural pressure layers plus EZduzziteh's CC0 recording,
`../audio_review_q_v2/sources/squishsplat_impact.mp3`, trimmed, resampled to
0.82x, band-filtered, enveloped and mixed quietly. Source and license:
https://opengameart.org/content/squish-sounds-effects
https://creativecommons.org/publicdomain/zero/1.0/
No new downloads. No claw recording is loaded by the generator.

Rebuild: `python3 art/revenant/audio_review_e_v2/build_e.py` (NumPy, SciPy,
ffmpeg). Stereo PCM16, 48 kHz, -4.5 dBTP; technical checks and source hash in
measurements.json. Technical checks do not imply subjective listening or
in-game approval. Runtime files are not modified by the generator.
