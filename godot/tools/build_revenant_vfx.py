"""Blender-authored UV ribbons for a three-claw blood slash; units = reach radius.
Rebuild: blender -b -t 4 --python godot/tools/build_revenant_vfx.py
"""
import bpy, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def ribbons(name,wisps=False):
    verts=[];faces=[];uv=[]
    for claw in range(3):
        for strand in range(3 if wisps else 1):
            base=len(verts)
            for i in range(65):
                t=i/64; a=-1.08+t*2.16
                radius=.73+claw*.105
                jag=(math.sin(t*43+claw*2)+math.sin(t*91+strand))* (.019 if wisps else .005)
                radius+=jag+(strand-1)*.025 if wisps else jag
                width=(.105 if wisps else .065)*max(.025,math.sin(math.pi*t))**.65
                for side in [-1,1]:
                    r=radius+width*side
                    # Blender -Y exports to Godot +Z, the actor's forward direction.
                    verts.append((math.sin(a)*r,-math.cos(a)*r,.42+claw*.095+math.sin(a)*.13+(strand-1)*.03))
                    uv.append((t,(side+1)/2))
                if i<64:
                    n=base+i*2;faces.append((n,n+1,n+3,n+2))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    layer=mesh.uv_layers.new(name='UVMap')
    for poly in mesh.polygons:
        for j in poly.loop_indices:layer.data[j].uv=uv[mesh.loops[j].vertex_index]
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    mat=bpy.data.materials.new(name+'Preview');mat.diffuse_color=(.7,.004,.013,1);mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF');shader.inputs['Base Color'].default_value=(.45,.001,.003,1)
    shader.inputs['Emission Color'].default_value=(1,.005,.015,1);shader.inputs['Emission Strength'].default_value=3
    mesh.materials.append(mat)
ribbons('ClawCore');ribbons('BloodWisps',True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/vfx/revenant_claws.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/revenant/blender/revenant_claws.blend'))
# Separate upward fountain for Blood Burst / teleport gates. The reference has
# long, irregular blood blades, not a solid sphere or a flat expanding ring.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for name,count,thin in [('BloodLances',18,False),('BloodVeil',27,True)]:
    verts=[];faces=[];uv=[]
    for strand in range(count):
        angle=strand*math.tau/count
        tall=.68+.30*(.5+.5*math.sin(strand*13.17))
        base=len(verts)
        for i in range(41):
            t=i/40
            r=.08+(.72+.13*math.sin(strand*7.3))*t
            a=angle+math.sin(t*math.pi)*.22
            jitter=math.sin(t*47+strand)*math.sin(t*17+strand)*(.025 if thin else .013)
            z=(t**.65)*tall+math.sin(t*math.pi)*.12
            width=(.035 if thin else .052)*math.sin(math.pi*min(.999,max(.001,t)))**.6
            for side in [-1,1]:
                x=math.cos(a)*(r+jitter)-math.sin(a)*width*side
                y=math.sin(a)*(r+jitter)+math.cos(a)*width*side
                verts.append((x,y,z));uv.append((t,(side+1)/2))
            if i<40:
                n=base+i*2;faces.append((n,n+1,n+3,n+2))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    layer=mesh.uv_layers.new(name='UVMap')
    for p in mesh.polygons:
        for j in p.loop_indices:layer.data[j].uv=uv[mesh.loops[j].vertex_index]
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/vfx/revenant_burst.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/revenant/blender/revenant_blood_burst.blend'))
