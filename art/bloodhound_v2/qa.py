"""Frame-by-frame numeric checks and real-time-rate motion previews."""
import bpy,json,math,subprocess,sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;OUT=HERE/'qa'
rig=bpy.data.objects['Bloodhound_Rig'];mesh=bpy.data.objects['Bloodhound_Body'];scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE_NEXT';scene.eevee.taa_render_samples=8
scene.render.resolution_x=384;scene.render.resolution_y=384
scene.render.image_settings.file_format='PNG'
cam=scene.camera;center=Vector((0,0,.85))
bpy.ops.mesh.primitive_plane_add(size=20);floor=bpy.context.object;floor.name='QA Ground'
mat=bpy.data.materials.new('QA Ground');mat.diffuse_color=(.055,.06,.07,1);floor.data.materials.append(mat)
report={'status':'IN_REVIEW','actions':{},'notes':['Weapon props are provisional geometry.','Source holstered weapons remain part of the supplied body mesh.','This report does not certify clothing collision clearance.']}
only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else None
if only and (OUT/'measurements.json').exists():report=json.loads((OUT/'measurements.json').read_text())
for action in list(bpy.data.actions):
 if not action.name.startswith('BH_'):continue
 if only and action.name!=only:continue
 rig.animation_data.action=action
 start,end=map(int,action.frame_range);poses=[];low=1e9
 for f in range(start,end+1):
  scene.frame_set(f);bpy.context.view_layer.update()
  pts=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices
  low=min(low,min(v.co.z for v in pts))
  poses.append({b.name:[x for row in b.matrix for x in row] for b in rig.pose.bones})
 seam=max(abs(x-y) for n in poses[0] for x,y in zip(poses[0][n],poses[-1][n]))
 movement=max(abs(x-y) for pose in poses for n in pose for x,y in zip(pose[n],poses[0][n]))
 markers={m.name:m.frame for m in action.pose_markers}
 report['actions'][action.name]={'frames':[start,end],'duration_seconds':(end-start)/60,'max_pose_change':movement,'loop_pose_difference':seam if action.name in ['BH_Idle','BH_Walk_InPlace'] else None,'lowest_vertex_z':low,'events':markers}
 if '--metrics-only' in sys.argv:
  print('QA_METRICS',action.name,report['actions'][action.name],flush=True);continue
 folder=OUT/action.name;folder.mkdir(exist_ok=True)
 cam.location=(2.5,-5,2.1);cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=2.4
 # Every other source frame, played at 30fps: no arbitrary respeeding.
 for i,f in enumerate(range(start,end+1,2)):
  scene.frame_set(f);scene.render.filepath=str(folder/f'{i:04}.png');bpy.ops.render.render(write_still=True)
 subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate','30','-i',str(folder/'%04d.png'),'-c:v','libx264','-pix_fmt','yuv420p',str(OUT/(action.name+'.mp4'))],check=True)
 for view,loc in [('front',(0,-5,1.2)),('side',(5,0,1.2)),('back',(0,5,1.2))]:
  cam.location=loc;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
  for f in sorted(set([start,(start+end)//2,end])):
   scene.frame_set(f);scene.render.filepath=str(OUT/f'{action.name}_{view}_{f:03}.png');bpy.ops.render.render(write_still=True)
 print('QA_CLIP',action.name,report['actions'][action.name],flush=True)
(OUT/'measurements.json').write_text(json.dumps(report,indent=2))
print('QA_RENDER_COMPLETE',flush=True)
