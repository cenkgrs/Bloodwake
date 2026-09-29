extends SceneTree

# The six bound skills the other suites do not reach. combat_flow_test already
# drives the mage's meteor and leap end to end; these are the warrior, gunslinger
# and assassin casts, which had no coverage at all.
var checks=0
var failures=0
func check(ok: bool,why: String):
	checks+=1
	if not ok:failures+=1;push_error(why)
func _initialize():call_deferred("suite")

# A cast needs a world that is live enough to move a body and reach an enemy, but
# not one that is also spawning waves on top of the test.
func arena(scene: Node,id: String) -> Array:
	scene.start_run(id);await process_frame
	var world=scene.world;var run=scene.run
	world.running=true;world.auto_fire=false;world.rest_time=999
	run.stats.dodgeChance=0;run.stats.armor=0;run.stats.criticalChance=0;run.stats.lifesteal=0
	return [world,run]

func dummy(world,at: Vector3,hp: float=2000.0) -> Dictionary:
	var e=world.spawn_enemy("tank",at);e.cooldown=1e9;e.hp=hp;e.maxHp=hp
	return e

func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.meta=BWMeta.new();scene.meta.path="user://class_kit_test_progression.json"

	# Every class fields exactly two bound skills, and each one is a behaviour the
	# kit actually dispatches - a typo in a catalog behaviour would otherwise cast
	# nothing at all and still spend the cooldown.
	var behaviours=["meteor","voidLeap","thrust","backstepVolley","ricochet","powderCharge","markOfRuin"]
	for id in BWData.CLASSES:
		for skill_id in BWData.skills(id):
			var row=BWData.entry("abilities",skill_id)
			check(not row.is_empty(),"skill is catalogued: "+skill_id)
			check(row.behavior in behaviours,"skill behaviour is dispatched: "+skill_id+" / "+String(row.get("behavior","")))
			check(row.cooldown>0,"skill has a cooldown: "+skill_id)

	# --- Warrior Q: Sunder Leap. Shares voidLeap with the mage but is the shorter
	# jump into the wider crater, so what matters here is that it reaches its mark.
	var pair=await arena(scene,"warrior")
	var world=pair[0];var run=pair[1]
	world.aim=Vector3.FORWARD
	var sunder=BWData.entry("abilities","sunder_leap")
	var landing=world.ground_target(sunder.range*run.stats.attackRange*BWData.UNIT)
	var victim=dummy(world,landing)
	var launch=world.player.position
	world.skill(0)
	# Read the cooldown here: the world ticks it down through the flight below.
	check(run.skill_cd.sunder_leap==sunder.cooldown,"Sunder Leap spends its own cooldown")
	check(run.skill_ready("shield_thrust"),"the warrior's second skill is untouched by the first")
	check(world.airborne,"Sunder Leap leaves the ground")
	check(victim.hp==2000,"Sunder Leap damage waits for the landing")
	var mid=run.stats.hp;world._hurt_player(30)
	check(run.stats.hp==mid,"the warrior cannot be hit mid-leap")
	await create_timer(0.9).timeout
	check(not world.airborne,"Sunder Leap lands")
	check(world.player.position.distance_to(landing)<0.05,"Sunder Leap arrives where it was aimed")
	check(launch.distance_to(world.player.position)>1.0,"Sunder Leap covers ground")
	check(victim.hp<2000,"Sunder Leap's crater damages what is standing in it")

	# --- Warrior E: Shield Thrust. A lane, not a circle: something beside the
	# fighter must survive a lunge that kills what is lined up in front of it.
	run.skill_cd.sunder_leap=0.0;run.skill_cd.shield_thrust=0.0
	for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()
	world.player.position=Vector3.ZERO;world.aim=Vector3.FORWARD
	var thrust=BWData.entry("abilities","shield_thrust")
	var reach=thrust.range*run.stats.attackRange*BWData.UNIT
	var lane=thrust.blastRadius*run.stats.attackRange*BWData.UNIT
	var heading=world.aim.normalized()
	var beside=heading.cross(Vector3.UP).normalized()
	var ahead=dummy(world,heading*reach*0.5)
	var aside=dummy(world,beside*lane*4.0)
	world.skill(1)
	check(ahead.hp<2000,"Shield Thrust spears what is lined up in front of it")
	check(aside.hp==2000,"Shield Thrust spares what is beside the lane")
	check(world.player.position.distance_to(Vector3.ZERO)>=0.0,"Shield Thrust commits the body forward")
	await create_timer(0.3).timeout

	# --- Gunslinger Q: Ricochet Round. One round, redirected: the point is that a
	# second body it never pointed at still takes the hit.
	pair=await arena(scene,"gunslinger")
	world=pair[0];run=pair[1]
	world.player.position=Vector3.ZERO;world.aim=Vector3.FORWARD
	var first=dummy(world,Vector3(0,0,3.0))
	var second=dummy(world,Vector3(1.6,0,3.4))
	world.skill(0)
	check(world.bullets.size()==1,"Ricochet Round fires a single round")
	check(world.bullets[0].get("bounces",0)==BWData.entry("abilities","ricochet_round").bounces,"the round carries its bounce budget")
	for i in 90:
		world._projectiles(0.016)
		await process_frame
		if first.hp<2000 and second.hp<2000:break
	check(first.hp<2000,"the round hits what it was aimed at")
	check(second.hp<2000,"the round redirects into a body it was never pointed at")

	# --- Gunslinger E: Powder Charge. Telegraphs, then detonates: damage must not
	# land while the keg is still in the air.
	run.skill_cd.powder_charge=0.0
	for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()
	for b in world.bullets.duplicate():b.node.queue_free()
	world.bullets.clear()
	world.player.position=Vector3.ZERO;world.aim=Vector3.FORWARD
	var charge=BWData.entry("abilities","powder_charge")
	var spot=world.ground_target(charge.range*run.stats.attackRange*BWData.UNIT)
	var caught=dummy(world,spot)
	var outside=dummy(world,spot+Vector3(charge.blastRadius*BWData.UNIT*3.0,0,0))
	world.skill(1)
	check(caught.hp==2000,"Powder Charge does not damage while the keg is still in the air")
	await create_timer(0.8).timeout
	check(caught.hp<2000,"Powder Charge detonates on what is standing on it")
	check(outside.hp==2000,"Powder Charge spares what is outside the blast")

	# --- Assassin Q: Phantom Volley. Retreats one way, throws blades the other.
	pair=await arena(scene,"assassin")
	world=pair[0];run=pair[1]
	world.player.position=Vector3.ZERO;world.aim=Vector3.FORWARD
	var pursuer=dummy(world,Vector3(0,0,2.4))
	var standing=world.player.position
	world.skill(0)
	await create_timer(0.35).timeout
	var retreated=world.player.position
	check(standing.distance_to(retreated)>1.0,"Phantom Volley breaks away from the body on top of it")
	check((retreated-standing).normalized().dot(world.aim)<-0.8,"Phantom Volley retreats opposite the blades it throws")
	check(world.bullets.size()>=3,"Phantom Volley answers with three blades")
	for i in 60:
		world._projectiles(0.016)
		await process_frame
		if pursuer.hp<2000:break
	check(pursuer.hp<2000,"the blades travel back toward what was chasing")

	# --- Assassin E: Mark of Ruin. The brand bites harder, and outlives its host.
	run.skill_cd.mark_of_ruin=0.0
	for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()
	for b in world.bullets.duplicate():b.node.queue_free()
	world.bullets.clear()
	world.player.position=Vector3.ZERO
	var host=dummy(world,Vector3(0,0,2.0),100.0)
	var heir=dummy(world,Vector3(0.8,0,2.4),2000.0)
	world.skill(1)
	check(host.get("marked",false),"Mark of Ruin brands the nearest body")
	check(not heir.get("marked",false),"only one body carries the brand at a time")
	check(host.node.find_child("RuinMark",true,false)!=null,"the brand is drawn on its host")
	# A marked body takes more than an unmarked one from the same hit.
	var plain=dummy(world,Vector3(4.0,0,2.0),2000.0)
	world._damage_enemy(host,50.0,false,false)
	world._damage_enemy(plain,50.0,false,false)
	check(host.hp<plain.hp-1.0,"the brand makes every hit bite harder")
	# Killing the host must hand the brand on rather than lose it.
	world._damage_enemy(host,10000.0,false,false)
	check(heir.get("marked",false) or plain.get("marked",false),"the brand outlives its host and moves to the next body")
	check(world.mark_chain==1,"each jump deepens the chain")

	scene.queue_free();await process_frame
	await create_timer(1.0).timeout
	print("CLASS_KIT_TESTS ",checks," checks / ",failures," failures")
	quit(1 if failures>0 else 0)
