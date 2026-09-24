"""Package Blender renders as Flame sprite strips and review animations."""
from pathlib import Path
from PIL import Image, ImageDraw
HERE=Path(__file__).resolve().parent
preview=HERE/'preview'
states=['idle','run','attack','hit','death','reload']
contact=Image.new('RGB',(8*160,6*180),(27,32,40))
draw=ImageDraw.Draw(contact)
for row,name in enumerate(states):
    frames=[Image.open(p).convert('RGBA') for p in sorted((preview/name).glob('*.png'))]
    assert len(frames)==(8 if name in ['run','death','reload'] else 6)
    sheet=Image.new('RGBA',(128*len(frames),128))
    review=[]
    draw.text((5,row*180+4),name,fill='white')
    for i,im in enumerate(frames):
        assert im.size==(128,128)
        bbox=im.getchannel('A').getbbox()
        assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<128 and bbox[3]<128,(name,i,bbox)
        sheet.paste(im,(i*128,0))
        scaled=im.resize((160,160))
        contact.paste(scaled,(i*160,row*180+20),scaled)
        bg=Image.new('RGB',(384,384),(27,32,40));scaled=im.resize((384,384))
        bg.paste(scaled,(0,0),scaled);review.append(bg)
    dest=HERE.parent.parent/'assets/images/characters/gunslinger' if name!='reload' else preview
    sheet.save(dest/f'{name}.png')
    review[0].save(preview/f'{name}.gif',save_all=True,append_images=review[1:],duration=100,loop=0)
contact.save(preview/'contact_sheet.jpg')
print('PASS: all six clips have visible frames and transparent guard edges')
