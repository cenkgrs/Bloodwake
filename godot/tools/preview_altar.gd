extends SceneTree
func _initialize():call_deferred("capture")
func capture():
 var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
 await process_frame
 scene.start_run("warrior")
 await process_frame
 var world=scene.world
 world.running=false
 world.player.position=Vector3(-20,0,21)
 world.camera.position=world.player.position+Vector3(0,16,12)
 world.camera.look_at(world.player.position)
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../art/environment/altar/ingame_preview.png")
 quit()
