class_name BWRun
extends RefCounted

var class_id = "gunslinger"
var stats: Dictionary
var weapons: Dictionary = {}
var upgrades: Dictionary = {}
var items: Array = []
var wave = 1
var kills = 0
var gold = 0
var level = 1
var xp = 0
var pending_levels = 0
var ability_cd = 0.0
var awarded = false

func _init(id: String = "gunslinger",meta = null):
	class_id=id;stats=BWData.stats(id)
	if meta!=null:meta.apply_to(stats)
	add_weapon(BWData.CLASSES[id].weapon)

func add_weapon(id: String) -> bool:
	if weapons.has(id) or weapons.size()>=4:return false
	var data=BWData.entry("weapons",id)
	if data.is_empty():return false
	weapons[id]={"data":data,"cooldown":0.0,"damage":1.0,"speed":1.0,"range":1.0,"pierce":0,"chain":0,"shockwave":0.0,"burn":0.0,"bleed":0.0,"swings":0}
	return true

func add_xp(amount: int):
	xp+=int(round(amount*stats.xpMultiplier))
	while xp>=20+(level-1)*15:
		xp-=20+(level-1)*15;level+=1;pending_levels+=1

func available(row: Dictionary,kind: String) -> bool:
	if kind=="upgrades" and upgrades.get(row.id,0)>=row.maxLevel:return false
	if kind=="items" and (items.has(row.id) or items.size()>=8):return false
	var gate=row.get("isAvailable","")
	var classes={"_warrior":"warrior","_gunslinger":"gunslinger","_mage":"mage","_assassin":"assassin"}
	if classes.has(gate):return class_id==classes[gate]
	var weapon_gates={"_ownsSword":"sword","_ownsLightning":"lightning","_ownsRifle":"rapid_rifle","_ownsOrb":"magic_orb","_ownsDaggers":"daggers"}
	if weapon_gates.has(gate):return weapons.has(weapon_gates[gate])
	var prerequisites={"thunderquake":["warrior","greatsword","storm_blade"],"armor_piercer":["gunslinger","rifle_caliber","rifle_range"],"spellfire":["mage","orb_pierce","orb_power"],"hemorrhage":["assassin","dagger_tempo","dagger_edge"]}
	if prerequisites.has(row.id):
		var req=prerequisites[row.id]
		return class_id==req[0] and upgrades.get(req[1],0)>0 and upgrades.get(req[2],0)>0
	return true

func offers(kind: String,boss: bool=false) -> Array:
	var choices=[]
	for row in BWData.rows(kind):
		if available(row,kind) and (not boss or row.get("rarity","")!="common"):choices.append(row)
	choices.shuffle();return choices.slice(0,3)

func apply_upgrade(id: String) -> bool:
	var row=BWData.entry("upgrades",id)
	if row.is_empty() or not available(row,"upgrades"):return false
	upgrades[id]=int(upgrades.get(id,0))+1;apply_effect(id);return true

func buy_item(id: String) -> bool:
	var item=BWData.entry("items",id)
	if item.is_empty() or not available(item,"items") or gold<item.cost:return false
	gold-=int(item.cost);items.append(id);apply_effect(id);return true

func apply_effect(id: String):
	BWData.apply_stats(stats,id)
	var effects={
	"greatsword":["sword","range",0.25],"storm_blade":["sword","chain",1],"shockwave":["sword","shockwave",35],"rifle_tempo":["rapid_rifle","speed",0.18],"rifle_caliber":["rapid_rifle","damage",0.20],"rifle_range":["rapid_rifle","range",0.15],"orb_pierce":["magic_orb","pierce",1],"orb_power":["magic_orb","damage",0.25],"orb_range":["magic_orb","range",0.2],"dagger_tempo":["daggers","speed",0.18],"dagger_reach":["daggers","range",0.2],"dagger_edge":["daggers","damage",0.2],"armor_piercer":["rapid_rifle","pierce",2],"spellfire":["magic_orb","burn",7.0],"hemorrhage":["daggers","bleed",9.0],"rifle_mechanism":["rapid_rifle","speed",0.25],"orb_focus":["magic_orb","damage",0.30],"dagger_steel":["daggers","damage",0.30]}
	if effects.has(id):
		var e=effects[id]
		if weapons.has(e[0]):weapons[e[0]][e[1]]+=e[2]
	if id=="thunderquake" and weapons.has("sword"):
		weapons.sword.chain+=1;weapons.sword.shockwave+=60
	if id=="gold_sword" and weapons.has("sword"):weapons.sword.damage*=1.3
	if id=="thunder_core" and weapons.has("lightning"):weapons.lightning.damage*=1.25

func hurt(damage: float,roll: float=1.0) -> float:
	if stats.hp<=0 or roll<stats.dodgeChance:return 0.0
	var amount=damage*clampf(1-stats.armor,0,1)
	stats.hp=maxf(0,stats.hp-amount)
	if stats.hp<=0 and stats.hasSecondWind:stats.hasSecondWind=false;stats.hp=1
	return amount

func damage_roll(base: float) -> Dictionary:
	var critical=randf()<stats.criticalChance
	return {"damage":base*(stats.criticalDamage if critical else 1),"critical":critical}
