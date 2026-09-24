extends Node

var world: BWWorld
var run: BWRun
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
const GOLD=Color("d7ae64")
const MUTED=Color("a2aab5")

func _ready():
 _inputs();BWData.load_catalogs();meta.load_save()
 if cfg.load("user://settings.cfg")==OK:
  quality=cfg.get_value("graphics","profile","PC");volume=cfg.get_value("audio","volume",0.65)
 mobile_controls=OS.has_feature("mobile")
 if mobile_controls:quality="Mobile"
 AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.001)))
 canvas=CanvasLayer.new();add_child(canvas)
 root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.add_child(root)
 root.theme=_theme()
 _menu_backdrop();show_menu()
 if "--smoke" in OS.get_cmdline_user_args():
  smoke_mode=true;_smoke()
 elif "--qa" in OS.get_cmdline_user_args():
  _visual_qa()

func _theme() -> Theme:
 var theme=Theme.new();theme.default_font_size=18
 theme.set_color("font_color","Label",Color("ece3d2"))
 var normal=StyleBoxFlat.new();normal.bg_color=Color("18212c");normal.border_color=Color("46505e");normal.set_border_width_all(1);normal.set_corner_radius_all(5);normal.content_margin_left=20;normal.content_margin_right=20;normal.content_margin_top=14;normal.content_margin_bottom=14
 var hover=normal.duplicate();hover.bg_color=Color("293440");hover.border_color=GOLD
 var pressed=normal.duplicate();pressed.bg_color=Color("473a2b");pressed.border_color=GOLD
 var disabled=normal.duplicate();disabled.bg_color=Color("111820");disabled.border_color=Color("28313d")
 theme.set_stylebox("normal","Button",normal);theme.set_stylebox("hover","Button",hover);theme.set_stylebox("pressed","Button",pressed);theme.set_stylebox("focus","Button",hover);theme.set_stylebox("disabled","Button",disabled)
 theme.set_color("font_color","Button",Color("ece3d2"));theme.set_color("font_disabled_color","Button",Color("657080"))
 var panel=StyleBoxFlat.new();panel.bg_color=Color(0.04,0.06,0.085,0.95);panel.border_color=Color("3f4854");panel.set_border_width_all(1);panel.set_corner_radius_all(8);panel.set_content_margin_all(24);theme.set_stylebox("panel","PanelContainer",panel)
 var bar=StyleBoxFlat.new();bar.bg_color=Color("202c37");bar.set_corner_radius_all(3);theme.set_stylebox("background","ProgressBar",bar)
 var fill=StyleBoxFlat.new();fill.bg_color=Color("b54c4b");fill.set_corner_radius_all(3);theme.set_stylebox("fill","ProgressBar",fill)
 return theme

func _inputs():
 var keys={"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"ability":[KEY_SPACE,KEY_E],"pause":[KEY_ESCAPE],"auto_fire":[KEY_TAB],"fullscreen":[KEY_F11],"debug":[KEY_F3]}
 for action in keys:
  if not InputMap.has_action(action):InputMap.add_action(action)
  for key in keys[action]:
   var event=InputEventKey.new();event.physical_keycode=key;InputMap.action_add_event(action,event)
 for action in ["fire","aim_left","aim_right","aim_up","aim_down"]:
  if not InputMap.has_action(action):InputMap.add_action(action,0.2)
 for spec in [["fire",MOUSE_BUTTON_LEFT],["ability",MOUSE_BUTTON_RIGHT]]:
  var event=InputEventMouseButton.new();event.button_index=spec[1];InputMap.action_add_event(spec[0],event)
 for spec in [["move_left",JOY_AXIS_LEFT_X,-1],["move_right",JOY_AXIS_LEFT_X,1],["move_up",JOY_AXIS_LEFT_Y,-1],["move_down",JOY_AXIS_LEFT_Y,1],["aim_left",JOY_AXIS_RIGHT_X,-1],["aim_right",JOY_AXIS_RIGHT_X,1],["aim_up",JOY_AXIS_RIGHT_Y,-1],["aim_down",JOY_AXIS_RIGHT_Y,1],["fire",JOY_AXIS_TRIGGER_RIGHT,1]]:
  var event=InputEventJoypadMotion.new();event.axis=spec[1];event.axis_value=spec[2];InputMap.action_add_event(spec[0],event)
 for spec in [["ability",JOY_BUTTON_A],["pause",JOY_BUTTON_START],["auto_fire",JOY_BUTTON_Y]]:
  var event=InputEventJoypadButton.new();event.button_index=spec[1];InputMap.action_add_event(spec[0],event)

func _menu_backdrop():
 backdrop=Node3D.new();add_child(backdrop)
 var camera=Camera3D.new();camera.position=Vector3(0,2.2,5.8);backdrop.add_child(camera);camera.look_at(Vector3(0,1,0));camera.current=true
 var env=WorldEnvironment.new();var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("0b1019");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("8596b1");environment.ambient_light_energy=0.55;env.environment=environment;backdrop.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-35,0);light.light_energy=1.5;backdrop.add_child(light)
 menu_art=BWVisual.new();backdrop.add_child(menu_art);menu_art.position.x=1.3;menu_art.configure("gunslinger",false,Color.WHITE,2.7)

func _process(dt):
 if is_instance_valid(menu_art):menu_art.rotation.y+=dt*0.12;menu_art.tick(dt,false)
 if is_instance_valid(world) and page=="playing":
  if is_instance_valid(touch):world.move_input=touch.movement
  hp_bar.max_value=run.stats.maxHp;hp_bar.value=run.stats.hp
  xp_bar.max_value=20+(run.level-1)*15;xp_bar.value=run.xp
  hud_label.text="WAVE %02d     ·     LV %d\n%d / %d HP     ·     %d GOLD     ·     %d KILLS" % [run.wave,run.level,ceili(run.stats.hp),int(run.stats.maxHp),run.gold,run.kills]
  skill_label.text="%s  ·  %s\nAUTO FIRE %s  [TAB]     ·     PAUSE [ESC]" % [BWData.entry("abilities",BWData.CLASSES[run.class_id].ability).name,"READY [SPACE / RMB]" if run.ability_cd<=0 else "%.1fs" % run.ability_cd,"ON" if world.auto_fire else "OFF"]
  boss_label.text=""
  for enemy in world.enemies:
   if enemy.id=="boss":boss_label.text="THE BLOOD WARDEN   ·   PHASE %d   ·   %d / %d" % [enemy.phase,ceili(enemy.hp),int(enemy.maxHp)]
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
 if event.is_action_pressed("auto_fire"):world.auto_fire=not world.auto_fire
 if event.is_action_pressed("debug") and OS.is_debug_build():show_debug()

func clear_page():
 if is_instance_valid(content):content.queue_free()
 content=Control.new();content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(content)

func label(parent: Node,text: String,size: int=18,color: Color=Color("ece3d2")) -> Label:
 var node=Label.new();node.text=text;node.add_theme_font_size_override("font_size",size);node.add_theme_color_override("font_color",color);parent.add_child(node);return node

func title(parent: Node,text: String,size: int=38):
 var node=label(parent,text,size,GOLD);node.add_theme_font_override("font",load("res://assets/art/title.ttf"));return node

func button(parent: Node,text: String,callback: Callable,disabled: bool=false) -> Button:
 var node=Button.new();node.text=text;node.custom_minimum_size=Vector2(0,48);node.disabled=disabled;node.pressed.connect(callback);parent.add_child(node);return node

func panel_page(heading: String,subtext: String="") -> VBoxContainer:
 clear_page()
 var dim=ColorRect.new();dim.color=Color(0.025,0.035,0.05,0.9);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.add_child(dim)
 var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,28)
 content.add_child(margin)
 var scroll=ScrollContainer.new();margin.add_child(scroll)
 var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",16);scroll.add_child(column)
 title(column,heading);if not subtext.is_empty():label(column,subtext,16,MUTED)
 return column

func show_menu():
 page="menu"
 if is_instance_valid(world):world.queue_free();world=null
 if is_instance_valid(hud):hud.queue_free()
 if not is_instance_valid(backdrop):_menu_backdrop()
 clear_page()
 var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);margin.add_theme_constant_override("margin_left",72);margin.add_theme_constant_override("margin_top",70);margin.add_theme_constant_override("margin_bottom",32);content.add_child(margin)
 var column=VBoxContainer.new();column.custom_minimum_size.x=380;column.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;column.add_theme_constant_override("separation",12);margin.add_child(column)
 label(column,"A BLOOD OATH. AN ENDLESS NIGHT.",14,MUTED);title(column,"BLOODWAKE",58)
 label(column,"SURVIVE THE NIGHT. CLAIM THE DAWN.",14,MUTED)
 var spacer=Control.new();spacer.custom_minimum_size.y=24;column.add_child(spacer)
 button(column,"BEGIN RUN",show_classes)
 button(column,"SKILL TREE   ·   %d ESSENCE" % meta.essence,show_skills)
 button(column,"ARMORY",show_armory)
 button(column,"BUILDS / LOADOUTS",show_builds)
 button(column,"SETTINGS",show_settings)
 button(column,"QUIT",func():get_tree().quit())
 label(column,"PC: WASD · MOUSE · SPACE     /     CONTROLLER SUPPORTED",12,MUTED)
 if not meta.last_error.is_empty():label(column,meta.last_error,14,Color("e77c70"))

func show_classes():
 page="classes";var column=panel_page("CHOOSE YOUR OATH","Four paths into the same darkness. Build %d equipped." % (meta.active+1))
 var grid=GridContainer.new();grid.columns=2 if get_viewport().get_visible_rect().size.x>850 else 1;grid.add_theme_constant_override("h_separation",18);grid.add_theme_constant_override("v_separation",18);column.add_child(grid)
 for id in BWData.CLASSES:
  var data=BWData.CLASSES[id];var panel=PanelContainer.new();panel.custom_minimum_size=Vector2(450,190);panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(panel)
  var box=VBoxContainer.new();box.add_theme_constant_override("separation",12);panel.add_child(box)
  title(box,data.name,30);label(box,data.tag,14,Color(data.color))
  var stats=BWData.stats(id);meta.apply_to(stats)
  label(box,"%d HP  ·  %d SPEED  ·  %d%% ARMOR" % [stats.maxHp,stats.moveSpeed,stats.armor*100],16)
  label(box,BWData.entry("weapons",data.weapon).name+"  /  "+BWData.entry("abilities",data.ability).name,16,MUTED)
  button(box,"ENTER AS "+data.name.to_upper(),func():start_run(id))
 button(column,"BACK",show_menu)

func start_run(id: String):
 if is_instance_valid(backdrop):backdrop.queue_free();backdrop=null;menu_art=null
 if is_instance_valid(world):world.queue_free()
 run=BWRun.new(id,meta);world=BWWorld.new();add_child(world);world.start(run,quality)
 world.wave_cleared.connect(_intermission);world.run_ended.connect(show_game_over)
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

func freeze():
 if is_instance_valid(world):world.process_mode=Node.PROCESS_MODE_DISABLED
 if is_instance_valid(hud):hud.visible=false

func resume():
 clear_page();page="playing";world.process_mode=Node.PROCESS_MODE_INHERIT;hud.visible=true
 if is_instance_valid(touch):touch.movement=Vector2.ZERO;touch.finger=-1

func show_pause():
 if page!="playing":return
 freeze();page="pause";var column=panel_page("THE NIGHT WAITS","Wave %d · %d kills" % [run.wave,run.kills])
 button(column,"RESUME",resume)
 button(column,"RETURN TO MENU (END RUN)",func():_award();show_menu())
 label(column,"WASD / LEFT STICK — Move\nLeft click / RT — Aim and fire\nSpace / Right click / A — Class ability\nTab / Y — Toggle automatic fire\nEscape / Start — Pause\nMouse wheel — Zoom\nF11 — Fullscreen",18,MUTED)

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
    world.sound("upgrade_pick")
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
   if run.buy_item(item.id):world.sound("purchase");_shop(),run.gold<item.cost or run.items.has(item.id) or run.items.size()>=8)
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
 page="skills";var column=panel_page("THE BLOOD OATH","%d Essence · Permanent improvements · Three levels per node" % meta.essence)
 var grid=GridContainer.new();grid.columns=3 if get_viewport().get_visible_rect().size.x>1000 else 1;grid.add_theme_constant_override("h_separation",16);column.add_child(grid)
 for branch in ["offense","defense","mobility"]:
  var box=VBoxContainer.new();box.custom_minimum_size.x=330;box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",10);grid.add_child(box);title(box,branch.to_upper(),24)
  for node in BWData.rows("skills"):
   if node.branch!=branch:continue
   var level=int(meta.levels.get(node.id,0))
   button(box,"%s  %d/3\n%s\n%d Essence%s" % [node.name,level,node.description,node.baseCost*(level+1)," · Requires "+node.get("requires","") if node.has("requires") else ""],func():meta.buy_skill(node.id);show_skills(),not meta.can_buy_skill(node))
 button(column,"BACK",show_menu)

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
 get_tree().quit()

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
 get_tree().quit()
