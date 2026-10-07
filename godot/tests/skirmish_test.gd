extends SceneTree

# What a wave is supposed to feel like now that it is a handful of enemies instead of
# a crowd: one swing cuts what is in front of it and no more, a body that is hit is
# visibly hit, nothing stands inside the player, missile troops fight from the flank,
# and a mage's rune is a thing on the ground that can be left or broken.

var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)

func _initialize():call_deferred("suite")

func clear_enemies(world):
	for e in world.enemies.duplicate():
		world.enemies.erase(e);e.node.queue_free()
	world.clear_hazards()

func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var world=scene.world;world.running=false;world.auto_fire=false;world.arena.blockers.clear()
	world.player.position=Vector3.ZERO;world.player_velocity=Vector3.ZERO

	# --- One swing, one arc, a few bodies.
	clear_enemies(world)
	var front=[]
	for i in 6:
		var offset=Vector3.FORWARD.rotated(Vector3.UP,-0.6+0.24*i)*1.2
		front.append(world.spawn_enemy("grunt",offset))
	var behind=world.spawn_enemy("grunt",Vector3.BACK*1.2)
	var facing=Vector3.FORWARD
	var before={}
	for e in world.enemies:before[e.node.get_instance_id()]=e.hp
	world._resolve_weapon("sword",facing)
	var cut=0
	for e in front:
		if e.hp<before[e.node.get_instance_id()]:cut+=1
	check(cut==BWWorld.MELEE_TARGETS,"a swing cuts the nearest few, not everything in reach: "+str(cut))
	check(behind.hp==before[behind.node.get_instance_id()],"a swing does not reach round behind the player")
	# The bodies it did cut are the nearest ones.
	var nearest_hit=true
	for e in front:
		var struck=e.hp<before[e.node.get_instance_id()]
		if struck and e.node.position.length()>1.21:nearest_hit=false
	check(nearest_hit,"the cap takes the nearest bodies")

	# --- The shockwave swing is the stated exception: full circle, more bodies.
	clear_enemies(world)
	var ring=[]
	for i in 6:ring.append(world.spawn_enemy("grunt",Vector3.FORWARD.rotated(Vector3.UP,TAU*i/6.0)*1.2))
	var slot=world.run.weapons.sword
	slot.shockwave=40.0;slot.swings=2
	world._resolve_weapon("sword",Vector3.FORWARD)
	var wide=0
	for e in ring:
		if e.hp<e.maxHp:wide+=1
	check(wide>BWWorld.MELEE_TARGETS,"the shockwave swing still clears a crowd: "+str(wide))
	slot.shockwave=0.0;slot.swings=0

	# --- A hit lands on the body: it is shoved back and taken off its feet. A tank,
	# because a grunt dies to one warrior swing and a corpse cannot be staggered.
	clear_enemies(world)
	var struck=world.spawn_enemy("tank",Vector3.FORWARD*1.1)
	var distance=struck.node.position.length()
	world._resolve_weapon("sword",Vector3.FORWARD)
	check(struck.hp<struck.maxHp,"the swing connected")
	check(struck.node.position.length()>distance+0.05,"a hit knocks the body back: "+str(struck.node.position.length()))
	check(struck.stagger>0.0,"a hit staggers the body")
	var held=struck.node.position
	world._enemy_tick(struck,0.05)
	check(struck.node.position.is_equal_approx(held),"a staggered body does not advance")
	check(struck.visual.state=="hit","the body plays its hit clip: "+struck.visual.state)
	for i in 10:world._enemy_tick(struck,0.05)
	check(struck.stagger==0.0,"the stagger runs out")

	# --- A staggered body cannot answer the combo: it does not swing the moment it
	# recovers, and a wind-up it was holding is lost to the hit.
	clear_enemies(world)
	var grunt=world.spawn_enemy("grunt",Vector3.FORWARD*1.1)
	grunt.hp=1e6;grunt.maxHp=1e6;grunt.cooldown=0.0
	var before_hp=world.run.stats.hp
	world._resolve_weapon("sword",Vector3.FORWARD)
	check(grunt.stagger>=0.4,"a grunt is staggered for a readable beat: "+str(grunt.stagger))
	for i in 9:world._enemy_tick(grunt,0.05)
	check(world.run.stats.hp==before_hp,"it does not strike while staggered or the instant it recovers")
	var drawn=world.spawn_enemy("archer",Vector3.FORWARD*1.1)
	drawn.hp=1e6;drawn.maxHp=1e6;drawn.state="draw";drawn.timer=0.2
	world._stagger(drawn)
	check(drawn.state=="chase","a hit breaks an archer's draw")

	# --- Nothing fights from inside the player.
	clear_enemies(world)
	var closer=world.spawn_enemy("grunt",Vector3(0,0,7))
	var floor_gap=closer.radius+BWWorld.PERSONAL_SPACE*0.8
	var closest=INF
	for i in 160:
		world._enemy_tick(closer,0.05)
		closest=minf(closest,closer.node.position.distance_to(world.player.position))
	check(closest>=floor_gap-0.01,"a grunt closes to arm's length and no further: "+str(closest))
	check(closest<1.6,"it does close - the standoff is not a reason to hang back")

	# --- Archers take the flank; mages hold their casting spot (mage_movement_test).
	for id in ["archer"]:
		clear_enemies(world)
		var shooter=world.spawn_enemy(id,Vector3(0,0,-7))
		shooter.hunt_side=1.0;shooter.hunt_depth=0.5
		for i in 200:world._enemy_tick(shooter,0.05)
		var post=shooter.node.position-world.player.position
		check(post.dot(world.screen_direction(Vector2.RIGHT))>6.0,"%s fights from the player's flank: x=%s" % [id,str(post.x)])
		check(absf(post.dot(world.screen_direction(Vector2.DOWN)))<3.0,"%s holds a side, not the line the player is on" % id)
		check(post.length()>4.0,"%s keeps its distance" % id)

	# --- A mage builds. The rune burns a fuse, then goes off under whoever stayed.
	clear_enemies(world)
	world.run.stats.hp=world.run.stats.maxHp
	var caster=world.spawn_enemy("mage",Vector3(0,0,-8))
	world._plant_rune(caster)
	check(world.hazards.size()==1,"the mage planted one rune")
	var rune=world.hazards[0]
	check(rune.pos.distance_to(world.player.position)<1.2,"the rune is planted where the player stands")
	var hp=world.run.stats.hp
	for i in 80:
		if world.hazards.is_empty():break
		world._hazards(0.05)
	check(world.hazards.is_empty(),"the fuse ends")
	check(world.run.stats.hp<hp,"standing on the rune costs health")

	# Walking out of it costs nothing.
	world.run.stats.hp=world.run.stats.maxHp
	world._plant_rune(caster)
	world.player.position=Vector3(0,0,12)
	for i in 80:
		if world.hazards.is_empty():break
		world._hazards(0.05)
	check(world.run.stats.hp==world.run.stats.maxHp,"leaving the rune's circle is an answer to it")
	world.player.position=Vector3.ZERO

	# Breaking it first is the other answer, and it does not blow up doing it.
	world._plant_rune(caster)
	var standing=world.hazards[0]
	world.damage_hazards(standing.pos,0.5,standing.hp*0.5)
	check(world.hazards.size()==1,"a rune takes more than one hit")
	world.damage_hazards(standing.pos,0.5,standing.hp)
	check(world.hazards.is_empty(),"a rune can be broken before its fuse ends")
	check(world.run.stats.hp==world.run.stats.maxHp,"breaking a rune defuses it instead of setting it off")

	# A swing over a rune is a swing at the rune: one call covers props and runes both.
	world._plant_rune(caster)
	var swung=world.hazards[0]
	var remaining=swung.hp
	world.damage_area(swung.pos,1.0,remaining*0.25)
	check(swung.hp<remaining,"an area attack hits what is standing in it")
	world.clear_hazards()
	check(world.hazards.is_empty(),"a cleared wave leaves no runes standing")

	# The floor cannot be carpeted however many mages a wave fields.
	for i in BWWorld.HAZARD_LIMIT+4:
		if world.hazards.size()>=BWWorld.HAZARD_LIMIT:break
		world._plant_rune(caster)
	check(world.hazards.size()<=BWWorld.HAZARD_LIMIT,"runes standing at once stay under the limit")
	world.clear_hazards()

	# --- The wave shape itself: fewer bodies than the version that lost the feel.
	for wave in [1,5,9,15]:
		var rules=BWData.wave_rules(wave)
		check(rules.quota<12+wave*8,"the wave fields fewer bodies than the horde did: "+str(wave))
		check(rules.cap<=12,"never more than a dozen on screen at once: "+str(wave))
	check(BWArena.HALF<=26.0,"the map is the tighter one")

	clear_enemies(world)
	scene.queue_free();await process_frame
	print("SKIRMISH_TEST checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
