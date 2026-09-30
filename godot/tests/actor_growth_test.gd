extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var w=scene.world;w.running=false
	var enemy=w.spawn_enemy("grunt",Vector3(7,0,0));enemy.cooldown=1000
	check(is_equal_approx(enemy.visual.base_scale.x,2.15/1.8),"enemy warrior starts at 2.15 m instead of 1.7 m")
	var original_enemy=enemy.visual.model.scale.x;var original_player=w.visual.model.scale.x
	w.run.level=11;w.running=true;w.rest_time=1000;w._physics_process(0.01);w.running=false
	check(is_equal_approx(enemy.visual.model.scale.x/original_enemy,1.25),"existing enemy grows with level")
	check(is_equal_approx(w.visual.model.scale.x/original_player,1.25),"player shares level growth")
	var new_enemy=w.spawn_enemy("grunt",Vector3(8,0,0))
	check(new_enemy.visual.model.scale.is_equal_approx(enemy.visual.model.scale),"later spawns match existing bodies")
	var elite=w.spawn_enemy("grunt",Vector3(9,0,0),true)
	check(elite.visual.model.scale.x>new_enemy.visual.model.scale.x,"elite remains larger than enlarged warrior")
	check(BWData.actor_growth(100)==1.5,"growth has a visual readability cap")
	scene.queue_free();await process_frame
	print("ACTOR_GROWTH_TEST failures=",failures);quit(failures)
