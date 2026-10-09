extends SceneTree
var failures=0
var checks=0
func check(condition: bool,message: String):
	checks+=1
	if not condition:failures+=1;push_error(message)
func _initialize():
	call_deferred("suite")
func suite():
	BWData.load_catalogs()
	for pair in [["weapons",7],["abilities",15],["enemies",8],["upgrades",22],["items",14],["equipment",9],["skills",15]]:check(BWData.rows(pair[0]).size()==pair[1],"catalog count: "+pair[0])
	# Only the mage carries extra skills; every ability a class references must exist.
	for id in BWData.CLASSES:
		check(BWData.skills(id).size()==2,"class skill count: "+id)
		for ability in [BWData.CLASSES[id].ability]+BWData.skills(id):
			check(not BWData.entry("abilities",ability).is_empty(),"ability exists: "+ability)
	for id in ["arcane_meteor","void_leap"]:
		var row=BWData.entry("abilities",id)
		check(row.cooldown>0 and row.damage>0 and row.get("blastRadius",0)>0,"mage skill is fully specified: "+id)
	var mage=BWRun.new("mage")
	check(mage.skill_cd.size()==2 and mage.skill_ready("arcane_meteor") and mage.skill_ready("void_leap"),"mage skills start ready")
	mage.skill_cd.arcane_meteor=4.0
	check(not mage.skill_ready("arcane_meteor") and mage.skill_ready("void_leap"),"skill cooldowns are independent")
	mage.tick_skills(4.0);check(mage.skill_ready("arcane_meteor"),"skill cooldown drains")
	# the warrior carries two skills now, so the gunslinger is the class with none
	# every class now fields two skills alongside its ultimate
	for id in BWData.CLASSES:check(BWRun.new(id).skill_cd.size()==2,"cooldown tracked per skill: "+id)
	for wave in [1,9,10,20,100,999]:
		var rules=BWData.wave_rules(wave)
		check(rules.boss==(wave%10==0),"boss formula")
		check(rules.quota==(1 if wave%10==0 else 5),"quota")
		check(rules.cap<=12 and rules.interval>=0.45,"spawn bounds")
	var allowed={"revenant":["greatsword","storm_blade","shockwave"],"warrior":["greatsword","storm_blade","shockwave"],"gunslinger":["rifle_tempo","rifle_caliber","rifle_range"],"mage":["orb_pierce","orb_power","orb_range"],"assassin":["dagger_tempo","dagger_reach","dagger_edge"]}
	for id in BWData.CLASSES:
		var state=BWRun.new(id)
		for row in BWData.rows("upgrades"):
			if row.get("isAvailable","") in ["_warrior","_gunslinger","_mage","_assassin"]:check(state.available(row,"upgrades")==allowed[id].has(row.id),"class gate "+id+" "+row.id)
	var rifle=BWRun.new("gunslinger")
	check(not rifle.apply_upgrade("armor_piercer"),"synergy locked")
	rifle.apply_upgrade("rifle_caliber");rifle.apply_upgrade("rifle_range")
	check(rifle.apply_upgrade("armor_piercer") and rifle.weapons.rapid_rifle.pierce==2,"synergy applies")
	check(not rifle.apply_upgrade("armor_piercer"),"max level gate")
	rifle.gold=100;check(rifle.buy_item("rifle_mechanism"),"shop buys owned weapon effect")
	var gold=rifle.gold;check(not rifle.buy_item("rifle_mechanism") and rifle.gold==gold,"duplicate purchase cannot charge")
	check(not rifle.buy_item("gold_sword"),"wrong weapon item blocked")
	rifle.add_xp(100);check(rifle.level==2 and rifle.pending_levels==1 and rifle.xp==20,"one level with XP carry")
	rifle.stats.hasSecondWind=true;rifle.hurt(10000);check(rifle.stats.hp==1 and not rifle.stats.hasSecondWind,"second wind")
	rifle.hurt(10000);check(rifle.stats.hp==0,"second wind consumed")
	var meta=BWMeta.new();meta.path="user://test_progression.json";meta.essence=100
	check(not meta.buy_skill("execution"),"skill prerequisite")
	check(meta.buy_skill("might") and meta.buy_skill("precision"),"skill unlocks")
	check(meta.buy_equipment("bloodplate") and meta.equip("armor","bloodplate"),"equipment equip")
	check(not meta.equip("boots","bloodplate"),"slot validation")
	meta.active=2;meta.equip("armor","bloodplate");meta.save()
	var loaded=BWMeta.new();loaded.path=meta.path;loaded.load_save()
	check(loaded.active==2 and loaded.essence==meta.essence and loaded.loadouts[2].armor=="bloodplate","save roundtrip")
	var stats=BWData.stats("warrior");loaded.apply_to(stats);check(stats.maxHp==152 and is_equal_approx(stats.damage,3.02),"permanent stats applied")
	check(not loaded.import_json("not json"),"corrupt save rejected")
	check(loaded.import_json('{"essence":-1,"levels":{"might":999},"ownedEquipment":["fake"],"activeLoadout":9}'),"legacy JSON parsed")
	check(loaded.essence==0 and loaded.levels.might==3 and loaded.owned.is_empty() and loaded.active==2,"save validation")
	DirAccess.remove_absolute(meta.path)
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	await process_frame
	for method in ["show_classes","show_skills","show_armory","show_builds","show_settings","show_menu"]:
		scene.call(method);await process_frame
	check(scene.page=="menu","all menu pages mount")
	for id in BWData.CLASSES:
		scene.start_run(id);await process_frame
		check(scene.world.visual!=null,"class visual "+id)
		if id=="revenant":
			check(scene.world.visual.clips.get("idle","")=="REV_AssassinIdle","Revenant uses Assassin idle retarget")
			check(scene.world.visual.clips.get("run","")=="REV_AssassinRun","Revenant uses Assassin run retarget")
			var revenant_run=scene.world.visual.animation.get_animation("REV_AssassinRun")
			check(revenant_run.loop_mode==Animation.LOOP_LINEAR,"Revenant Assassin run remains looped through walk alias")
			var grounded_pelvis=true
			for track in revenant_run.get_track_count():
				if revenant_run.track_get_type(track)!=Animation.TYPE_POSITION_3D:continue
				if String(revenant_run.track_get_path(track)).get_slice(":",1)!="pelvis":continue
				for key in revenant_run.track_get_key_count(track):
					if (revenant_run.track_get_key_value(track,key) as Vector3).y>1.0:grounded_pelvis=false
			check(grounded_pelvis,"Revenant Assassin run keeps target pelvis grounded")
			scene.world.visual.tick(0.0,true,1.0)
			check(is_equal_approx(scene.world.visual.animation.speed_scale,BWVisual.REVENANT_LOCOMOTION_RATE),"Revenant locomotion cadence is slowed independently of travel speed")
		if id=="gunslinger":
			for clip in ["idle","run","attack","hit","death","bombthrow","ultimate"]:check(scene.world.visual.clips.has(clip),"Bloodhound clip "+clip)
		if id=="warrior":
			var visual=scene.world.visual
			# The rig gained the melee chain and the spin after this suite was written,
			# so an exact clip count just goes stale on the next animation added. What
			# matters is that every clip the combat code reaches for is actually there.
			for required in ["idle","run","attack","hit","death","ultimate","attack1","attack2","attack3","attack4","spinattack"]:
				check(visual.clips.has(required),"Warrior clip present: "+required)
			check(visual.model.position.is_equal_approx(Vector3.ZERO),"Warrior rig stays centered on actor")
			check(visual.model.scale.is_equal_approx(Vector3.ONE*(2.05/1.8)),"Warrior rig (authored at 1.8 m) is scaled to the player's 2.05 m presence height")
			check(visual.model.find_child("Greatsword",true,false)!=null,"Warrior carries supplied greatsword")
			for clip in ["idle","run","attack","hit","death","ultimate"]:
				check(visual.clips.has(clip),"Warrior clip "+clip)
				if visual.clips.has(clip):
					var anim=visual.animation.get_animation(visual.clips[clip])
					check(anim.length>0 and anim.get_track_count()>0,"Warrior skeletal animation "+clip)
					check((anim.loop_mode==Animation.LOOP_LINEAR)==(clip in ["idle","run"]),"Warrior loop mode "+clip)
		scene.world.running=false
		for row in BWData.rows("enemies"):
			var enemy=scene.world.spawn_enemy(row.id,Vector3(4,0,0))
			scene.world._enemy_tick(enemy,0.1)
			scene.world._damage_enemy(enemy,100000)
		check(scene.run.kills==BWData.rows("enemies").size(),"every enemy type resolves a death "+id)
		scene.run.pending_levels=1;scene._intermission();check(scene.page=="upgrades","intermission offers levels")
		scene.run.pending_levels=0;scene.boss_reward=false;scene._next_pick();check(scene.page=="shop","shop follows rewards")
		scene.world.next_wave();check(scene.run.wave==2 and scene.world.rest_time==4,"wave rest starts")
		scene.show_menu();await process_frame
	scene.queue_free();await process_frame
	await create_timer(3.0).timeout
	print("BLOODWAKE_TESTS ",checks," checks / ",failures," failures")
	quit(1 if failures>0 else 0)
