from pathlib import Path
import bpy

HERE=Path(__file__).resolve().parent

def reset(): bpy.ops.wm.read_factory_settings(use_empty=True)

def inspect_glb(path):
    reset();bpy.ops.import_scene.gltf(filepath=str(path))
    print('GLB',path.name)
    for obj in bpy.context.scene.objects:
        if obj.type=='MESH':
            print(' MESH',obj.name,'verts',len(obj.data.vertices),'matrix',tuple(round(v,4) for row in obj.matrix_world for v in row))
            for mat in obj.data.materials:
                print('  MAT',mat.name,'metallic',mat.metallic,'roughness',mat.roughness,'base',tuple(round(x,4) for x in mat.diffuse_color))
                if mat.use_nodes:
                    for node in mat.node_tree.nodes:
                        if node.type=='TEX_IMAGE' and node.image:
                            print('   IMAGE',node.name,node.image.name,node.image.size[:],node.image.file_format,node.image.colorspace_settings.name)

def inspect_fbx(name):
    reset();bpy.ops.import_scene.fbx(filepath=str(HERE/'source/animations'/f'{name}.fbx'),use_anim=True)
    arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH');action=next(iter(bpy.data.actions))
    print('FBX',name,'arm_matrix',tuple(round(v,5) for row in arm.matrix_world for v in row),'mesh_matrix',tuple(round(v,5) for row in mesh.matrix_world for v in row),'range',action.frame_range,'curves',len(action.fcurves))
    for bone in ['mixamorig:Hips','mixamorig:RightHand','mixamorig:LeftHand']:
        b=arm.data.bones[bone];print(' BONE',bone,'head',tuple(round(v,5) for v in b.head_local),'tail',tuple(round(v,5) for v in b.tail_local),'matrix',tuple(round(v,5) for row in b.matrix_local for v in row))
    for path in [f'pose.bones["mixamorig:Hips"].location',f'pose.bones["mixamorig:RightHand"].rotation_quaternion']:
        curves=[c for c in action.fcurves if c.data_path==path]
        print(' CURVE',path,[(c.array_index,len(c.keyframe_points),round(c.keyframe_points[0].co.y,5),round(c.keyframe_points[-1].co.y,5)) for c in curves])

inspect_glb(HERE/'source/character/vesper_character.glb')
inspect_glb(HERE/'source/sword/fiery_sword_v1.glb')
for name in ['Idle','Attack1','Attack2','Attack3','DashAttack','CastQ','Ultimate']:
    inspect_fbx(name)
