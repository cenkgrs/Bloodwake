extends SceneTree
var failures = 0
func check(ok: bool, message: String):
 if not ok: failures += 1; push_error(message)
func _initialize(): call_deferred("suite")
func suite():
 var arena = BWArena.new();root.add_child(arena);arena.build("PC",42)
 for kind in ["pillar","brazier","bones","urn","altar"]:
  var spec = BWArena.PROPS[kind]
  var obj = arena._model(kind,spec,BWArena.ZONES[3]);arena.add_child(obj)
  var bounds = arena._prop_bounds(obj.get_child(0))
  check(absf(bounds.position.y)<0.001,"grounded: "+kind)
  check(bounds.size.y<=spec.height+0.001,"height: "+kind)
  check(maxf(bounds.size.x,bounds.size.z)<=spec.radius*2+0.001,"footprint: "+kind)
  if kind=="brazier":check(obj.get_child_count()==3,"brazier keeps embers and light")
  obj.queue_free()
 var urn=arena.breakables[0]
 check(arena.damage_area(urn.pos,0.01,20).size()>0,"urn breaks under damage")
 var obstacle=arena.blockers[0]
 check(arena.push_out(obstacle.pos,0.3).distance_to(obstacle.pos)>=obstacle.radius+0.29,"solid props block movement")
 arena.queue_free();await process_frame
 print("ALTAR_PROPS_TEST failures=",failures);quit(0 if failures==0 else 1)
