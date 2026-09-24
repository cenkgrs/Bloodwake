"""Snapshot existing Dart content into engine-neutral JSON (no Dart runtime)."""
from pathlib import Path
import re,json
ROOT=Path(__file__).resolve().parents[2]
output={}
for name,filename,ctor in [
 ('weapons','lib/game/weapons/weapon_data.dart','WeaponData'),
 ('abilities','lib/game/abilities/ability_data.dart','AbilityData'),
 ('enemies','lib/game/enemies/enemy_data.dart','EnemyData'),
 ('upgrades','lib/game/upgrades/upgrade_catalog.dart','UpgradeData'),
 ('items','lib/game/items/item_catalog.dart','ItemData'),
 ('equipment','lib/game/progression/equipment_catalog.dart','EquipmentData'),
 ('skills','lib/game/progression/skill_tree.dart','SkillNode')]:
 text=(ROOT/filename).read_text();rows=[]
 # Only explicit catalog entries contain literal id/type values.
 for m in re.finditer(r'\b'+ctor+r'\(\s*\n(.*?)\n\s*\)',text,re.S):
  block=m.group(1);entry={}
  for f in re.finditer(r'^\s*(\w+):\s*((?:[^\n]|\n\s+)*?),(?=\s*\n\s*\w+:|\s*$)',block,re.M):
   key,val=f.groups();val=val.strip()
   strings=re.findall(r"'((?:\\.|[^'\\])*)'|\"((?:\\.|[^\"\\])*)\"",val)
   if strings:entry[key]=''.join(a or b for a,b in strings).replace("\\'", "'")
   elif re.fullmatch(r'-?\d+(\.\d+)?',val):entry[key]=float(val) if '.' in val else int(val)
   elif val in ('true','false'):entry[key]=val=='true'
   elif val.startswith('Color('):entry[key]='#'+val[8:14]
   elif re.fullmatch(r'\w+\.\w+',val):entry[key]=val.split('.')[-1]
   elif re.fullmatch(r'_\w+',val):entry[key]=val
  if 'id' in entry or (name=='enemies' and entry.get('type') in ['grunt','archer','tank','assassin','healer','commander','boss']):
   entry.setdefault('id',entry.get('type'));rows.append(entry)
 output[name]=rows
expected={'weapons':7,'abilities':4,'enemies':7,'upgrades':22,'items':11,'equipment':9,'skills':15}
for k,n in expected.items():assert len(output[k])==n,(k,len(output[k]),output[k])
(ROOT/'godot/data/catalogs.json').write_text(json.dumps(output,indent=2)+'\n')
print({k:len(v) for k,v in output.items()})
