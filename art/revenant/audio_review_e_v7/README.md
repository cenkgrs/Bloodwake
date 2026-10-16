# E v7 — ending burst +30% over v6

User requested only another 30% increase of the blood burst. Input is the
actual v6 single. Same ending envelope (.395–.435 s rise, .90–1.05 s fall),
multiplied by 1 + .30 * envelope. At full gain this is 1.30x v6, or 1.625x v4.
Earlier claw retains v6's -10%; samples outside the ending are unchanged.
No other processing, normalization, source, timing or layer changes.

Preview plays the new candidate twice. Single is one cast. 48 kHz stereo
PCM16. Source hash/peak measurements in JSON. Inherits v1/v4 provenance.
Approved by the user on 2026-10-16 ("bu gayet iyi böyle kalabilir"). The exact
single WAV is now copied to Unity Resources/audio/revenant_e_blood_bomb.wav.
Existing gain/pitch and cast timing are unchanged. Q/Space unchanged.
The generator/measurements retain the original audition-time status.

Rebuild: `python3 art/revenant/audio_review_e_v7/build_e.py`.
