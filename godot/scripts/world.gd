class_name BWWorld
extends Node3D

signal wave_cleared
signal run_ended
signal changed

var run: BWRun
var player: Node3D
var visual: BWVisual
var camera: Camera3D
var enemies: Array = []
var bullets: Array = []
var pickups: Array = []
var spawn_timer = 0.0
var spawned = 0
var running = true
var auto_fire = true
var move_input = Vector2.ZERO
var touch_aim = Vector2.ZERO
var aim = Vector3.FORWARD
var last_move = Vector3.FORWARD
var quality = "PC"
var elapsed = 0.0
var rest_time = 0.0
var hit_flash = 0.0
var shake = 0.0
var audio_times = {}
var pending_attacks: Array = []
var bullet_mesh: SphereMesh
var bullet_material: StandardMaterial3D
var rng = RandomNumberGenerator.new()
const ARENA_HALF = 24.0
const ENEMY_COLORS = {"grunt":"8b6256","archer":"9a789e","tank":"65463f","assassin":"667482","healer":"72b78e","commander":"c4a75e","boss":"8a3440"}

func start(state: BWRun,profile: String="PC"):
 run=state;quality=profile;rng.randomize()
 _environment()
 player=Node3D.new();player.name="Player";add_child(player)
 # Enemies read as 1.7-3.5 m (tanks/bosses run bigger on purpose); the player
 # was left at the 1.8 m rig default and looked undersized next to them.
 visual=BWVisual.new();player.add_child(visual);visual.configure(run.class_id,false,Color.WHITE,2.05)
 get_viewport().msaa_3d=Viewport.MSAA_4X if quality=="PC" else Viewport.MSAA_DISABLED
 var fill=OmniLight3D.new();fill.position=Vector3(0,2.5,1);fill.omni_range=4;fill.light_energy=1.0;fill.light_color=Color("d1def0");player.add_child(fill)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=17
 camera.position=Vector3(0,16,12);camera.current=true;add_child(camera);camera.look_at(Vector3.ZERO)
 bullet_mesh=SphereMesh.new();bullet_mesh.radius=0.07;bullet_mesh.height=0.14;bullet_mesh.radial_segments=8;bullet_mesh.rings=4
 bullet_material=StandardMaterial3D.new();bullet_material.albedo_color=Color("ffd99a");bullet_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED

func _environment():
 var env_node=WorldEnvironment.new();var env=Environment.new()
 env.background_mode=Environment.BG_COLOR;env.background_color=Color("121923")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("a6bad0");env.ambient_light_energy=0.55
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 env_node.environment=env;add_child(env_node)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-25,0);sun.light_color=Color("b4c7e0");sun.light_energy=1.5;sun.shadow_enabled=quality=="PC";sun.directional_shadow_max_distance=45;add_child(sun)
 var floor=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(48,48);floor.mesh=plane
 var mat=StandardMaterial3D.new();mat.albedo_texture=load("res://assets/art/arena.png");mat.uv1_scale=Vector3(10,10,10);mat.roughness=0.95;mat.albedo_color=Color("555d67");floor.material_override=mat;add_child(floor)
 var stone=StandardMaterial3D.new();stone.albedo_color=Color("303844");stone.roughness=0.9
 for edge in 4:
  var wall=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(49,1.0,0.45);wall.mesh=box;wall.material_override=stone
  wall.position=Vector3(0,0.5,-24) if edge==0 else Vector3(0,0.5,24) if edge==1 else Vector3(-24,0.5,0) if edge==2 else Vector3(24,0.5,0)
  if edge>1:wall.rotation.y=PI/2
  add_child(wall)
 for i in 16:
  var angle=TAU*i/16;var pillar=MeshInstance3D.new();var cylinder=CylinderMesh.new();cylinder.top_radius=0.28;cylinder.bottom_radius=0.36;cylinder.height=2.4;cylinder.radial_segments=8
  pillar.mesh=cylinder;pillar.material_override=stone;pillar.position=Vector3(cos(angle)*22.3,1.2,sin(angle)*22.3);add_child(pillar)
  var fire=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=0.15;sphere.height=0.35;fire.mesh=sphere;fire.position=pillar.position+Vector3.UP*1.35
  var glow=StandardMaterial3D.new();glow.albedo_color=Color("ff9b48");glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;fire.material_override=glow;add_child(fire)
  if quality=="PC":
   var lamp=OmniLight3D.new();lamp.position=fire.position;lamp.light_color=Color("ff9854");lamp.light_energy=1.3;lamp.omni_range=4;add_child(lamp)

func _physics_process(dt: float):
 if run==null:return
 if not running:
  visual.tick(dt,false)
  return
 elapsed+=dt
 if rest_time>0:
  rest_time=maxf(0,rest_time-dt)
  if rest_time==0:changed.emit()
 run.ability_cd=maxf(0,run.ability_cd-dt)
 run.stats.hp=minf(run.stats.maxHp,run.stats.hp+run.stats.regenPerSecond*dt)
 # Enemies get visibly bigger/tankier as the run goes on (elite odds and the
 # tank/boss mix both climb with wave); grow the player to match instead of
 # shrinking into an ant by wave 10, capped so a long run doesn't get silly.
 visual.set_level_scale(1.0+minf(run.level-1,20)*0.015)
 var input=Input.get_vector("move_left","move_right","move_up","move_down")+move_input
 input=input.limit_length()
 var movement=Vector3(input.x,0,input.y)
 player.position+=movement*run.stats.moveSpeed*BWData.UNIT*dt
 player.position.x=clampf(player.position.x,-23.5,23.5);player.position.z=clampf(player.position.z,-23.5,23.5)
 if movement.length_squared()>0.001:last_move=movement.normalized()
 var aim_stick=Input.get_vector("aim_left","aim_right","aim_up","aim_down")
 if touch_aim.length_squared()>0.04:aim=Vector3(touch_aim.x,0,touch_aim.y).normalized()
 elif aim_stick.length_squared()>0.04:aim=Vector3(aim_stick.x,0,aim_stick.y).normalized()
 elif Input.is_action_pressed("fire") and not OS.has_feature("mobile"):
  var mouse=get_viewport().get_mouse_position();var plane=Plane(Vector3.UP,0)
  var hit=plane.intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
  if hit!=null and player.position.distance_squared_to(hit)>0.01:aim=(hit-player.position).normalized()
 elif movement.length_squared()>0.001:aim=last_move
 var facing=aim if Input.is_action_pressed("fire") or aim_stick.length_squared()>0.04 else last_move
 if facing.length_squared()>0.01:visual.rotation.y=lerp_angle(visual.rotation.y,atan2(facing.x,facing.z),minf(1,dt*16))
 visual.tick(dt,movement.length_squared()>0.001,run.stats.moveSpeed/BWData.stats(run.class_id).moveSpeed)
 var desired=player.position+Vector3(0,16,12);camera.position=camera.position.lerp(desired,1-exp(-dt*10))
 if shake>0:camera.position+=Vector3(rng.randf_range(-shake,shake),rng.randf_range(-shake,shake),0);shake=move_toward(shake,0,dt*2)
 _pending_attacks(dt)
 _weapons(dt)
 for enemy in enemies.duplicate():
  if is_instance_valid(enemy.node):_enemy_tick(enemy,dt)
 _projectiles(dt)
 if run.stats.hp>0:_pickups(dt)
 if run.stats.hp<=0:
  running=false;pending_attacks.clear();visual.action("death");sound("game_over",0.0)
  run_ended.emit()
 elif rest_time<=0:_spawn_tick(dt)

func _spawn_tick(dt: float):
 var rules=BWData.wave_rules(run.wave)
 if spawned>=rules.quota:
  if enemies.is_empty():
   for pickup in pickups:
    if pickup.kind=="xp":run.add_xp(pickup.amount)
    pickup.node.queue_free()
   pickups.clear();pending_attacks.clear();running=false;wave_cleared.emit()
  return
 spawn_timer-=dt
 if spawn_timer>0 or enemies.size()>=rules.cap:return
 spawn_timer=rules.interval
 var id="boss"
 if not rules.boss:
  var pool=[]
  for row in BWData.rows("enemies"):
   if row.id!="boss" and run.wave>=row.get("unlockWave",1):
    for n in int(row.get("spawnWeight",1)):pool.append(row.id)
  id=pool[rng.randi_range(0,pool.size()-1)]
 var angle=rng.randf()*TAU;var pos=player.position+Vector3(cos(angle),0,sin(angle))*10.4
 pos.x=clampf(pos.x,-23,23);pos.z=clampf(pos.z,-23,23)
 spawn_enemy(id,pos,not rules.boss and rng.randf()<rules.elite,rules.multiplier if not rules.boss else 1.0)
 spawned+=1

func spawn_enemy(id: String,pos: Vector3,elite: bool=false,multiplier: float=1.0):
 var data=BWData.entry("enemies",id)
 var actor=Node3D.new();add_child(actor);actor.position=pos
 var art=BWVisual.new();actor.add_child(art)
 var color=Color(ENEMY_COLORS[id]);if elite:color=Color("c59857")
 art.configure(id,true,color,3.5 if id=="boss" else 2.3 if id=="tank" else 1.9 if elite else 1.7)
 var max_hp=data.maxHp*multiplier*(2.5 if elite else 1)
 var enemy={"id":id,"data":data,"node":actor,"visual":art,"hp":max_hp,"maxHp":max_hp,"damage":data.damage*multiplier*(1.4 if elite else 1),"speed":data.moveSpeed*(1.15 if elite else 1),"radius":data.radius*BWData.UNIT*(1.35 if elite else 1),"elite":elite,"cooldown":2.5 if id=="boss" else rng.randf()*0.7,"state":"chase","timer":0.0,"summon":7.0,"phase":1,"pending_phase":1,"aura":0.0,"slow":0.0,"slow_amount":0.0,"burn":0.0,"burn_dps":0.0,"bleed":0.0,"bleed_dps":0.0,"status_tick":0.0}
 enemies.append(enemy)
 return enemy

func _enemy_tick(e: Dictionary,dt: float):
 if e.hp<=0:return
 var node=e.node;var data=e.data
 e.aura=maxf(0,e.aura-dt);e.slow=maxf(0,e.slow-dt)
 for status in ["burn","bleed"]:
  if e[status]>0:
   e[status]=maxf(0,e[status]-dt)
   _damage_enemy(e,e[status+"_dps"]*dt,false,false)
   if e.hp<=0:return
 var delta=player.position-node.position;delta.y=0
 var distance=delta.length();var direction=delta.normalized()
 var speed=e.speed*BWData.UNIT*(1.22 if e.aura>0 else 1)*(1-e.slow_amount if e.slow>0 else 1)
 var move=Vector3.ZERO;e.cooldown-=dt
 var range_value=data.attackRange*BWData.UNIT
 match e.id:
  "archer":
   var preferred=data.preferredRange*BWData.UNIT
   if distance<preferred*0.75:move=-direction*speed
   elif distance>preferred*1.1:move=direction*speed
   if distance<=range_value and e.cooldown<=0:
    _bullet(node.position,direction,data.projectileSpeed*BWData.UNIT,e.damage*(1.25 if e.aura>0 else 1),range_value,false,0,"",0,0,false)
    e.cooldown=data.attackCooldown;e.visual.action("attack")
  "healer","commander":
   var preferred=data.preferredRange*BWData.UNIT
   if distance<preferred*(0.65 if e.id=="commander" else 1):move=-direction*speed
   elif distance>preferred*1.5:move=direction*speed*0.4
   if e.cooldown<=0:
    e.cooldown=data.attackCooldown
    var best={};var missing=0.0
    for ally in enemies:
     if ally==e or ally.node.position.distance_to(node.position)>data.supportRadius*BWData.UNIT:continue
     if e.id=="commander" and ally.id not in ["commander","boss"]:ally.aura=data.auraDuration
     elif e.id=="healer" and ally.maxHp-ally.hp>missing:best=ally;missing=ally.maxHp-ally.hp
    if not best.is_empty():best.hp=minf(best.maxHp,best.hp+data.healAmount*(2.5 if e.elite else 1))
    ring(node.position,data.supportRadius*BWData.UNIT,Color("619c82") if e.id=="healer" else Color("cfab53"),0.45)
  "assassin":
   e.timer-=dt
   match e.state:
    "chase":
     if distance<3.2:e.state="vanish";e.timer=0.35;e.visual.visible=false
     else:move=direction*speed
    "vanish":
     if e.timer<=0:
      var angle=rng.randf()*TAU;node.position=player.position+Vector3(cos(angle),0,sin(angle))*3.2;e.visual.visible=true;e.state="dash"
    "dash":
     if distance<range_value+0.15:
      _hurt_player(e.damage*(1.25 if e.aura>0 else 1));e.visual.action("attack");e.state="retreat";e.timer=0.7
     else:move=direction*speed*4.5
    "retreat":
     move=-direction*speed*1.3
     if e.timer<=0:e.state="chase"
  "boss":
   var phase=1 if e.hp/e.maxHp>0.66 else 2 if e.hp/e.maxHp>0.33 else 3
   if phase!=e.phase:e.phase=phase;sound("boss_phase");shake=0.15
   if e.state=="telegraph":
    e.timer-=dt
    if e.timer<=0:
     match e.pending_phase:
      1:
       if distance<=1.4+0.36:_hurt_player(e.damage)
       e.cooldown=2.0
      2:
       for i in 3:_bullet(node.position,direction.rotated(Vector3.UP,(i-1)*0.3),5.2,e.damage*0.6,10.4,false,0,"",0,0,false)
       e.cooldown=1.6
      3:
       if distance<=3:_hurt_player(e.damage*0.75)
       e.cooldown=2.4
     e.visual.action("attack");e.state="chase"
   else:
    var preferred=1.4 if phase==1 else 6.24 if phase==2 else 4.5
    if distance>preferred:move=direction*speed*(1 if phase==1 else 0.5 if phase==2 else 0.3)
    if e.cooldown<=0:
     e.state="telegraph";e.timer=0.5;e.pending_phase=phase
     ring(node.position,1.4 if phase==1 else 0.52 if phase==2 else 3.0,Color("e3564d"),0.5)
   if phase==3:
    e.summon-=dt
    if e.summon<=0:
     e.summon=7
     for i in 2:
      if enemies.size()<24:spawn_enemy("grunt",node.position+Vector3(randf_range(-1.8,1.8),0,randf_range(-1.8,1.8)))
  _:
   if distance>range_value:move=direction*speed
   elif e.cooldown<=0:
    _hurt_player(e.damage*(1.25 if e.aura>0 else 1));e.cooldown=data.attackCooldown;e.visual.action("attack")
 if move.length_squared()>0.01:
  var separation=Vector3.ZERO
  for other in enemies:
   if other==e:continue
   var offset=node.position-other.node.position;offset.y=0;var d=offset.length()
   if d>0.01 and d<e.radius*3.5:separation+=offset/d*(1-d/(e.radius*3.5))
  move+=separation*speed*1.4
  node.position+=move.limit_length(speed*(4.5 if e.state=="dash" else 1.3))*dt
 node.position.x=clampf(node.position.x,-23.5,23.5);node.position.z=clampf(node.position.z,-23.5,23.5)
 if distance>0.01:e.visual.rotation.y=lerp_angle(e.visual.rotation.y,atan2(direction.x,direction.z),minf(1,dt*10))
 e.visual.tick(dt,move.length_squared()>0.01)

func nearest(origin: Vector3,range_value: float,excluded: Array=[]):
 var best=null;var best_distance=range_value*range_value
 for e in enemies:
  if e.hp<=0 or excluded.has(e):continue
  var distance=origin.distance_squared_to(e.node.position)
  if distance<=best_distance:best=e;best_distance=distance
 return best

func _weapons(dt: float):
 for id in run.weapons:
  var slot=run.weapons[id];slot.cooldown-=dt
  if slot.cooldown>0:continue
  var data=slot.data;var range_value=data.range*run.stats.attackRange*slot.range*BWData.UNIT
  var target=nearest(player.position,range_value)
  var manual=Input.is_action_pressed("fire")
  if not manual and (not auto_fire or target==null):continue
  var primary=id==BWData.CLASSES[run.class_id].weapon
  if primary and visual.fitted_timing and visual.lock_time>0:continue
  var direction=aim if manual else (target.node.position-player.position).normalized()
  var cooldown=1.0/(data.attacksPerSecond*run.stats.attackSpeed*slot.speed)
  if primary and visual.fitted_timing:
   var duration=minf(0.45,cooldown*0.85)
   visual.action("attack",duration)
   pending_attacks.append({"time":duration*0.32,"id":id,"direction":direction})
  else:
   _resolve_weapon(id,direction)
   if not visual.fitted_timing:visual.action("attack")
  # Snap to face the attack immediately, even mid-movement - the per-frame
  # facing lerp in _physics_process picks the movement direction back up
  # on its own once the attack's done and the player keeps moving.
  visual.rotation.y=atan2(direction.x,direction.z)
  slot.cooldown=cooldown

func _pending_attacks(dt: float):
 for attack in pending_attacks.duplicate():
  attack.time-=dt
  if attack.time<=0:
   pending_attacks.erase(attack)
   if run.stats.hp<=0:continue
   if attack.id=="ultimate":_resolve_ability(attack.data)
   else:_resolve_weapon(attack.id,attack.direction)

func _resolve_weapon(id: String,direction: Vector3):
 var slot=run.weapons[id];var data=slot.data
 var range_value=data.range*run.stats.attackRange*slot.range*BWData.UNIT
 var base=data.damage*run.stats.damage*slot.damage
 var behavior=data.get("behavior","singleProjectile")
 match behavior:
  "melee":
   slot.swings+=1
   var radius=range_value+(slot.shockwave*BWData.UNIT if slot.swings%3==0 else 0)
   var hit=[]
   for e in enemies.duplicate():
    if e.node.position.distance_to(player.position)<=radius:
     var roll=run.damage_roll(base);_damage_enemy(e,roll.damage,roll.critical);hit.append(e)
     if e.hp>0 and slot.bleed>0:e.bleed=3;e.bleed_dps=slot.bleed
   ring(player.position,radius,Color("e1ae69"),0.18)
   if not hit.is_empty() and slot.chain>0:_chain(hit[0].node.position,base*0.5,int(slot.chain),2.4,hit)
  "chain":_chain(player.position,base,int(data.get("chainCount",0)+slot.chain+1),range_value,[])
  _:
   var count=int(data.get("projectileCount",1))
   for i in count:
    var angle=(float(i)/maxi(1,count-1)-0.5)*0.5 if count>1 else 0.0
    var roll=run.damage_roll(base)
    var origin=player.position
    var shot_direction=direction.rotated(Vector3.UP,angle)
    if id=="magic_orb" and is_instance_valid(visual.hand_magic):
     var hand=visual.hand_magic.global_position
     var target=nearest(player.position,range_value)
     var destination=player.position+shot_direction*range_value+Vector3.UP*0.8
     if target!=null and (target.node.position-player.position).normalized().dot(shot_direction)>0.95:destination=target.node.position+Vector3.UP*0.8
     shot_direction=(destination-hand).normalized()
     # Clear the hand/body mesh - the orb used to spawn right at the palm and
     # visibly poke out of the model instead of appearing in front of it.
     origin=hand+shot_direction*0.45-Vector3.UP*0.8
    _bullet(origin,shot_direction,data.projectileSpeed*BWData.UNIT,roll.damage,range_value,true,int(data.get("pierceCount",0)+slot.pierce),id,slot.burn,0.35 if behavior=="piercing" and slot.burn<=0 else 0.0,roll.critical)
 sound({"sword":"sword_swing","daggers":"sword_swing","rapid_rifle":"shoot_rifle","basic_pistol":"shoot_pistol","shotgun":"shoot_shotgun","magic_orb":"magic_orb_cast","lightning":"lightning_cast"}.get(id,"shoot"))

func _chain(origin: Vector3,base: float,count: int,radius: float,hit: Array):
 for i in count:
  var next=nearest(origin,radius,hit)
  if next==null:return
  var end=next.node.position;beam(origin+Vector3.UP,end+Vector3.UP,Color("a5cfff"))
  var roll=run.damage_roll(base);_damage_enemy(next,roll.damage,roll.critical)
  if next.hp>0:next.burn=2;next.burn_dps=4
  hit.append(next);origin=end;sound("chain_lightning")

func ability():
 if not running or run.ability_cd>0 or run.stats.hp<=0:return
 var data=BWData.entry("abilities",BWData.CLASSES[run.class_id].ability)
 run.ability_cd=data.cooldown
 if visual.fitted_timing and visual.clips.has("ultimate"):
  pending_attacks.clear()
  visual.action("ultimate",0.9)
  pending_attacks.append({"time":0.45,"id":"ultimate","data":data})
 else:
  _resolve_ability(data);visual.action("attack")
 changed.emit()

func _resolve_ability(data: Dictionary):
 var range_value=data.range*run.stats.attackRange*BWData.UNIT
 if data.id=="fan_shot":
  for i in range(-2,3):
   var roll=run.damage_roll(data.damage*run.stats.damage)
   _bullet(player.position,aim.rotated(Vector3.UP,i*0.16),data.projectileSpeed*BWData.UNIT,roll.damage,range_value,true,0,"rapid_rifle",0,0,roll.critical)
 else:
  var strike_position=player.position
  if data.id=="shadow_strike":
   # A fast dash reads better than a blink and disorients less - cover the
   # distance in a short tween instead of snapping player.position directly.
   strike_position=player.position+aim*data.range*BWData.UNIT*0.5
   strike_position.x=clampf(strike_position.x,-23.5,23.5);strike_position.z=clampf(strike_position.z,-23.5,23.5)
   create_tween().tween_property(player,"position",strike_position,0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
   range_value=65*run.stats.attackRange*BWData.UNIT
  for e in enemies.duplicate():
   if e.node.position.distance_to(strike_position)<=range_value:
    var roll=run.damage_roll(data.damage*run.stats.damage);_damage_enemy(e,roll.damage,roll.critical)
    if e.hp>0 and data.id=="frost_nova":e.slow=3;e.slow_amount=0.45
  ring(strike_position,range_value,Color(BWData.CLASSES[run.class_id].color),0.4)
 sound("magic_orb_cast" if data.id=="frost_nova" else "shoot")

func _bullet(origin: Vector3,direction: Vector3,speed: float,damage: float,distance: float,friendly: bool,pierce: int,weapon: String,burn: float,slow: float,critical: bool):
 if bullets.size()>=384:return
 var node=MeshInstance3D.new();node.mesh=bullet_mesh;node.material_override=bullet_material
 add_child(node);node.position=origin+Vector3.UP*0.8
 if not friendly:
  var mat=bullet_material.duplicate();mat.albedo_color=Color("ed5d60");node.material_override=mat
 elif weapon=="magic_orb":
  node.scale=Vector3.ONE*2.4;var mat=bullet_material.duplicate();mat.albedo_color=Color("8db8f4");node.material_override=mat
 bullets.append({"node":node,"direction":direction.normalized(),"speed":speed,"damage":damage,"remaining":distance,"friendly":friendly,"pierce":pierce,"hit":[],"weapon":weapon,"burn":burn,"slow":slow,"critical":critical})

func _projectiles(dt: float):
 for b in bullets.duplicate():
  var previous=b.node.position;var step=b.direction*b.speed*dt;b.node.position+=step;b.remaining-=step.length()
  var targets=enemies.duplicate() if b.friendly else [{"node":player,"radius":0.36,"hp":run.stats.hp}]
  for target in targets:
   if target.hp<=0 or b.hit.has(target.node.get_instance_id()):continue
   var p=target.node.position+Vector3.UP*0.8
   var closest=Geometry3D.get_closest_point_to_segment(p,previous,b.node.position)
   if p.distance_to(closest)<=target.radius+0.1:
    b.hit.append(target.node.get_instance_id())
    if b.friendly:
     _damage_enemy(target,b.damage,b.critical)
     if target.hp>0:
      if b.burn>0:target.burn=3;target.burn_dps=b.burn
      if b.slow>0:target.slow=2;target.slow_amount=b.slow
    else:_hurt_player(b.damage)
    b.pierce-=1
    if b.pierce<0:b.remaining=-1;break
  if b.remaining<=0:b.node.queue_free();bullets.erase(b)

func _damage_enemy(e: Dictionary,damage: float,critical: bool=false,effects: bool=true):
 if e.hp<=0:return
 var actual=minf(e.hp,damage);e.hp-=damage
 if run.stats.hp>0:run.stats.hp=minf(run.stats.maxHp,run.stats.hp+actual*run.stats.lifesteal)
 if effects:
  damage_text(e.node.position,damage,Color("ffe4a8") if critical else Color("d9dce2"));sound("hit",0.08)
 if e.hp>0:return
 enemies.erase(e);e.visual.action("death")
 run.kills+=1;run.gold+=int(e.data.goldReward*(4 if e.elite else 1)+run.stats.bonusGoldPerKill)
 _drop(e.node.position,"xp",int(e.data.xpReward*(4 if e.elite else 1)))
 var chance=1.0 if e.id=="boss" else 0.22 if e.elite else 0.08
 if rng.randf()<chance:_drop(e.node.position+Vector3(0.2,0,0),"health",70 if e.id=="boss" else 35 if e.elite else 18)
 sound("boss_death" if e.id=="boss" else "enemy_death",0.12)
 var corpse=e.node
 get_tree().create_timer(2.5).timeout.connect(corpse.queue_free)
 changed.emit()

func _hurt_player(damage: float):
 var actual=run.hurt(damage,rng.randf())
 if actual<=0:return
 if visual.fitted_timing and visual.state=="attack":pending_attacks.clear()
 damage_text(player.position,actual,Color("ff8678"));visual.action("hit");shake=clampf(actual/100,0.04,0.18);sound("player_hit",0.12);changed.emit()

func _drop(pos: Vector3,kind: String,amount: int):
 var node=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=0.12;mesh.height=0.24;mesh.radial_segments=8;mesh.rings=4;node.mesh=mesh
 var mat=StandardMaterial3D.new();mat.albedo_color=Color("85c8cf") if kind=="xp" else Color("eb665c");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;node.material_override=mat;add_child(node);node.position=pos+Vector3.UP*0.2
 pickups.append({"node":node,"kind":kind,"amount":amount})

func _pickups(dt: float):
 for p in pickups.duplicate():
  var target=player.position+Vector3.UP*0.2;var distance=p.node.position.distance_to(target)
  if distance<=run.stats.pickupRadius*BWData.UNIT:p.node.position=p.node.position.move_toward(target,dt*8)
  if distance<0.4:
   if p.kind=="xp":run.add_xp(p.amount)
   else:run.stats.hp=minf(run.stats.maxHp,run.stats.hp+p.amount)
   p.node.queue_free();pickups.erase(p);changed.emit()

func next_wave():
 for b in bullets:b.node.queue_free()
 bullets.clear();run.wave+=1;spawned=0;spawn_timer=0;rest_time=4;running=true;changed.emit()

func ring(pos: Vector3,radius: float,color: Color,duration: float):
 var mesh=TorusMesh.new();mesh.inner_radius=maxf(0.01,radius-0.04);mesh.outer_radius=radius+0.04;mesh.rings=32;mesh.ring_segments=6
 var node=MeshInstance3D.new();node.mesh=mesh;node.position=pos+Vector3.UP*0.045;var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=color;mesh.material=mat;node.material_override=mat;add_child(node)
 var tween=create_tween();tween.tween_property(node,"scale",Vector3(1.06,1,1.06),duration);tween.tween_callback(node.queue_free)

func beam(a: Vector3,b: Vector3,color: Color):
 var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES);mesh.surface_add_vertex(a);mesh.surface_add_vertex((a+b)*0.5+Vector3(0.1,0.2,0.1));mesh.surface_add_vertex((a+b)*0.5+Vector3(0.1,0.2,0.1));mesh.surface_add_vertex(b);mesh.surface_end()
 var node=MeshInstance3D.new();node.mesh=mesh;var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=color;mesh.surface_set_material(0,mat);node.material_override=mat;add_child(node)
 get_tree().create_timer(0.15).timeout.connect(node.queue_free)

func damage_text(pos: Vector3,amount: float,color: Color):
 if quality!="PC" and randf()>0.4:return
 var label=Label3D.new();label.text=str(int(round(amount)));label.font_size=38;label.pixel_size=0.008;label.modulate=color;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.position=pos+Vector3(rng.randf_range(-0.2,0.2),2.0,0);add_child(label)
 var tween=create_tween();tween.set_parallel(true);tween.tween_property(label,"position:y",label.position.y+0.6,0.55);tween.tween_property(label,"modulate:a",0.0,0.55);tween.chain().tween_callback(label.queue_free)

func sound(id: String,interval: float=0.08):
 var now=Time.get_ticks_msec()/1000.0
 if now-audio_times.get(id,-100.0)<interval:return
 audio_times[id]=now
 var stream=load("res://assets/audio/%s.mp3" % id)
 if stream==null:return
 var audio=AudioStreamPlayer.new();audio.stream=stream;audio.volume_db=-5 if id=="game_over" else -14;audio.bus="Master";add_child(audio);audio.finished.connect(audio.queue_free);audio.play()
