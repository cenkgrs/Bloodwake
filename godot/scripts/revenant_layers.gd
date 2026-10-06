extends SkeletonModifier3D
# Revenant overlay layers, applied after the AnimationPlayer has posed the body.
# - Light hits are upper-body additive clips (each track is a local delta from the
#   clip's first frame), so taking damage never stops the legs or cancels a swing.
# - While the body travels during a claw strike, the lower body takes the run
#   cycle, so the feet keep pace with the ground instead of skating.
var actor
var hits={}
var hit_clip={}
var hit_time=-1.0
var run: Animation
var run_tracks=[]
var run_phase=0.0
var legs_weight=0.0
const LOWER=["pelvis","thigh_l","calf_l","foot_l","ball_l","thigh_r","calf_r","foot_r","ball_r"]

func configure(visual):
	actor=visual
	var skeleton=get_skeleton()
	for side in ["Front","Left","Right"]:
		var name="REV_HitLight_%s_Additive" % side
		if not actor.animation.has_animation(name):continue
		var anim=actor.animation.get_animation(name)
		var tracks=[]
		for track in anim.get_track_count():
			if anim.track_get_type(track)!=Animation.TYPE_ROTATION_3D:continue
			var path=anim.track_get_path(track)
			if path.get_subname_count()==0:continue
			var bone_name=String(path.get_subname(0))
			if not _upper(bone_name):continue
			var bone=skeleton.find_bone(bone_name)
			if bone<0:continue
			tracks.append({"track":track,"bone":bone,"rest":skeleton.get_bone_rest(bone).basis.get_rotation_quaternion().inverse()})
		hits[side]={"anim":anim,"tracks":tracks}
	if actor.clips.has("run"):
		run=actor.animation.get_animation(actor.clips.run)
		for track in run.get_track_count():
			var path=run.track_get_path(track)
			if path.get_subname_count()==0:continue
			var name=String(path.get_subname(0))
			var coat=name.begins_with("coat_")
			if not (name in LOWER or coat):continue
			var bone=skeleton.find_bone(name)
			if bone>=0:run_tracks.append({"track":track,"bone":bone,"type":run.track_get_type(track)})

# The additive layer is authored on the chest, arms, head and hair only.
func _upper(name: String) -> bool:
	for prefix in ["spine_","neck_","head","clavicle_","upperarm_","lowerarm_","hand_","blood_claw","armor_","thumb_","index_","middle_","ring_","pinky_","hair_"]:
		if name.begins_with(prefix):return true
	return false

func play_hit(side: String="") -> bool:
	if hits.is_empty():return false
	if side=="" or not hits.has(side):side=hits.keys()[randi()%hits.size()]
	hit_clip=hits[side];hit_time=0.0
	return true

func hit_active() -> bool:
	return hit_time>=0.0

func advance(delta: float):
	if hit_time<0.0:return
	hit_time+=delta
	if hit_time>hit_clip.anim.length:hit_time=-1.0

func _process_modification():
	if actor==null or actor.dead:return
	var skeleton=get_skeleton()
	if legs_weight>0.001 and run!=null:
		for entry in run_tracks:
			if entry.type==Animation.TYPE_POSITION_3D:
				var now=skeleton.get_bone_pose_position(entry.bone)
				skeleton.set_bone_pose_position(entry.bone,now.lerp(run.position_track_interpolate(entry.track,run_phase),legs_weight))
			elif entry.type==Animation.TYPE_ROTATION_3D:
				var turn=skeleton.get_bone_pose_rotation(entry.bone)
				skeleton.set_bone_pose_rotation(entry.bone,turn.slerp(run.rotation_track_interpolate(entry.track,run_phase),legs_weight))
	if hit_time>=0.0:
		var anim: Animation=hit_clip.anim
		for entry in hit_clip.tracks:
			var delta: Quaternion=entry.rest*anim.rotation_track_interpolate(entry.track,hit_time)
			skeleton.set_bone_pose_rotation(entry.bone,skeleton.get_bone_pose_rotation(entry.bone)*delta)
