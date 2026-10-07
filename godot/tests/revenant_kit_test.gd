extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func dummy(w,pos: Vector3):
	var e=w.spawn_enemy("tank",pos);e.hp=1000.0;e.maxHp=1000.0;e.cooldown=999
	return e
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("revenant");await process_frame
	var w=scene.world;w.running=true;w.auto_fire=false;w.rest_time=999;w.set_physics_process(false)
	w.run.stats.criticalChance=0;w.run.stats.dodgeChance=0;w.run.stats.regenPerSecond=0
	w.arena.blockers.clear();w.player.position=Vector3.ZERO;w.touch_aim=Vector2.RIGHT
	w.aim=w.screen_direction(w.touch_aim).normalized()
	var data=BWData.entry("abilities","blood_step")
	var reach=data.range*w.run.stats.attackRange*BWData.UNIT
	var destination=w.ground_target(reach)
	var target=dummy(w,destination)
	var departure=dummy(w,Vector3.ZERO)
	w.skill(0)
	check(w.visual.state=="teleport" and w.skills.cast_active,"Q plays its own clip and owns the cast")
	check(w.run.skill_cd.blood_step==data.cooldown,"Q spends only its own cooldown")
	check(target.hp==1000,"Q does not deal damage before arrival")
	var hp=w.run.stats.hp;w._hurt_player(10);check(w.run.stats.hp==hp,"Teleport transition evades damage")
	w.ability();check(w.run.ability_cd==0,"Cannot overlap ultimate with teleport")
	# Markers: hide 16, move 20, show 22, damage 26, recover 35 (60 fps).
	await create_timer(BWVisual.revenant_time("teleport","hide")+.03).timeout
	check(not w.visual.visible,"Body vanishes during transit")
	check(w.player.position.distance_to(Vector3.ZERO)<.01,"Teleport does not slide along the path")
	await create_timer(BWVisual.revenant_time("teleport","show")-BWVisual.revenant_time("teleport","hide")).timeout
	check(w.visual.visible and w.player.position.distance_to(destination)<.01,"Body reappears at the aimed point")
	check(target.hp==1000 and w.airborne,"Rematerialising precedes the claw strike")
	await create_timer(BWVisual.revenant_time("teleport","damage")-BWVisual.revenant_time("teleport","show")).timeout
	check(is_equal_approx(target.hp,1000-data.damage*w.run.stats.damage),"Arrival damages the target exactly once")
	check(departure.hp==1000,"Departure does not duplicate arrival damage")
	check(not w.airborne,"Damage immunity ends at contact")
	await create_timer(BWVisual.revenant_time("teleport","recover")-BWVisual.revenant_time("teleport","damage")).timeout
	check(not w.skills.cast_active,"Q releases movement/weapon lock")
	var after=target.hp;w.skill(0);await create_timer(.1).timeout
	check(target.hp==after,"Cooldown rejects an immediate recast")
	# A blocked endpoint backs off into free ground, still within cast range.
	w.player.position=Vector3.ZERO
	w.arena.blockers=[{"pos":Vector3(6,0,0),"radius":.7}]
	var safe=w.skills.blood_step_destination(Vector3(50,0,0),6)
	check(safe.length()<=6.001 and safe.distance_to(Vector3(6,0,0))>=1.13,"Teleport cannot land inside a blocker or beyond range")
	w.arena.blockers.clear()
	for e in w.enemies.duplicate():w.enemies.erase(e);e.node.queue_free()
	var burst=BWData.entry("abilities","blood_burst")
	var inside=dummy(w,Vector3(1,0,0));var behind=dummy(w,Vector3(0,0,-2));var outside=dummy(w,Vector3(8,0,0))
	w.ability()
	check(w.visual.state=="ultimate" and w.run.ability_cd==burst.cooldown,"Blood Burst has its own clip and cooldown")
	await create_timer(BWVisual.revenant_time("ultimate","damage")-.25).timeout
	check(inside.hp==1000,"Burst waits for its charge")
	w._weapons(0);check(w.pending_attacks.is_empty(),"Ordinary attacks cannot interrupt charge")
	await create_timer(.3).timeout
	check(is_equal_approx(inside.hp,1000-burst.damage*w.run.stats.damage),"Burst deals one area hit")
	check(behind.hp<1000 and outside.hp==1000,"Burst is radial and respects its radius")
	await create_timer(BWVisual.revenant_time("ultimate","dissipate")-BWVisual.revenant_time("ultimate","damage")).timeout
	check(not w.skills.cast_active,"Ultimate releases its lock")
	# Cancelling by death must not leave a delayed ghost explosion.
	w.run.ability_cd=0;var before=inside.hp;w.ability();w.run.stats.hp=0;w.running=false
	await create_timer(.65).timeout
	check(inside.hp==before and not w.skills.cast_active and w.visual.visible,"Death cancels delayed burst and restores visibility")
	# A cancelled invisible transit cannot strand the model or fire its old
	# arrival callback if a run becomes active again before recovery finishes.
	w.run.stats.hp=w.run.stats.maxHp;w.running=true;w.run.skill_cd.blood_step=0
	w.player.position=Vector3.ZERO;w.skill(0)
	await create_timer(.18).timeout
	w.running=false
	await create_timer(.10).timeout
	check(not w.skills.cast_active and not w.airborne and w.visual.visible,"Cancelled transit restores body and vulnerability")
	w.running=true;var cancelled_origin=w.player.position
	await create_timer(.4).timeout
	check(w.player.position==cancelled_origin,"Cancelled transit never resumes its old teleport")
	# The claw cut reaches as far as its marks are drawn, across their fan.
	for e in w.enemies.duplicate():e.node.queue_free()
	w.enemies.clear();w.player.position=Vector3.ZERO;w.combo_step=0;w.running=false
	var blade=w.run.weapons[BWData.CLASSES.revenant.weapon]
	var base_reach=blade.data.range*w.run.stats.attackRange*blade.range*BWData.UNIT
	var forward=Vector3(1,0,0)
	var marked=dummy(w,forward*base_reach*1.6)
	var flank=dummy(w,forward.rotated(Vector3.UP,deg_to_rad(58))*base_reach*1.5)
	var beyond=dummy(w,forward*base_reach*2.6)
	var rear=dummy(w,-forward*base_reach*1.5)
	w._resolve_weapon(BWData.CLASSES.revenant.weapon,forward)
	check(marked.hp<1000,"A body under the claw marks is cut")
	check(flank.hp<1000,"The cut covers the claws' fan, not a narrow blade arc")
	check(beyond.hp==1000,"Nothing past the marks is cut")
	check(rear.hp==1000,"Nothing behind the swing is cut")
	# Every body under the marks is cut, however many there are.
	for e in w.enemies.duplicate():e.node.queue_free()
	w.enemies.clear();w.player.position=Vector3.ZERO;w.combo_step=0
	var pack=[]
	for angle in [-50,-25,0,25,50]:
		for d in [0.9,1.6]:pack.append(dummy(w,forward.rotated(Vector3.UP,deg_to_rad(angle))*base_reach*d))
	w._resolve_weapon(BWData.CLASSES.revenant.weapon,forward)
	check(pack.all(func(e):return e.hp<1000),"The claws cut every body they cross: "+str(pack.filter(func(e):return e.hp<1000).size())+"/"+str(pack.size()))
	w.visual.action("death");w.visual._process(2.6)
	check(not w.visual.death_materials.is_empty(),"Death installs the blood dissolve on the body")
	check(w.visual.death_materials[0].get_shader_parameter("progress")==1.0,"Death fully dissolves the body")
	scene.queue_free();await process_frame
	print("REVENANT_KIT_TEST failures=",failures);quit(1 if failures else 0)
