extends SceneTree
func _initialize():call_deferred("export_rooms")
func export_rooms():
	BWRooms.load_all()
	var output=ProjectSettings.globalize_path("res://../unity/RoomSources")
	DirAccess.make_dir_recursive_absolute(output)
	for id in BWRooms.rooms:
		var arena=BWRoomArena.new();root.add_child(arena)
		arena.build_room(BWRooms.rooms[id],"PC",1234)
		await process_frame
		var collision={"circles":[],"rects":[],"hidden":[]}
		for block in arena.blockers:collision.circles.append([block.pos.x,block.pos.z,block.radius])
		for rect in arena.rects:collision.rects.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
		arena.set_camera_side_visible(false)
		for node in arena.camera_side:collision.hidden.append(str(node.name))
		var file=FileAccess.open(output+"/"+id+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify(collision,"  "));file.close()
		var document=GLTFDocument.new();var state=GLTFState.new()
		var result=document.append_from_scene(arena,state)
		if result==OK:result=document.write_to_filesystem(state,output+"/"+id+".glb")
		if result!=OK:push_error("Room export failed: "+id);quit(1);return
		print("UNITY_ROOM_EXPORTED ",id);arena.queue_free();await process_frame
	quit()
