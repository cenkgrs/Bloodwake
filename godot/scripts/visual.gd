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
var blood_hands=[]
var death_materials=[]
var death_elapsed=0.0
var bloodhound_grenade: MeshInstance3D
var bloodhound_skeleton: Skeleton3D
var bloodhound_stride: SkeletonModifier3D
var revenant_layers: SkeletonModifier3D

# Revenant event frames, authored at 60 fps (frame 1 = 0 s). The marker names in
# art/revenant-astra-ready/deliverables/animation_events.json are the source.
const REVENANT_CLIPS={"idle":"REV_Idle","run":"REV_AgileRun_InPlace","walk":"REV_AgileMove_InPlace","hit":"REV_HitLight_Front",
	"death":"REV_Death","attack":"REV_ClawAttack_1","attack1":"REV_ClawAttack_1","attack2":"REV_ClawAttack_2","attack3":"REV_ClawAttack_3",
	"teleport":"REV_TeleportAttack","ultimate":"REV_BloodBurst"}
# Claw combo: right-hand horizontal sweep, left-hand rising rake, right-hand overhead slam.
const REVENANT_EVENTS={"attack1":{"damage":11},"attack2":{"damage":12},"attack3":{"damage":19},
	"teleport":{"hide":16,"move":20,"show":22,"damage":26,"recover":35},
	"ultimate":{"telegraph":19,"damage":60,"dissipate":85,"recover":101},
	"death":{"impact":5,"ground":52}}
# The run cycle is authored at the class's base pace: 1.2 m per step at 6 m/s.
const REVENANT_RUN_SPEED=6.0

static func revenant_time(clip: String,event: String) -> float:
	return float(REVENANT_EVENTS[clip][event]-1)/60.0

# Keep strong references: the resource loader's weak cache otherwise releases a
# PackedScene when its last body dies, forcing a synchronous GLB reload on spawn.
static var model_scenes: Dictionary = {}
const ENEMY_MODELS = ["warrior","enemy_warrior","enemy_healer","enemy_assassin","enemy_archer","enemy_tank","enemy_commander","enemy_mage","enemy_boss"]

static func model_scene(file: String) -> PackedScene:
	if model_scenes.has(file):return model_scenes[file]
	var start=Time.get_ticks_usec()
	var packed=load("res://assets/models/%s.glb" % file) as PackedScene
	if packed!=null:model_scenes[file]=packed
	if "--profile" in OS.get_cmdline_user_args():
		print("MODEL_LOAD t=",Time.get_ticks_msec()," asset=",file," ms=",(Time.get_ticks_usec()-start)/1000.0)
	return packed

static func warm_enemy_models():
	for file in ENEMY_MODELS:
		if ResourceLoader.exists("res://assets/models/%s.glb" % file):model_scene(file)

static func player_model(kind: String) -> String:
	return {"gunslinger":"bloodhound_player","revenant":"revenant_player"}.get(kind,kind+"_player")

func configure(kind: String, enemy: bool = false, tint: Color = Color.WHITE, height: float = 1.8):
	var file = {"gunslinger":"bloodhound_player","warrior":"warrior","assassin":"assassin"}.get(kind,"warrior")
	var enemy_file="enemy_"+{"grunt":"warrior"}.get(kind,kind)
	enemy_asset=enemy and ResourceLoader.exists("res://assets/models/%s.glb" % enemy_file)
	actor_kind=kind
	fitted_timing=not enemy and kind in ["warrior","mage","assassin","revenant"]
	# Bloodhound uses its own authored event schedule, not the generic single-hit
	# fitted attack path. Keep the other classes' timing unchanged.
	fitted_attack=not enemy and kind=="gunslinger"
	if fitted_timing:file=player_model(kind)
	if enemy_asset:file=enemy_file
	if kind in ["mage","healer"] and enemy and not enemy_asset:
		_mage(tint);procedural=true;return
	var packed = model_scene(file)
	if not packed is PackedScene:
		_mage(tint);procedural=true;return
	model=packed.instantiate();add_child(model)
	animation=_find_animation(model)
	if animation:
		for anim_name in animation.get_animation_list():
			var key=String(anim_name).to_lower()
			for pair in [["idle","idle"],["run","run"],["walk","run"],["attack","attack"],["hit","hit"],["death","death"],["die","death"],["fall","death"],["ultimate","ultimate"]]:
				if key.contains(pair[0]) and not clips.has(pair[1]):clips[pair[1]]=anim_name
		# The substring pass above folds Attack1..4 and SpinAttack into "attack",
		if kind=="gunslinger" and not enemy:
			var bloodhound={"idle":"BH_Idle","run":"BH_Walk_InPlace","hit":"BH_GetHit","death":"BH_Death","attack":"BH_FiveShot","bombthrow":"BH_BombThrow","ultimate":"BH_Ultimate_BloodWake"}
			for key in bloodhound:
				if animation.has_animation(bloodhound[key]):clips[key]=bloodhound[key]
			# Ricochet is a single shot: use only the first recoil of FiveShot,
			# then blend back to locomotion. Do not squeeze five recoils into Q.
			if clips.has("attack"):
				var single=animation.get_animation(clips.attack).duplicate() as Animation
				single.length=13.0/60.0
				for track in single.get_track_count():
					for key in range(single.track_get_key_count(track)-1,-1,-1):
						if single.track_get_key_time(track,key)>single.length:single.track_remove_key(track,key)
				var library=animation.get_animation_library("")
				if not library.has_animation("BH_Ricochet"):library.add_animation("BH_Ricochet",single)
				clips["ricochet"]="BH_Ricochet"
		# Register the other characters' exact combo names.
		# so the combo links are registered by their exact clip name instead.
		for exact in ["Dash","Teleport","Attack1","Attack2","Attack3","Attack4","SpinAttack","Slam","Sweep","Charge","Cast","Summon","Draw"]:
			if animation.has_animation(exact):clips[exact.to_lower()]=exact
		if kind=="revenant" and not enemy:
			for key in REVENANT_CLIPS:
				if animation.has_animation(REVENANT_CLIPS[key]):clips[key]=REVENANT_CLIPS[key]
		if not enemy and kind=="warrior" and clips.has("ultimate"):
			clips["attack4"]=clips["ultimate"]
		if file=="warrior":
			for desired in {"idle":"Idle_Weapon","run":"Run_Weapon","attack":"Sword_Attack","hit":"RecieveHit","death":"Death"}:
				var source={"idle":"Idle_Weapon","run":"Run_Weapon","attack":"Sword_Attack","hit":"RecieveHit","death":"Death"}[desired]
				if animation.has_animation(source):clips[desired]=source
		for clip in clips:
			var anim=animation.get_animation(clips[clip])
			anim.loop_mode=Animation.LOOP_LINEAR if clip in ["idle","run"] else Animation.LOOP_NONE
		if clips.has("idle"):animation.play(clips.idle);animation.advance(0)
	var bounds=_bounds(model)
	if fitted_timing or enemy_asset or (kind=="gunslinger" and not enemy):
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
	if kind=="mage" and (not enemy or enemy_asset):_attach_hand_magic()
	if kind=="revenant" and not enemy:
		_attach_blood_hands()
		var skeleton=_find_skeleton(model)
		if skeleton!=null:
			revenant_layers=preload("res://scripts/revenant_layers.gd").new()
			skeleton.add_child(revenant_layers);revenant_layers.configure(self)
	if kind=="gunslinger" and not enemy:
		bloodhound_skeleton=_find_skeleton(model)
		bloodhound_grenade=MeshInstance3D.new();bloodhound_grenade.name="HeldGrenade"
		var sphere=SphereMesh.new();sphere.radius=0.045;sphere.height=0.09
		bloodhound_grenade.mesh=sphere
		var metal=StandardMaterial3D.new();metal.albedo_color=Color("5b232a");metal.metallic=0.7;metal.roughness=0.35
		bloodhound_grenade.material_override=metal;bloodhound_grenade.visible=false;add_child(bloodhound_grenade)
		bloodhound_stride=preload("res://scripts/bloodhound_stride.gd").new()
		bloodhound_skeleton.add_child(bloodhound_stride);bloodhound_stride.configure(self)

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
	if actor_kind=="boss" and lock_time>0:return
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
	if actor_kind=="gunslinger" and String(clips[next]).begins_with("BH_"):
		return clip_length(next)/duration if duration>0 else 1.0
	if not fitted_timing and not enemy_asset and not (fitted_attack and next=="attack"):return 1.0
	# Revenant clips carry their own timing (markers drive the skills); the run is
	# rate-matched to ground speed in tick().
	if actor_kind=="revenant" and String(clips[next]).begins_with("REV_"):
		return clip_length(next)/duration if duration>0 else 1.0
	var run_targets={"warrior":0.72,"revenant":0.72,"mage":0.72,"assassin":0.5,"tank":1.05,"commander":0.95,"grunt":1.0}
	var attack_targets={"assassin":0.3,"gunslinger":0.3}
	var targets={"run":run_targets.get(actor_kind,0.65),"attack":attack_targets.get(actor_kind,0.45),"hit":0.22,"ultimate":0.9,"death":2.2}
	var target=duration if duration>0 else targets.get(next,-1.0)
	return animation.get_animation(clips[next]).length/target if target>0 else 1.0

# How long a clip runs at its authored pace. The combat code sizes a swing off this
# instead of forcing every clip into one target length.
func clip_length(name: String) -> float:
	if animation==null or not clips.has(name):return 0.0
	return animation.get_animation(clips[name]).length

func play(next: String):
	if dead and next!="death":return
	if next==state:return
	state=next
	if animation and clips.has(next):
		animation.speed_scale=1.0
		animation.play(clips[next],0.14,clip_speed(next))

func action(next: String,duration: float=-1.0,reverse: bool=false) -> bool:
	if dead:return false
	# A light hit is an upper-body additive layer: it never stops the legs, a swing or a cast.
	if next=="hit" and revenant_layers!=null:
		if hit_clip_time>0:return false
		hit_clip_time=0.2
		return revenant_layers.play_hit()
	if actor_kind=="gunslinger" and lock_time>0 and state in ["ultimate","bombthrow"] and next in ["attack","hit"]:return false
	# Every link of the chain is its own clip now, so this guards the prefix rather
	# than the single old "attack" name; otherwise a swing could restart itself.
	# A link of the chain may cut into the previous one's recovery - that is what
	# makes a combo feel responsive - but a clip must not restart itself.
	if next.begins_with("attack") and next==state and lock_time>0:return false
	# A normal hit must not restart a committed spell or every incoming hit stun-locks it.
	# Nor may it cut a swing short. Being staggered out of every attack is what made
	# the chain read as broken rather than as heavy; the screen flash still sells the
	# hit without stealing the animation.
	if next=="hit" and lock_time>0 and (state.begins_with("attack") or state in ["ultimate","hit","spinattack","draw","cast","ricochet"]):return false
	if next=="death":
		dead=true
		# tick() stops for a corpse (it leaves the enemies array), so a kill landed
		# mid-flash would leave the additive overlay stuck on for the 2.5s it lingers.
		_clear_flash()
		if is_instance_valid(hand_magic):hand_magic.visible=false
		if actor_kind=="revenant":_start_blood_death()
	if animation and clips.has(next):
		var speed=clip_speed(next,duration)
		animation.speed_scale=1.0
		# Cancelling one link into the next needs a longer crossfade than a cold start:
		# the outgoing clip is stopped mid-recovery, so 0.05 s snapped.
		var blend=0.14 if next.begins_with("attack") and state.begins_with("attack") else 0.05
		# These short authored claws already share their ready pose; a 140 ms blend
		# swallowed most of their wind-up at Revenant's attack speed.
		if actor_kind=="revenant" and next.begins_with("attack"):blend=0.075
		if reverse:animation.play(clips[next],blend,-speed,true)
		else:animation.play(clips[next],blend,speed)
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
	if revenant_layers!=null:_revenant_tick(delta,moving,movement_rate)
	if is_instance_valid(bloodhound_grenade):
		var time=animation.current_animation_position if animation and animation.is_playing() else -1.0
		bloodhound_grenade.visible=not dead and state=="bombthrow" and time>=7.0/60 and time<19.0/60
		if bloodhound_grenade.visible:
			var bone=bloodhound_skeleton.find_bone("Hand.L")
			bloodhound_grenade.global_transform=bloodhound_skeleton.global_transform*bloodhound_skeleton.get_bone_global_pose(bone)
			bloodhound_grenade.position+=bloodhound_grenade.basis*Vector3(.068,.072,-.03)

# Feet stay planted: the run plays at ground speed over the authored stride (which
# grows with the model). Swings taken on the move borrow the run for the legs.
func _revenant_tick(delta: float,moving: bool,movement_rate: float):
	var rate=movement_rate/maxf(0.01,model.scale.x)
	if state=="run" and animation:
		animation.speed_scale=rate
		revenant_layers.run_phase=animation.current_animation_position
	elif moving and revenant_layers.run!=null:
		revenant_layers.run_phase=fposmod(revenant_layers.run_phase+delta*rate,revenant_layers.run.length)
	var layered=moving and not dead and (state.begins_with("attack") or state=="hit") and lock_time>0
	revenant_layers.legs_weight=move_toward(revenant_layers.legs_weight,1.0 if layered else 0.0,delta*10.0)
	revenant_layers.advance(delta)

# World velocity in metres/second; stance travels 0.32m over 15.5 frames.
# Account for model/level scale instead of tying footsteps to an upgrade ratio.
func bloodhound_locomotion(speed: float,velocity: Vector3=Vector3.ZERO,delta: float=0.0):
	if actor_kind!="gunslinger" or not animation:return
	var rate=maxf(0.01,speed/(0.32/(15.5/60.0)*model.scale.x))
	if state=="run":animation.speed_scale=rate
	if bloodhound_stride:
		bloodhound_stride.speed=speed
		var local=global_basis.inverse()*velocity
		var heading=atan2(local.x,local.z) if local.length_squared()>0.0001 else 0.0
		var backwards=absf(heading)>PI*0.5
		bloodhound_stride.heading=wrapf(heading+PI,-PI,PI) if backwards else heading
		if state=="run":bloodhound_stride.phase=animation.current_animation_position
		else:bloodhound_stride.phase=fposmod(bloodhound_stride.phase+delta*rate*(-1.0 if backwards else 1.0),clip_length("run"))

func bloodhound_socket(side: String) -> Vector3:
	var skeleton=_find_skeleton(model)
	if skeleton:
		var index=skeleton.find_bone("WeaponSocket."+side)
		if index>=0:
			# Offset in the socket's own bone frame (X lateral, Y along hand).
			var muzzle=Vector3(0.068 if side=="L" else -0.073,0.035+0.168+0.063,0.068-0.033)
			return skeleton.global_transform*skeleton.get_bone_global_pose(index)*muzzle
	return global_position+Vector3.UP

func bloodhound_bomb_position() -> Vector3:
	if bloodhound_skeleton:
		var index=bloodhound_skeleton.find_bone("Hand.L")
		if index>=0:return bloodhound_skeleton.global_transform*bloodhound_skeleton.get_bone_global_pose(index)*Vector3(.068,.072,-.03)
	return global_position+Vector3.UP

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
		# Held orb and projectile origin must share the casting hand in every clip.
		if String(hand_skeleton.get_bone_name(index)).ends_with("RightHand"):
			hand_bone=index;break
	if hand_bone<0:return
	hand_magic=Node3D.new();hand_magic.name="HandMagic";add_child(hand_magic)
	hand_magic.top_level=true
	# Reuse the projectile's core, dark curved shell and halo at a smaller held size.
	var tone=Color("ec45b5") if enemy_asset else Color("19cbff")
	var accent=Color("e02c50") if enemy_asset else Color("2448df")
	var factory=BWFx.new();factory.configure("Mobile" if OS.has_feature("mobile") else "PC")
	var orb=factory.orb_dressing(tone,not OS.has_feature("mobile"),accent)
	factory.free()
	hand_magic.add_child(orb)
	var lamp=OmniLight3D.new();lamp.light_color=tone;lamp.light_energy=0.7;lamp.omni_range=1.2;hand_magic.add_child(lamp)

func magic_palm_position() -> Vector3:
	if not is_instance_valid(hand_skeleton) or hand_bone<0:return global_position+Vector3.UP
	var pose=hand_skeleton.global_transform*hand_skeleton.get_bone_global_pose(hand_bone)
	return pose.origin+pose.basis.orthonormalized()*Vector3(0,0.10,0.035)

func _attach_blood_hands():
	hand_skeleton=_find_skeleton(model)
	if hand_skeleton==null:return
	var factory=BWFx.new();factory.configure("Mobile" if OS.has_feature("mobile") else "PC")
	for index in hand_skeleton.get_bone_count():
		var name=String(hand_skeleton.get_bone_name(index))
		if not name.ends_with("RightHand") and not name.ends_with("LeftHand") and not name in ["hand_r","hand_l"]:continue
		var aura=Node3D.new();aura.name="BloodHand";add_child(aura);aura.top_level=true
		aura.add_child(factory.glow_sprite(Color("ab102b"),0.23,0.55))
		aura.add_child(factory.trail_emitter(Color("c51634"),0.024,0.38,8,0.12))
		blood_hands.append({"bone":index,"node":aura})
	factory.free()

func _start_blood_death():
	death_elapsed=0.0
	for hand in blood_hands:hand.node.hide()
	for node in model.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var original=node.get_active_material(surface)
			if not original is StandardMaterial3D:continue
			var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/revenant_dissolve.gdshader")
			if original.albedo_texture!=null:mat.set_shader_parameter("body_texture",original.albedo_texture)
			mat.set_shader_parameter("body_tone",original.albedo_color)
			node.set_surface_override_material(surface,mat);death_materials.append(mat)

func _process(delta: float):
	if dead and not death_materials.is_empty():
		death_elapsed+=delta
		var start=revenant_time("death","ground")+0.15 if revenant_layers!=null else 0.65
		for mat in death_materials:mat.set_shader_parameter("progress",clampf((death_elapsed-start)/1.55,0,1))
	if not dead and is_instance_valid(hand_skeleton):
		for hand in blood_hands:
			var pose=hand_skeleton.global_transform*hand_skeleton.get_bone_global_pose(hand.bone)
			hand.node.global_position=pose.origin
			hand.node.scale=Vector3.ONE*(1.4 if state=="ultimate" else 1.0)
	if not is_instance_valid(hand_magic) or dead:return
	magic_time+=delta
	hand_magic.global_position=magic_palm_position()
	var pulse=0.75*(1.0+sin(magic_time*5)*0.06)
	if state=="ultimate" and lock_time>0:pulse*=1.8
	hand_magic.scale=Vector3.ONE*pulse
	hand_magic.get_node("ArcaneOrb/Motes").rotate_y(delta*TAU/0.9)

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
