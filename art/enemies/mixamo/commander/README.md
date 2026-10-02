# Commander

Mixamo Pro Magic Pack downloaded on 2026-10-02 with the uploaded commander rig.
Five retained clips: Idle, Run (walking), Attack (one-hand upward cast), Hit and
Death. Rebuild using Blender with godot/tools/build_mixamo_enemy.py -- commander.
Original character and skull staff PBR textures are preserved from source/Commander.
Staff attaches to LeftHand; placement is recorded in clips.json.

Commander keeps the existing support role and wave-scaled stats. Its rally lasts
1.1 seconds and applies the existing aura at 0.55 seconds to living nearby allies,
excluding commanders and bosses. It holds position and heading through the cast.
The aura pulse is displayed at release. No additional projectile or damage added.

Validation: enemy_commander_test, enemy_tank_test, healer_animation_test and
enemy_asset_test. In-game idle, walking, rally and death captures are in preview/.
