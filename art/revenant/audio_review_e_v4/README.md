# E v4 — small revision of the first approved E

User rejected v2 (balloon pop) and v3 (too far from the original). The first
approved E v1 is the base again. Do not reinterpret this as a request for a
new unrelated blast or removal of the entire original sound character.

Only input: exact `../audio_review_e_space_v1/e_v1_single.wav`.
No v2/v3 samples, no newly synthesized sound or downloaded explosion.
Within .33–.85 s, rebalance the existing sound toward low/mid impact, reduce
its high scratch edge, and extend its own low-mid body slightly. Apply local
gain to keep the original peak budget, not global loudness normalization.
Samples before .33 and after .85 s are identical to the original. The original
preparation, timing and blood texture are retained; the claw is softened, not
removed. Existing v1 provenance/licensing applies.

`e_v1_then_v4_comparison.wav`: FIRST original, THEN revision (not two repeats).
`e_v4_single.wav`: only the revised candidate, no comparison or lead-in.

Audition only. Unity still uses E v1. Q/Space/runtime code are untouched.
Rebuild: `python3 art/revenant/audio_review_e_v4/build_e.py`.
Technical measurements/hashes in measurements.json; listening approval pending.
