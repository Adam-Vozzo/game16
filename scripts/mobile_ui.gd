extends Control
## Phone HUD uses CSS-sized logical pixels; pointer IDs allow simultaneous holds.
var game: Node3D
var host: Control
var pointers: Dictionary = {}
var zones: Dictionary = {}
var menu: Control
var pause_button: Button
var values: Dictionary = {}
var buttons: Dictionary = {}
var rebuilding := false
var dock_style: StyleBoxFlat
var control_styles: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	get_window().focus_exited.connect(release_all)
	dock_style=host._style(Color("111f35"),Color("31464b"))
	for key in ["left","right","lower","raise","toss"]:
		var color: Color=host.ACCENT if key=="toss" else Color("20363c")
		control_styles[key]=[host._style(color,Color("547680")),host._style(color.lightened(0.18),Color("547680"))]
	sync_screen()

func release_all() -> void: pointers.clear()

func dock_height() -> float:
	return (160.0 if size.x<600 else 112.0)+game.mobile_safe_bottom

func layout_zones() -> void:
	zones.clear()
	var gap := 8.0
	var w := size.x
	var y := size.y-dock_height()+30
	if w<600:
		var cell := (w-40)/4.0
		for i in 4: zones[["left","right","lower","raise"][i]]=Rect2(8+i*(cell+gap),y,cell,54)
		zones.toss=Rect2(8,y+62,w-16,54)
	else:
		var cell := (w-64)/6.0
		for i in 4: zones[["left","right","lower","raise"][i]]=Rect2(16+i*(cell+gap),y,cell,58)
		zones.toss=Rect2(16+4*(cell+gap),y,cell*2+gap,58)

func action_at(point: Vector2) -> String:
	for key in zones:
		if zones[key].has_point(point): return key
	return ""

func pointer_down(id: int,point: Vector2) -> bool:
	if not visible or game.paused: return false
	var action := action_at(point)
	if action.is_empty(): return false
	pointers[id]=action
	return true

func pointer_up(id: int,point: Vector2,canceled: bool=false) -> bool:
	if not pointers.has(id): return false
	var action: String=pointers[id]
	pointers.erase(id)
	if not canceled and action=="toss" and action_at(point)=="toss" and not game.paused: game.toss()
	return true

func _input(event: InputEvent) -> void:
	if not visible or game.paused: return
	var handled := false
	if event is InputEventScreenTouch:
		handled=pointer_down(event.index,event.position) if event.pressed else pointer_up(event.index,event.position,event.canceled)
	elif event is InputEventScreenDrag and pointers.has(event.index):
		if action_at(event.position)!=pointers[event.index]: pointers.erase(event.index)
		handled=true
	elif event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION and event.button_index==MOUSE_BUTTON_LEFT:
		handled=pointer_down(-100,event.position) if event.pressed else pointer_up(-100,event.position)
	elif event is InputEventMouseMotion and pointers.has(-100):
		if action_at(event.position)!=pointers[-100]: pointers.erase(-100)
		handled=true
	if handled: get_viewport().set_input_as_handled()

func apply_holds(delta: float) -> void:
	if game.paused or not visible: release_all(); return
	var held := pointers.values()
	var rotation := int("right" in held)-int("left" in held)
	var elevation := int("raise" in held)-int("lower" in held)
	if rotation: game.orbit(rotation*delta*deg_to_rad(game.rotation_speed))
	if elevation: game.adjust_elevation(elevation*delta*game.trajectory_speed)

func _process(_delta: float) -> void:
	if not visible: return
	queue_redraw()

func label(text: String,font_size: int=16,color: Color=Color("edf2ec")) -> Label:
	var node := Label.new()
	node.text=text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return node

func button(parent: Node,text: String,callback: Callable,primary: bool=false) -> Button:
	var node: Button=host._button(parent,text,Rect2(0,0,0,52),callback,primary,16)
	node.custom_minimum_size.y=52
	node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return node

func sync_screen() -> void:
	visible=game.mobile_mode
	release_all()
	if is_instance_valid(menu): menu.hide(); menu.queue_free()
	if is_instance_valid(pause_button): pause_button.hide(); pause_button.queue_free()
	values.clear()
	buttons.clear()
	if not visible: return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_zones()
	if game.screen==game.Screen.PLAY:
		pause_button=button(self,"Pause",func(): game.toggle_pause())
		pause_button.position=Vector2(size.x-108,12)
		pause_button.size=Vector2(96,48)
		return
	menu=PanelContainer.new()
	add_child(menu)
	menu.position=Vector2(12,12)
	menu.size=Vector2(minf(size.x-24,560),size.y-24-game.mobile_safe_bottom)
	menu.position.x=(size.x-menu.size.x)*0.5
	if game.screen==game.Screen.MENU and size.y>size.x:
		menu.size.y=minf(menu.size.y,350)
		menu.position.y=size.y-menu.size.y-12-game.mobile_safe_bottom
	menu.add_theme_stylebox_override("panel",host._style(Color("111f35"),Color("31464b")))
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	menu.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",12)
	scroll.add_child(stack)
	match game.screen:
		game.Screen.MENU:
			stack.add_child(label("SOFT MOUNTAIN",30))
			stack.add_child(label("Tidal Glow · a living pool of soft light",16,host.MUTED))
			stack.add_child(label("Hold the arrows to aim. Tap Toss to release a cell.",16,host.ACCENT))
			button(stack,"Play",func(): game.restart(),true)
			button(stack,"Options",func(): game.open_options())
		game.Screen.PAUSE:
			stack.add_child(label("Paused",28))
			button(stack,"Resume",func(): game.toggle_pause(),true)
			button(stack,"Options",func(): game.open_options())
			button(stack,"Dev tweaks",func(): game.open_dev_tweaks())
			button(stack,"New bowl",func(): game.request_new_bowl())
			button(stack,"Main menu",func(): game.show_main_menu())
		game.Screen.GAME_OVER:
			stack.add_child(label("Bowl over",28))
			stack.add_child(label("%d points · A cell escaped the bowl." % game.score))
			button(stack,"New bowl",func(): game.request_new_bowl(),true)
			button(stack,"Options",func(): game.open_options())
			button(stack,"Main menu",func(): game.show_main_menu())
		game.Screen.CONFIRM_RESET:
			stack.add_child(label("Start a new bowl?",28))
			stack.add_child(label("This will reset the current round. Your score and all balls will be cleared."))
			button(stack,"Cancel",func(): game.cancel_new_bowl(),true)
			button(stack,"Reset round",func(): game.restart())
		game.Screen.OPTIONS,game.Screen.DEV_TWEAKS: build_options(stack)
	sync_values()

func build_options(stack: VBoxContainer) -> void:
	var dev: bool=game.screen==game.Screen.DEV_TWEAKS
	stack.add_child(label("Dev tweaks" if dev else "Options",28))
	button(stack,"Done",func(): game.close_options(),true)
	var tabs := HBoxContainer.new()
	stack.add_child(tabs)
	var names := ["Material","Throw / camera"] if dev else ["Performance","Lighting","Effects"]
	for i in names.size():
		var page: int=i+(0 if dev else 2)
		var tab := button(tabs,names[i],func():
			host.option_page=page
			if dev: host.dev_page=page
			sync_screen(),page==host.option_page)
		tab.add_theme_font_size_override("font_size",12)
	if host.option_page==0:
		for i in 3:
			var material := i
			button(stack,["Balloon","Foam","Dough"][i],func(): game.set_material(material))
	for spec in host.performance_specs:
		if spec.get("page",2)!=host.option_page: continue
		var setting: Dictionary=spec
		stack.add_child(label(spec.label,18))
		buttons[spec.key]=button(stack,"",func():
			var current: int=setting.values.find(game.get(setting.key))
			game.set_performance_option(setting.key,setting.values[(current+1)%setting.values.size()]))
		stack.add_child(label(spec.hint,13,host.MUTED))
	for spec in host.slider_specs:
		if spec.get("page",0)!=host.option_page: continue
		var setting: Dictionary=spec
		var title := label(spec.label,16)
		stack.add_child(title)
		var slider := HSlider.new()
		slider.min_value=spec.min
		slider.max_value=spec.max
		slider.step=spec.step
		slider.custom_minimum_size.y=48
		slider.editable=not spec.get("desktop",false) or game.desktop_effects
		stack.add_child(slider)
		values[spec.key]={"slider":slider,"label":title,"spec":spec}
		slider.value_changed.connect(func(value):
			if rebuilding: return
			if setting.get("page",0)>=2: game.set_performance_option(setting.key,value)
			elif host._option_owner(setting.key)==game: game.set_play_option(setting.key,value)
			else: game.sim.set(setting.key,value)
			if setting.key in ["stiffness","recovery","damping"]: game.material_index=-1
			host.sync_options())
		stack.add_child(label(spec.hint,13,host.MUTED))
	if host.option_page==0:
		buttons.lab=button(stack,"",func(): game.toggle_lab(); sync_values())
		buttons.slow=button(stack,"",func(): game.slow_motion=not game.slow_motion; sync_values())
	if host.option_page==1:
		buttons.smart=button(stack,"",func(): game.smart_trajectory=not game.smart_trajectory; sync_values())
	button(stack,"Reset defaults",func():
		if dev: game.reset_dev_tweaks()
		else: game.reset_options())

func sync_values() -> void:
	if not visible: return
	rebuilding=true
	for key in values:
		var item: Dictionary=values[key]
		var value: float=host._option_owner(key).get(key)
		item.slider.set_value_no_signal(value)
		item.label.text=item.spec.label+"  ·  "+("%.2f" % value if item.slider.editable else "Desktop only")
	for spec in host.performance_specs:
		if not buttons.has(spec.key): continue
		var node: Button=buttons[spec.key]
		node.disabled=spec.get("desktop",false) and not game.desktop_effects
		node.text="Desktop only" if node.disabled else spec.choices[spec.values.find(game.get(spec.key))]+"  ›"
	if buttons.has("lab"): buttons.lab.text="Collision lab: "+("On" if game.lab_mode else "Off")
	if buttons.has("slow"): buttons.slow.text="Slow motion: "+("0.25×" if game.slow_motion else "Off")
	if buttons.has("smart"): buttons.smart.text="Smart trajectory: "+("On" if game.smart_trajectory else "Off")
	rebuilding=false

func _draw() -> void:
	if not visible or game.screen!=game.Screen.PLAY: return
	var font: Font=ThemeDB.fallback_font
	draw_string(font,Vector2(16,37),"%d" % game.score,HORIZONTAL_ALIGNMENT_LEFT,-1,28,host.INK)
	draw_string(font,Vector2(16,56),"POINTS",HORIZONTAL_ALIGNMENT_LEFT,-1,10,host.MUTED)
	for i in 3: draw_circle(Vector2(size.x*0.5-22+i*22,35),7-i,SoftBall.COLORS[game.queue[i]])
	for i in 8: draw_circle(Vector2(14,size.y-dock_height()-18-i*20),4+i*0.4,SoftBall.COLORS[i])
	if game.show_fps: draw_string(font,Vector2(16,78),"%d FPS" % Engine.get_frames_per_second(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,host.MUTED)
	draw_style_box(dock_style,Rect2(0,size.y-dock_height(),size.x,dock_height()))
	var down := pointers.values()
	for key in zones:
		var rect: Rect2=zones[key]
		draw_style_box(control_styles[key][int(key in down)],rect)
		if key!="toss":
			_draw_control_icon(key,rect.get_center())
			continue
		var fs := 20 if key=="toss" else 30
		var text := "Toss" if game.cooldown<=0 else "Ready soon"
		var text_width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
		draw_string(font,rect.get_center()+Vector2(-text_width*0.5,fs*0.35),text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color("14282b") if key=="toss" else host.INK)
	for pair in [["left","right","ROTATE"],["lower","raise","TRAJECTORY"]]:
		var center: float=(zones[pair[0]].get_center().x+zones[pair[1]].get_center().x)*0.5
		var text_width := font.get_string_size(pair[2],HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
		draw_string(font,Vector2(center-text_width*0.5,size.y-dock_height()+20),pair[2],HORIZONTAL_ALIGNMENT_LEFT,-1,11,host.MUTED)
	if host.notice_time>0: draw_string(font,Vector2(28,size.y-dock_height()-12),host.notice,HORIZONTAL_ALIGNMENT_LEFT,size.x-50,12,host.ACCENT)

func _draw_control_icon(action: String,at: Vector2) -> void:
	# Geometry keeps the arrows readable even without OS fallback fonts on Web.
	var path := PackedVector2Array()
	if action in ["left","right"]:
		var flip := 1.0 if action=="left" else -1.0
		for i in 33:
			var angle := PI*i/32.0
			path.append(at+Vector2(cos(angle)*11*flip,-sin(angle)*11))
		path.append(at+Vector2(-11*flip,8))
		draw_polyline(path,host.INK,2.5,true)
		draw_polyline(PackedVector2Array([at+Vector2(-16*flip,3),at+Vector2(-11*flip,8),at+Vector2(-6*flip,3)]),host.INK,2.5,true)
	else:
		var flip := 1.0 if action=="raise" else -1.0
		draw_line(at+Vector2(0,11*flip),at+Vector2(0,-11*flip),host.INK,2.5,true)
		draw_polyline(PackedVector2Array([at+Vector2(-7,-4*flip),at+Vector2(0,-11*flip),at+Vector2(7,-4*flip)]),host.INK,2.5,true)
