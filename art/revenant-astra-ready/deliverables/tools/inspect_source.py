import bpy,json
from pathlib import Path
from mathutils import Vector
D=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(D.parent/'input/revenant-tripo.glb'))
s=bpy.context.scene;s.render.fps=60
for im in bpy.data.images:
 if im.has_data:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(D/'Revenant_Source.blend'))
r=next(o for o in s.objects if o.type=='ARMATURE');m=next(o for o in s.objects if o.type=='MESH')
info={'objects':[{ 'name':o.name,'type':o.type,'matrix':[list(v) for v in o.matrix_world],'dims':list(o.dimensions)} for o in s.objects], 'bones':[{ 'name':b.name,'parent':b.parent.name if b.parent else '', 'head':list(r.matrix_world@b.head_local),'tail':list(r.matrix_world@b.tail_local)} for b in r.data.bones], 'vertices':len(m.data.vertices),'triangles':sum(len(p.vertices)-2 for p in m.data.polygons),'uv':[u.name for u in m.data.uv_layers],'images':[(i.name,list(i.size)) for i in bpy.data.images]}
(D/'qa/source_audit.json').write_text(json.dumps(info,indent=2))
print(json.dumps(info,indent=2))
s.render.engine='BLENDER_WORKBENCH';s.render.resolution_x=900;s.render.resolution_y=900;s.render.resolution_percentage=100
s.display.shading.light='STUDIO';s.display.shading.color_type='TEXTURE';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True;s.display.shading.background_type='WORLD';s.world=bpy.data.worlds.new('Studio');s.world.color=(.06,.06,.06)
coords=[m.matrix_world@Vector(c) for c in m.bound_box];lo=Vector([min(v[k] for v in coords) for k in range(3)]);hi=Vector([max(v[k] for v in coords) for k in range(3)]);center=(lo+hi)/2
for name,dir in [('front',(0,-1,.05)),('side',(1,0,.05)),('back',(0,1,.05)),('three',(1,-2,.4))]:
 bpy.ops.object.camera_add(location=center+Vector(dir).normalized()*(hi-lo).length*2)
 c=bpy.context.object;c.rotation_euler=(center-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=max(hi-lo)*1.17;s.camera=c
 s.render.filepath=str(D/'qa'/('source_'+name+'.png'));bpy.ops.render.render(write_still=True)
