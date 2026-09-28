class_name BWVisual
extends Node3D

const FLASH_ENERGY = 0.4

var animation: AnimationPlayer
var clips = {}
var state = ""
var lock_time = 0.0
var model: Node3D
var dead = false
var procedural = false
var elapsed = 0.0
var base_y = 0.0
var fitted_timing = false
var fitted_attack = false
var actor_kind = ""
var hand_magic: Node3D
var hand_skeleton: Skeleton3D
var hand_bone = -1
var magic_time = 0.0
var base_scale = Vector3.ONE
var enemy_asset = false
var flash_time = 0.0
var flash_span = 0.0
var flash_ready = false
var flash_surfaces = []
var flinch_time = 0.0
var hit_clip_time = 0.0

func configure(kind: String, enemy: bool = false, tint: Color = Color.WHITE, height: float = 1.8):
	var file = {"gunslinger":"bloodbound","warrior":"warrior","assassin":"assassin"}.get(kind,"warrior")
	var enemy_file="enemy_"+{"grunt":"warrior"}.get(kind,kind)
	enemy_asset=enemy and ResourceLoader.exists("res://assets/models/%s.glb" % enemy_file)
	actor_kind=kind
	fitted_timing=not enemy and kind in ["warrior","mage","assassin"]
	# The gunslinger keeps bloodbound.glb (there is no gunslinger_player rig) so it
	# stays out of fitted_timing. Only its shot clip needs fitting - normalising the
	# rest sent the run cycle to 1.9x and the hit clip to 4.4x.
	fitted_attack=not enemy and kind=="gunslinger"
	if fitted_timing:file=kind+"_player"
	if enemy_asset:file=enemy_file
	if kind in ["mage","healer"] and enemy and not enemy_asset:
		_mage(tint);procedural=true;return
	var packed = load("res://assets/models/%s.glb" % file)
	if not packed is PackedScene:
		_mage(tint);procedural=true;return
	model=packed.instantiate();add_child(model)
	animation=_find_animation(model)
	if animation:
		for anim_name in animation.get_animation_list():
			var key=String(anim_name).to_lower()
			for pair in [["idle","idle"],["run","run"],["walk","run"],["attack","attack"],["hit","hit"],["death","death"],["die","death"],["fall","death"],["ultimate","ultimate"]]:
				if key.contains(pair[0]) and not clips.has(pair[1]):clips[pair[1]]=anim_name
		if file=="warrior":
			for desired in {"idle":"Idle_Weapon","run":"Run_Weapon","attack":"Sword_Attack","hit":"RecieveHit","death":"Death"}:
				var source={"idle":"Idle_Weapon","run":"Run_Weapon","attack":"Sword_Attack","hit":"RecieveHit","death":"Death"}[desired]
				if animation.has_animation(source):clips[desired]=source
		for clip in clips:
			var anim=animation.get_animation(clips[clip])
			anim.loop_mode=Animation.LOOP_LINEAR if clip in ["idle","run"] else Animation.LOOP_NONE
		if clips.has("idle"):animation.play(clips.idle);animation.advance(0)
	var bounds=_bounds(model)
	if fitted_timing or enemy_asset:
		# This rig is authored at 1.8 m. Its unskinned mesh AABB is in bind space.
		model.scale=Vector3.ONE*(height/1.8)
		model.position=Vector3.ZERO
	elif bounds.size.y>0.01:
		var ratio=height/bounds.size.y
		model.scale=Vector3.ONE*ratio
		model.position=Vector3(-bounds.get_center().x*ratio,-bounds.position.y*ratio,-bounds.get_center().z*ratio)
	base_y=model.position.y
	base_scale=model.scale
	if enemy and not enemy_asset:_tint(model,tint)
	play("idle")
	if kind=="mage" and not enemy:_attach_hand_magic()

var level_scale = 1.0

# In the world an actor just stands at its own origin, so the fitted rigs are never
# horizontally centred. A portrait has to frame the bust, so it asks for the shift.
func frame_offset() -> Vector3:
	if not is_instance_valid(model):return Vector3.ZERO
	# Skinned meshes report their AABB in bind space, which is why configure() refuses
	# to centre the fitted rigs on it. The posed bones are the honest measure: they put
	# the mage back on the axis and drop the warrior onto the floor of the frame.
	var skeleton=_find_skeleton(model)
	if skeleton!=null and skeleton.get_bone_count()>0:
		var low=Vector3.INF;var high=-Vector3.INF
		for bone in skeleton.get_bone_count():
			var spot=(skeleton.global_transform*skeleton.get_bone_global_pose(bone)).origin
			low=low.min(spot);high=high.max(spot)
		return Vector3(-(low.x+high.x)*0.5,-low.y,-(low.z+high.z)*0.5)
	var bounds=_bounds(model)
	if bounds.size.y<=0.01:return Vector3.ZERO
	var centre=bounds.get_center()
	return Vector3(-centre.x,-bounds.position.y,-centre.z)*model.scale.x

func set_level_scale(multiplier: float):
	level_scale=multiplier;_apply_scale()

func _apply_scale():
	if not is_instance_valid(model):return
	model.scale=base_scale*level_scale

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:return node
	for child in node.get_children():
		var found=_find_animation(child)
		if found:return found
	return null

func _bounds(node: Node3D) -> AABB:
	var bounds=AABB();var first=true
	for mesh in _meshes(node):
		# Equipment must not change the actor's height or horizontal centering.
		if mesh.name=="Greatsword":continue
		var transform=model.global_transform.affine_inverse()*mesh.global_transform
		var box=transform*mesh.get_aabb()
		if first:bounds=box;first=false
		else:bounds=bounds.merge(box)
	return bounds

func _meshes(node: Node) -> Array:
	var result=[]
	if node is MeshInstance3D:result.append(node)
	for child in node.get_children():result.append_array(_meshes(child))
	return result

func _tint(node: Node,color: Color):
	for mesh in _meshes(node):
		for i in mesh.mesh.get_surface_count():
			var source=mesh.get_active_material(i)
			if source is StandardMaterial3D:
				var mat=source.duplicate();mat.albedo_color=source.albedo_color.lerp(color*0.35,0.5);mesh.set_surface_override_material(i,mat)

# A hit brightens the existing materials through surface overrides - the idiom
# _tint already uses here - instead of stacking a material_overlay on top, which
# leaves the renderer querying a null material. Duplicates are built once and
# reused so a hit does not allocate.
func _build_flash_surfaces():
	flash_ready=true
	for mesh in _meshes(self):
		if mesh.mesh==null:continue
		for i in mesh.mesh.get_surface_count():
			var source=mesh.get_active_material(i)
			if source is StandardMaterial3D:
				var mat=source.duplicate();mat.emission_enabled=true;mat.emission=Color(1,0.94,0.86)
				flash_surfaces.append({"mesh":mesh,"surface":i,"material":mat,"restore":mesh.get_surface_override_material(i)})

func flinch(direction: Vector3,strength: float=1.0):
	if dead or model==null:return
	flinch_time=0.16
	var push=direction.normalized()*0.16*strength
	var knock=create_tween();knock.set_parallel(true)
	knock.tween_property(model,"position",Vector3(push.x,0,push.z),0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	knock.chain().tween_property(model,"position",Vector3.ZERO,0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hit_react(direction: Vector3,strength: float=1.0):
	flinch(direction,strength)
	if hit_clip_time>0 or not clips.has("hit"):return
	hit_clip_time=0.45
	action("hit")

func flash(duration: float=0.11):
	if dead:return
	if not flash_ready:_build_flash_surfaces()
	for entry in flash_surfaces:
		entry.material.emission_energy_multiplier=FLASH_ENERGY
		entry.mesh.set_surface_override_material(entry.surface,entry.material)
	flash_span=maxf(duration,0.02);flash_time=flash_span

func _clear_flash():
	flash_time=0.0
	for entry in flash_surfaces:
		if is_instance_valid(entry.mesh):entry.mesh.set_surface_override_material(entry.surface,entry.restore)

func clip_speed(next: String,duration: float=-1.0) -> float:
	if not animation or not clips.has(next):return 1.0
	if not fitted_timing and not enemy_asset and not (fitted_attack and next=="attack"):return 1.0
	var run_targets={"warrior":0.62,"mage":0.72,"assassin":0.5}
	var attack_targets={"assassin":0.3,"gunslinger":0.3}
	var targets={"run":run_targets.get(actor_kind,0.65),"attack":attack_targets.get(actor_kind,0.45),"hit":0.22,"ultimate":0.9,"death":2.2}
	var target=duration if duration>0 else targets.get(next,-1.0)
	return animation.get_animation(clips[next]).length/target if target>0 else 1.0

func play(next: String):
	if dead and next!="death":return
	if next==state:return
	state=next
	if animation and clips.has(next):
		animation.speed_scale=1.0
		animation.play(clips[next],0.08,clip_speed(next))

func action(next: String,duration: float=-1.0,reverse: bool=false) -> bool:
	if dead:return false
	if next=="attack" and lock_time>0:return false
	# A normal hit must not restart a committed spell or every incoming hit stun-locks it.
	if next=="hit" and state in ["ultimate","hit"] and lock_time>0:return false
	if next=="death":
		dead=true
		# tick() stops for a corpse (it leaves the enemies array), so a kill landed
		# mid-flash would leave the additive overlay stuck on for the 2.5s it lingers.
		_clear_flash()
		if is_instance_valid(hand_magic):hand_magic.visible=false
	if animation and clips.has(next):
		var speed=clip_speed(next,duration)
		animation.speed_scale=1.0
		if reverse:animation.play(clips[next],0.05,-speed,true)
		else:animation.play(clips[next],0.05,speed)
		lock_time=animation.get_animation(clips[next]).length/speed
		state=next
	else:
		lock_time=0.25 if next!="death" else 1.0
		state=next
		if next=="death":create_tween().tween_property(self,"rotation:z",PI*0.48,0.7)
	return true

func tick(delta: float,moving: bool,movement_rate: float=1.0):
	elapsed+=delta;lock_time=maxf(0,lock_time-delta)
	hit_clip_time=maxf(0,hit_clip_time-delta)
	if flash_time>0:
		flash_time=maxf(0,flash_time-delta)
		if flash_time<=0:_clear_flash()
		else:
			var energy=FLASH_ENERGY*(flash_time/flash_span)
			for entry in flash_surfaces:entry.material.emission_energy_multiplier=energy
	if (procedural or animation==null) and not dead:
		model.position.y=sin(elapsed*(10 if moving else 2))*0.035
	if not dead and lock_time<=0:play("run" if moving else "idle")
	if fitted_timing and animation and state=="run":animation.speed_scale=clampf(movement_rate,0.5,2.5)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:return node
	for child in node.get_children():
		var found=_find_skeleton(child)
		if found:return found
	return null

func _attach_hand_magic():
	hand_skeleton=_find_skeleton(model)
	if not hand_skeleton:return
	for index in hand_skeleton.get_bone_count():
		if String(hand_skeleton.get_bone_name(index)).ends_with("RightHand"):
			hand_bone=index;break
	if hand_bone<0:return
	hand_magic=Node3D.new();hand_magic.name="HandMagic";add_child(hand_magic)
	hand_magic.top_level=true
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color("86e8ff");mat.emission_enabled=true;mat.emission=Color("70bfff");mat.emission_energy_multiplier=2.0
	var orb=MeshInstance3D.new();orb.name="Core";var sphere=SphereMesh.new();sphere.radius=0.075;sphere.height=0.15;sphere.radial_segments=16;sphere.rings=8;orb.mesh=sphere;orb.material_override=mat;hand_magic.add_child(orb)
	for i in 2:
		var ring=MeshInstance3D.new();ring.name="Rune"+str(i);var torus=TorusMesh.new();torus.inner_radius=0.12+i*0.03;torus.outer_radius=0.13+i*0.03;torus.rings=24;torus.ring_segments=4;ring.mesh=torus;ring.material_override=mat;ring.rotation.x=PI/2 if i==0 else 0;hand_magic.add_child(ring)
	var sparks=CPUParticles3D.new();sparks.name="Sparks";sparks.amount=18;sparks.lifetime=0.55;sparks.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;sparks.emission_sphere_radius=0.1;sparks.direction=Vector3.UP;sparks.spread=180;sparks.initial_velocity_min=0.1;sparks.initial_velocity_max=0.35;sparks.gravity=Vector3(0,0.2,0)
	var fleck=SphereMesh.new();fleck.radius=0.012;fleck.height=0.024;fleck.radial_segments=6;fleck.rings=3;fleck.material=mat;sparks.mesh=fleck;sparks.material_override=mat;hand_magic.add_child(sparks)
	var lamp=OmniLight3D.new();lamp.light_color=Color("7cc7ff");lamp.light_energy=0.7;lamp.omni_range=1.2;hand_magic.add_child(lamp)

func _process(delta: float):
	if not is_instance_valid(hand_magic) or dead:return
	magic_time+=delta
	var pose=hand_skeleton.global_transform*hand_skeleton.get_bone_global_pose(hand_bone)
	hand_magic.global_position=pose.origin+pose.basis.orthonormalized()*Vector3(0,0.10,0.035)
	var pulse=1.0+sin(magic_time*5)*0.10
	if state=="ultimate" and lock_time>0:pulse*=1.8
	hand_magic.scale=Vector3.ONE*pulse
	hand_magic.get_node("Rune0").rotate_y(delta*2.5)
	hand_magic.get_node("Rune1").rotate_z(-delta*3)

func _mage(tint: Color):
	model=Node3D.new();add_child(model)
	var robe=StandardMaterial3D.new();robe.albedo_color=Color("51436e") if tint==Color.WHITE else tint
	var body=MeshInstance3D.new();var shape=CylinderMesh.new();shape.top_radius=0.22;shape.bottom_radius=0.42;shape.height=1.35
	body.mesh=shape;body.material_override=robe;body.position.y=0.8;model.add_child(body)
	var hood=MeshInstance3D.new();var hood_mesh=SphereMesh.new();hood_mesh.radius=0.26;hood_mesh.height=0.54
	hood.mesh=hood_mesh;hood.material_override=robe;hood.position=Vector3(0,1.65,0);model.add_child(hood)
	var face=MeshInstance3D.new();var face_mesh=SphereMesh.new();face_mesh.radius=0.18;face_mesh.height=0.3
	face.mesh=face_mesh;var dark=StandardMaterial3D.new();dark.albedo_color=Color("141621");face.material_override=dark;face.position=Vector3(0,1.64,0.15);model.add_child(face)
	var staff=MeshInstance3D.new();var shaft=CylinderMesh.new();shaft.top_radius=0.025;shaft.bottom_radius=0.035;shaft.height=1.8;staff.mesh=shaft;staff.position=Vector3(0.48,0.92,0);model.add_child(staff)
	var orb=MeshInstance3D.new();var gem=SphereMesh.new();gem.radius=0.11;gem.height=0.22;orb.mesh=gem;orb.position=Vector3(0.48,1.86,0);model.add_child(orb)
	var light=StandardMaterial3D.new();light.albedo_color=Color("b695ff");light.emission_enabled=true;light.emission=Color("9678df");orb.material_override=light
