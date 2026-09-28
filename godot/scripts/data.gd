class_name BWData
extends RefCounted

# Distances and speeds in legacy catalogs use pixels. 50 px = one metre.
const UNIT = 0.02
const CLASSES = {
	"warrior": {"name":"Warrior", "tag":"MELEE / DURABLE", "weapon":"sword", "ability":"war_cry", "color":"d56558", "stats":{"damage":3, "maxHp":130.0,"moveSpeed":200.0,"armor":0.2}, "skills":["sunder_leap","shield_thrust"]},
	"gunslinger": {"name":"Bloodbound", "tag":"RANGED / RELENTLESS", "weapon":"rapid_rifle", "ability":"fan_shot", "color":"d7ae64", "stats":{"maxHp":90.0,"moveSpeed":250.0,"attackSpeed":0.85}},
	"mage": {"name":"Mage", "tag":"ARCANE / AREA CONTROL", "weapon":"magic_orb", "ability":"frost_nova", "skills":["arcane_meteor","void_leap"], "color":"9b83de", "stats":{"maxHp":85.0,"moveSpeed":215.0,"damage":1.5}},
	"assassin": {"name":"Assassin", "tag":"MOBILE / CRITICAL", "weapon":"daggers", "ability":"shadow_strike", "color":"63bd9f", "stats":{"maxHp":80.0,"moveSpeed":350.0,"criticalChance":0.8,"criticalDamage":2.8,"dodgeChance":0.3}, "skills":["phantom_volley"]}
}
static var catalogs: Dictionary = {}

static func load_catalogs():
	if catalogs.is_empty():
		catalogs = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalogs.json"))
	return catalogs

static func rows(kind: String) -> Array:
	return load_catalogs().get(kind, [])

static func entry(kind: String, id: String) -> Dictionary:
	for row in rows(kind):
		if row.id == id: return row.duplicate(true)
	return {}

static func skills(id: String) -> Array:
	return CLASSES[id].get("skills",[])

static func stats(id: String) -> Dictionary:
	var result = {"maxHp":100.0,"hp":100.0,"moveSpeed":220.0,"damage":1.0,"attackSpeed":1.0,"attackRange":1.0,"criticalChance":0.05,"criticalDamage":1.5,"armor":0.0,"dodgeChance":0.0,"lifesteal":0.0,"xpMultiplier":1.0,"pickupRadius":80.0,"regenPerSecond":0.0,"bonusGoldPerKill":0,"hasSecondWind":false}
	result.merge(CLASSES[id].stats, true)
	result.hp = result.maxHp
	return result

static func wave_rules(wave: int) -> Dictionary:
	return {"boss":wave % 10 == 0, "quota":1 if wave % 10 == 0 else 6+wave*4, "cap":clampi(5+wave,5,20), "interval":clampf(1.2-wave*0.04,0.35,1.2), "elite":clampf(0.03*(wave-1),0,0.35), "multiplier":1+(wave-1)*0.08}

static func effects(id: String) -> Array:
	var table = {
	"sharpened":[["damage",0.10]],"rapid_fire_stat":[["attackSpeed",0.12]],"vitality":[["maxHp",20],["hp",20]],"predator":[["criticalChance",0.05]],"vampirism":[["lifesteal",0.02]],"swift":[["moveSpeed",1.08,"mul"]],
	"platinum_armor":[["armor",0.10],["maxHp",20],["hp",20]],"swift_boots":[["moveSpeed",1.15,"mul"],["dodgeChance",0.10]],"hunters_scope":[["attackRange",0.20],["criticalChance",0.05]],"vampiric_amulet":[["lifesteal",0.03],["regenPerSecond",2]],"lucky_charm":[["bonusGoldPerKill",3],["xpMultiplier",0.20]],"guardian_angel":[["hasSecondWind",true,"set"]],
	"bloodplate":[["maxHp",22],["hp",22],["armor",0.04]],"shadow_cloak":[["moveSpeed",18],["dodgeChance",0.04]],"storm_robe":[["damage",0.07],["attackRange",0.07]],"iron_greaves":[["armor",0.03],["maxHp",10],["hp",10]],"hunter_boots":[["moveSpeed",22],["pickupRadius",25]],"arcane_steps":[["moveSpeed",12],["attackSpeed",0.06]],"ember_sigil":[["damage",0.10]],"leech_pendant":[["lifesteal",0.025]],"scholar_rune":[["xpMultiplier",0.12]],
	"might":[["damage",0.02]],"precision":[["criticalChance",0.01]],"fury":[["attackSpeed",0.02]],"execution":[["criticalDamage",0.03]],"reach":[["attackRange",0.02]],"vigor":[["maxHp",4],["hp",4]],"plate":[["armor",0.005]],"renewal":[["regenPerSecond",0.15]],"drain":[["lifesteal",0.003]],"stride":[["moveSpeed",3]],"reflex":[["dodgeChance",0.005]],"magnet":[["pickupRadius",5]],"insight":[["xpMultiplier",0.02]],"scavenger":[["bonusGoldPerKill",1]]}
	return table.get(id, [])

static func apply_stats(stats_block: Dictionary, id: String, level: int = 1):
	for effect in effects(id):
		var mode = effect[2] if effect.size()>2 else "add"
		match mode:
			"mul": stats_block[effect[0]] *= pow(effect[1],level)
			"set": stats_block[effect[0]] = effect[1]
			_: stats_block[effect[0]] += effect[1]*level
	if id == "last_stand" and level >= 3: stats_block.hasSecondWind = true
