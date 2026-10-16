# E v5 — v4, blood forward / claw behind

User liked v4, but the claw masked the blood spray; requested reversed
loudness/density hierarchy. This is a stem rebalance, not a new sound design.

Reconstruct the exact deterministic v1 claw and organic contact layers, apply
the v4 linear processing with its saved local contact gain, and subtract those
from the actual v4 single. Remix only these two layers. The remainder (pressure
body, preparation, reflections of the other layers) is unchanged mathematically.
Source preparation is executed without the original generator's output loop.

- Claw gain .25 (-12.04 dB relative to its v4 layer).
- Boost the existing blood-contact source, capped by -4 dBTP mix headroom.
  The original organic layer was extremely quiet; measured gain is in JSON.
- Blood layer whole-file RMS now exceeds claw by about 3.4 dB.
- No new source, no v2/v3 explosion, no timing or duration changes.
- The quiet reverse-organic preparation is left alone; only the contact spray
  is boosted. Original v1 CC0 provenance/licensing remains applicable.

Files:

- `e_blood_forward_v5_preview.wav`: NEW candidate twice.
- `e_v4_then_v5_comparison.wav`: PREVIOUS v4, THEN new v5.
- `e_blood_forward_v5_single.wav`: one cast for future integration if approved.

Audition only, not in Unity. Runtime E still v1. Q/Space untouched.
Script requires ffmpeg/NumPy/SciPy and the preserved v1 generator + v4 files.
Rebuild with `python3 art/revenant/audio_review_e_v5/build_e.py`.
Checks reconstruct v1 within PCM quantization tolerance and confirm unchanged
remaining layers, finite audio, peak headroom and blood-over-claw RMS hierarchy.
Technical checks do not replace user listening approval.
