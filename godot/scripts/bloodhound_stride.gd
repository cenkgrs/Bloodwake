extends SkeletonModifier3D
# Apply the authored walk only to the lower body while the upper body shoots.
# A modifier runs after AnimationPlayer, avoiding competing pose writes.
var actor
var walk: Animation
var phase=0.0
var speed=0.0
var heading=0.0
var tracks=[]
func configure(visual):
	actor=visual;walk=actor.animation.get_animation(actor.clips.run)
	var skeleton=get_skeleton()
	for track in walk.get_track_count():
		var path=walk.track_get_path(track)
		if path.get_subname_count()==0:continue
		var name=String(path.get_subname(0))
		if name=="Pelvis" or name.begins_with("Thigh.") or name.begins_with("Shin.") or name.begins_with("Foot.") or name.begins_with("Coat"):
			var bone=skeleton.find_bone(name)
			if bone>=0:tracks.append({"track":track,"bone":bone,"type":walk.track_get_type(track)})
func _process_modification():
	if actor==null or walk==null or speed<0.01 or actor.dead:return
	if actor.state not in ["attack","ricochet"]:return
	var skeleton=get_skeleton()
	var spine=skeleton.find_bone("Spine")
	var pelvis=skeleton.find_bone("Pelvis")
	var upper=skeleton.get_bone_global_pose(spine)
	for entry in tracks:
		if entry.type==Animation.TYPE_POSITION_3D:skeleton.set_bone_pose_position(entry.bone,walk.position_track_interpolate(entry.track,phase))
		elif entry.type==Animation.TYPE_ROTATION_3D:skeleton.set_bone_pose_rotation(entry.bone,walk.rotation_track_interpolate(entry.track,phase))
	# Legs face the actual travel direction; torso keeps the committed shot aim.
	var lower=skeleton.get_bone_global_pose(pelvis)
	lower.basis=Basis(Vector3.UP,heading)*lower.basis
	skeleton.set_bone_global_pose(pelvis,lower)
	skeleton.set_bone_global_pose(spine,upper)
