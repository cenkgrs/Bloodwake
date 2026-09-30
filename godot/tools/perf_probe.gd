extends SceneTree

# Plays a run unattended and reports every frame that took too long, so a stall can
# be measured instead of guessed at.
#
#   godot --path godot --script tools/perf_probe.gd
#
# Needs a real display: headless skips rendering, and a stall that lives in the
# renderer would not show up at all.

const SECONDS = 60.0
const SPIKE_MS = 80.0

func _initialize():
	call_deferred("probe")

func probe():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.meta = BWMeta.new()
	scene.meta.path = "user://perf_probe_progression.json"
	scene.start_run("warrior")
	await process_frame
	var world = scene.world
	world.auto_fire = true
	world.run.wave=5
	world.run.stats.maxHp=100000;world.run.stats.hp=100000
	world.wave_cleared.disconnect(scene._wave_complete)
	world.wave_cleared.connect(func():world.next_wave();world.rest_time=0.1)
	Input.action_press("fire")
	var skill_beat=-1


	# Waves have to actually arrive for the stall to have anything to stall on, and
	# resting between them wastes most of the window.
	world.rest_time = 0.5
	var start = Time.get_ticks_usec()
	var beat = 0.0
	var last = start
	var frames = 0
	var spikes = []
	while float(Time.get_ticks_usec() - start) / 1e6 < SECONDS:
		await process_frame
		var now = Time.get_ticks_usec()
		var ms = float(now - last) / 1000.0
		last = now
		frames += 1
		var elapsed = float(now - start) / 1e6
		if int(elapsed/3.0)%2==0:Input.action_press("heavy")
		else:Input.action_release("heavy")
		if int(elapsed/4.0)!=skill_beat:
			skill_beat=int(elapsed/4.0);world.skill(skill_beat%2);world.ability()
		if elapsed - beat >= 5.0:
			beat = elapsed
			print("BEAT t=%5.1fs wave=%d level=%d pending=%d enemies=%2d bullets=%2d hp=%.0f" % [elapsed, world.run.wave, world.run.level, world.run.pending_levels, world.enemies.size(), world.bullets.size(), world.run.stats.hp])
		if ms > SPIKE_MS:
			spikes.append([float(now - start) / 1e6, ms, world.run.wave, world.enemies.size(), world.bullets.size()])

	var span = float(Time.get_ticks_usec() - start) / 1e6
	print("PROBE %d frames over %.1fs (%.1f fps avg), %d spikes over %d ms" % [frames, span, frames / span, spikes.size(), SPIKE_MS])
	var previous = 0.0
	for s in spikes:
		print("SPIKE t=%6.2fs  %7.1f ms  gap=%5.2fs  wave=%d  enemies=%2d  bullets=%d" % [s[0], s[1], s[0] - previous, s[2], s[3], s[4]])
		previous = s[0]
	Input.action_release("fire");Input.action_release("heavy")
	quit()
