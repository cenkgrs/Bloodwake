# Gunslinger — detailed stylized character

This is the earlier procedural prototype. The new user-provided Bloodbound
source is tracked separately in `../bloodbound/README.md`; this builder does
not process that imported model. Rebuilding this prototype overwrites the
currently used Gunslinger/Bloodbound sprite strips.

Original procedural model built for this project. Editable source:
`source/gunslinger.blend`; exchange asset:
`../../assets/models/characters/gunslinger/gunslinger.glb`.

84,404 triangles, 18 deform bones, six 30 fps skeletal clips:
idle (1 s), run (0.67 s), attack (0.4 s), hit (0.33 s), death (1.07 s),
reload (1.6 s). Idle/run are cyclic; other clips are one-shots. The root
stays in place during locomotion. Forward is -Y in Blender, Z is up;
glTF export converts axes to its standard Y-up coordinates.

Includes shaped coat and lapels, curved hat brim, anatomical face details,
gloved fingers, holsters, boot straps, and a lever-action rifle. This is a
more detailed stylized asset, not a photorealistic sculpt. Materials use
solid PBR colors; no photographic textures. Separated parts use rigid bone
weights; the rig is an FK deformation skeleton, without IK controls or
facial animation. Reload is a gesture blockout, without moving cartridges.
Further art polish would include continuous joint topology, blended skin
weights, hand/weapon contact refinement and textured surface wear.

The Flame game uses transparent 128 px rendered frames packaged into
sprite strips. Five states are connected to the existing Gunslinger;
reload is included only in the source/GLB and review renders because the
game has no reload state. The high-resolution mesh is not loaded at runtime.
The sprite loader now uses all rendered idle/run frames and full frame
bounds, and enables attack playback for this class.

Rebuild from repository root:

```sh
/path/to/blender --background --python art/gunslinger/build.py
python3 art/gunslinger/package.py
```

`geometry.py` defines the detailed geometry. `build.py` creates the rig,
keys every pose, exports GLB, saves Blender source, and renders previews.
`package.py` checks frame bounds and builds strips, contact sheet, and GIFs.
Pillow is required for packaging. `asset_report.json` records exported counts.

Validation: inspected static render and six-animation contact sheet;
all frames have transparent guard edges; GLB has the six named clips and
18 joints; Dart analyzer passes for the modified animator. The game has
not been playtested in this session.
