# Periodic combat stall — 2026-09-30

Measured in Godot 4.6.3, GL Compatibility, NVIDIA RTX 4090, with the real renderer.
`tools/perf_probe.gd -- --profile` starts wave 5, holds fire, alternates heavy attack,
uses skills and ultimate every four seconds when available, and samples 60 seconds.
The probe has isolated progression and extra health so death does not end sampling.

Before: 3387 frames / 60 seconds, 56.4 average FPS. Frame stalls at 2.54 s,
11.27 s and 19.57 s lasted 1193.0, 1147.3 and 1227.5 ms. Gaps were 8.74 and
8.30 seconds. Each coincided with a synchronous enemy GLB load: Assassin,
Healer, then Assassin again. The weak resource cache did not retain PackedScenes
once their instances were gone.

After: strongly retained model scenes, with enemy models warmed before combat.
3601 frames / 60 seconds, 60.0 average FPS, **zero frames over 80 ms**. The same
combat-input scenario was used, with normal random enemy draws. Loading cost is
paid once before combat instead of during enemy spawns; retained assets use more
memory. This measures this scenario and machine, not every possible future stall.

Raw before/after logs are checked in alongside this report. The cache regression
also verifies that freeing the last actor does not evict its model scene.
