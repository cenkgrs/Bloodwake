extends SceneTree
func _initialize():call_deferred("run_probe")
func run_probe():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("mage");await process_frame
	var w=scene.world;w.running=false;w.auto_fire=false
	for e in w.enemies:e.node.queue_free()
	w.enemies.clear()
	var elapsed=0.0;var fire=0.0;var blast=0.0;var serial=0
	var frames=[];var last=Time.get_ticks_usec();var peak_bullets=0;var peak_fx=0
	while elapsed<12.0:
		await process_frame
		var now=Time.get_ticks_usec();var dt=(now-last)/1000000.0;last=now;elapsed+=dt
		if elapsed>2.0:frames.append(dt*1000.0)
		fire-=dt;blast-=dt
		if fire<=0:
			fire+=1.0/12.0;serial+=1
			var direction=Vector3.RIGHT.rotated(Vector3.UP,serial*0.51)
			var friendly=serial%2==0
			w._bullet(direction*2.0,direction,5,0,8,friendly,0,"magic_orb" if friendly else "enemy_magic_orb",0,0,false)
		if blast<=0:
			blast+=0.75
			w.fx.arcane_blast(Vector3.ZERO,2.7,Color("19cbff") if serial%2==0 else Color("df45bc"),Color("234aff"))
		w._projectiles(dt)
		peak_bullets=maxi(peak_bullets,w.bullets.size());peak_fx=maxi(peak_fx,w.fx.get_child_count())
	frames.sort();var total=0.0;var stalls=0
	for value in frames:
		total+=value
		if value>80:stalls+=1
	print("VFX_STRESS frames=",frames.size()," mean_ms=",total/frames.size()," p99_ms=",frames[int(frames.size()*0.99)]," max_ms=",frames[-1]," over_80ms=",stalls," peak_bullets=",peak_bullets," peak_fx_nodes=",peak_fx)
	scene.queue_free();await process_frame;quit()
