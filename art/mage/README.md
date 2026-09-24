# Mage — supplied Tripo mesh and Mixamo animation pack

Original model/textures: source/model. User-supplied Mixamo files: source/mixamo.
Build: blender -b -t 4 --python godot/tools/build_mixamo_mage.py (from repo root).
Output: godot/assets/models/mage_player.glb, with Idle, Run (provided walk), Attack,
Hit, Death, Ultimate. Source FPS is preserved on a shared 60 FPS timeline.
The body is normalized to 1.8 m, grounded and centered; planar root motion is
removed. PBR textures are embedded at up to 2K. No staff is added.
The right-hand orb, orbiting runes, particles and light are generated in BWVisual
and follow the animated hand bone. Ultimate increases the hand effect briefly.
