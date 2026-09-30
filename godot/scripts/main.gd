extends Node

var world: BWWorld
var run: BWRun
var audio: BWAudio
var meta=BWMeta.new()
var canvas: CanvasLayer
var root: Control
var content: Control
var hud: Control
var hud_label: Label
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var skill_label: Label
var boss_label: Label
var touch: BWTouch
var page="menu"
var class_pick="warrior"
var skill_pick="might"
var quality="PC"
var volume=0.65
var mobile_controls=false
var boss_reward=false
var choosing_boss=false
var choices=[]
var shop_offers=[]
var rerolls=0
var refreshes=0
var backdrop: Node3D
var menu_art: BWVisual
var cfg=ConfigFile.new()
var smoke_mode=false
var transition_serial=0
const WAVE_TRANSITION_SECONDS=2.0
const DEATH_ANIMATION_SECONDS=2.0
const DEATH_TRANSITION_SECONDS=2.7
const GOLD=BWKit.GOLD
const MUTED=BWKit.MUTED

func _ready():
	_inputs();BWData.load_catalogs();meta.load_save()
	if cfg.load("user://settings.cfg")==OK:
		quality=cfg.get_value("graphics","profile","PC");volume=cfg.get_value("audio","volume",0.65)
	mobile_controls=OS.has_feature("mobile")
	if mobile_controls:quality="Mobile"
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.001)))
	audio=BWAudio.new();add_child(audio)
	canvas=CanvasLayer.new();add_child(canvas)
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.add_child(root)
	root.theme=_theme()
	_menu_backdrop();show_menu()
	if "--smoke" in OS.get_cmdline_user_args():
		smoke_mode=true;_smoke()
	elif "--qa" in OS.get_cmdline_user_args():
		_visual_qa()
	elif "--shots" in OS.get_cmdline_user_args():
		_menu_shots()
	elif "--arena" in OS.get_cmdline_user_args():
		_arena_shots()

func _theme() -> Theme:
	var theme=Theme.new();theme.default_font_size=16;theme.default_font=BWKit.body_font()
	theme.set_color("font_color","Label",BWKit.INK)
	var normal=StyleBoxFlat.new();normal.bg_color=Color(0.075,0.048,0.052,0.92);normal.border_color=Color(BWKit.IRON,0.95);normal.set_border_width_all(1);normal.set_corner_radius_all(2);normal.content_margin_left=20;normal.content_margin_right=20;normal.content_margin_top=13;normal.content_margin_bottom=13
	var hover=normal.duplicate();hover.bg_color=Color(0.16,0.05,0.058,0.95);hover.border_color=BWKit.EMBER
	var pressed=normal.duplicate();pressed.bg_color=Color(0.22,0.06,0.07,0.96);pressed.border_color=BWKit.EMBER
	var disabled=normal.duplicate();disabled.bg_color=Color(0.05,0.042,0.044,0.9);disabled.border_color=Color(BWKit.IRON,0.5)
	theme.set_stylebox("normal","Button",normal);theme.set_stylebox("hover","Button",hover);theme.set_stylebox("pressed","Button",pressed);theme.set_stylebox("focus","Button",hover);theme.set_stylebox("disabled","Button",disabled)
	theme.set_color("font_color","Button",BWKit.INK);theme.set_color("font_hover_color","Button",Color.WHITE);theme.set_color("font_disabled_color","Button",BWKit.DIM)
	var panel=StyleBoxFlat.new();panel.bg_color=BWKit.PANEL;panel.border_color=Color(BWKit.IRON,0.95);panel.set_border_width_all(1);panel.set_corner_radius_all(2);panel.set_content_margin_all(22);theme.set_stylebox("panel","PanelContainer",panel)
	var bar=StyleBoxFlat.new();bar.bg_color=Color(0.13,0.09,0.09);bar.set_corner_radius_all(1);theme.set_stylebox("background","ProgressBar",bar)
	var fill=StyleBoxFlat.new();fill.bg_color=BWKit.BLOOD;fill.set_corner_radius_all(1);theme.set_stylebox("fill","ProgressBar",fill)
	return theme

func _inputs():
	# E used to be a second binding for the ulti; it drives the class's second skill
	# now, and W stays on movement.
	var keys={"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"ability":[KEY_SPACE],"skill_1":[KEY_Q],"skill_2":[KEY_E],"heavy":[KEY_SHIFT],"pause":[KEY_ESCAPE],"auto_fire":[KEY_TAB],"fullscreen":[KEY_F11],"debug":[KEY_F3]}
	for action in keys:
		if not InputMap.has_action(action):InputMap.add_action(action)
		for key in keys[action]:
			var event=InputEventKey.new();event.physical_keycode=key;InputMap.action_add_event(action,event)
	for action in ["fire","aim_left","aim_right","aim_up","aim_down"]:
		if not InputMap.has_action(action):InputMap.add_action(action,0.2)
	# The right button used to be a second binding for the ulti. It is the heavy
	# modifier now - held, it turns the next left click into the spin attack - so the
	# ulti keeps SPACE alone, which is the binding the class screen advertises.
	for spec in [["fire",MOUSE_BUTTON_LEFT],["heavy",MOUSE_BUTTON_RIGHT]]:
		var event=InputEventMouseButton.new();event.button_index=spec[1];InputMap.action_add_event(spec[0],event)
	for spec in [["move_left",JOY_AXIS_LEFT_X,-1],["move_right",JOY_AXIS_LEFT_X,1],["move_up",JOY_AXIS_LEFT_Y,-1],["move_down",JOY_AXIS_LEFT_Y,1],["aim_left",JOY_AXIS_RIGHT_X,-1],["aim_right",JOY_AXIS_RIGHT_X,1],["aim_up",JOY_AXIS_RIGHT_Y,-1],["aim_down",JOY_AXIS_RIGHT_Y,1],["fire",JOY_AXIS_TRIGGER_RIGHT,1]]:
		var event=InputEventJoypadMotion.new();event.axis=spec[1];event.axis_value=spec[2];InputMap.action_add_event(spec[0],event)
	for spec in [["ability",JOY_BUTTON_A],["skill_1",JOY_BUTTON_X],["skill_2",JOY_BUTTON_B],["heavy",JOY_BUTTON_LEFT_SHOULDER],["pause",JOY_BUTTON_START],["auto_fire",JOY_BUTTON_Y]]:
		var event=InputEventJoypadButton.new();event.button_index=spec[1];InputMap.action_add_event(spec[0],event)

func _menu_backdrop():
	backdrop=Node3D.new();add_child(backdrop)
	var camera=Camera3D.new();camera.position=Vector3(0,2.2,5.8);backdrop.add_child(camera);camera.look_at(Vector3(0,1,0));camera.current=true
	var env=WorldEnvironment.new();var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("0b1019");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("8596b1");environment.ambient_light_energy=0.55;env.environment=environment;backdrop.add_child(env)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-35,0);light.light_energy=1.5;backdrop.add_child(light)
	menu_art=BWVisual.new();backdrop.add_child(menu_art);menu_art.position.x=3.6;menu_art.position.z=-1.4;menu_art.configure("gunslinger",false,Color.WHITE,2.7)

func _process(dt):
	if is_instance_valid(menu_art):menu_art.rotation.y+=dt*0.12;menu_art.tick(dt,false)
	if is_instance_valid(world) and page=="playing":
		if is_instance_valid(touch):world.move_input=touch.movement;world.fire_input=touch.firing
		hp_bar.max_value=run.stats.maxHp;hp_bar.value=run.stats.hp
		xp_bar.max_value=run.xp_needed();xp_bar.value=run.xp
		xp_bar.tooltip_text="Wave level earned · saving up to half of the next XP bar" if run.level_awarded_wave==run.wave else "XP to next level"
		hud_label.text="WAVE %02d     ·     LV %d\n%d / %d HP     ·     %d GOLD     ·     %d KILLS" % [run.wave,run.level,ceili(run.stats.hp),int(run.stats.maxHp),run.gold,run.kills]
		var lines=["%s  ·  %s" % [BWData.entry("abilities",BWData.CLASSES[run.class_id].ability).name,"READY [SPACE / RMB]" if run.ability_cd<=0 else "%.1fs" % run.ability_cd]]
		var keys=["Q","E"]
		for i in BWData.skills(run.class_id).size():
			var id=BWData.skills(run.class_id)[i];var cd=run.skill_cd.get(id,0.0)
			lines.append("%s  ·  %s" % [BWData.entry("abilities",id).name,"READY [%s]" % keys[i] if cd<=0 else "%.1fs" % cd])
		if world.has_heavy():lines.append("SPIN ATTACK  ·  HOLD RMB + LMB")
		lines.append("AUTO FIRE %s  [TAB]     ·     PAUSE [ESC]" % ("ON" if world.auto_fire else "OFF"))
		skill_label.text="\n".join(lines)
		boss_label.text=""
		for enemy in world.enemies:
			if enemy.id=="boss":
				boss_label.text="THE BLOOD WARDEN   ·   %d / %d" % [ceili(enemy.hp),int(enemy.maxHp)]
		var hint=world.zone_hint()
		if not hint.is_empty() and boss_label.text.is_empty():boss_label.text=hint
		if world.rest_time>0:boss_label.text="THE NEXT WAVE ARRIVES IN %.0f" % ceil(world.rest_time)

func _unhandled_input(event):
	if event.is_action_pressed("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("pause"):
		if page=="playing":show_pause()
		elif page=="pause":resume()
		elif page in ["classes","skills","armory","builds","settings"]:show_menu()
	if page!="playing" or not is_instance_valid(world):return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:world.camera.size=maxf(10,world.camera.size-1)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:world.camera.size=minf(24,world.camera.size+1)
	if event.is_action_pressed("ability"):world.ability()
	if event.is_action_pressed("skill_1"):world.skill(0)
	if event.is_action_pressed("skill_2"):world.skill(1)
	if event.is_action_pressed("auto_fire"):world.auto_fire=not world.auto_fire
	if event.is_action_pressed("debug") and OS.is_debug_build():show_debug()

const PORTRAIT_PLATE="res://assets/ui/portraits/%s.png"
const CLASS_MARKS={"warrior":"sword","gunslinger":"crosshair","mage":"snowflake","assassin":"dagger"}

func _plate(id: String) -> Texture2D:
	var texture=load(PORTRAIT_PLATE % id)
	return texture if texture is Texture2D else null

# Every menu sits on the same darkened pane so the 3D backdrop reads as atmosphere
# rather than as competition for the type.
func _scrim(parent: Node,strength: float=0.8):
	var pane=ColorRect.new();pane.color=Color(0.035,0.022,0.026,strength)
	pane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);pane.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(pane)

# Ornaments are authored at a fixed width, so they are centred rather than stretched.
func _centre(parent: Node,node: Control,width: float) -> Control:
	var box=CenterContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	node.custom_minimum_size.x=width;box.add_child(node);parent.add_child(box);return box

func _spacer(parent: Node,height: float):
	var node=Control.new();node.custom_minimum_size.y=height;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(node)

func banner(parent: Node,text: String,callback: Callable,width: float=220.0,disabled: bool=false) -> BWUI.Banner:
	var node=BWUI.Banner.new(text,Vector2(width,46))
	node.muted=disabled
	parent.add_child(node)
	if not disabled:
		node.pressed.connect(callback)
		node.pressed.connect(func():audio.ui("ui_click"))
		node.mouse_entered.connect(func():audio.ui("ui_select"))
	return node

func body(parent: Node,text: String,size: int=14,color: Color=BWKit.MUTED,wrap: bool=true) -> Label:
	var node=Label.new();node.text=text
	node.add_theme_font_override("font",BWKit.body_font())
	node.add_theme_font_size_override("font_size",size);node.add_theme_color_override("font_color",color)
	if wrap:node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node);return node

func clear_page():
	if is_instance_valid(content):content.queue_free()
	content=Control.new();content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(content)

func label(parent: Node,text: String,size: int=18,color: Color=Color("ece3d2")) -> Label:
	var node=Label.new();node.text=text;node.add_theme_font_size_override("font_size",size);node.add_theme_color_override("font_color",color);parent.add_child(node);return node

func title(parent: Node,text: String,size: int=38):
	var node=label(parent,text,size,GOLD);node.add_theme_font_override("font",BWKit.title_font());return node

func button(parent: Node,text: String,callback: Callable,disabled: bool=false) -> Button:
	var node=Button.new();node.text=text;node.custom_minimum_size=Vector2(0,48);node.disabled=disabled;node.pressed.connect(callback);parent.add_child(node)
	# Every button in the game is built here, so the click/hover feedback only needs wiring once.
	node.pressed.connect(func():audio.ui("ui_click"))
	if not disabled:node.mouse_entered.connect(func():audio.ui("ui_select"))
	return node

func panel_page(heading: String,subtext: String="") -> VBoxContainer:
	clear_page();_scrim(content,0.9)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,60)
	margin.add_theme_constant_override("margin_top",30);margin.add_theme_constant_override("margin_bottom",30)
	content.add_child(margin)
	var outer=VBoxContainer.new();outer.add_theme_constant_override("separation",12);margin.add_child(outer)
	outer.add_child(BWUI.Heading.new(heading.to_upper(),34))
	if not subtext.is_empty():
		body(outer,subtext,13,BWKit.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var holder=Control.new();holder.size_flags_vertical=Control.SIZE_EXPAND_FILL;outer.add_child(holder)
	var frame=BWUI.Frame.new();frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);holder.add_child(frame)
	var inner=MarginContainer.new();inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:inner.add_theme_constant_override("margin_"+side,22)
	holder.add_child(inner)
	var scroll=ScrollContainer.new();inner.add_child(scroll)
	var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",14);scroll.add_child(column)
	return column

func show_menu():
	transition_serial+=1
	page="menu"
	audio.duck(0.0);audio.music("menu")
	if is_instance_valid(world):world.queue_free();world=null
	if is_instance_valid(hud):hud.queue_free()
	if not is_instance_valid(backdrop):_menu_backdrop()
	clear_page();_scrim(content,0.74)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top",84);margin.add_theme_constant_override("margin_bottom",48)
	margin.add_theme_constant_override("margin_left",56);margin.add_theme_constant_override("margin_right",56)
	content.add_child(margin)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",0);margin.add_child(column)
	_centre(column,BWUI.Rule.new(22),460)
	var heading=BWUI.Heading.new("BLOODWAKE",74);heading.rules=false;heading.tracking=10.0;column.add_child(heading)
	body(column,"SURVIVE THE NIGHT. CLAIM THE DAWN.",13,BWKit.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var lead=Control.new();lead.custom_minimum_size.y=40;lead.size_flags_vertical=Control.SIZE_EXPAND_FILL
	lead.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(lead)
	# The row is the whole menu: one plate per destination, in the order a night is run.
	var row=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",16);column.add_child(row)
	for spec in [["PLAY","sword",show_classes],["BUILDS","helm",show_builds],["SKILL TREE","tree",show_skills],["ARMORY","anvil",show_armory],["SETTINGS","cog",show_settings],["EXIT","gate",_quit]]:
		var tile=BWUI.Tile.new(spec[0],spec[1]);row.add_child(tile)
		tile.pressed.connect(spec[2]);tile.pressed.connect(func():audio.ui("ui_click"))
		tile.mouse_entered.connect(func():audio.ui("ui_select"))
	var tail=Control.new();tail.custom_minimum_size.y=40;tail.size_flags_vertical=Control.SIZE_EXPAND_FILL
	tail.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(tail)
	var footer=VBoxContainer.new()
	footer.alignment=BoxContainer.ALIGNMENT_END;footer.add_theme_constant_override("separation",6);column.add_child(footer)
	_centre(footer,BWUI.Chip.new("drop","BLOOD ESSENCE   %d" % meta.essence),190)
	body(footer,"WASD  ·  MOUSE  ·  SPACE      /      CONTROLLER SUPPORTED",11,BWKit.DIM).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if not meta.last_error.is_empty():
		body(footer,meta.last_error,13,BWKit.EMBER).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func show_classes():
	page="classes"
	if not BWData.CLASSES.has(class_pick):class_pick=BWData.CLASSES.keys()[0]
	clear_page();_scrim(content,0.86)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top",34);margin.add_theme_constant_override("margin_bottom",26)
	margin.add_theme_constant_override("margin_left",58);margin.add_theme_constant_override("margin_right",58)
	content.add_child(margin)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",18);margin.add_child(column)
	column.add_child(BWUI.Heading.new("CHOOSE A CLASS",42))
	var row=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",14);column.add_child(row)
	for id in BWData.CLASSES:
		var card=BWUI.ClassCard.new(BWData.CLASSES[id].name.to_upper(),_plate(id),CLASS_MARKS.get(id,"rune"))
		card.selected=(id==class_pick);card.crop_top=0.0;row.add_child(card)
		card.chosen.connect(func():class_pick=id;audio.ui("ui_click");show_classes())
		card.mouse_entered.connect(func():audio.ui("ui_select"))
	var detail=HBoxContainer.new();detail.add_theme_constant_override("separation",16)
	detail.custom_minimum_size.y=318;detail.size_flags_vertical=Control.SIZE_SHRINK_CENTER;column.add_child(detail)
	_class_dossier(detail,class_pick)
	_class_kit(detail,class_pick)
	var slack=Control.new();slack.size_flags_vertical=Control.SIZE_EXPAND_FILL
	slack.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(slack)
	var actions=HBoxContainer.new();actions.alignment=BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation",18);column.add_child(actions)
	banner(actions,"BACK",show_menu,190)
	banner(actions,"SELECT CLASS",func():start_run(class_pick),320)

# Left of the split: who this class is, and its numbers as bars so the four can be
# compared without reading a single figure.
func _class_dossier(parent: Node,id: String):
	var data=BWData.CLASSES[id]
	var shell=_framed(parent,Vector2(430,0),false)
	var head=HBoxContainer.new();head.add_theme_constant_override("separation",12);shell.add_child(head)
	var mark=BWUI.Emblem.new(CLASS_MARKS.get(id,"rune"),40,BWKit.EMBER);head.add_child(mark)
	var titles=VBoxContainer.new();titles.add_theme_constant_override("separation",0)
	titles.size_flags_vertical=Control.SIZE_SHRINK_CENTER;head.add_child(titles)
	var name_line=BWUI.Heading.new(data.name.to_upper(),28);name_line.rules=false;name_line.align_left=true
	name_line.tracking=4.0;name_line.custom_minimum_size.y=34;titles.add_child(name_line)
	body(titles,data.tag,11,BWKit.EMBER,false)
	body(shell,data.get("blurb",""),14,BWKit.MUTED)
	shell.add_child(BWUI.Rule.new(16))
	var stats=BWData.stats(id);meta.apply_to(stats)
	for spec in [["DAMAGE","sword",stats.damage/3.6],["ATTACK SPEED","slashes",stats.attackSpeed/1.6],["SPEED","boot",stats.moveSpeed/380.0],["ARMOR","shield",stats.armor/0.45],["HEALTH","heart",stats.maxHp/170.0]]:
		shell.add_child(BWUI.Meter.new(spec[0],spec[1],spec[2],BWKit.EMBER))
	body(shell,"WEAPON   ·   %s" % BWData.entry("weapons",data.weapon).get("name","").to_upper(),11,BWKit.DIM,false)

# Right of the split: the full kit, laid out the way it is bound on the keyboard.
func _class_kit(parent: Node,id: String):
	var data=BWData.CLASSES[id]
	var shell=_framed(parent,Vector2(0,0),true)
	var row=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",26)
	row.size_flags_vertical=Control.SIZE_EXPAND_FILL;shell.add_child(row)
	var kit=[]
	var skills=BWData.skills(id)
	for i in skills.size():kit.append([["Q","E"][i] if i<2 else "",skills[i]])
	kit.append(["SPACE",data.ability])
	for i in kit.size():
		if i>0:
			var split=ColorRect.new();split.color=Color(BWKit.IRON,0.8);split.custom_minimum_size=Vector2(1,120)
			split.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(split)
		_kit_slot(row,kit[i][0],BWData.entry("abilities",kit[i][1]))

func _kit_slot(parent: Node,key: String,ability: Dictionary):
	if ability.is_empty():return
	var box=VBoxContainer.new();box.custom_minimum_size.x=196
	box.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation",6);parent.add_child(box)
	var cap=CenterContainer.new();cap.add_child(BWUI.KeyCap.new(key));box.add_child(cap)
	var badge=CenterContainer.new();badge.add_child(BWUI.Emblem.new(BWKit.ABILITY_GLYPHS.get(ability.id,"rune"),56,BWKit.EMBER));box.add_child(badge)
	var name_line=BWUI.Heading.new(ability.name.to_upper(),15);name_line.rules=false;name_line.tracking=2.0
	name_line.custom_minimum_size.y=22;box.add_child(name_line)
	var blurb=body(box,ability.get("description",""),11,BWKit.MUTED)
	blurb.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	body(box,"%d SECOND COOLDOWN" % int(ability.get("cooldown",0)),10,BWKit.DIM,false).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

# A drawn frame with a column inside it. Drawn rather than styleboxed so the corner
# ticks land on the panel edge whatever the panel ends up measuring.
func _framed(parent: Node,minimum: Vector2,expand: bool) -> VBoxContainer:
	var holder=Control.new();holder.custom_minimum_size=minimum
	holder.size_flags_vertical=Control.SIZE_EXPAND_FILL
	holder.size_flags_horizontal=Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_BEGIN
	parent.add_child(holder)
	var frame=BWUI.Frame.new();frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);holder.add_child(frame)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,20)
	holder.add_child(margin)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",8);margin.add_child(column)
	return column

func start_run(id: String):
	transition_serial+=1
	if is_instance_valid(backdrop):backdrop.queue_free();backdrop=null;menu_art=null
	if is_instance_valid(world):world.queue_free()
	run=BWRun.new(id,meta);world=BWWorld.new();add_child(world);world.start(run,quality,audio)
	world.wave_cleared.connect(_wave_complete);world.run_ended.connect(_death_transition)
	audio.duck(0.0);world.wave_music()
	page="playing";clear_page();_hud()

func _hud():
	if is_instance_valid(hud):hud.queue_free()
	hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(hud)
	var panel=PanelContainer.new();panel.position=Vector2(24,24);panel.custom_minimum_size=Vector2(370,130);hud.add_child(panel)
	var column=VBoxContainer.new();panel.add_child(column);hud_label=label(column,"",17)
	hp_bar=ProgressBar.new();hp_bar.show_percentage=false;hp_bar.custom_minimum_size.y=12;column.add_child(hp_bar)
	xp_bar=ProgressBar.new();xp_bar.show_percentage=false;xp_bar.custom_minimum_size.y=6
	var fill=StyleBoxFlat.new();fill.bg_color=Color("769db8");xp_bar.add_theme_stylebox_override("fill",fill);column.add_child(xp_bar)
	skill_label=Label.new();skill_label.position=Vector2(24,185);skill_label.add_theme_font_size_override("font_size",14);hud.add_child(skill_label)
	boss_label=Label.new();boss_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);boss_label.offset_top=12;boss_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;boss_label.add_theme_color_override("font_color",Color("dc8271"));hud.add_child(boss_label)
	var pause=Button.new();pause.text="II";pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);pause.position=Vector2(-76,24);pause.size=Vector2(50,48);pause.pressed.connect(show_pause);hud.add_child(pause)
	touch=BWTouch.new();hud.add_child(touch);touch.enabled=mobile_controls;touch.visible=mobile_controls;touch.ability_pressed.connect(world.ability)
	touch.auto_fire_toggled.connect(func():world.auto_fire=touch.auto_fire_on)

func freeze():
	if is_instance_valid(world):world.process_mode=Node.PROCESS_MODE_DISABLED
	if is_instance_valid(hud):hud.visible=false
	audio.duck(-9.0)

func resume():
	clear_page();page="playing";world.process_mode=Node.PROCESS_MODE_INHERIT;hud.visible=true
	audio.duck(0.0)
	if is_instance_valid(touch):touch.movement=Vector2.ZERO;touch.finger=-1

func show_pause():
	if page!="playing":return
	freeze();page="pause";var column=panel_page("THE NIGHT WAITS","Wave %d · %d kills" % [run.wave,run.kills])
	button(column,"RESUME",resume)
	button(column,"RETURN TO MENU (END RUN)",func():_award();show_menu())
	label(column,"WASD / LEFT STICK — Move\nLeft click / RT — Aim and fire\nSpace / A — Class ultimate\nHold right click + left click — Spin attack (warrior)\nQ / X — First class skill (aimed at the cursor)\nE / B — Second class skill (aimed at the cursor)\nTab / Y — Toggle automatic fire\nEscape / Start — Pause\nMouse wheel — Zoom\nF11 — Fullscreen",18,MUTED)

func _transition_screen(heading: String,subtitle: String,color: Color):
	clear_page()
	if is_instance_valid(hud):hud.visible=false
	var dim=ColorRect.new();dim.color=Color(0.015,0.02,0.035,0.48);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.add_child(dim)
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.add_child(center)
	var band=PanelContainer.new();band.custom_minimum_size=Vector2(660,180)
	var style=StyleBoxFlat.new();style.bg_color=Color(0.025,0.02,0.03,0.82);style.border_color=color.darkened(0.45);style.border_width_top=1;style.border_width_bottom=1;style.set_content_margin_all(28);band.add_theme_stylebox_override("panel",style);center.add_child(band)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",14);band.add_child(column)
	var heading_label=title(column,heading,58);heading_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;heading_label.add_theme_color_override("font_color",color)
	var detail=label(column,subtitle,17,MUTED);detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	content.modulate.a=0.0;create_tween().tween_property(content,"modulate:a",1.0,0.18)

func _wave_complete():
	if page!="playing":return
	var serial=transition_serial;var completed_world=world
	page="wave_complete";world.running=false
	_transition_screen("WAVE CLEARED","WAVE %02d  ·  %d KILLS" % [run.wave,run.kills],GOLD)
	audio.play("wave_clear");audio.duck(-9.0)
	await get_tree().create_timer(WAVE_TRANSITION_SECONDS).timeout
	if serial!=transition_serial or world!=completed_world or page!="wave_complete":return
	_intermission()

func _death_transition():
	if page!="playing":return
	var serial=transition_serial;var completed_world=world
	page="death_animation";world.running=false
	clear_page()
	if is_instance_valid(hud):hud.visible=false
	# The death sound already started in BWWorld; keep the body fully visible first.
	await get_tree().create_timer(DEATH_ANIMATION_SECONDS).timeout
	if serial!=transition_serial or world!=completed_world or page!="death_animation":return
	page="death_transition"
	_transition_screen("YOU DIED","THE NIGHT CLAIMED YOU",Color("c64349"))
	await get_tree().create_timer(DEATH_TRANSITION_SECONDS).timeout
	if serial!=transition_serial or world!=completed_world or page!="death_transition":return
	show_game_over()

func _intermission():
	freeze();boss_reward=run.wave%10==0;refreshes=0;_next_pick()

func _next_pick():
	choosing_boss=false
	if run.pending_levels>0:
		choices=run.offers("upgrades");rerolls=0
		if choices.is_empty():run.pending_levels=0;_next_pick();return
		_upgrades()
	elif boss_reward:
		choices=run.offers("upgrades",true);choosing_boss=true
		if choices.is_empty():boss_reward=false;_shop(true);return
		_upgrades()
	else:_shop(true)

func _upgrades():
	page="upgrades";var column=panel_page("BOSS SPOILS" if choosing_boss else "GROW STRONGER","Wave %d cleared · %d pending level choices" % [run.wave,run.pending_levels])
	for row in choices:
		var panel=PanelContainer.new();column.add_child(panel);var box=VBoxContainer.new();panel.add_child(box)
		title(box,row.name,24);label(box,row.description,18);label(box,"%s · %d / %d" % [row.rarity.to_upper(),run.upgrades.get(row.id,0),row.maxLevel],14,MUTED)
		button(box,"CLAIM",func():
			if run.apply_upgrade(row.id):
				audio.play("upgrade_pick")
				if choosing_boss:boss_reward=false
				else:run.pending_levels-=1
				_next_pick())
	button(column,"REROLL (FREE)",func():rerolls+=1;choices=run.offers("upgrades");_upgrades(),choosing_boss or rerolls>=1)

func _shop(new_offers: bool=false):
	if new_offers:shop_offers=run.offers("items")
	page="shop";var column=panel_page("THE NIGHT MERCHANT","%d gold · %d / 8 items · Wave %d survived" % [run.gold,run.items.size(),run.wave])
	for item in shop_offers:
		var panel=PanelContainer.new();column.add_child(panel);var box=VBoxContainer.new();panel.add_child(box)
		title(box,item.name,24);label(box,item.description,18);label(box,item.rarity.to_upper(),14,MUTED)
		button(box,"BUY — %d GOLD" % item.cost,func():
			if run.buy_item(item.id):audio.play("purchase");_shop(),run.gold<item.cost or run.items.has(item.id) or run.items.size()>=8)
	if shop_offers.is_empty():label(column,"No further equipment is available for this build.",18,MUTED)
	button(column,"REFRESH — 20 GOLD (%d / 3)" % refreshes,func():run.gold-=20;refreshes+=1;_shop(true),refreshes>=3 or run.gold<20)
	button(column,"ENTER WAVE %d" % (run.wave+1),func():world.next_wave();resume())

func _award():
	if run!=null and not run.awarded:run.awarded=true;return meta.award(run.wave,run.kills)
	return 0

func show_game_over():
	if run==null:return
	var reward=_award();freeze();page="gameover"
	var column=panel_page("YOUR OATH ENDURES","The night claimed you. Your strength remains.")
	title(column,"WAVE %d   ·   %d KILLS" % [run.wave,run.kills],30)
	label(column,"+%d ESSENCE   /   %d TOTAL" % [reward,meta.essence],24,GOLD)
	button(column,"TRY AGAIN",func():start_run(run.class_id))
	button(column,"RETURN TO SANCTUARY",show_menu)

func show_skills():
	page="skills"
	var rows=BWData.rows("skills")
	if BWData.entry("skills",skill_pick).is_empty() and not rows.is_empty():skill_pick=rows[0].id
	clear_page();_scrim(content,0.95)
	var view=get_viewport().get_visible_rect().size
	var heading=BWUI.Heading.new("BLOODWAKE  -  SKILL TREE",34)
	heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);heading.offset_top=26;content.add_child(heading)
	var chips=VBoxContainer.new();chips.add_theme_constant_override("separation",8)
	chips.position=Vector2(view.x-232,26);chips.size=Vector2(200,70);content.add_child(chips)
	chips.add_child(BWUI.Chip.new("drop","BLOOD ESSENCE   %d" % meta.essence))
	chips.add_child(BWUI.Chip.new("coin","RANKS SPENT   %d / 45" % _ranks_spent()))
	_skill_tree(view)
	_oath_panel(view)
	_node_panel(view)
	var back=banner(content,"BACK",show_menu,200)
	back.position=Vector2(view.x-248,view.y-84)
	back.size=Vector2(200,46)

func _ranks_spent() -> int:
	var total=0
	for node in BWData.rows("skills"):total+=int(meta.levels.get(node.id,0))
	return total

# The tree is laid out radially: the origin in the middle, one arm per branch, and
# each arm fanning out as it goes. The x radius is stretched because the screen is.
func _skill_tree(view: Vector2):
	var hub=Vector2(view.x*0.5,view.y*0.53)
	var axes={"offense":-90.0,"defense":28.0,"mobility":152.0}
	var placed={}
	var wires=BWUI.Wires.new();wires.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.add_child(wires)
	for branch in axes:
		var rows=[]
		for node in BWData.rows("skills"):
			if node.branch==branch:rows.append(node)
		var root={}
		for node in rows:
			if not node.has("requires"):root=node
		if root.is_empty():continue
		placed[root.id]=_polar(hub,axes[branch],128.0)
		wires.links.append([hub,placed[root.id],int(meta.levels.get(root.id,0))>0])
		var kids=[]
		for node in rows:
			if node.get("requires","")==root.id:kids.append(node)
		for i in kids.size():
			var offset=-32.0+64.0*i
			placed[kids[i].id]=_polar(hub,axes[branch]+offset,226.0)
			wires.links.append([placed[root.id],placed[kids[i].id],int(meta.levels.get(kids[i].id,0))>0])
			for node in rows:
				if node.get("requires","")!=kids[i].id:continue
				placed[node.id]=_polar(hub,axes[branch]+offset*1.55,316.0)
				wires.links.append([placed[kids[i].id],placed[node.id],int(meta.levels.get(node.id,0))>0])
	var orb=BWUI.Orb.new(132.0);orb.position=hub-Vector2(66,66);content.add_child(orb)
	for node in BWData.rows("skills"):
		if not placed.has(node.id):continue
		_tree_node(node,placed[node.id])

func _polar(hub: Vector2,degrees: float,radius: float) -> Vector2:
	var angle=deg_to_rad(degrees)
	return hub+Vector2(cos(angle)*radius,sin(angle)*radius)

func _tree_node(data: Dictionary,spot: Vector2):
	var level=int(meta.levels.get(data.id,0))
	var node=BWUI.SkillNode.new(BWKit.SKILL_GLYPHS.get(data.id,"rune"),62.0)
	node.level=level
	node.caption=data.name.to_upper()
	node.selected=(data.id==skill_pick)
	if level>=3:node.state="maxed"
	elif level>0:node.state="owned"
	elif not data.has("requires") or int(meta.levels.get(data.requires,0))>0:node.state="ready"
	else:node.state="locked"
	node.size=Vector2(96,80)
	node.position=spot-Vector2(48,40)
	content.add_child(node)
	node.chosen.connect(func():skill_pick=data.id;audio.ui("ui_click");show_skills())
	node.mouse_entered.connect(func():audio.ui("ui_select"))

# The tree is shared by every class, so the left panel reports the oath itself:
# how far each branch has been taken, and what it is worth.
func _oath_panel(view: Vector2):
	var holder=Control.new();holder.position=Vector2(26,view.y*0.5-170);holder.size=Vector2(252,340)
	content.add_child(holder)
	var frame=BWUI.Frame.new();frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);holder.add_child(frame)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
	holder.add_child(margin)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",8);margin.add_child(column)
	var head=BWUI.Heading.new("THE OATH",20);head.rules=false;head.tracking=4.0;head.custom_minimum_size.y=28
	column.add_child(head)
	body(column,"Permanent. Paid in essence. Three ranks to a node.",11,BWKit.DIM)
	column.add_child(BWUI.Rule.new(14))
	for spec in [["OFFENSE","sword","offense"],["DEFENSE","shield","defense"],["MOBILITY","boot","mobility"]]:
		var taken=0
		for node in BWData.rows("skills"):
			if node.branch==spec[2]:taken+=int(meta.levels.get(node.id,0))
		var meter=BWUI.Meter.new(spec[0],spec[1],taken/15.0,BWKit.EMBER)
		meter.custom_minimum_size.y=22;column.add_child(meter)
	column.add_child(BWUI.Rule.new(14))
	var stats=BWData.stats("warrior")
	var base=BWData.stats("warrior")
	meta.apply_to(stats)
	for spec in [["DAMAGE",(stats.damage/base.damage-1.0)*100.0,"%+.0f%%"],["MAX HP",stats.maxHp-base.maxHp,"%+.0f"],["CRIT",(stats.criticalChance-base.criticalChance)*100.0,"%+.1f%%"],["SPEED",stats.moveSpeed-base.moveSpeed,"%+.0f"]]:
		var line=HBoxContainer.new();column.add_child(line)
		body(line,spec[0],11,BWKit.MUTED,false).custom_minimum_size.x=140
		var read=body(line,spec[2] % spec[1],11,BWKit.GOLD if spec[1]>0 else BWKit.DIM,false)
		read.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		read.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT

# The right panel is the selected node, and the only place essence is ever spent.
func _node_panel(view: Vector2):
	var data=BWData.entry("skills",skill_pick)
	if data.is_empty():return
	var level=int(meta.levels.get(data.id,0))
	var holder=Control.new();holder.position=Vector2(view.x-278,view.y*0.5-170);holder.size=Vector2(252,340)
	content.add_child(holder)
	var frame=BWUI.Frame.new();frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);holder.add_child(frame)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
	holder.add_child(margin)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",10);margin.add_child(column)
	var badge=CenterContainer.new();badge.add_child(BWUI.Emblem.new(BWKit.SKILL_GLYPHS.get(data.id,"rune"),64,BWKit.EMBER))
	column.add_child(badge)
	var name_line=BWUI.Heading.new(data.name.to_upper(),19);name_line.rules=false;name_line.tracking=3.0
	name_line.custom_minimum_size.y=26;column.add_child(name_line)
	body(column,data.description,12,BWKit.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(BWUI.Rule.new(12))
	var ranks=HBoxContainer.new();ranks.alignment=BoxContainer.ALIGNMENT_CENTER;column.add_child(ranks)
	body(ranks,"RANK %d / 3" % level,12,BWKit.INK,false)
	var cost=data.baseCost*(level+1)
	var blocked=data.has("requires") and int(meta.levels.get(data.requires,0))==0
	var note="MAXED" if level>=3 else ("REQUIRES %s" % BWData.entry("skills",data.requires).get("name","").to_upper() if blocked else "%d BLOOD ESSENCE" % cost)
	var tone=BWKit.GOLD if level>=3 else (BWKit.EMBER if blocked or meta.essence<cost else BWKit.INK)
	body(column,note,12,tone,false).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var slot=Control.new();slot.custom_minimum_size.y=52;slot.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(slot)
	var affordable=meta.can_buy_skill(data)
	var action=banner(slot,"UPGRADE",func():meta.buy_skill(data.id);show_skills(),228,not affordable)
	action.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	action.offset_top=-46;action.offset_left=0;action.offset_right=0

func show_armory():
	page="armory";var column=panel_page("THE ARMORY","%d Essence · Equipment persists between runs" % meta.essence)
	for slot in ["armor","boots","charm"]:
		title(column,slot.to_upper(),24)
		for item in BWData.rows("equipment"):
			if item.slot!=slot:continue
			button(column,"%s · %s · %s" % [item.name,item.description,"OWNED" if meta.owned.has(item.id) else "%d ESSENCE" % item.cost],func():meta.buy_equipment(item.id);show_armory(),meta.owned.has(item.id) or meta.essence<item.cost)
	button(column,"EDIT LOADOUTS",show_builds);button(column,"BACK",show_menu)

func show_builds():
	page="builds";var column=panel_page("YOUR BUILDS","Selected equipment applies when the next run begins.")
	var row=HBoxContainer.new();column.add_child(row)
	for i in 3:button(row,"BUILD %d%s" % [i+1," · ACTIVE" if meta.active==i else ""],func():meta.active=i;meta.save();show_builds())
	for slot in ["armor","boots","charm"]:
		title(column,slot.to_upper(),24)
		var current=meta.loadouts[meta.active].get(slot,"");label(column,"Equipped: "+(BWData.entry("equipment",current).get("name","None")),18)
		button(column,"UNEQUIP",func():meta.equip(slot,"");show_builds(),current.is_empty())
		for id in meta.owned:
			var item=BWData.entry("equipment",id)
			if item.slot==slot:button(column,item.name+" — "+item.description,func():meta.equip(slot,id);show_builds(),current==id)
	button(column,"BACK",show_menu)

func show_settings():
	page="settings";var column=panel_page("SETTINGS","Graphics changes apply to the next run.")
	button(column,"GRAPHICS: "+quality,func():quality="Mobile" if quality=="PC" else "PC";_save_settings();show_settings())
	label(column,"PC: shadows and arena lights. Mobile: reduced lighting and damage text.",16,MUTED)
	button(column,"TOUCH CONTROLS: "+("ON" if mobile_controls else "OFF"),func():mobile_controls=not mobile_controls;show_settings())
	label(column,"MASTER VOLUME",18)
	var slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=0.05;slider.value=volume;slider.custom_minimum_size=Vector2(350,36);column.add_child(slider)
	slider.value_changed.connect(func(value):volume=value;AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value,0.001)));_save_settings())
	button(column,"TOGGLE FULLSCREEN",func():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	button(column,"IMPORT FLUTTER PROGRESSION JSON",_import_save)
	label(column,"Save location: "+ProjectSettings.globalize_path(meta.path),14,MUTED)
	button(column,"BACK",show_menu)

func _quit():
	# One frame between dropping the stream and quitting lets the audio server
	# release the Ogg playback, which otherwise reports as a leak at cleanup.
	audio.shutdown()
	await get_tree().process_frame
	get_tree().quit()

func _save_settings():
	cfg.set_value("graphics","profile",quality);cfg.set_value("audio","volume",volume);cfg.save("user://settings.cfg")

func _import_save():
	var dialog=FileDialog.new();dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.filters=PackedStringArray(["*.json ; Bloodwake progression"]);dialog.title="Import progression (replaces current progression)";root.add_child(dialog)
	dialog.file_selected.connect(func(path):
		var confirmation=ConfirmationDialog.new();confirmation.dialog_text="Replace current progression with this save?";root.add_child(confirmation)
		confirmation.confirmed.connect(func():
			if meta.import_json(FileAccess.get_file_as_string(path)):meta.save();show_settings()
			confirmation.queue_free())
		confirmation.popup_centered();dialog.queue_free())
	dialog.popup_centered_ratio(0.7)

func show_debug():
	freeze();page="debug";var column=panel_page("PLAYTEST TOOLS","Debug builds only")
	button(column,"HEAL",func():run.stats.hp=run.stats.maxHp;resume())
	button(column,"GRANT 500 GOLD",func():run.gold+=500;resume())
	button(column,"GAIN 5 LEVEL CHOICES",func():run.pending_levels+=5;boss_reward=false;_next_pick())
	for wave in [1,5,6,10,20]:button(column,"START WAVE %d" % wave,func():
		for enemy in world.enemies:enemy.node.queue_free()
		world.enemies.clear();run.wave=wave;world.spawned=0;world.spawn_timer=0;world.running=true;run.stats.hp=run.stats.maxHp;resume())
	# Animation pacing is the kind of thing that can only be judged by feel, so it is
	# dialled here rather than by rebuilding.
	for spec in [["COMBO PACE",0],["SPIN PACE",1]]:
		var label=spec[0]
		var which=int(spec[1])
		var value=BWWorld.combo_pace if which==0 else BWWorld.spin_pace
		button(column,"%s: %.2fx  (tap to cycle)" % [label,value],func():
			var steps=[1.0,1.25,1.5,1.75,2.0,2.5]
			var current=BWWorld.combo_pace if which==0 else BWWorld.spin_pace
			var next=steps[(steps.find(snappedf(current,0.01))+1)%steps.size()]
			if which==0:BWWorld.combo_pace=next
			else:BWWorld.spin_pace=next
			show_debug())
	button(column,"RESUME",resume)

func _smoke():
	start_run("gunslinger")
	world.spawn_enemy("tank",Vector3(2,0,1))
	world.spawn_enemy("archer",Vector3(-4,0,-2))
	await get_tree().create_timer(3).timeout
	world.ability()
	await get_tree().create_timer(3).timeout
	print("BLOODWAKE_SMOKE_OK wave=",run.wave," enemies=",world.enemies.size()," kills=",run.kills)
	if DisplayServer.get_name()!="headless":
		var image=get_viewport().get_texture().get_image();image.save_png("user://smoke.png")
	show_menu()
	await get_tree().create_timer(3.0).timeout
	_quit()

# The three menu screens, captured without starting a run. Used to review layout
# changes against the design plates.
func _menu_shots():
	await get_tree().create_timer(0.8).timeout
	await _capture("shot_menu")
	show_classes();await get_tree().create_timer(0.5).timeout;await _capture("shot_classes")
	show_skills();await get_tree().create_timer(0.5).timeout;await _capture("shot_skills")
	show_armory();await get_tree().create_timer(0.4).timeout;await _capture("shot_armory")
	show_settings();await get_tree().create_timer(0.4).timeout;await _capture("shot_settings")
	print("BLOODWAKE_MENU_SHOTS_DONE")
	_quit()

# Walks the map and photographs each district, which is the only way to judge
# lighting and prop density.
func _arena_shots():
	start_run("warrior")
	world.auto_fire=false
	await get_tree().create_timer(0.6).timeout
	for zone in BWArena.ZONES:
		world.player.position=Vector3(zone.at.x,0,zone.at.y)
		world.run.wave=BWArena.ZONES.find(zone)+1
		await get_tree().create_timer(0.9).timeout
		await _capture("zone_"+zone.id)
	print("BLOODWAKE_ARENA_SHOTS_DONE")
	_quit()

func _capture(filename: String):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://"+filename+".png")

func _visual_qa():
	await get_tree().create_timer(1).timeout
	await _capture("menu")
	show_classes();await get_tree().create_timer(0.4).timeout;await _capture("classes")
	start_run("gunslinger");world.spawned=999;world.rest_time=999;world.auto_fire=false
	for action in ["move_up","move_right","move_down","move_left"]:
		Input.action_press(action);await get_tree().create_timer(0.7).timeout
		await _capture(action);Input.action_release(action)
	world.spawn_enemy("boss",world.player.position+Vector3(4,0,-2))
	world.spawn_enemy("healer",world.player.position+Vector3(-3,0,1))
	await get_tree().create_timer(0.5).timeout;await _capture("boss")
	show_pause();await get_tree().create_timer(0.3).timeout;await _capture("pause")
	world.running=false;run.pending_levels=1;_intermission();await get_tree().create_timer(0.3).timeout;await _capture("upgrades")
	run.pending_levels=0;boss_reward=false;_next_pick();await get_tree().create_timer(0.3).timeout;await _capture("shop")
	show_menu();show_skills();await get_tree().create_timer(0.3).timeout;await _capture("skills")
	print("BLOODWAKE_VISUAL_QA_COMPLETE")
	_quit()
