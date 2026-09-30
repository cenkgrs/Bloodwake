extends SceneTree
func _initialize():call_deferred("suite")
func suite():
	BWData.load_catalogs();BWVisual.warm_enemy_models()
	var scene=BWVisual.model_scene("enemy_warrior")
	var id=scene.get_instance_id()
	var actor=BWVisual.new();root.add_child(actor);actor.configure("grunt",true)
	actor.queue_free();await process_frame
	scene=null
	var failures=0
	if BWVisual.model_scene("enemy_warrior").get_instance_id()!=id:failures+=1
	var start=Time.get_ticks_usec()
	for i in 100:BWVisual.model_scene("enemy_warrior")
	print("MODEL_CACHE_TEST failures=",failures," cached_lookups_ms=",(Time.get_ticks_usec()-start)/1000.0)
	quit(failures)
