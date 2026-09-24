class_name BWMeta
extends RefCounted

var path = "user://bloodwake_progression.json"
var essence = 0
var levels = {}
var owned: Array = []
var loadouts: Array = [{},{},{}]
var active = 0
var last_error = ""

func load_save():
 if FileAccess.file_exists(path): import_json(FileAccess.get_file_as_string(path))

func import_json(text: String) -> bool:
 var parser = JSON.new()
 if parser.parse(text) != OK: return false
 var parsed = parser.data
 if not parsed is Dictionary: return false
 essence = clampi(int(parsed.get("essence",0)),0,1000000000)
 levels.clear(); owned.clear(); loadouts = [{},{},{}]
 var saved_levels = parsed.get("levels",{})
 if saved_levels is Dictionary:
  for node in BWData.rows("skills"):
   levels[node.id] = clampi(int(saved_levels.get(node.id,0)),0,3)
 var saved_owned = parsed.get("ownedEquipment",[])
 if saved_owned is Array:
  for id in saved_owned:
   if id is String and not BWData.entry("equipment",id).is_empty() and not owned.has(id): owned.append(id)
 var saved_loadouts = parsed.get("loadouts",[])
 if saved_loadouts is Array:
  for i in mini(3,saved_loadouts.size()):
   if not saved_loadouts[i] is Dictionary: continue
   for slot in ["armor","boots","charm"]:
    var id = saved_loadouts[i].get(slot,"")
    if id is String and owned.has(id) and BWData.entry("equipment",id).slot == slot: loadouts[i][slot] = id
 active = clampi(int(parsed.get("activeLoadout",0)),0,2)
 return true

func serialized() -> String:
 return JSON.stringify({"version":1,"essence":essence,"levels":levels,"ownedEquipment":owned,"loadouts":loadouts,"activeLoadout":active},"  ")

func save() -> bool:
 var f = FileAccess.open(path+".tmp",FileAccess.WRITE)
 if f == null:
  last_error = "Unable to write progression: " + error_string(FileAccess.get_open_error());return false
 f.store_string(serialized()); f.flush(); f.close()
 var err = DirAccess.rename_absolute(path+".tmp",path)
 last_error = "" if err == OK else "Save failed: " + error_string(err)
 return err == OK

func can_buy_skill(node: Dictionary) -> bool:
 var level = int(levels.get(node.id,0))
 return level<3 and essence>=node.baseCost*(level+1) and (not node.has("requires") or levels.get(node.requires,0)>0)

func buy_skill(id: String) -> bool:
 var node = BWData.entry("skills",id)
 if node.is_empty() or not can_buy_skill(node):return false
 var level = int(levels.get(id,0));essence-=int(node.baseCost*(level+1));levels[id]=level+1;save();return true

func buy_equipment(id: String) -> bool:
 var item = BWData.entry("equipment",id)
 if item.is_empty() or owned.has(id) or essence<item.cost:return false
 essence-=int(item.cost);owned.append(id);save();return true

func equip(slot: String,id: String) -> bool:
 if not ["armor","boots","charm"].has(slot):return false
 if id.is_empty():loadouts[active].erase(slot)
 else:
  var item = BWData.entry("equipment",id)
  if not owned.has(id) or item.get("slot","")!=slot:return false
  loadouts[active][slot]=id
 save();return true

func apply_to(stats: Dictionary):
 for id in levels: BWData.apply_stats(stats,id,int(levels[id]))
 for id in loadouts[active].values():BWData.apply_stats(stats,id)

func award(wave: int,kills: int) -> int:
 var amount = clampi(wave*2+int(kills/5.0),2,100000)
 essence+=amount;save();return amount
