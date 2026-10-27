import subprocess,json
from pathlib import Path
from PIL import Image,ImageDraw
D=Path(__file__).resolve().parents[1];P=D/'previews';info=json.loads((D/'animation_events.json').read_text())['actions'];(P/'clips').mkdir(exist_ok=True);(P/'encoded').mkdir(exist_ok=True)
def run(args):subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y',*args],check=True)
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
codec=['-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart']
for name,data in info.items():
 length=data['end']
 for view in ['front','side','three']:
  for f in range(1,length+1):
   file=P/'action_frames'/view/name/f'{f:04}.png'
   with Image.open(file) as im:im.verify()
 inputs=[]
 for view in ['front','side','three']:inputs+=['-framerate','60','-start_number','1','-i',str(P/'action_frames'/view/name/'%04d.png')]
 graph=f"[0:v]scale=480:480[a];[1:v]scale=480:480[b];[2:v]scale=480:480[c];[a][b][c]hstack=inputs=3,drawtext=fontfile={font}:text='{name}  /  60 FPS  /  FRONT - SIDE - THREE QUARTER':fontcolor=white:fontsize=18:box=1:boxcolor=black@0.65:x=16:y=14[out]"
 run([*inputs,'-filter_complex',graph,'-map','[out]',*codec,str(P/'clips'/f'{name}_ThreeViews.mp4')])
 title=f"drawtext=fontfile={font}:text='{name}  /  60 FPS':fontcolor=white:fontsize=22:box=1:boxcolor=black@0.65:x=20:y=20"
 run(['-framerate','60','-start_number','1','-i',str(P/'action_frames'/'three'/name/'%04d.png'),'-vf',title,*codec,str(P/'encoded'/f'{name}.mp4')])
 run(['-i',str(P/'encoded'/f'{name}.mp4'),'-vf','tpad=stop_mode=clone:stop_duration=0.2',*codec,str(P/'encoded'/f'{name}_hold.mp4')])
 # Contact sheet: readable body poses from each view, with actual frame numbers.
 frames=[1,max(2,length//4),max(3,length//2),max(4,length*3//4),length]
 if name=='REV_Death':frames=[5,24,38,52,72]
 if name=='REV_TeleportAttack':frames=[6,15,22,26,34]
 if name=='REV_BloodBurst':frames=[18,42,59,70,108]
 sheet=Image.new('RGB',(5*256,3*280),'#202126');draw=ImageDraw.Draw(sheet)
 for row,view in enumerate(['front','side','three']):
  for col,f in enumerate(frames):
   im=Image.open(P/'action_frames'/view/name/f'{f:04}.png').resize((256,256));sheet.paste(im,(col*256,row*280));draw.text((col*256+8,row*280+258),f'{view} / frame {f}',fill='white')
 sheet.save(D/'qa'/f'{name}_ContactSheet.jpg',quality=92)
names=list(info);manifest=P/'encoded'/'nla.txt';manifest.write_text(''.join(f"file '{name}{'_hold' if i<len(names)-1 else ''}.mp4'\n" for i,name in enumerate(names)))
run(['-f','concat','-safe','0','-i',str(manifest),'-c','copy','-movflags','+faststart',str(P/'Revenant_NLA_Preview.mp4')])
repeats=[2,6,4,4,4,2,3,2];manifest=P/'encoded'/'showcase.txt';manifest.write_text(''.join(f"file '{n}.mp4'\n" for n,k in zip(names,repeats) for _ in range(k)))
run(['-f','concat','-safe','0','-i',str(manifest),'-c','copy','-movflags','+faststart',str(P/'Revenant_All_Actions.mp4')])
print('ALL_LIBRARY_VIDEOS_ENCODED')
