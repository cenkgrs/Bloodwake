extends SceneTree
var checks=0
var failures=0
func check(ok: bool,why: String):
 checks+=1
 if not ok:failures+=1;push_error(why)
func _initialize():call_deferred("suite")
func suite():
 var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.meta=BWMeta.new();scene.meta.path="user://combat_flow_test_progression.json"
 scene.start_run("warrior");await process_frame
 var world=scene.world;var run=scene.run;var visual=world.visual
 world.running=false;world.auto_fire=false;run.stats.dodgeChance=0;run.stats.armor=0;run.stats.lifesteal=0
 var grunt=world.spawn_enemy("grunt",Vector3(0.4,0,0));grunt.cooldown=0
 var hp=run.stats.hp;world._enemy_tick(grunt,0.016)
 check(run.stats.hp==hp-8,"grunt melee deals eight damage")
 hp=run.stats.hp;world._enemy_tick(grunt,0.016);check(run.stats.hp==hp,"melee respects cooldown")
 world.enemies.erase(grunt);grunt.node.queue_free()
 var tank=world.spawn_enemy("tank",Vector3(0.4,0,0));tank.cooldown=0
 hp=run.stats.hp;world._enemy_tick(tank,0.016);check(run.stats.hp==hp-16,"tank deals damage")
 world.enemies.erase(tank);tank.node.queue_free()
 var archer=world.spawn_enemy("archer",Vector3(2,0,0));archer.cooldown=0
 hp=run.stats.hp;world._enemy_tick(archer,0.016)
 await process_frame
 for i in 40:
  world._projectiles(0.016)
  await process_frame
 check(run.stats.hp==hp-7,"archer projectile damages player")
 world.enemies.erase(archer);archer.node.queue_free()
 visual.lock_time=0;visual.action("attack",0.45)
 check(is_equal_approx(visual.lock_time,0.45),"Warrior attack fits 450 ms")
 visual.tick(0.46,true);check(visual.state=="run","Warrior returns to movement without long recovery")
 check(is_equal_approx(visual.animation.get_animation(visual.clips.run).length/visual.clip_speed("run"),0.62),"Warrior locomotion has responsive cadence")
 visual.tick(0.01,true,1.5);check(is_equal_approx(visual.animation.speed_scale,1.5),"movement upgrades affect cadence")
 var target=world.spawn_enemy("tank",Vector3(0.7,0,0));target.cooldown=100;target.hp=100;run.stats.criticalChance=0
 world.auto_fire=true;visual.lock_time=0;world._weapons(0.016)
 check(target.hp==100 and world.pending_attacks.size()==1,"sword waits for contact frame")
 world._pending_attacks(0.10);check(target.hp==100,"sword does not hit during wind-up")
 world._pending_attacks(0.06);check(target.hp==80,"sword deals one hit on contact")
 world._pending_attacks(0.5);check(target.hp==80,"pending attack resolves only once")
 visual.lock_time=0;run.weapons.sword.cooldown=0;run.stats.attackSpeed=3;world._weapons(0.016)
 check(visual.lock_time<0.2,"attack animation accelerates with attack speed")
 await create_timer(0.7).timeout
 scene.show_menu();await process_frame
 scene.start_run("mage");await process_frame;world=scene.world;run=scene.run;visual=world.visual;world.running=false
 check(visual.clips.size()==6 and visual.clips.has("ultimate"),"Mage has six authored clips")
 check(is_instance_valid(visual.hand_magic) and visual.hand_bone>=0,"Mage magic is attached to a real hand")
 check(not visual.procedural,"Mage uses the supplied model")
 var before=visual.hand_magic.global_position
 visual.animation.play(visual.clips.attack);visual.animation.seek(0.5,true);await process_frame
 check(before.distance_to(visual.hand_magic.global_position)>0.01,"hand VFX follows animated hand")
 world.running=true;world.auto_fire=false;world.rest_time=999
 target=world.spawn_enemy("tank",Vector3(1,0,0));target.cooldown=100;target.hp=1000
 world.ability()
 check(visual.state=="ultimate" and world.pending_attacks.size()==1,"Mage uses distinct ultimate clip")
 check(target.hp==1000,"ultimate damage waits for casting pose")
 world.running=false;await process_frame;world._pending_attacks(0.46);check(target.hp<1000,"ultimate resolves at cast frame")
 # The real wave signal must leave the arena visible for two seconds.
 await create_timer(0.7).timeout
 world.pending_attacks.clear()
 for enemy in world.enemies:enemy.node.queue_free()
 world.enemies.clear();world.spawned=999;run.pending_levels=0
 world._spawn_tick(0.01)
 check(scene.page=="wave_complete" and world.process_mode!=Node.PROCESS_MODE_DISABLED,"wave overlay preserves live animation")
 await create_timer(1.0).timeout;check(scene.page=="wave_complete","wave overlay remains after one second")
 await create_timer(1.15).timeout;check(scene.page=="shop","wave overlay reaches reward menu after two seconds")
 scene.start_run("warrior");await process_frame;world=scene.world;run=scene.run;world.auto_fire=false;world.rest_time=999;run.stats.hp=0
 world._physics_process(0.016)
 check(scene.page=="death_animation" and world.visual.dead,"death first shows unobstructed animation")
 check(world.audio_times.has("game_over"),"death sound is triggered")
 check(world.visual.lock_time<=2.7,"death animation fits overlay")
 await create_timer(1.0).timeout;check(scene.page=="death_animation","YOU DIED does not cover the first second")
 await create_timer(1.15).timeout;check(scene.page=="death_transition","YOU DIED appears after two seconds")
 await create_timer(1.0).timeout;check(scene.page=="death_transition","YOU DIED remains visible")
 await create_timer(1.85).timeout;check(scene.page=="gameover" and run.awarded,"death reaches results and awards once")
 # A stale transition must not replace a new run or menu.
 scene.start_run("warrior");await process_frame;scene._wave_complete();scene.show_menu()
 await create_timer(2.15).timeout;check(scene.page=="menu","stale transition cannot reopen reward menu")
 scene.start_run("gunslinger");await process_frame
 check(not scene.world.visual.fitted_timing and scene.world.visual.clip_speed("attack")==1.0,"Bloodbound keeps its original playback speed")
 DirAccess.remove_absolute(scene.meta.path)
 scene.queue_free();await process_frame
 print("COMBAT_FLOW_TESTS ",checks," checks / ",failures," failures")
 quit(1 if failures>0 else 0)
