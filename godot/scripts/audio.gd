class_name BWAudio
extends Node

# One mixer, one sample bank, one pool of voices. Every sound in the game goes
# through play()/play_at() so variation, pitch spread and voice limits are
# applied in one place instead of at each call site.

const DIR = "res://assets/audio/"
const POOL_FLAT = 10
const POOL_WORLD = 20
# The camera sits ~20 m back from the action, so attenuation has to be scaled up
# or every world sound would arrive already faded out.
const WORLD_UNIT_SIZE = 28.0
const WORLD_MAX_DISTANCE = 60.0

# files: variations picked at random (or by index for combo steps)
# db: trim relative to the normalised sample
# pitch: randomised range - what stops a repeated sample reading as a machine gun
# voices: how many of this event may sound at once
# gap: minimum seconds between two triggers of this event
const BANK := {
	"sword_swing":      {"files":["sword_swing_a","sword_swing_b","sword_swing_c"],"db":-3.0,"pitch":[0.96,1.05],"voices":3,"gap":0.0},
	"sword_hit_flesh":  {"files":["sword_hit_flesh_1","sword_hit_flesh_2","sword_hit_flesh_3"],"db":-4.0,"pitch":[0.93,1.07],"voices":3,"gap":0.02},
	"sword_hit_armor":  {"files":["sword_hit_armor_1","sword_hit_armor_2","sword_hit_armor_3"],"db":-5.0,"pitch":[0.94,1.06],"voices":3,"gap":0.02},
	"dagger_swing":     {"files":["dagger_swing_a","dagger_swing_b","dagger_swing_c"],"db":-4.0,"pitch":[0.95,1.08],"voices":3,"gap":0.0},
	"revenant_swing":   {"files":["revenant_basic_attack_a","revenant_basic_attack_b","revenant_basic_attack_c"],"db":-3.0,"pitch":[0.98,1.02],"voices":3,"gap":0.0},
	"dagger_hit":       {"files":["dagger_hit_1","dagger_hit_2","dagger_hit_3"],"db":-6.0,"pitch":[0.93,1.09],"voices":3,"gap":0.02},
	"gun_rifle":        {"files":["gun_rifle_1","gun_rifle_2","gun_rifle_3"],"db":-5.0,"pitch":[0.94,1.07],"voices":4,"gap":0.0},
	"gun_pistol":       {"files":["gun_pistol_1","gun_pistol_2"],"db":-5.0,"pitch":[0.95,1.05],"voices":3,"gap":0.0},
	"gun_shotgun":      {"files":["gun_shotgun_1","gun_shotgun_2"],"db":-4.0,"pitch":[0.96,1.04],"voices":2,"gap":0.0},
	"orb_cast":         {"files":["orb_cast_1","orb_cast_2","orb_cast_3"],"db":-4.0,"pitch":[0.94,1.06],"voices":3,"gap":0.0},
	"orb_impact":       {"files":["orb_impact_1","orb_impact_2","orb_impact_3"],"db":-6.0,"pitch":[0.92,1.08],"voices":3,"gap":0.02},
	"lightning_cast":   {"files":["lightning_cast"],"db":-4.0,"pitch":[0.95,1.06],"voices":2,"gap":0.0},
	"lightning_chain":  {"files":["lightning_chain_1","lightning_chain_2","lightning_chain_3"],"db":-7.0,"pitch":[0.92,1.10],"voices":3,"gap":0.02},
	"ulti_war_cry":       {"files":["ulti_war_cry"],"db":0.0,"pitch":[0.99,1.01],"voices":1,"gap":0.2},
	"ulti_frost_nova":    {"files":["ulti_frost_nova"],"db":-1.0,"pitch":[0.99,1.01],"voices":1,"gap":0.2},
	"ulti_shadow_strike": {"files":["ulti_shadow_strike"],"db":-1.0,"pitch":[0.99,1.01],"voices":1,"gap":0.2},
	"ulti_fan_shot":      {"files":["ulti_fan_shot"],"db":-1.0,"pitch":[0.99,1.01],"voices":1,"gap":0.2},
	"skill_meteor_cast":  {"files":["skill_meteor_cast"],"db":-4.0,"pitch":[0.97,1.04],"voices":2,"gap":0.1},
	"skill_meteor_blast": {"files":["skill_meteor_blast"],"db":-1.0,"pitch":[0.97,1.03],"voices":2,"gap":0.1},
	"skill_leap_launch":  {"files":["skill_leap_launch"],"db":-5.0,"pitch":[0.98,1.03],"voices":1,"gap":0.1},
	"skill_leap_land":    {"files":["skill_leap_land"],"db":-1.0,"pitch":[0.98,1.02],"voices":1,"gap":0.1},
	"hit_light":        {"files":["hit_light_1","hit_light_2","hit_light_3","hit_light_4"],"db":-9.0,"pitch":[0.90,1.10],"voices":3,"gap":0.03},
	"hit_heavy":        {"files":["hit_heavy_1","hit_heavy_2","hit_heavy_3"],"db":-6.0,"pitch":[0.92,1.08],"voices":3,"gap":0.03},
	"enemy_death":      {"files":["enemy_death_1","enemy_death_2","enemy_death_3"],"db":-5.0,"pitch":[0.92,1.08],"voices":4,"gap":0.04},
	"boss_death":       {"files":["boss_death"],"db":1.0,"pitch":[1.0,1.0],"voices":1,"gap":0.5},
	"boss_phase":       {"files":["boss_phase"],"db":-1.0,"pitch":[0.98,1.02],"voices":1,"gap":0.3},
	"player_hit":       {"files":["player_hit_1","player_hit_2","player_hit_3"],"db":-3.0,"pitch":[0.94,1.06],"voices":2,"gap":0.10},
	"player_death":     {"files":["player_death"],"db":1.0,"pitch":[1.0,1.0],"voices":1,"gap":0.5},
	"level_up":         {"files":["level_up"],"db":-3.0,"pitch":[1.0,1.0],"voices":1,"gap":0.1},
	"upgrade_pick":     {"files":["upgrade_pick"],"db":-4.0,"pitch":[0.98,1.02],"voices":1,"gap":0.05},
	"purchase":         {"files":["purchase"],"db":-4.0,"pitch":[0.98,1.02],"voices":1,"gap":0.05},
	"wave_clear":       {"files":["wave_clear"],"db":-2.0,"pitch":[1.0,1.0],"voices":1,"gap":0.2},
	"wave_start":       {"files":["wave_start"],"db":-3.0,"pitch":[0.99,1.01],"voices":1,"gap":0.2},
	"pickup_health":    {"files":["pickup_health"],"db":-8.0,"pitch":[0.95,1.08],"voices":2,"gap":0.05},
	"ui_click":         {"files":["ui_click"],"db":-6.0,"pitch":[0.98,1.02],"voices":2,"gap":0.03},
	"ui_select":        {"files":["ui_select"],"db":-6.0,"pitch":[0.98,1.02],"voices":2,"gap":0.03},
	"ui_error":         {"files":["ui_error"],"db":-6.0,"pitch":[1.0,1.0],"voices":1,"gap":0.05},
}

const MUSIC := {"menu":"music_menu","combat":"music_combat","boss":"music_boss"}
const MUSIC_DB := {"menu":-13.0,"combat":-15.0,"boss":-13.0}

var streams: Dictionary = {}
var music_streams: Dictionary = {}
var flat: Array[AudioStreamPlayer] = []
var world: Array[AudioStreamPlayer3D] = []
var active: Dictionary = {}
var last_played: Dictionary = {}
var last_variant: Dictionary = {}
var music_players: Array[AudioStreamPlayer] = []
var music_track = ""
var music_fade: Tween
var duck_db = 0.0
var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buses()
	for event in BANK:
		for name in BANK[event].files:
			if not streams.has(name):
				var mastered=DIR+"polished/"+name+".wav"
				var source=mastered if ResourceLoader.exists(mastered) else DIR+name+".wav"
				streams[name] = load(source) if ResourceLoader.exists(source) else null
	for key in MUSIC:
		music_streams[key] = load(DIR + MUSIC[key] + ".ogg")
		if music_streams[key] is AudioStreamOggVorbis:
			music_streams[key].loop = true
	for i in POOL_FLAT:
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		flat.append(player)
	for i in POOL_WORLD:
		var player = AudioStreamPlayer3D.new()
		player.bus = "SFX"
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = WORLD_UNIT_SIZE
		player.max_distance = WORLD_MAX_DISTANCE
		player.panning_strength = 0.6
		add_child(player)
		world.append(player)
	for i in 2:
		var player = AudioStreamPlayer.new()
		player.bus = "Music"
		add_child(player)
		music_players.append(player)

# A music stream still playing at shutdown keeps its Ogg playback alive past
# ObjectDB cleanup, which Godot reports as a leak; release it on the way out.
func _exit_tree():
	shutdown()

# Releases every stream reference this node holds. Called on the way out so an
# Ogg playback is not still alive at ObjectDB cleanup, which reports as a leak.
# Never free() the players here - doing that mid-teardown deadlocks it.
func shutdown():
	stop_music()
	for player in flat + world:
		if is_instance_valid(player):player.stop();player.stream = null
	streams.clear()
	music_streams.clear()

func stop_music():
	if music_fade != null and music_fade.is_valid():music_fade.kill()
	music_track = ""
	for player in music_players:
		if not is_instance_valid(player):continue
		player.stop()
		player.stream = null

func _buses():
	for name in ["Music","SFX","UI"]:
		if AudioServer.get_bus_index(name) != -1: continue
		var index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, name)
		AudioServer.set_bus_send(index, "Master")

	var sfx=AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx)==0:
		var compressor=AudioEffectCompressor.new();compressor.threshold=-12.0;compressor.ratio=3.0;compressor.attack_us=2500;compressor.release_ms=90;compressor.gain=0.0
		AudioServer.add_bus_effect(sfx,compressor)
	var master=AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master)==0:AudioServer.add_bus_effect(master,AudioEffectLimiter.new())

# --- sfx ------------------------------------------------------------------

func play(event: String, db_offset: float = 0.0, variant: int = -1):
	var config = _take(event, variant)
	if config.is_empty(): return
	var player = _free_flat()
	if player == null: return
	player.stream = config.stream
	player.volume_db = config.db + db_offset
	player.pitch_scale = config.pitch
	player.play()
	_track(event, player)

func play_at(event: String, position: Vector3, db_offset: float = 0.0, variant: int = -1):
	var config = _take(event, variant)
	if config.is_empty(): return
	var player = _free_world()
	if player == null: return
	player.global_position = position
	player.stream = config.stream
	player.volume_db = config.db + db_offset
	player.pitch_scale = config.pitch
	player.play()
	_track(event, player)

func has_sample(event: String) -> bool:
	var entry=BANK.get(event)
	if entry==null:return false
	for name in entry.files:
		if streams.get(name)!=null:return true
	return false

func ui(event: String):
	var config = _take(event, -1)
	if config.is_empty(): return
	var player = _free_flat()
	if player == null: return
	player.bus = "UI"
	player.stream = config.stream
	player.volume_db = config.db
	player.pitch_scale = config.pitch
	player.play()
	_track(event, player)

# Resolves a bank entry into a concrete stream, or {} when the event is rate
# limited, out of voices or unknown.
func _take(event: String, variant: int) -> Dictionary:
	var entry = BANK.get(event)
	if entry == null: return {}
	var now = Time.get_ticks_msec() / 1000.0
	if now - float(last_played.get(event, -100.0)) < entry.gap: return {}
	if int(active.get(event, 0)) >= entry.voices: return {}
	var files = entry.files
	var index = clampi(variant, 0, files.size() - 1) if variant >= 0 else rng.randi_range(0, files.size() - 1)
	if variant<0 and files.size()>1 and index==last_variant.get(event,-1):index=(index+1+rng.randi_range(0,files.size()-2))%files.size()
	last_variant[event]=index
	var stream = streams.get(files[index])
	if stream == null: return {}
	last_played[event] = now
	return {"stream":stream,"db":entry.db,"pitch":rng.randf_range(entry.pitch[0], entry.pitch[1])}

func _track(event: String, player: Node):
	active[event] = int(active.get(event, 0)) + 1
	player.finished.connect(func(): active[event] = maxi(0, int(active.get(event, 0)) - 1), CONNECT_ONE_SHOT)

func _free_flat() -> AudioStreamPlayer:
	for player in flat:
		if not player.playing:
			player.bus = "SFX"
			return player
	return null

func _free_world() -> AudioStreamPlayer3D:
	for player in world:
		if not player.playing: return player
	return null

# --- music ----------------------------------------------------------------

func music(track: String, fade: float = 1.2):
	if track == music_track: return
	music_track = track
	var target = music_players[0] if not music_players[0].playing else music_players[1]
	var previous = music_players[1] if target == music_players[0] else music_players[0]
	if music_fade != null and music_fade.is_valid(): music_fade.kill()
	music_fade = create_tween().set_parallel(true)
	if track.is_empty():
		if previous.playing: music_fade.tween_property(previous, "volume_db", -60.0, fade)
		if target.playing: music_fade.tween_property(target, "volume_db", -60.0, fade)
		music_fade.chain().tween_callback(_stop_music)
		return
	var stream = music_streams.get(track)
	if stream == null: return
	target.stream = stream
	target.volume_db = -60.0
	target.play()
	music_fade.tween_property(target, "volume_db", _music_db(), fade)
	if previous.playing:
		music_fade.tween_property(previous, "volume_db", -60.0, fade)
		music_fade.chain().tween_callback(previous.stop)

func _stop_music():
	for player in music_players: player.stop()

func _music_db() -> float:
	return float(MUSIC_DB.get(music_track, -15.0)) + duck_db

# Pulls the music down under menus and overlays so panels read as a lull.
func duck(amount: float, fade: float = 0.35):
	if is_equal_approx(duck_db, amount): return
	duck_db = amount
	for player in music_players:
		if player.playing: create_tween().tween_property(player, "volume_db", _music_db(), fade)
