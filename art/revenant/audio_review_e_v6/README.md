# E v6 — only volume moves on the actual v4 file

User rejected v5: they wanted the ending blood-burst section of
`e_v1_then_v4_comparison.wav` louder and the claw only slightly quieter,
not an entirely different balance with a 75% claw reduction.

Input is the actual v4 single, verified byte-for-byte PCM against the second
sound in that named comparison. Multiply the existing stereo samples by a
smooth gain envelope: early claw section -10%, ending burst section +25%.
Transitions: early .055–.09 s / .345–.395 s; ending .395–.435 s / .90–1.05 s.
These are section faders, not claims of isolated stem separation.

No new source, no EQ, filtering, pitch, stretch, timing, layer or normalization
change. Do not reuse v5's tiny-organic-layer boost. Original v1 provenance
continues to apply through v4; no source was downloaded.

- `e_v6_volume_only_preview.wav`: adjusted version twice.
- `e_v4_then_v6_comparison.wav`: unchanged v4 first, volume-adjusted v6 second.
- `e_v6_volume_only_single.wav`: one adjusted cast.

Audition only. Runtime E remains v1; Q and Space unchanged.
Rebuild: `python3 art/revenant/audio_review_e_v6/build_e.py`.
PCM16/48 kHz stereo; peak/source hash in measurements.json. No live game test.
