# Revenant Q — mist into claw, v3 audition

User rejected v2's wet/sloppy arrival and suggested the existing basic-combo claw.
V3 preserves the v2 departure stem byte-decoded at its previous level, removes
all v2 arrival splat/slurp/droplet layers, and adds the existing polished
`revenant_basic_attack_c.wav` at original speed and pitch, gain 0.58.

Important: current runtime selects A/B/C randomly for every Revenant swing;
there is no dedicated third-hit sound. C is the concrete candidate selected
for this audition, not a claim that C was previously the fixed finisher.

The claw's strongest 15 ms energy window is aligned to Q DAMAGE at 25/60 s.
Its wind-up starts earlier, while the character enters/transits the mist.
The preview plays the same candidate twice. Single and claw-only versions
are also included; technical measurements and source hashes are in JSON.

Approved by the user on 2026-10-16. The exact single WAV is now copied to
Unity Resources as `revenant_q_mist_claw.wav`, played once at Q cast start,
at unity gain and original pitch. Q no longer plays the old generic launch
or landing sounds. Gameplay and animation markers are unchanged.
The build script and measurements describe the original audition snapshot.
The departure retains the CC0 source attribution documented in
`../audio_review_q_v2/README.md`. The claw is the user's existing game asset;
no new external source was downloaded for v3.
