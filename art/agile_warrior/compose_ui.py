"""Pack the six Vesper key-art frames into Bloodwake's Unity UI formats."""
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art/agile_warrior/cinematics'
UI=ROOT/'unity/Assets/Bloodwake/Resources/ui'
names=['vesper_01_idle.png','vesper_02_outward_slash.png','vesper_03_inward_slash.png',
       'vesper_04_spin.png','vesper_05_q.png','vesper_06_space.png']

def cinematic_frame(path):
    image=Image.open(path).convert('RGB')
    width,height=image.size
    crop_width=int(height*0.5)
    left=max(0,(width-crop_width)//2)
    return image.crop((left,0,min(width,left+crop_width),height)).resize((512,1024),Image.Resampling.LANCZOS)

frames=[cinematic_frame(SOURCE/name) for name in names]
for folder in ('loading_cinematics','portraits','class_screen/classes','class_screen/abilities'):
    (UI/folder).mkdir(parents=True,exist_ok=True)
for index,suffix in [(0,''),(3,'_2')]:
    atlas=Image.new('RGB',(1536,1024))
    for column in range(3):atlas.paste(frames[index+column],(column*512,0))
    atlas.save(UI/'loading_cinematics'/f'vesper_triptych{suffix}.png',optimize=True)

portrait=Image.open(SOURCE/names[0]).convert('RGB').resize((1024,1536),Image.Resampling.LANCZOS)
portrait.save(UI/'portraits/vesper.png',optimize=True)
# Class cards are square bust medallions; keep the face, shoulders and sword hilt.
card=portrait.crop((0,40,1024,1064)).resize((256,256),Image.Resampling.LANCZOS).convert('RGBA')
card.save(UI/'class_screen/classes/vesper.png',optimize=True)
# Readable ability tiles derived from the two authored cast frames.
for name,index in [('cinder_ward',4),('bloodfire_rite',5),('ember_dash',3)]:
    icon=frames[index].crop((64,210,448,594)).resize((256,256),Image.Resampling.LANCZOS).convert('RGBA')
    icon.save(UI/'class_screen/abilities'/f'{name}.png',optimize=True)
print('VESPER_UI_READY')
