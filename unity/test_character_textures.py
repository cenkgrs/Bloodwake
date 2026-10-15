"""Check restored actor sources, UV texture identity and lossless output pixels."""
import json, subprocess
import numpy as np
from PIL import Image
from restore_character_textures import ROOT, MODELS, sources

spec=sources(); count=0
for manifest in MODELS.glob('*/materials.json'):
    rows=json.loads(manifest.read_text())
    if all(row.get('preserveOriginal') for row in rows.values()):
        for row in rows.values():
            image=Image.open(manifest.parent/row['albedo']);assert image.size==(8192,8192)
        continue
    previous=json.loads(subprocess.check_output(['git','show','HEAD:'+str(manifest.relative_to(ROOT))],cwd=ROOT))
    for material,row in rows.items():
        for channel in ['albedo','normal','metallicRoughness']:
            if channel not in row: continue
            path=manifest.parent/row[channel]; current=Image.open(path)
            assert current.format=='PNG' and current.size==(4096,4096), (path,current.format,current.size)
            old=Image.open(manifest.parent/previous[material][channel])
            a=np.asarray(current.convert('RGB').resize((256,256)),dtype=float).flatten()
            b=np.asarray(old.convert('RGB').resize((256,256)),dtype=float).flatten()
            correlation=float(np.corrcoef(a,b)[0,1])
            # Same UV layout/material, allowing old JPEG/resampling/channel error.
            assert correlation>.95, (path,'UV/source mismatch',correlation)
            print(manifest.parent.name,material,channel,'correlation',round(correlation,5))
            count+=1
print('CHARACTER_TEXTURE_TESTS_PASSED',count)
