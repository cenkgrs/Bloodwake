extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	for id in ["grunt","healer","assassin","archer","tank","commander","boss"]:
		var file="warrior" if id=="grunt" else id
		if not ResourceLoader.exists("res://assets/models/enemy_%s.glb" % file):continue
		var visual=BWVisual.new();root.add_child(visual);visual.configure(id,true,Color.WHITE,1.7)
		check(visual.enemy_asset,"dedicated enemy asset: "+id)
		check(not visual.procedural,"rigged model: "+id)
		check(visual._find_skeleton(visual.model).get_bone_count()>=60,"Mixamo skeleton: "+id)
		for clip in ["idle","run","attack","hit","death"]:
			check(visual.clips.has(clip),"missing clip %s: %s" % [clip,id])
		if id=="assassin":
			for hand in ["RightHand","LeftHand"]:
				check(visual.model.find_child("Equipment_"+hand,true,false)!=null,"Assassin dagger attached to "+hand)
		visual.action("attack")
		check(visual.lock_time<=0.5,"attack recovery exceeds half a second: "+id)
		visual.tick(0.6,true)
		check(visual.state=="run","movement resumes after attack: "+id)
		visual.action("death")
		check(visual.dead and visual.lock_time<=2.5,"death completes before corpse removal: "+id)
		visual.queue_free()
	await process_frame
	print("ENEMY_ASSET_TEST failures=",failures)
	quit(0 if failures==0 else 1)
