extends SceneTree
func _initialize():
	var target=ProjectSettings.globalize_path("res://../unity/Assets/Bloodwake/Resources/Data")
	DirAccess.make_dir_recursive_absolute(target)
	var effects={}
	for kind in ["upgrades","items","equipment","skills"]:
		for row in BWData.rows(kind):effects[row.id]=BWData.effects(row.id)
	var data={"classes":BWData.CLASSES,"effects":effects,"defaults":BWData.stats("warrior"),"audio":BWAudio.BANK,"boss":BWBoss.ATTACKS}
	data.defaults={"maxHp":100.0,"hp":100.0,"moveSpeed":220.0,"damage":1.0,"attackSpeed":1.0,"attackRange":1.0,"criticalChance":0.05,"criticalDamage":1.5,"armor":0.0,"dodgeChance":0.0,"lifesteal":0.0,"xpMultiplier":1.0,"pickupRadius":80.0,"regenPerSecond":0.0,"bonusGoldPerKill":0,"hasSecondWind":false}
	var file=FileAccess.open(target+"/rules.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"  "));file.close()
	for name in ["catalogs","maps","rooms","room_kit"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path("res://data/"+name+".json"),target+"/"+name+".json")
	print("UNITY_DATA_EXPORTED");quit()
