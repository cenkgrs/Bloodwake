# Bloodwake

PC-first dark fantasy survivor, built in **Godot 4.6.3 (standard/GDScript)**.
Open `godot/project.godot` in Godot and press F6/F5 to play. The game uses real
3D characters and skeletal animation.

See [Godot setup, controls, conventions and builds](godot/README.md) and
[latest handoff](MIGRATION_STATUS.md).

The game lives in `godot/`. Source art and the Blender/Mixamo pipelines live in
`art/`, which the tools under `godot/tools/` read from and write processed models
back into `godot/assets/`. Local engine caches and exported binaries are not
committed.

This started as a Flutter/Flame prototype. That code has been removed; the Godot
port carries the whole game, and the history is in git if an old decision ever
needs looking up.
