"""Export authored, static Revenant GLB ribbons without Blender or re-meshing.
Run: python3 unity/export_vfx.py. Unity's VFX builder creates native mesh assets.
Coordinates match export_assets.py: mirror X, preserve forward +Z and all UVs.
"""
from pathlib import Path
import hashlib, json, struct, shutil
ROOT=Path(__file__).resolve().parent.parent

def read_glb(path):
    with path.open('rb') as f:
        magic, version, total=struct.unpack('<III',f.read(12))
        assert magic==0x46546c67 and version==2
        n,kind=struct.unpack('<II',f.read(8)); assert kind==0x4e4f534a
        doc=json.loads(f.read(n)); n,kind=struct.unpack('<II',f.read(8)); assert kind==0x004e4942
        data=f.read(n)
    def accessor(index):
        a=doc['accessors'][index]; v=doc['bufferViews'][a['bufferView']]
        fmt={5123:'H',5125:'I',5126:'f'}[a['componentType']]
        width={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']]
        stride=v.get('byteStride',struct.calcsize('<'+fmt*width))
        offset=v.get('byteOffset',0)+a.get('byteOffset',0)
        return [list(struct.unpack_from('<'+fmt*width,data,offset+i*stride)) for i in range(a['count'])]
    meshes=[]
    for node in doc['nodes']:
        assert not any(k in node for k in ('matrix','translation','rotation','scale')), 'Bake source node transforms before export'
        for p in doc['meshes'][node['mesh']]['primitives']:
            assert p.get('mode',4)==4
            positions=accessor(p['attributes']['POSITION']); normals=accessor(p['attributes']['NORMAL'])
            uv=accessor(p['attributes']['TEXCOORD_0']); indices=[x[0] for x in accessor(p['indices'])]
            for v in positions+normals:v[0]=-v[0]
            # Reflection reverses handedness; reverse triangle winding too.
            indices=[v for i in range(0,len(indices),3) for v in (indices[i],indices[i+2],indices[i+1])]
            meshes.append(dict(name=node['name'],positions=positions,normals=normals,uv=uv,indices=indices))
    return dict(name=path.stem,source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),meshes=meshes)

def export():
    out=ROOT/'unity/Assets/Bloodwake/Resources/Vfx';out.mkdir(parents=True,exist_ok=True)
    for name in ('revenant_claws','revenant_burst'):
        source=ROOT/'godot/assets/vfx'/f'{name}.glb'
        (out/f'{name}.json').write_text(json.dumps(read_glb(source),separators=(',',':'))+'\n')
    shutil.copyfile(ROOT/'art/revenant-astra-ready/deliverables/animation_events.json',ROOT/'unity/Assets/Bloodwake/Resources/Data/revenant_events.json')
    print('REVENANT_VFX_SOURCE_EXPORTED')
if __name__=='__main__':export()
