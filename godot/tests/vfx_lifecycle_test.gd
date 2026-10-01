extends SceneTree
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	for quality in ["PC","Mobile"]:
		var fx=BWFx.new();root.add_child(fx);fx.configure(quality)
		fx.slash(Vector3.ZERO,Vector3.RIGHT,2,Color.ORANGE)
		fx.arcane_blast(Vector3.ZERO,3,Color.CYAN,Color.BLUE)
		var mark=fx.telegraph(Vector3.ZERO,3,Color.MAGENTA,0.5)
		var ring=fx.surface(Vector3.ZERO,2,Color.CYAN,0.5,3)
		await create_timer(0.1).timeout
		check(is_instance_valid(mark) and is_instance_valid(ring),quality+": surfaces stay alive during animation")
		check(float(ring.get_child(0).material_override.get_shader_parameter("progress"))>0,quality+": shader progress advances")
		await create_timer(1.2).timeout
		check(fx.get_child_count()==0,quality+": transient VFX clean up all nodes")
		var orb=fx.orb_dressing(Color.MAGENTA,quality=="PC",Color.RED);fx.add_child(orb)
		check(orb.get_node_or_null("Motes")!=null,quality+": orb keeps segmented shell")
		var tail=fx.arcane_tail(Color.MAGENTA,Color.RED);fx.add_child(tail)
		check(tail.get_child_count()==(2 if quality=="PC" else 1),quality+": bounded trail layers")
		fx.queue_free();await process_frame
	print("VFX_LIFECYCLE_TEST checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
