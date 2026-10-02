# Tank

Rigged tank downloaded from Mixamo on 2026-10-02. Idle, walking, downward axe
attack and gut reaction come from Pro Melee Axe Pack. Death is Standing React
Death Backward, retargeted to the same uploaded tank. Only the five used clips
are retained. Original character and axe PBR textures come from source/Tank.

Rebuild with Blender and `godot/tools/build_mixamo_enemy.py -- tank`.
The axe is rigidly weighted to RightHand; its grip and orientation are recorded
in clips.json. The builder removes planar root motion. Godot uses the existing
2.3 m tank height and existing wave-scaled health/damage.

Attack lasts 1.3 seconds. Contact is at 69/136 of the clip (source pose at 1.15 s),
checked with preview_enemy_tank.gd. Tank holds its heading during the attack;
range and facing are checked again at contact so moving away avoids damage.
Validation: enemy_tank_test.gd and combat_flow_test.gd.

Axe blade roll is -90 degrees around its shaft: its cutting face follows the
forward walking direction instead of pointing sideways. Preview includes Run.
