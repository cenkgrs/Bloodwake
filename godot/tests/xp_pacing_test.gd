extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():
	BWData.load_catalogs()
	var run=BWRun.new("warrior")
	for wave in range(1,31):
		run.wave=wave;var before=run.level
		for i in 100:run.add_xp(1000)
		check(run.level==before+1,"exactly one level even with excess XP in wave "+str(wave))
		check(run.xp<=run.xp_needed()/2,"overflow is bounded")
	check(run.pending_levels==30,"thirty waves cannot produce more than thirty XP picks")
	var baseline=BWRun.new("warrior");var bonus=BWRun.new("warrior");bonus.stats.xpMultiplier=1.5
	baseline.add_xp(60);bonus.add_xp(60)
	check(baseline.level==1 and bonus.level==2,"XP bonuses still earn the wave level sooner")
	# The opening wave has to be worth its level off the bodies it actually fields, so
	# this reads the quota and the reward rather than restating either of them.
	var full_wave=BWRun.new("warrior")
	var grunt_xp=int(BWData.entry("enemies","grunt").xpReward)
	for i in BWData.wave_rules(1).quota:full_wave.add_xp(grunt_xp)
	check(full_wave.level==2,"opening wave awards one level")
	var carried=full_wave.xp;full_wave.wave=2
	check(full_wave.xp==carried,"wave transition preserves saved XP")
	full_wave.add_xp(full_wave.xp_needed())
	check(full_wave.level==3,"next wave unlocks its own level")
	print("XP_PACING_TEST failures=",failures);quit(failures)
