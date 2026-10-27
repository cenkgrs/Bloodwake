"""Write Revenant_Animated.fbx from Revenant_Animated.blend, then re-import FBX and GLB
into empty scenes and record what survived.  blender -b Revenant_Animated.blend --python ..."""
import bpy, json, sys
from pathlib import Path
D = Path(__file__).resolve().parents[1]
rig = bpy.data.objects['REV_Rig']; body = bpy.data.objects['REV_Body']
for o in list(bpy.data.objects):
    if o not in (rig, body):
        bpy.data.objects.remove(o, do_unlink=True)
body.animation_data_clear()
rig.animation_data.action = None
for t in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(t)
for a in list(bpy.data.actions):
    if not a.name.startswith('REV_'):
        bpy.data.actions.remove(a)
for a in bpy.data.actions:
    for fc in list(a.fcurves):
        if not fc.data_path.startswith('pose.bones'):
            a.fcurves.remove(fc)
for b in rig.pose.bones:
    b.matrix_basis.identity()
# FBX cannot follow the Mix node in front of Base Color: link the texture directly
# (in memory only). Metallic/roughness ride in one packed map FBX has no slot for.
mat = body.data.materials[0]
nt = mat.node_tree
tex = next(n for n in nt.nodes if n.type == 'TEX_IMAGE' and 'basecolor' in n.image.name)
nt.links.new(tex.outputs['Color'], nt.nodes['Principled BSDF'].inputs['Base Color'])
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True); body.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(filepath=str(D / 'Revenant_Animated.fbx'), use_selection=True, object_types={'ARMATURE', 'MESH'},
                         add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=True, bake_anim_use_nla_strips=False,
                         bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0.0, path_mode='COPY', embed_textures=True,
                         axis_forward='-Z', axis_up='Y', apply_scale_options='FBX_SCALE_ALL', armature_nodetype='NULL', primary_bone_axis='Y', secondary_bone_axis='X')
report = {}
expected = sorted(a.name for a in bpy.data.actions)
for kind, path in (('fbx', D / 'Revenant_Animated.fbx'), ('glb', D / 'Revenant_Animated.glb')):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if kind == 'fbx':
        bpy.ops.import_scene.fbx(filepath=str(path), automatic_bone_orientation=False)
    else:
        bpy.ops.import_scene.gltf(filepath=str(path))
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    mesh = [o for o in bpy.data.objects if o.type == 'MESH']
    acts = sorted(a.name for a in bpy.data.actions)
    found = [e for e in expected if any(a == e or a.startswith(e + '|') or a.endswith('|' + e) or e in a for a in acts)]
    m = max(mesh, key=lambda o: len(o.data.vertices)) if mesh else None
    report[kind] = {'file_mb': round(path.stat().st_size / 1e6, 1), 'armatures': len(arm), 'bones': len(arm[0].data.bones) if arm else 0,
                    'meshes': len(mesh), 'vertices': len(m.data.vertices) if m else 0,
                    'materials': [s.name for s in m.data.materials] if m else [],
                    'images': [i.name for i in bpy.data.images], 'actions_found': len(found), 'actions_expected': len(expected),
                    'missing': [e for e in expected if e not in found],
                    'height_m': round(max((m.matrix_world @ v.co).z for v in m.data.vertices) - min((m.matrix_world @ v.co).z for v in m.data.vertices), 3) if m else 0}
(D / 'qa' / 'export_roundtrip.json').write_text(json.dumps(report, indent=1))
print('ROUNDTRIP', json.dumps(report))
