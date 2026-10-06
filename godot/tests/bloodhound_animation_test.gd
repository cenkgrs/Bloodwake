extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	var actor=BWVisual.new();root.add_child(actor);actor.configure("gunslinger")
	var expected={"idle":"BH_Idle","run":"BH_Walk_InPlace","attack":"BH_FiveShot","hit":"BH_GetHit","death":"BH_Death","bombthrow":"BH_BombThrow","ultimate":"BH_Ultimate_BloodWake"}
	for key in expected:
		check(actor.clips.get(key,"")==expected[key],"Runtime clip mapping: "+key)
		check(actor.clip_length(key)>0,"Imported animation has duration: "+key)
	var skeleton=actor._find_skeleton(actor.model)
	check(skeleton.get_bone_count()==48,"New rig has 48 bones, not old Bloodbound skeleton")
	for name in ["WeaponSocket.L","WeaponSocket.R","Foot.L","Foot.R","Hand.L"]:
		check(skeleton.find_bone(name)>=0,"Runtime bone resolves: "+name)
	for key in ["idle","run"]:
		actor.animation.play(actor.clips[key],0)
		actor.animation.seek(0,true);actor.animation.pause();await process_frame
		var first=[]
		for bone in skeleton.get_bone_count():first.append(skeleton.get_bone_global_pose(bone))
		actor.animation.seek(actor.clip_length(key),true);await process_frame
		for bone in skeleton.get_bone_count():
			check(first[bone].is_equal_approx(skeleton.get_bone_global_pose(bone)),"Loop seam "+key+" / "+str(bone))
	# World-space stance contact: in-place feet must exactly cancel translation.
	for side in ["L","R"]:
		var baseline=Vector3.ZERO
		for sample in 7:
			var time=(sample+(0 if side=="L" else 16))/60.0
			actor.position=Vector3(0,0,time*0.32/(15.5/60.0))
			actor.animation.play(actor.clips.run,0);actor.animation.seek(time,true);actor.animation.pause();await process_frame
			var contact=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Foot."+side)).origin
			if sample==0:baseline=contact
			else:check(contact.distance_to(baseline)<0.003,"Planted foot world drift <3mm "+side+" / "+str(sample))
	actor.position=Vector3.ZERO
	actor.animation.play(actor.clips.attack,0);actor.animation.seek(0.25,true);actor.animation.pause();await process_frame
	var spine=skeleton.find_bone("Spine");var foot=skeleton.find_bone("Foot.L")
	var upper=skeleton.get_bone_global_pose(spine)
	actor.state="attack";actor.bloodhound_stride.speed=1;actor.bloodhound_stride.phase=0
	actor.bloodhound_stride._process_modification()
	var first_foot=skeleton.get_bone_global_pose(foot).origin
	actor.bloodhound_stride.phase=0.12;actor.bloodhound_stride._process_modification()
	check(first_foot.distance_to(skeleton.get_bone_global_pose(foot).origin)>0.08,"Moving attack actually moves feet")
	check(upper.is_equal_approx(skeleton.get_bone_global_pose(spine)),"Leg blend preserves upper-body aim pose")
	actor.bloodhound_stride.speed=0
	actor.action("bombthrow")
	check(actor.animation.current_animation=="BH_BombThrow","Bomb clip starts")
	check(not actor.action("attack"),"Auto-fire cannot interrupt throw")
	actor.lock_time=0;actor.action("ultimate")
	check(actor.animation.current_animation=="BH_Ultimate_BloodWake","Ultimate clip starts")
	check(not actor.action("attack"),"Auto-fire cannot interrupt ultimate")
	actor.action("death")
	check(actor.animation.current_animation=="BH_Death","Death can interrupt ultimate")
	actor.queue_free();await process_frame
	print("BLOODHOUND_ANIMATION_TEST failures=",failures);quit(1 if failures else 0)
