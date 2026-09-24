class_name BWVisual
extends Node3D

var animation: AnimationPlayer
var clips = {}
var state = ""
var lock_time = 0.0
var model: Node3D
var dead = false
var procedural = false
var elapsed = 0.0
var base_y = 0.0

func configure(kind: String, enemy: bool = false, tint: Color = Color.WHITE, height: float = 1.8):
 var file = {"gunslinger":"bloodbound","warrior":"warrior","assassin":"assassin"}.get(kind,"warrior")
 if kind=="mage":
  _mage(tint);procedural=true;return
 var packed = load("res://assets/models/%s.glb" % file)
 if not packed is PackedScene:
  _mage(tint);procedural=true;return
 model=packed.instantiate();add_child(model)
 animation=_find_animation(model)
 if animation:
  for anim_name in animation.get_animation_list():
   var key=String(anim_name).to_lower()
   for pair in [["idle","idle"],["run","run"],["walk","run"],["attack","attack"],["hit","hit"],["death","death"],["die","death"],["fall","death"]]:
    if key.contains(pair[0]) and not clips.has(pair[1]):clips[pair[1]]=anim_name
  if kind=="warrior":
   for desired in {"idle":"Idle_Weapon","run":"Run_Weapon","attack":"Sword_Attack","hit":"RecieveHit","death":"Death"}:
    var source={"idle":"Idle_Weapon","run":"Run_Weapon","attack":"Sword_Attack","hit":"RecieveHit","death":"Death"}[desired]
    if animation.has_animation(source):clips[desired]=source
  for clip in clips:
   var anim=animation.get_animation(clips[clip])
   anim.loop_mode=Animation.LOOP_LINEAR if clip in ["idle","run"] else Animation.LOOP_NONE
  if clips.has("idle"):animation.play(clips.idle);animation.advance(0)
 var bounds=_bounds(model)
 if bounds.size.y>0.01:
  var ratio=height/bounds.size.y
  model.scale=Vector3.ONE*ratio
  model.position=Vector3(-bounds.get_center().x*ratio,-bounds.position.y*ratio,-bounds.get_center().z*ratio)
 base_y=model.position.y
 if enemy:_tint(model,tint)
 play("idle")

func _find_animation(node: Node) -> AnimationPlayer:
 if node is AnimationPlayer:return node
 for child in node.get_children():
  var found=_find_animation(child)
  if found:return found
 return null

func _bounds(node: Node3D) -> AABB:
 var bounds=AABB();var first=true
 for mesh in _meshes(node):
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

func play(next: String):
 if dead and next!="death":return
 if next==state:return
 state=next
 if animation and clips.has(next):animation.play(clips[next],0.12)

func action(next: String):
 if dead:return
 if next=="attack" and lock_time>0:return
 if next=="death":dead=true
 if animation and clips.has(next):
  animation.play(clips[next],0.08)
  lock_time=animation.get_animation(clips[next]).length
  state=next
 else:
  lock_time=0.25 if next!="death" else 1.0
  if next=="death":create_tween().tween_property(self,"rotation:z",PI*0.48,0.7)

func tick(delta: float,moving: bool):
 elapsed+=delta;lock_time=maxf(0,lock_time-delta)
 if (procedural or animation==null) and not dead:
  model.position.y=sin(elapsed*(10 if moving else 2))*0.035
 if not dead and lock_time<=0:play("run" if moving else "idle")

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
