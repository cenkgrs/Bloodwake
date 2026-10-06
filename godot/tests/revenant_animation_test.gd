extends SceneTree
# In-engine checks of the imported Revenant clips (REV_*): loops close, the run
# keeps planted feet still at the class's ground speed, swings and casts return
# to the ready pose, light hits only touch the upper body, and every authored
# event lies inside its clip.
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")

func world_point(skeleton: Skeleton3D,bone: int,tail: Vector3=Vector3.ZERO) -> Vector3:
	return skeleton.global_transform*(skeleton.get_bone_global_pose(bone)*tail)

func pose_of(skeleton: Skeleton3D) -> Array:
	var out=[]
	for b in skeleton.get_bone_count():out.append(skeleton.get_bone_pose(b))
	return out

func pose_delta(a: Array,b: Array,bones: Array=[]) -> float:
	var worst=0.0
	for i in a.size():
		if not bones.is_empty() and not i in bones:continue
		worst=maxf(worst,a[i].origin.distance_to(b[i].origin))
		worst=maxf(worst,a[i].basis.get_rotation_quaternion().angle_to(b[i].basis.get_rotation_quaternion()))
	return worst

func suite():
	var actor=BWVisual.new();root.add_child(actor);actor.configure("revenant")
	var skeleton=actor._find_skeleton(actor.model)
	var anim=actor.animation
	for key in ["idle","run","death","attack1","attack2","attack3","teleport","ultimate","hit"]:
		check(actor.clips.has(key) and String(actor.clips[key]).begins_with("REV_"),"Revenant clip mapped: "+key)
	check(actor.revenant_layers!=null and actor.revenant_layers.hits.size()==3,"Three additive light hits are loaded")
	var bones={}
	for name in ["pelvis","head","ball_l","ball_r","foot_l","foot_r","hand_r","spine_01"]:
		bones[name]=skeleton.find_bone(name);check(bones[name]>=0,"Rig bone present: "+name)
	if failures:quit(1);return
	actor.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var pl=actor.revenant_layers
	pl.active=false
	# Loops close without a pose jump.
	for clip in ["idle","run"]:
		anim.play(actor.clips[clip]);anim.seek(0,true);var a=pose_of(skeleton)
		anim.seek(actor.clip_length(clip),true);var b=pose_of(skeleton)
		check(pose_delta(a,b)<0.002,"Loop closes: "+clip)
	# Run at 6 m/s: while a ball joint is on the floor its world position holds.
	anim.play(actor.clips.run)
	var length=actor.clip_length("run")
	var worst_slip=0.0;var planted_frames=0
	for side in ["ball_l","ball_r"]:
		var anchor=Vector3.INF
		var floor_y=INF
		for f in 24:
			anim.seek(f/60.0,true);floor_y=minf(floor_y,world_point(skeleton,bones[side]).y)
		for f in 49:
			var t=fposmod(f/60.0,length)
			anim.seek(t,true)
			var p=world_point(skeleton,bones[side])+Vector3(0,0,BWVisual.REVENANT_RUN_SPEED*f/60.0)
			if p.y<floor_y+0.003:
				planted_frames+=1
				if anchor==Vector3.INF:anchor=p
				worst_slip=maxf(worst_slip,Vector2(p.x-anchor.x,p.z-anchor.z).length())
			else:anchor=Vector3.INF
	check(planted_frames>=24,"Feet are planted for real stance phases (%d)" % planted_frames)
	check(worst_slip<0.01,"Planted feet hold still in the world at run speed (%.3f m)" % worst_slip)
	# Head bob smaller than pelvis bob.
	var pz=[];var hz=[]
	for f in 24:
		anim.seek(f/60.0,true)
		pz.append(world_point(skeleton,bones.pelvis).y);hz.append(world_point(skeleton,bones.head).y)
	check(hz.max()-hz.min()<pz.max()-pz.min(),"Head moves less vertically than the pelvis")
	# Swings and casts leave from and return to the combat-ready pose.
	anim.play(actor.clips.idle);anim.seek(0,true);var ready=pose_of(skeleton)
	for clip in ["attack1","attack2","attack3","teleport","ultimate"]:
		anim.play(actor.clips[clip]);anim.seek(0,true)
		check(pose_delta(pose_of(skeleton),ready,[bones.pelvis,bones.spine_01,bones.head])<0.02,"Starts in the ready pose: "+clip)
		anim.seek(actor.clip_length(clip),true)
		check(pose_delta(pose_of(skeleton),ready,[bones.pelvis,bones.spine_01,bones.head])<0.02,"Returns to the ready pose: "+clip)
		var lowest=INF
		for f in int(actor.clip_length(clip)*60)+1:
			anim.seek(f/60.0,true)
			for side in ["foot_l","foot_r","ball_l","ball_r"]:lowest=minf(lowest,world_point(skeleton,bones[side]).y)
		check(lowest>0.02,"Feet stay above the floor: %s (%.3f)" % [clip,lowest])
	# The claw drives forward into contact.
	var hand_r=skeleton.find_bone("hand_r");var hand_l=skeleton.find_bone("hand_l")
	for clip in ["attack1","attack2","attack3"]:
		anim.play(actor.clips[clip]);anim.seek(0,true)
		var start=world_point(skeleton,bones.pelvis)
		anim.seek(BWVisual.revenant_time(clip,"damage"),true)
		check(world_point(skeleton,bones.pelvis).z-start.z>0.15,"Pelvis lunges toward the target at contact: "+clip)
		# Right, left, right: the striking hand opens wide to its own side before the
		# sweep, then crosses in front of the chest at contact.
		var striker=hand_l if clip=="attack2" else hand_r
		var side=1.0 if clip=="attack2" else -1.0
		var widest=0.0
		for f in int(BWVisual.revenant_time(clip,"damage")*60):
			anim.seek(f/60.0,true)
			widest=maxf(widest,(world_point(skeleton,striker)-world_point(skeleton,bones.spine_01)).x*side)
		check(widest>0.55,"%s opens the striking arm wide to its side (%.2f m)" % [clip,widest])
		anim.seek(BWVisual.revenant_time(clip,"damage"),true)
		check((world_point(skeleton,striker)-world_point(skeleton,bones.spine_01)).z>0.3,"%s sweeps in front at contact" % clip)
	# Events lie inside their clips.
	for clip in BWVisual.REVENANT_EVENTS:
		for event in BWVisual.REVENANT_EVENTS[clip]:
			check(BWVisual.revenant_time(clip,event)<=actor.clip_length(clip),"Event inside clip: %s.%s" % [clip,event])
	# Death ends on the floor.
	anim.play(actor.clips.death);anim.seek(actor.clip_length("death"),true)
	check(world_point(skeleton,bones.head).y<0.5,"Death settles on the floor")
	# A light hit only moves the upper body and fades out by itself.
	anim.play(actor.clips.run);anim.seek(0.1,true)
	pl.active=true
	var base=pose_of(skeleton)
	pl.play_hit("Left");pl.advance(4.0/60.0)
	pl._process_modification()
	var hit_pose=pose_of(skeleton)
	check(pose_delta(base,hit_pose,[bones.spine_01,bones.head])>0.05,"Hit layer turns the torso")
	check(pose_delta(base,hit_pose,[bones.pelvis,bones.foot_l,bones.foot_r])<1e-4,"Hit layer leaves the legs on locomotion")
	pl.advance(1.0);check(not pl.hit_active(),"Hit layer ends on its own")
	var before=actor.state;check(actor.action("hit") and actor.state==before,"A hit does not change the locomotion state")
	var fx=BWFx.new();root.add_child(fx);fx.configure("PC")
	var a=fx.revenant_claws(Vector3.ZERO,Vector3.RIGHT,2.0)
	check(a!=null,"Blender claw VFX imports")
	await create_timer(1.8).timeout
	check(fx.get_child_count()==0,"Transient ribbons clean up")
	actor.queue_free();fx.queue_free();await process_frame
	print("REVENANT_ANIMATION_TEST failures=",failures);quit(1 if failures else 0)
