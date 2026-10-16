"""Restore UV-matched original character textures, without touching meshes/rigs.

Run with Python + Pillow. PNG output preserves decoded source pixels exactly;
an original JPEG remains limited by its original quality (never 'restored' by
renaming a low-resolution runtime JPEG). Re-run after re-exporting a character model.
"""
from pathlib import Path
from PIL import Image
import io, json, struct, re

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / 'unity/Assets/Bloodwake/Resources/Models'

def one(folder, pattern):
    paths = list(folder.glob(pattern))
    assert len(paths) == 1, (folder, pattern, paths)
    return paths[0]

def files(folder, knight=False):
    patterns = ['*_basecolor.*', '*_normal.*', '*_metallic.*', '*_roughness.*'] if knight else ['Color.jpg', 'Normal.png', '*metallic*', '*roughness*']
    return dict(zip(['albedo', 'normal', 'metallic', 'roughness'], [one(folder,p) for p in patterns]))

def glb_material(path, name=None):
    raw=path.read_bytes(); n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]); binary=raw[28+n:]
    mats=[m for m in doc['materials'] if name is None or m.get('name')==name]
    assert len(mats)==1, (path, name, [m.get('name') for m in mats])
    mat=mats[0]; pbr=mat.get('pbrMetallicRoughness',{}); result={}
    for key, tex in [('albedo',pbr.get('baseColorTexture')),('normal',mat.get('normalTexture')),('metallicRoughness',pbr.get('metallicRoughnessTexture'))]:
        if not tex: continue
        image=doc['images'][doc['textures'][tex['index']]['source']]
        view=doc['bufferViews'][image['bufferView']]; start=view.get('byteOffset',0)
        result[key]=(Image.open(io.BytesIO(binary[start:start+view['byteLength']])).copy(),str(path.relative_to(ROOT))+'#'+key)
    return result

def sources():
    spec={}
    for row in json.loads((ROOT/'art/enemies/manifest.json').read_text()):
        spec[('enemy_'+row['id'],row['id']+'_'+row['kind']+'_PBR')]=files((ROOT/row['source']).with_suffix('.fbm'))
    spec[('enemy_mage','mage_character_PBR')]=glb_material(ROOT/'art/enemies/source/Mage/fantasy_wizard.glb')
    for model,material,folder,knight in [
        ('warrior_player','Knight PBR','art/warrior/source/knight',True),
        ('warrior_player','Greatsword PBR','art/warrior/source/greatsword',True),
        ('mage_player','Mage PBR','art/mage/source/model',False)]:
        spec[(model,material)]=files(one(ROOT/folder,'*.fbm'),knight)
    return spec

def restore():
    spec=sources(); report=[]
    # Resolve and validate every mapping before changing any manifest.
    manifests={p:json.loads(p.read_text()) for p in MODELS.glob('*/materials.json')}
    for path,rows in manifests.items():
        for name,row in rows.items():
            if 'albedo' not in row or row.get('preserveOriginal'): continue
            key=(path.parent.name,re.sub(r'\.\d+$','',name))
            assert key in spec, ('Missing original source',key)
    for path,rows in manifests.items():
        for name,row in rows.items():
            if 'albedo' not in row or row.get('preserveOriginal'): continue
            source=spec[(path.parent.name,re.sub(r'\.\d+$','',name))]; decoded={}; origins={}
            for channel,value in source.items():
                if isinstance(value,Path): decoded[channel]=Image.open(value).copy(); origins[channel]=str(value.relative_to(ROOT))
                else: decoded[channel],origins[channel]=value
            if 'metallic' in decoded:
                metal=decoded.pop('metallic').convert('L'); rough=decoded.pop('roughness').convert('L')
                assert metal.size==rough.size, (name,metal.size,rough.size)
                decoded['metallicRoughness']=Image.merge('RGB',(Image.new('L',metal.size,255),rough,metal))
                origins['metallicRoughness']=origins['metallic']+' + '+origins['roughness']
            for channel,image in decoded.items():
                old=Image.open(path.parent/row[channel]); filename='HQ_'+re.sub(r'[^a-zA-Z0-9_]','_',name)+'_'+channel+'.png'
                dest=path.parent/filename
                staging=ROOT/'unity/Library/TextureRestore'; staging.mkdir(parents=True,exist_ok=True)
                temporary=staging/filename; image.save(temporary); temporary.replace(dest)
                assert Image.open(dest).tobytes()==image.tobytes(), dest
                report.append(dict(model=path.parent.name,material=name,channel=channel,source=origins[channel],previous=list(old.size),restored=list(image.size),output=str(dest.relative_to(ROOT))))
                row[channel]=filename
        path.write_text(json.dumps(rows,indent=2)+'\n')
    (ROOT/'unity/character-texture-audit.json').write_text(json.dumps(report,indent=2)+'\n')
    print('RESTORED',len(report),'texture bindings across',len(manifests),'actors')
    for r in report: print(r['model'],r['material'],r['channel'],r['previous'],'->',r['restored'])

if __name__=='__main__': restore()
