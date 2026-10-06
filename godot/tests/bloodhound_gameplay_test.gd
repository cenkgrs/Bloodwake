extends SceneTree

var failures=0
var checks=0
var events=[]
var elapsed=0.0
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("suite")
func reset(world):
	world.pending_attacks.clear();world.visual.lock_time=0;world.visual.state="idle"
	for bullet in world.bullets:bullet.node.queue_free()
	world.bullets.clear();events.clear();elapsed=0
func advance(world,seconds: float):
	var steps=roundi(seconds*600)
	for i in steps:
		elapsed+=1.0/600
		world._pending_attacks(1.0/600)

func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.meta=BWMeta.new();scene.meta.path="user://bloodhound_test_progression.json"
	scene.start_run("gunslinger");await process_frame
	var w=scene.world;var run=scene.run
	w.set_physics_process(false);w.running=true;w.rest_time=999;w.auto_fire=true
	w.bloodhound_event.connect(func(label):events.append({"label":label,"time":elapsed}))
	w.spawn_enemy("tank",w.player.position+Vector3(0,0,3))
	w.visual.lock_time=0;run.weapons.rapid_rifle.cooldown=0
	w._weapons(0)
	check(w.visual.state=="attack","Primary starts FiveShot in real world")
	check(is_equal_approx(w.visual.lock_time,41.0/60),"FiveShot keeps authored frame 1–42 duration")
	check(w.pending_attacks.size()==5,"Exactly five queued trigger events")
	check(w.bullets.is_empty(),"No projectile during anticipation")
	advance(w,0.145);check(events.is_empty(),"No shot before frame 10")
	advance(w,0.30)
	check(events.size()==5,"All five events actually resolve")
	check(w.bullets.size()==6,"Final event fires both barrels")
	for index in mini(events.size(),5):
		check(events[index].label=="FIRE_%02d"%(index+1),"Ordered trigger "+str(index))
		check(absf(events[index].time-float([10,14,18,22,26][index]-1)/60)<0.002,"Frame-accurate trigger "+str(index))
	# Autofire must not pin the player forever; lower body walks under the shot.
	var start=w.player.position
	w.move_input=Vector2(0.4,0);w.visual.lock_time=0.4;w.visual.state="attack"
	w._physics_process(1.0/60)
	check(w.player.position.distance_to(start)>0.01,"Player can move during FiveShot")
	check(w.visual.bloodhound_stride.speed>0.1,"Moving attack drives lower-body overlay")
	w.move_input=Vector2.ZERO
	reset(w);w.auto_fire=false
	w.skills._cast_powder_charge(BWData.entry("abilities","powder_charge"),w.player.position+Vector3(0,0,3))
	check(w.visual.state=="bombthrow","Powder charge selects throw, not generic attack")
	advance(w,0.315);check(events.is_empty(),"Grenade held until frame 20")
	advance(w,0.005);check(events.size()==1 and events[0].label=="THROW_RELEASE","Grenade released at frame 20")
	check(not w.visual.action("attack"),"Autofire cannot steal grenade recovery")
	reset(w);run.ability_cd=0;w.ability()
	check(w.visual.state=="ultimate","Ability starts 108-frame ultimate")
	check(w.bullets.is_empty(),"No ultimate damage during charge")
	check(w.pending_attacks.size()==9,"Nine radial salvo events scheduled")
	var dirs=[]
	for event in w.pending_attacks:dirs.append(event.direction)
	for index in dirs.size():
		var next=dirs[(index+1)%dirs.size()]
		check(dirs[index].angle_to(next)<deg_to_rad(43),"No missing radial sector "+str(index))
	advance(w,1.31)
	check(events.size()==9 and w.bullets.size()==9,"Nine salvo events produce nine real bullets")
	check(absf(events[0].time-29.0/60)<0.002,"First salvo waits for frame 30")
	reset(w);run.ability_cd=0;w.ability();run.stats.hp=0
	advance(w,1.4);check(events.is_empty() and w.bullets.is_empty(),"Death cancels delayed damage")
	scene.queue_free();await process_frame
	print("BLOODHOUND_GAMEPLAY_TEST checks=",checks," failures=",failures)
	quit(1 if failures else 0)
