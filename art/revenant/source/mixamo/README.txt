Revenant animation sources — downloaded from the user's signed-in Mixamo account
on 2026-10-03, after the user completed the character upload/auto-rig.
All clips: FBX Binary, With Skin, 30 fps, no keyframe reduction.

Idle: Mutant Breathing Idle, full clip
Run: Mutant Run, In Place enabled, full clip
Attack1: Mutant Swiping, source frames 29–61
Attack2: Mutant Punch, source frames 5–29
Dash: Dodging (Boxing Dodge Advance), source frames 1–26
Hit: Standing React Small From Front, source frames 1–22
Death: Mutant Dying, full clip

Original downloads are preserved. The builder performs trimming only in memory.
The original Tripo GLB supplies the PBR material. No Warrior mesh, skeleton,
or animation is included in revenant_player.glb.
Rebuild: blender -b -t 4 --python godot/tools/build_mixamo_revenant.py
