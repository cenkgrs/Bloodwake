class_name BWFx
extends Node3D

# Every transient the fight draws: the sprites, rings, sparks, beams and floating
# numbers. None of it reads or writes gameplay state, so it lives away from the
# rules it decorates and can be exercised without a run in progress.
#
# Kept at the world's origin with an identity transform on purpose - the effects
# below are positioned in world coordinates, so moving this node would silently
# drag every one of them off its mark.

const SURFACE_SHADER = preload("res://shaders/combat_surface.gdshader")
const FLAME_SHADER = preload("res://shaders/arcane_flame.gdshader")
const TRAIL_SHADER = preload("res://shaders/arcane_trail.gdshader")
const CORE_SHADER = preload("res://shaders/arcane_core.gdshader")

var quality = "PC"
var rng = RandomNumberGenerator.new()
var glow_texture: GradientTexture2D
var ring_texture: GradientTexture2D

func configure(profile: String):
	quality=profile;rng.randomize()
	glow_texture=GradientTexture2D.new()
	glow_texture.fill=GradientTexture2D.FILL_RADIAL;glow_texture.fill_from=Vector2(0.5,0.5);glow_texture.fill_to=Vector2(0.5,1.0)
	glow_texture.width=96;glow_texture.height=96
	var ramp=Gradient.new()
	ramp.set_offset(0,0.0);ramp.set_color(0,Color(1,1,1,1))
	ramp.set_offset(1,1.0);ramp.set_color(1,Color(1,1,1,0))
	ramp.add_point(0.35,Color(1,1,1,0.55));ramp.add_point(0.7,Color(1,1,1,0.12))
	glow_texture.gradient=ramp
	ring_texture=GradientTexture2D.new()
	ring_texture.fill=GradientTexture2D.FILL_RADIAL;ring_texture.fill_from=Vector2(0.5,0.5);ring_texture.fill_to=Vector2(0.5,1.0)
	ring_texture.width=128;ring_texture.height=128
	var rim=Gradient.new()
	rim.set_offset(0,0.0);rim.set_color(0,Color(1,1,1,0))
	rim.set_offset(1,1.0);rim.set_color(1,Color(1,1,1,0))
	rim.add_point(0.55,Color(1,1,1,0.08));rim.add_point(0.8,Color(1,1,1,1.0));rim.add_point(0.92,Color(1,1,1,0.18))
	ring_texture.gradient=rim

func radial_streaks(pos: Vector3,radius: float,color: Color,count: int,duration: float=0.26):
	for i in count:
		var angle=TAU*i/count+rng.randf_range(-0.34,0.34)
		var reach=radius*rng.randf_range(0.5,1.15)
		var lance=flat_sprite(color,radius*rng.randf_range(0.07,0.15),reach*0.9,2.0)
		lance.position=pos+Vector3.UP*0.09;add_child(lance)
		lance.rotation.y=angle
		lance.get_child(0).position.z=-reach*0.5
		lance.scale=Vector3(1,1,0.25)
		var mat=lance.get_child(0).material_override
		var tween=create_tween();tween.set_parallel(true)
		tween.tween_property(lance,"scale",Vector3.ONE,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(mat,"albedo_color",Color(0,0,0),duration)
		tween.chain().tween_callback(lance.queue_free)

func flash_light(pos: Vector3,color: Color,energy: float,range_value: float,duration: float):
	if quality!="PC":return
	var lamp=OmniLight3D.new();lamp.light_color=color;lamp.light_energy=energy;lamp.omni_range=range_value
	lamp.position=pos+Vector3.UP*0.8;add_child(lamp)
	var tween=create_tween()
	tween.tween_property(lamp,"light_energy",0.0,duration)
	tween.tween_callback(lamp.queue_free)

static func arcane_material(tone: Color,accent: Color=Color("234aff")) -> ShaderMaterial:
	var mat=ShaderMaterial.new();mat.shader=CORE_SHADER;mat.set_shader_parameter("tone",tone);mat.set_shader_parameter("accent",accent)
	return mat

func arcane_core(tone: Color,radius: float) -> MeshInstance3D:
	var core=MeshInstance3D.new();var sphere=SphereMesh.new()
	sphere.radius=radius;sphere.height=radius*2.0;sphere.radial_segments=20;sphere.rings=10
	core.mesh=sphere;core.material_override=arcane_material(tone)
	core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return core

# Two crossed sheets give the moving plasma tail volume without a particle cloud.
func arcane_tail(tone: Color,accent: Color,length_value: float=2.1) -> Node3D:
	var rig=Node3D.new();rig.name="PlasmaTail"
	var mat=ShaderMaterial.new();mat.shader=TRAIL_SHADER
	mat.set_shader_parameter("tone",tone);mat.set_shader_parameter("accent",accent)
	for i in (2 if quality=="PC" else 1):
		var sheet=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(0.85,length_value)
		sheet.mesh=plane;sheet.material_override=mat;sheet.position.z=length_value*0.48
		sheet.rotation.z=PI*0.5*i;sheet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;rig.add_child(sheet)
	return rig

# Three curved dark blades orbit the energy, like the reference's broken shell.
func orb_dressing(tone: Color,rich: bool,accent: Color=Color("234aff")) -> Node3D:
	var rig=Node3D.new();rig.name="ArcaneOrb"
	rig.add_child(glow_sprite(tone,0.95,0.65))
	var core=arcane_core(tone,0.21);core.material_override=arcane_material(tone,accent);rig.add_child(core)
	var motes=Node3D.new();motes.name="Motes";rig.add_child(motes)
	var shell_material=StandardMaterial3D.new();shell_material.albedo_color=accent.darkened(0.75)
	shell_material.metallic=0.55;shell_material.roughness=0.5
	shell_material.emission_enabled=true;shell_material.emission=tone;shell_material.emission_energy_multiplier=0.06
	shell_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var blade=ImmediateMesh.new();blade.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var t0=i/10.0;var t1=(i+1)/10.0
		var a0=t0*1.7;var a1=t1*1.7
		var outer0=Vector3(cos(a0),0,sin(a0))*(0.29+sin(t0*PI)*0.10)
		var outer1=Vector3(cos(a1),0,sin(a1))*(0.29+sin(t1*PI)*0.10)
		var inner0=Vector3(cos(a0),0.035,sin(a0))*0.28
		var inner1=Vector3(cos(a1),0.035,sin(a1))*0.28
		for v in [outer0,inner0,outer1,outer1,inner0,inner1]:
			blade.surface_set_normal(Vector3.UP);blade.surface_add_vertex(v)
	blade.surface_end()
	for i in 3:
		var shard=MeshInstance3D.new();shard.mesh=blade;shard.material_override=shell_material
		shard.rotation=Vector3(0.5,TAU*i/3.0,0.45);shard.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;motes.add_child(shard)
		if rich:
			var mote=glow_sprite(tone.lightened(0.25),0.1,1.2);mote.position=Vector3.RIGHT.rotated(Vector3.UP,TAU*i/3.0)*0.31;motes.add_child(mote)
	return rig

func flame_crown(pos: Vector3,radius: float,tone: Color,accent: Color):
	var root=Node3D.new();root.position=pos;add_child(root)
	var mat=ShaderMaterial.new();mat.shader=FLAME_SHADER
	mat.set_shader_parameter("tone",tone);mat.set_shader_parameter("accent",accent)
	var count=18 if quality=="PC" else 8
	var quad=QuadMesh.new();quad.size=Vector2(0.7,1.25)
	for i in count:
		var angle=TAU*i/count+rng.randf_range(-0.05,0.05)
		var tall=rng.randf_range(0.55,1.1)
		var flame=MeshInstance3D.new();flame.mesh=quad;flame.material_override=mat
		flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position=Vector3(cos(angle),0,sin(angle))*radius*0.91+Vector3.UP*tall*0.6
		flame.rotation.y=-angle+PI/2;flame.scale=Vector3(1,tall,1);root.add_child(flame)
	root.scale=Vector3.ONE*0.2
	var tween=root.create_tween();tween.set_parallel(true)
	tween.tween_property(root,"scale",Vector3.ONE,0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float):mat.set_shader_parameter("progress",value),0.0,1.0,0.7)
	tween.chain().tween_callback(root.queue_free)

func arcane_blast(pos: Vector3,radius: float,tone: Color,accent: Color):
	surface(pos+Vector3.UP*0.08,radius,tone,0.85,3,0.95)
	shockwave(pos,radius,tone,0.42,0.0,1.6)
	flame_crown(pos,radius,tone,accent)
	burst_ring(pos,radius,tone,28 if quality=="PC" else 12,3.5,0.65)
	flash_light(pos,tone,2.2,radius*1.25,0.3)

# Radius is the actual outer boundary, not the size of a blurry sprite.
func surface(pos: Vector3,radius: float,color: Color,duration: float,shape: int,energy: float=1.2,delay: float=0.0) -> Node3D:
	var pivot=Node3D.new();pivot.position=pos;add_child(pivot)
	var plane=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2.ONE*radius*2.0
	plane.mesh=quad;plane.rotation.x=-PI/2;plane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat=ShaderMaterial.new();mat.shader=SURFACE_SHADER
	mat.set_shader_parameter("tone",color);mat.set_shader_parameter("shape",shape);mat.set_shader_parameter("energy",energy)
	plane.material_override=mat;pivot.add_child(plane)
	pivot.visible=delay<=0
	var tween=pivot.create_tween()
	if delay>0:
		tween.tween_interval(delay);tween.tween_callback(func():pivot.visible=true)
	tween.tween_method(func(value: float):mat.set_shader_parameter("progress",value),0.0,1.0,maxf(duration,0.01))
	tween.tween_callback(pivot.queue_free)
	return pivot

func telegraph(pos: Vector3,radius: float,color: Color,duration: float) -> Node3D:
	return surface(pos+Vector3.UP*0.055,radius,color,duration,2,0.9)

func ring(pos: Vector3,radius: float,color: Color,duration: float):
	surface(pos+Vector3.UP*0.065,radius,color,duration,0,1.15)

# A swing reads as an arc swept in front of the fighter, not a circle drawn around it.

func slash(origin: Vector3,direction: Vector3,radius: float,color: Color):
	var pivot=surface(origin+Vector3.UP*0.6,radius,color,0.22,1,1.6)
	aim_along(pivot,direction);pivot.rotation.y+=0.45
	var tween=pivot.create_tween()
	tween.tween_property(pivot,"rotation:y",pivot.rotation.y-0.9,0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func beam(a: Vector3,b: Vector3,color: Color,duration: float=0.15):
	var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES);mesh.surface_add_vertex(a);mesh.surface_add_vertex((a+b)*0.5+Vector3(0.1,0.2,0.1));mesh.surface_add_vertex((a+b)*0.5+Vector3(0.1,0.2,0.1));mesh.surface_add_vertex(b);mesh.surface_end()
	var node=MeshInstance3D.new();node.mesh=mesh;var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=color;mesh.surface_set_material(0,mat);node.material_override=mat;add_child(node)
	get_tree().create_timer(duration).timeout.connect(node.queue_free)

# A soft additive billboard. Layering two or three of these at different sizes is
# what turns a flat coloured dot into something that reads as light.

func glow_sprite(color: Color,size: float,energy: float=1.0) -> MeshInstance3D:
	var quad=QuadMesh.new();quad.size=Vector2(size,size)
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;mat.billboard_keep_scale=true
	mat.albedo_texture=glow_texture;mat.albedo_color=Color(color.r*energy,color.g*energy,color.b*energy)
	mat.disable_receive_shadows=true
	var node=MeshInstance3D.new();node.mesh=quad;node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

# local_coords=false leaves emitted particles behind in world space, so a moving
# emitter draws a trail instead of dragging its particles along with it.

func trail_emitter(color: Color,radius: float,life: float,amount: int,drift: float=0.4) -> CPUParticles3D:
	var p=CPUParticles3D.new()
	p.amount=amount;p.lifetime=life;p.local_coords=false;p.explosiveness=0.0
	p.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;p.emission_sphere_radius=radius
	p.direction=Vector3.UP;p.spread=180;p.initial_velocity_min=0.0;p.initial_velocity_max=drift
	p.gravity=Vector3.ZERO;p.damping_min=0.6;p.damping_max=1.2
	p.scale_amount_min=0.6;p.scale_amount_max=1.0
	var curve=Curve.new();curve.add_point(Vector2(0,1.0));curve.add_point(Vector2(1,0.0))
	var shrink=CurveTexture.new();shrink.curve=curve;p.scale_amount_curve=shrink
	var ramp=Gradient.new()
	ramp.set_offset(0,0.0);ramp.set_color(0,color)
	ramp.set_offset(1,1.0);ramp.set_color(1,Color(color.r,color.g,color.b,0.0))
	p.color_ramp=ramp
	var mesh=SphereMesh.new();mesh.radius=radius*0.9;mesh.height=radius*1.8;mesh.radial_segments=5;mesh.rings=3
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo=true;mat.albedo_color=color
	mesh.material=mat;p.mesh=mesh;p.material_override=mat
	p.emitting=true
	return p

func flat_sprite(color: Color,width: float,length: float,energy: float=1.0,texture: Texture2D=null) -> Node3D:
	var quad=QuadMesh.new();quad.size=Vector2(width,length)
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture=texture if texture!=null else glow_texture
	mat.albedo_color=Color(color.r*energy,color.g*energy,color.b*energy)
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.disable_receive_shadows=true
	var blade=MeshInstance3D.new();blade.mesh=quad;blade.material_override=mat
	blade.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blade.rotation.x=-PI*0.5
	var pivot=Node3D.new();pivot.add_child(blade)
	return pivot

# An expanding pressure front. Several of these staggered read as a blast rolling
# outwards rather than one circle appearing at full size.

func shockwave(pos: Vector3,radius: float,color: Color,duration: float,delay: float=0.0,energy: float=1.6):
	surface(pos+Vector3.UP*0.07,radius,color,duration,0,energy*0.7,delay)

# Particles thrown outward along the ground from a ring, for dust and frost fronts.

func burst_ring(pos: Vector3,radius: float,color: Color,amount: int,speed: float=3.0,life: float=0.5):
	if quality!="PC" and rng.randf()>0.5:return
	var p=CPUParticles3D.new()
	p.amount=amount;p.lifetime=life;p.one_shot=true;p.explosiveness=0.95
	p.emission_shape=CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis=Vector3.UP;p.emission_ring_radius=radius*0.55;p.emission_ring_inner_radius=radius*0.2
	p.emission_ring_height=0.1
	p.direction=Vector3.UP;p.spread=25;p.initial_velocity_min=speed*0.3;p.initial_velocity_max=speed*0.6
	p.radial_accel_min=speed*1.6;p.radial_accel_max=speed*2.6
	p.gravity=Vector3(0,-3.0,0);p.damping_min=0.8;p.damping_max=1.6
	p.scale_amount_min=0.5;p.scale_amount_max=1.1
	var curve=Curve.new();curve.add_point(Vector2(0,1.0));curve.add_point(Vector2(1,0.0))
	var shrink=CurveTexture.new();shrink.curve=curve;p.scale_amount_curve=shrink
	var mesh=SphereMesh.new();mesh.radius=0.022;mesh.height=0.044;mesh.radial_segments=4;mesh.rings=2
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;mat.albedo_color=color
	mesh.material=mat;p.mesh=mesh;p.material_override=mat
	p.position=pos;add_child(p);p.emitting=true
	get_tree().create_timer(life+0.25).timeout.connect(p.queue_free)

# Spikes driven up out of the ground around a radius - the frost nova's silhouette.

func shards(pos: Vector3,radius: float,color: Color,count: int):
	var mesh=CylinderMesh.new();mesh.top_radius=0.0;mesh.bottom_radius=0.12;mesh.height=1.0;mesh.radial_segments=5;mesh.rings=1
	var mat=StandardMaterial3D.new();mat.albedo_color=color
	mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=1.1
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.roughness=0.25
	for i in count:
		var angle=TAU*i/count+rng.randf_range(-0.16,0.16)
		var spike=MeshInstance3D.new();spike.mesh=mesh;spike.material_override=mat
		spike.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spike.position=pos+Vector3(cos(angle),0,sin(angle))*radius*rng.randf_range(0.55,0.95)
		spike.rotation=Vector3(rng.randf_range(-0.22,0.22),angle,rng.randf_range(-0.22,0.22))
		var tall=rng.randf_range(0.5,1.0)
		spike.scale=Vector3(1,0.05,1);add_child(spike)
		var tween=create_tween()
		tween.tween_property(spike,"scale",Vector3(1,tall,1),0.11).set_delay(i*0.012).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.2)
		tween.tween_property(spike,"scale",Vector3(0.2,0.02,0.2),0.22)
		tween.tween_callback(spike.queue_free)

func impact(pos: Vector3,weapon: String,friendly: bool):
	var magic=weapon in ["magic_orb","enemy_magic_orb"]
	var tone=(Color("23cfff") if friendly else Color("ed46b8")) if magic else (Color("ffcf8a") if friendly else Color("ff8a72"))
	spark(pos,tone,16 if magic else 9)
	var burst=glow_sprite(tone,0.75 if magic else 0.6,1.15)
	burst.position=pos;add_child(burst)
	var tween=create_tween();tween.set_parallel(true)
	tween.tween_property(burst,"scale",Vector3.ONE*(1.7 if magic else 1.4),0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst.material_override,"albedo_color",Color(0,0,0),0.18)
	tween.chain().tween_callback(burst.queue_free)
	if magic:
		surface(Vector3(pos.x,0.08,pos.z),0.9,tone,0.4,3,1.1)
		shockwave(Vector3(pos.x,0,pos.z),0.9,tone,0.3)

func spark(pos: Vector3,color: Color,amount: int=8):
	if quality!="PC" and rng.randf()>0.45:return
	var node=CPUParticles3D.new();node.amount=amount;node.lifetime=0.3;node.one_shot=true;node.explosiveness=1.0
	node.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;node.emission_sphere_radius=0.09
	node.direction=Vector3.UP;node.spread=180;node.initial_velocity_min=1.3;node.initial_velocity_max=3.4
	node.gravity=Vector3(0,-5.5,0);node.scale_amount_min=0.45;node.scale_amount_max=1.0
	var mesh=PrismMesh.new();mesh.size=Vector3(0.025,0.09,0.018)
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=color
	mesh.material=mat;node.mesh=mesh;node.material_override=mat
	node.position=pos;add_child(node);node.emitting=true
	get_tree().create_timer(node.lifetime+0.15).timeout.connect(node.queue_free)

func muzzle(pos: Vector3,direction: Vector3,color: Color):
	if quality!="PC":return
	var node=glow_sprite(color,0.7,1.5)
	node.position=pos;add_child(node)
	var mat=node.material_override
	aim_along(node,direction);node.scale=Vector3(1.5,1,1)
	var lamp=OmniLight3D.new();lamp.light_color=color;lamp.light_energy=1.7;lamp.omni_range=1.5;node.add_child(lamp)
	var tween=create_tween();tween.set_parallel(true)
	tween.tween_property(node,"scale",Vector3(0.2,0.2,0.5),0.07)
	tween.tween_property(mat,"albedo_color:a",0.0,0.07)
	tween.chain().tween_callback(node.queue_free)

# look_at needs a target that is not colinear with UP; aim vectors are horizontal
# here, but guard anyway so a stray vertical direction cannot spam errors.

func aim_along(node: Node3D,direction: Vector3):
	if direction.length_squared()<0.0001:return
	var d=direction.normalized()
	if absf(d.y)>0.99:return
	node.rotation=Vector3(0,atan2(-d.x,-d.z),0)

func damage_text(pos: Vector3,amount: float,color: Color):
	if quality!="PC" and randf()>0.4:return
	var label=Label3D.new();label.text=str(int(round(amount)));label.font_size=38;label.pixel_size=0.008;label.modulate=color;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.position=pos+Vector3(rng.randf_range(-0.2,0.2),2.0,0);add_child(label)
	var tween=create_tween();tween.set_parallel(true);tween.tween_property(label,"position:y",label.position.y+0.6,0.55);tween.tween_property(label,"modulate:a",0.0,0.55);tween.chain().tween_callback(label.queue_free)

# Physical impact: fragments rise and fall, dust settles, the cracked imprint
# remains for 1.9 seconds. All animation belongs to the impact's own root.
func ground_impact(pos: Vector3,radius: float):
	var root=Node3D.new();root.name="GroundImpact";root.position=pos;add_child(root)
	var scar=MeshInstance3D.new();scar.name="Scar"
	var plane=PlaneMesh.new();plane.size=Vector2.ONE*radius*2.0;scar.mesh=plane
	var ink=ShaderMaterial.new();ink.shader=preload("res://shaders/ground_scar.gdshader")
	scar.material_override=ink;scar.position.y=0.035;scar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(scar)
	var rock=PrismMesh.new();rock.size=Vector3(0.24,0.23,0.20)
	var stone=StandardMaterial3D.new();stone.albedo_color=Color("625343");stone.roughness=1.0
	var count=14 if quality=="PC" else 7
	for i in count:
		var angle=TAU*i/count+rng.randf_range(-0.2,0.2)
		var direction=Vector3(cos(angle),0,sin(angle))
		var piece=MeshInstance3D.new();piece.mesh=rock;piece.material_override=stone
		piece.position=direction*radius*rng.randf_range(0.12,0.4)
		piece.rotation=Vector3(rng.randf(),angle,rng.randf());piece.scale=Vector3.ONE*rng.randf_range(0.6,1.7)
		piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(piece)
		var landing=direction*radius*rng.randf_range(0.55,0.95);landing.y=0.08
		var apex=(piece.position+landing)*0.5+Vector3.UP*rng.randf_range(0.35,0.95)
		var flight=piece.create_tween()
		flight.tween_property(piece,"position",apex,0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flight.tween_property(piece,"position",landing,0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flight.tween_interval(0.65)
		flight.tween_property(piece,"scale",Vector3.ZERO,0.35)
	var dust=CPUParticles3D.new();dust.amount=22 if quality=="PC" else 10
	dust.one_shot=true;dust.explosiveness=1.0;dust.lifetime=0.8
	dust.direction=Vector3.UP;dust.spread=75;dust.initial_velocity_min=0.6;dust.initial_velocity_max=1.7
	dust.gravity=Vector3(0,-0.8,0);dust.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;dust.emission_sphere_radius=radius*0.4
	var puff=QuadMesh.new();puff.size=Vector2(0.7,0.7)
	var haze=StandardMaterial3D.new();haze.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;haze.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	haze.albedo_texture=glow_texture;haze.albedo_color=Color("8a7460");haze.vertex_color_use_as_albedo=true
	puff.material=haze;dust.mesh=puff
	var ramp=Gradient.new();ramp.set_color(0,Color(1,1,1,0.38));ramp.set_color(1,Color(1,1,1,0));dust.color_ramp=ramp
	root.add_child(dust);dust.emitting=true
	var lifetime=root.create_tween()
	lifetime.tween_method(func(value: float):ink.set_shader_parameter("age",value),0.0,1.9,1.9)
	lifetime.tween_callback(root.queue_free)
