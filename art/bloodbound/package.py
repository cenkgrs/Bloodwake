"""Package transparent rendered frames as bounded-size Flame atlases."""
from pathlib import Path
import json, math, sys
from PIL import Image, ImageDraw
HERE=Path(__file__).resolve().parent
review='--preview' in sys.argv
source=HERE/('review' if review else 'frames')
metadata=json.loads((source/'animations.json').read_text())
names=['idle','run','attack','hit','death']
contact=Image.new('RGB',(8*180,len(names)*200),(38,41,47));draw=ImageDraw.Draw(contact)
dest=HERE.parent.parent/'assets/images/characters/bloodbound'
if not review:dest.mkdir(parents=True,exist_ok=True)
for row,name in enumerate(names):
    clip=metadata[name];paths=sorted((source/name).glob('*.png'))
    assert len(paths)==clip['frames'],(name,len(paths),clip)
    size=128;columns=min(16,len(paths));atlas=Image.new('RGBA',(columns*size,math.ceil(len(paths)/columns)*size))
    draw.text((4,row*200+3),name,fill='white');gif=[]
    samples=[round(i*(len(paths)-1)/7) for i in range(8)]
    for i,p in enumerate(paths):
        frame=Image.open(p).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
        alpha=frame.getchannel('A');box=alpha.point(lambda x:255 if x>16 else 0).getbbox()
        assert box and box[0]>0 and box[1]>0 and box[2]<size and box[3]<size,(name,i,box)
        atlas.paste(frame,((i%columns)*size,(i//columns)*size))
        for index,sample in enumerate(samples):
            if sample==i:
                im=frame.resize((180,180));contact.paste(im,(index*180,row*200+20),im)
        bg=Image.new('RGB',(256,256),(38,41,47));im=frame.resize((256,256));bg.paste(im,(0,0),im);gif.append(bg.quantize(colors=128, method=Image.Quantize.FASTOCTREE))
    clip.update(columns=columns,frameSize=size)
    if not review:atlas.save(dest/f'{name}.png')
    gif[0].save(source/f'{name}.gif',save_all=True,append_images=gif[1:],duration=round(clip['stepTime']*1000),loop=0)
contact.save(source/'contact.jpg')
if not review:
    (dest/'animations.json').write_text(json.dumps(metadata,indent=2)+'\n')
    Image.open(source/'idle/000.png').save(dest/'portrait.png')
print('PASS: five clips, frame counts, nonempty images and transparent bounds')
