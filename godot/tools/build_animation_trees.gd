extends SceneTree

const CLASSES = ["warrior", "revenant", "gunslinger", "mage", "assassin"]
const OUTPUT = "res://assets/animation_trees"

func _init():
	call_deferred("_build")

func _build():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for kind in CLASSES:
		var visual=BWVisual.new()
		root.add_child(visual)
		visual.configure(kind)
		if visual.animation==null:
			push_error("No AnimationPlayer found for "+kind)
			continue
		var tree=visual.build_animation_tree()
		var result=ResourceSaver.save(tree,"%s/%s.tres" % [OUTPUT,kind])
		if result!=OK:push_error("Could not save AnimationTree for %s: %s" % [kind,result])
		else:print("ANIMATION_TREE_BUILT ",kind," player=",visual.animation_tree.anim_player," clips=",visual.clips.keys())
		visual.free()
	quit()
