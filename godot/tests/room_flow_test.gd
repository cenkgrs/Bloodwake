extends SceneTree

# The map/room flow end to end: the pool and its routes, every room's markers
# and walkability, the six-room route played through, rewards and the exit only
# working once, the merchant across nights, the safehouse, a seventh room added
# from data alone, and markers read from a delivered scene.

var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")

func suite():
	BWData.load_catalogs();BWRooms.load_all()
	_pool()
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	await _route(scene)
	await _safehouse(scene)
	await _seventh_room(scene)
	await _delivered_scene()
	scene.queue_free();await process_frame
	print("ROOM_FLOW_TESTS ",checks," checks / ",failures," failures")
	quit(1 if failures>0 else 0)

func _pool():
	var map_row=BWRooms.map("cursed_town")
	check(not map_row.is_empty(),"the cursed town map is registered")
	var plan=BWRooms.night_plan(map_row)
	check(plan==["town_gateyard_01","town_cargo_02","town_well_03","town_stables_04","town_station_05","town_boss_blackbell_01","town_night_market"],"one night: five rooms, the boss, the merchant")
	check(BWRooms.room("town_boss_blackbell_01").type=="boss" and BWRooms.room("town_night_market").type=="merchant","room types come from data")
	check(not BWRooms.safehouse().is_empty(),"a safehouse room exists")
	# The brief's sizes, taken down by 30% so a fight is not a hike.
	var sizes={"town_gateyard_01":Vector2(25,22),"town_cargo_02":Vector2(28,24),"town_well_03":Vector2(27,27),"town_stables_04":Vector2(31,24),"town_station_05":Vector2(32,28),"town_boss_blackbell_01":Vector2(36,34)}
	for id in sizes:check(BWRooms.room(id).half*2.0==sizes[id],"interior size is the reduced brief: "+id)
	var gate=BWRooms.room("town_gateyard_01")
	check(BWRooms.waves(gate,1).size()==2 and BWRooms.waves(gate,1).all(func(w):return w.size()==5),"a room fights two waves of five")
	check(BWRooms.waves(BWRooms.room("town_station_05"),1).size()==3,"the station holds three waves before the boss")
	check(BWRooms.waves(gate,2).all(func(w):return w.size()==6),"later nights field one more body per wave")
	# Every room is built standalone and must pass its own checks: required markers,
	# nothing inside an obstacle, everything reachable from EntrySpawn.
	for id in BWRooms.rooms:
		var arena=BWRoomArena.new();root.add_child(arena)
		arena.build_room(BWRooms.room(id),"Mobile",7)
		check(arena.problems.is_empty(),"room %s validates: %s" % [id,str(arena.problems)])
		var row=BWRooms.room(id)
		if row.type in ["combat","boss"]:
			var spawns=arena.enemy_spawns()
			for spot in spawns:check(spot.distance_to(arena.marker("EntrySpawn"))>=8.0,"enemy spawn is away from the entry: "+id)
			var open=0;var total=0
			for y in arena.nav_size.y:
				for x in arena.nav_size.x:
					total+=1;open+=1 if arena.nav_solid[y*arena.nav_size.x+x]==0 else 0
			check(float(open)/total>=0.65,"at least 65%% of the floor is open: %s (%.0f%%)" % [id,100.0*open/total])
			check(arena.exit_zone().size.x>=BWRooms.DOOR_WIDTH,"exit opening is at least 6 m: "+id)
		arena.queue_free()
	var well=BWRoomArena.new();root.add_child(well);well.build_room(BWRooms.room("town_well_03"),"Mobile",7)
	for angle in 16:
		var spot=Vector3(cos(TAU*angle/16.0),0,sin(TAU*angle/16.0))*6.0
		check(not well.in_rect(spot,0.4) and well.push_out(spot,0.4).distance_to(spot)<0.01,"the ring round the well is open")
	well.queue_free()
	var stables=BWRoomArena.new();root.add_child(stables);stables.build_room(BWRooms.room("town_stables_04"),"Mobile",7)
	check(stables.reachable(Vector3(-10,0,0),Vector3(10,0,0)),"the two courts connect")
	check(stables.segment_blocked(Vector3(-5,0,0),Vector3(5,0,0),0.4),"the divider cuts the straight line")
	stables.goal=Vector3(8,0,0)
	var way=stables.flow_direction(Vector3(-3,0,0))
	check(absf(way.z)>0.5,"a chaser behind the divider is routed round its end")
	stables.queue_free()

func _route(scene):
	scene.start_run("warrior",true,false,"cursed_town");await process_frame
	var w: BWWorld=scene.world;var run: BWRun=scene.run
	w.auto_fire=false
	check(scene.room_mode() and w.room.id=="town_gateyard_01","a hunt starts in the first room of the route")
	check(w.arena.door_open("entrance") and not w.arena.door_open("exit"),"entry: came in through an open entrance; the exit is shut")
	run.stats.maxHp=1e6;run.stats.hp=1e6
	run.upgrades["vitality"]=1;run.gold=500
	var exits=[0]
	w.exit_reached.connect(func():exits[0]+=1)
	var nights_seen=[]
	for step in 7:
		w=scene.world;var row=w.room
		nights_seen.append(run.night)
		if w.is_fight():
			check(w.room_state=="entry","%s opens in the entry state" % row.id)
			w.rest_time=0.0;w._room_tick()
			check(w.room_state=="active" and not w.arena.door_open("entrance") and not w.arena.door_open("exit"),"%s: both doors shut once the fight starts" % row.id)
			check(w.encounter==BWRooms.waves(row,run.night)[0],"%s opens with its first authored wave" % row.id)
			var advances=[0];var counter=func(_i,_t):advances[0]+=1
			w.wave_advanced.connect(counter)
			# Nothing alive but the roster not yet fielded: still not clear.
			w.spawned=0
			for e in w.enemies:w._damage_enemy(e,1e9,false,false)
			w._encounter_tick()
			check(w.room_state=="active" and not w.arena.door_open("exit"),"%s stays shut while spawns are pending" % row.id)
			var guard=0
			while w.room_state=="active" and guard<400:
				guard+=1;w.spawn_timer=0.0;w._encounter_tick()
				for e in w.enemies.duplicate():w._damage_enemy(e,1e12,false,false)
			check(w.room_state=="cleared","%s clears once the roster is spent and dead" % row.id)
			check(advances[0]==BWRooms.waves(row,run.night).size()-1,"%s brings on each of its waves in turn" % row.id)
			w.wave_advanced.disconnect(counter)
			check(scene.page=="playing","%s: clearing does not open a menu by itself" % row.id)
			if row.type=="boss":
				check(w.reward.get("required",false) and not w.arena.door_open("exit"),"boss spoils hold the gate shut")
				check(w.arena.reward_state=="ready","the pedestal lights")
				w.player.position=w.arena.marker("RewardPoint")+Vector3(1.2,0,0)
				check(w.interaction().get("role","")=="reward","the pedestal can be used from beside it")
				w.interact();await process_frame
				var picks=0
				while scene.page=="upgrades" and picks<20:
					picks+=1;scene.run.apply_upgrade(scene.choices[0].id)
					if scene.choosing_boss:scene.boss_reward=false
					else:run.pending_levels-=1
					scene._next_pick();await process_frame
				check(scene.page=="playing" and w.reward.is_empty() and w.arena.door_open("exit"),"spoils taken: the gate opens and play resumes")
				check(not run.claim(),"boss spoils cannot be claimed twice")
				check(w.interaction().get("role","")!="reward","the spent pedestal offers nothing")
			else:
				check(w.arena.door_open("exit"),"%s: the exit opens on clear" % row.id)
		else:
			check(w.room_state=="hub" and w.arena.door_open("exit"),"%s has no fight and an open road" % row.id)
			if row.type=="merchant":
				w.player.position=BWRooms.vec(row.hosts[0].at)+Vector3(0,0,1.5)
				check(w.interaction().get("role","")=="merchant","the merchant can be spoken to")
				w.interact();await process_frame
				check(scene.page=="shop","talking to the merchant opens the stall")
				var stock=scene.shop_offers.duplicate()
				check(not stock.is_empty() and stock.all(func(o):return o.grade==1.0),"night one's goods are sold as written")
				var bought=run.buy_offer(stock[0])
				check(bought,"the merchant sells")
				scene.resume();await process_frame
		# Leave: walk into the exit once, then try to trigger it again.
		var hp_before=run.stats.hp;var gold_before=run.gold;var items_before=run.items.size()
		var level_before=run.level;var upgrades_before=run.upgrades.duplicate()
		var crossing=w.arena.exit_zone().get_center()
		var count=exits[0]
		w.player.position=Vector3(crossing.x,0,crossing.y)
		w._exit_check();w._exit_check()
		check(exits[0]==count+1,"%s: the exit fires once" % row.id)
		await create_timer(1.1).timeout
		check(scene.page=="playing" and scene.world==w,"%s: the transition hands back to play" % row.id)
		check(w.room.id!=row.id,"%s: the next room is loaded" % row.id)
		check(w.enemies.is_empty() and w.bullets.is_empty() and w.pickups.is_empty() and w.hazards.is_empty(),"nothing of %s follows into the next room" % row.id)
		check(is_equal_approx(run.stats.hp,hp_before) and run.gold==gold_before and run.items.size()==items_before and run.level==level_before and run.upgrades==upgrades_before,"health, gold, items and build survive leaving %s" % row.id)
		check(w.get_children().filter(func(n):return n is BWRoomArena and not n.is_queued_for_deletion()).size()==1,"only one room is held in the scene")
	check(nights_seen==[1,1,1,1,1,1,1] and run.night==2 and w.room.id=="town_gateyard_01","after the merchant the second night starts on the same route")
	check(w.encounter.size()==6 and w.room_state=="entry","night two enters its first room fresh, one body stronger")
	# A new wave rises out of the ground: hidden, untouchable, still, then standing.
	w.rest_time=0.0;w._room_tick();w.spawn_timer=0.0;w._encounter_tick()
	var riser=w.enemies[0]
	check(riser.node.position.y<-1.0 and not riser.node.visible,"a spawn starts below the street, unseen")
	check(w.nearest(riser.node.position,50.0)==null,"nothing can target a body still rising")
	var hp=riser.hp;w._damage_enemy(riser,50.0);check(riser.hp==hp,"a rising body cannot be hurt")
	check(w.fx.get_children().any(func(n):return n.name.begins_with("SpawnSmoke")),"smoke marks where it rises")
	var spot=riser.node.position
	var ticks=0
	while riser.rising>0.0 and ticks<60:ticks+=1;w._enemy_tick(riser,0.07)
	check(riser.rising==0.0 and is_zero_approx(riser.node.position.y) and riser.node.visible,"it stands after the rise")
	check(Vector2(spot.x,spot.z).distance_to(Vector2(riser.node.position.x,riser.node.position.z))<0.01,"it does not move while rising")
	check(BWData.enemy_power(run.wave,"boss",2).health>BWData.enemy_power(run.wave,"boss",1).health,"the second night's boss is stronger")
	check(BWRooms.roster(w.room,2).size()>BWRooms.roster(w.room,1).size(),"the second night fields more bodies")
	var night_two=run.merchant_offers(6)
	check(run.merchant_grade()>1.0 and not night_two.is_empty() and night_two.all(func(o):return o.grade>1.0 and (o.get("temper",false) or o.get("rarity","")!="common")),"the second night's merchant sells stronger, rarer goods")
	var exclusive=false
	for i in 30:
		for offer in run.merchant_offers(6):exclusive=exclusive or offer.get("minNight",1)>=2
	check(exclusive,"night-only goods reach the second night's stall")
	var first_night=BWRun.new("warrior")
	for i in 30:
		for offer in first_night.merchant_offers(6):check(offer.get("minNight",1)<=1,"night-only goods never show on the first night")
	var graded=BWRun.new("warrior");graded.night=2;graded.gold=1000
	var armor=graded.stats.armor
	check(graded.buy_offer({"id":"platinum_armor","grade":graded.merchant_grade(),"cost":10}),"a graded item can be bought")
	check(is_equal_approx(graded.stats.armor-armor,0.10*graded.merchant_grade()),"a graded item applies at its grade")
	graded.night=3
	var tempered=graded.merchant_offers(20).filter(func(o):return o.get("temper",false))
	check(not tempered.is_empty(),"owned goods can be tempered on a later night")
	scene.show_menu();await process_frame

func _safehouse(scene):
	scene.enter_safehouse("mage");await process_frame
	var w: BWWorld=scene.world
	check(scene.in_safehouse() and scene.page=="playing" and w.run.class_id=="mage","the chosen class opens in the safehouse")
	check(w.hosts.size()==3 and not w.combat_enabled(),"three hosts and no fighting in the safehouse")
	var roles=w.hosts.map(func(h):return h.role)
	check(roles.has("builds") and roles.has("skills") and roles.has("maps"),"builds, skills and the map table have separate hosts")
	for role in ["builds","skills","maps"]:
		var host=w.hosts.filter(func(h):return h.role==role)[0]
		w.player.position=host.pos+Vector3(0,0,1.3)
		check(w.interaction().get("role","")==role,"the %s host is in reach" % role)
		w.interact();await process_frame
		check(scene.page==role,"the %s host opens its page" % role)
		scene._back();await process_frame
		check(scene.page=="playing" and scene.in_safehouse(),"back from %s returns to the safehouse" % role)
	# The war table is a carousel: arrows, keys and a swipe turn it, and it wraps.
	BWRooms.register_map({"id":"zz_second_map","name":"THE SECOND MAP","route":["town_gateyard_01"],"boss":"town_boss_blackbell_01"})
	scene.map_index=0;scene._interact("maps");await process_frame
	check(scene.page=="maps" and scene.map_index==0,"the war table opens on the first map")
	check(not scene._map_preview(BWRooms.map("cursed_town")) is GradientTexture2D,"the cursed town shows its rendered picture")
	check(scene._map_preview(BWRooms.map("zz_second_map")) is GradientTexture2D,"a map with no picture still gets a plate")
	var right=InputEventAction.new();right.action="ui_right";right.pressed=true
	scene._unhandled_input(right);await process_frame
	check(scene.map_index==1 and scene.page=="maps","the right arrow turns to the next map")
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=Vector2(500,300)
	var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=Vector2(300,300)
	scene._map_swipe(press);scene._map_swipe(release);await process_frame
	check(scene.map_index==0 and scene.page=="maps","a swipe to the left turns the table on, wrapping round to the first")
	var small=InputEventMouseButton.new();small.button_index=MOUSE_BUTTON_LEFT;small.pressed=false;small.position=Vector2(470,300)
	var before=scene.map_index;scene._map_swipe(press);scene._map_swipe(small)
	check(scene.map_index==before,"a short drag does not turn it")
	BWRooms.maps.erase("zz_second_map");BWRooms.map_order.erase("zz_second_map")
	scene._back();await process_frame
	scene.show_menu();await process_frame
	# Death in a hunt lands back in the safehouse.
	scene.start_run("warrior",true,false,"cursed_town");await process_frame
	scene.run.stats.hp=0;scene.world._physics_process(0.016)
	await create_timer(5.5).timeout
	check(scene.page=="gameover","a death in a hunt reaches the results")
	scene.enter_safehouse(scene.run.class_id);await process_frame
	check(scene.in_safehouse() and scene.world.run.class_id=="warrior","results lead back to the safehouse")
	scene.show_menu();await process_frame

# A room no core code knows about: registered from data, routed by its own map.
func _seventh_room(scene):
	var extra={"id":"town_test_alley_07","name":"THE TEST ALLEY","region":"cursed_town","type":"combat","size":[30,24],
		"doors":{"entrance":{"at":[0,12]},"exit":{"at":[0,-12]}},
		"markers":{"EntrySpawn":[0,8],"RewardPoint":[7,-9],"EnemySpawn":[[-11,-6],[11,-6],[-11,4],[11,4]]},
		"layout":[{"kind":"cargo","at":[-6,0],"size":[4,3],"height":1.2}],
		"encounter":{"roster":["grunt","grunt","archer"],"cap":3}}
	check(BWRooms.register(extra),"a seventh ordinary room registers from data")
	check(BWRooms.rooms_of("cursed_town","combat").size()==6,"the pool now holds six ordinary town rooms")
	check(BWRooms.night_plan(BWRooms.map("cursed_town")).size()==7,"the existing route is untouched by the bigger pool")
	check(BWRooms.register_map({"id":"test_alley_route","name":"TEST","route":["town_test_alley_07","town_gateyard_01"],"boss":"town_boss_blackbell_01"}),"a separate route can use it")
	var drawn=BWRooms.night_plan({"draw":{"region":"cursed_town","count":3},"boss":"town_boss_blackbell_01"},RandomNumberGenerator.new())
	check(drawn.size()==4 and drawn[3]=="town_boss_blackbell_01","a drawn route takes only the number of rooms it asks for")
	scene.start_run("warrior",true,false,"test_alley_route");await process_frame
	var w=scene.world
	check(w.room.id=="town_test_alley_07" and w.arena.problems.is_empty(),"the new room loads and validates")
	w.rest_time=0.0;w._room_tick()
	check(w.encounter==["grunt","grunt","archer"],"the new room fields its own roster")
	check(not BWRooms.register({"id":"broken","type":"combat","size":[20,20]}),"a room without doors or markers is rejected")
	BWRooms.maps.erase("test_alley_route");BWRooms.map_order.erase("test_alley_route");BWRooms.rooms.erase("town_test_alley_07")
	scene.show_menu();await process_frame

# Markers, collision proxies and door leaves come from a delivered scene when there
# is one. A .tscn stands in for the exported .glb: both load as a PackedScene.
func _delivered_scene():
	var top=Node3D.new();top.name="town_scene_test"
	var named=func(parent: Node,name: String,spot: Vector3) -> Node3D:
		var node=Node3D.new();node.name=name;node.position=spot;parent.add_child(node);node.owner=top;return node
	for spec in [["EntrySpawn",Vector3(0,0,10)],["EntranceDoor",Vector3(0,0,14)],["ExitDoor",Vector3(0,0,-14)],["RewardPoint",Vector3(-6,0,-11)],["EnemySpawn_02",Vector3(9,0,-4)],["EnemySpawn_01",Vector3(-9,0,-4)]]:
		named.call(top,spec[0],spec[1])
	var collision=named.call(top,"Collision",Vector3.ZERO)
	var proxy=MeshInstance3D.new();proxy.name="COL_Cart";var box=BoxMesh.new();box.size=Vector3(4,1.5,2);proxy.mesh=box
	proxy.position=Vector3(5,0.75,2);collision.add_child(proxy);proxy.owner=top
	named.call(top,"ExitLeaf_L",Vector3(-3,0,-14));named.call(top,"ExitLeaf_R",Vector3(3,0,-14))
	var packed=PackedScene.new();packed.pack(top);ResourceSaver.save(packed,"user://room_scene_test.tscn");top.free()
	var row={"id":"town_scene_test","type":"combat","size":[30,28],"scene":"user://room_scene_test.tscn",
		"doors":{"entrance":{"at":[0,14]},"exit":{"at":[0,-14]}},"markers":{"EntrySpawn":[0,0],"EnemySpawn":[[1,1]]},
		"encounter":{"roster":["grunt"]}}
	check(BWRooms.register(row),"a room with a scene registers")
	var arena=BWRoomArena.new();root.add_child(arena);arena.build_room(BWRooms.room("town_scene_test"),"Mobile",3)
	check(arena.from_scene,"the delivered scene is used instead of the grey box")
	check(arena.marker("EntrySpawn").is_equal_approx(Vector3(0,0,10)),"EntrySpawn is read from the scene")
	check(arena.enemy_spawns().size()==2 and arena.enemy_spawns()[0].x<0,"EnemySpawn_NN markers are read in order")
	check(arena.in_rect(Vector3(5,0,2)) and not arena.in_rect(Vector3(0,0,0)),"COL_ proxies become obstacles")
	check(not arena.find_child("COL_Cart",true,false).visible,"collision proxies are not drawn")
	check(arena.exit_zone().has_point(Vector2(0,-13)),"the exit zone is derived from ExitDoor")
	check(arena.doors.has("exit") and arena.doors.exit.leaves.size()==2,"door leaves are found by name")
	arena.set_door("exit",true,false)
	check(not is_zero_approx(arena.find_child("ExitLeaf_L",true,false).rotation.y),"the leaves swing on their pivots")
	check(arena.problems.is_empty(),"the delivered room validates: "+str(arena.problems))
	arena.queue_free();BWRooms.rooms.erase("town_scene_test")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://room_scene_test.tscn"))
	# A delivered kit piece replaces its primitive everywhere it is used, fitted
	# inside the footprint the layout gives it.
	var crate=MeshInstance3D.new();crate.name="CargoModel";var mesh=BoxMesh.new();mesh.size=Vector3(10,4,6);crate.mesh=mesh
	var kit_scene=PackedScene.new();kit_scene.pack(crate);ResourceSaver.save(kit_scene,"user://kit_cargo_test.tscn");crate.free()
	BWRoomArena.kit_rows()
	var saved=BWRoomArena.kit.get("cargo",{}).duplicate(true)
	BWRoomArena.kit["cargo"]={"fit":"footprint","files":["user://kit_cargo_test.tscn"]}
	var yard=BWRoomArena.new();root.add_child(yard);yard.build_room(BWRooms.room("town_cargo_02"),"Mobile",5)
	var pieces=yard.find_children("*Kit_cargo*","",true,false)
	check(pieces.size()==3,"every cargo island uses the delivered model")
	check(yard.get_children().filter(func(n):return String(n.name).begins_with("Cargo")).is_empty(),"no grey-box cargo is built alongside it")
	var island=BWRooms.room("town_cargo_02").layout[0]
	var fitted=yard._prop_bounds(pieces[0])
	check(fitted.size.x<=float(island.size[0])+0.01 and fitted.size.z<=float(island.size[1])+0.01 and absf(fitted.position.y)<0.01,"the model is fitted inside its footprint, standing on the street")
	check(yard.problems.is_empty(),"the room still validates with kit pieces")
	yard.queue_free()
	if saved.is_empty():BWRoomArena.kit.erase("cargo")
	else:BWRoomArena.kit["cargo"]=saved
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://kit_cargo_test.tscn"))
	await process_frame
