extends Control
## A quiet play HUD, with development controls in a shared options modal.

const INK := Color("edf2ec")
const MUTED := Color("8da5a6")
const ACCENT := Color("a5daed")
const PANEL := Color("111f35")
var game: Node3D
var mobile_ui: Control
var font: Font = ThemeDB.fallback_font
var menu_controls: Control
var play_controls: Control
var modal_blocker: Control
var pause_controls: Control
var options_controls: Control
var end_controls: Control
var reset_controls: Control
var option_page := 0
var dev_page := 0
var option_tabs: Array[Button] = []
var material_buttons: Array[Button] = []
var sliders: Dictionary = {}
var lab_button: Button
var slow_button: Button
var smart_button: Button
var aim_layers: Array[Node2D] = []
var aim_groups: Array[CanvasGroup] = []
var performance_buttons: Dictionary = {}
var performance_specs := [
	{"key":"frame_limit","label":"Frame limit","choices":["60 FPS","30 FPS","Display refresh"],"values":[60,30,0],"hint":"30 FPS uses less power on phones.","x":374,"y":260},
	{"key":"render_scale","label":"3D resolution","choices":["50%","75%","100%"],"values":[0.5,0.75,1.0],"hint":"Lower resolution; menus stay sharp.","x":746,"y":260},
	{"key":"ball_detail","label":"Ball detail","choices":["Low","Medium","High"],"values":[0,1,2],"hint":"Simpler surfaces reduce mesh-building work.","x":374,"y":360},
	{"key":"visual_rate","label":"Ball animation","choices":["30 Hz","60 Hz","Every frame"],"values":[30,60,0],"hint":"Visual refresh only; physics stays the same.","x":746,"y":360},
	{"key":"shadows_enabled","label":"Shadows","choices":["Off","On"],"values":[false,true],"hint":"Turn off cast shadows to ease GPU load.","x":374,"y":460},
	{"key":"antialiasing","label":"Edge smoothing","choices":["Off","2×","4×"],"values":[0,1,2],"hint":"Lower settings reduce GPU work.","x":746,"y":460},
	{"key":"merge_effects","label":"Merge effects","choices":["Off","Reduced","Full"],"values":[0,1,2],"hint":"Fewer stars and simpler trails.","x":374,"y":560},
	{"key":"show_fps","label":"FPS counter","choices":["Off","On"],"values":[false,true],"hint":"Show the frame rate during play.","x":746,"y":560},
	{"key":"lighting_quality","label":"Living lights","choices":["Off","Reduced","Full"],"values":[0,1,2],"hint":"Cells and merges illuminate their surroundings.","x":374,"y":282,"page":3},
	{"key":"sss_enabled","label":"Subsurface scattering","choices":["Off","On"],"values":[false,true],"hint":"Soft light diffusion through the inner tissue.","x":746,"y":282,"page":3,"desktop":true},
	{"key":"bloom_enabled","label":"Bloom","choices":["Off","On"],"values":[false,true],"hint":"","x":374,"y":588,"page":4,"desktop":true}]
var score_popups: Array[Dictionary] = []
var merge_stars: Array[Dictionary] = []
var notice := ""
var notice_time := 0.0
var slider_specs := [
	{"key":"ball_glow","label":"Ball glow","hint":"Brightness of tissue and luminous filaments.","min":0.0,"max":5.0,"step":0.05,"x":374,"y":282,"page":4},
	{"key":"ball_light_strength","label":"Cast light strength","hint":"Light from balls and merges onto the bowl.","min":0.0,"max":3.0,"step":0.05,"x":746,"y":282,"page":4},
	{"key":"bloom_intensity","label":"Bloom intensity","hint":"Strength of the halo around bright areas.","min":0.0,"max":2.0,"step":0.05,"x":374,"y":388,"page":4,"desktop":true},
	{"key":"bloom_threshold","label":"Bloom threshold","hint":"Lower values let more surfaces bloom.","min":0.1,"max":3.0,"step":0.05,"x":746,"y":388,"page":4,"desktop":true},
	{"key":"bloom_floor","label":"Ambient bloom","hint":"Adds a soft haze beyond the highlights.","min":0.0,"max":1.0,"step":0.01,"x":374,"y":494,"page":4,"desktop":true},
	{"key":"exposure","label":"Scene exposure","hint":"Overall scene brightness before tone mapping.","min":0.5,"max":2.0,"step":0.05,"x":746,"y":494,"page":4,"desktop":true},
	{"key":"stiffness","label":"Firmness","hint":"Yielding to springy.","min":0.06,"max":0.6,"step":0.01,"x":374,"y":282},
	{"key":"recovery","label":"Shape recovery","hint":"How quickly a dent rounds out.","min":0.001,"max":0.035,"step":0.001,"x":374,"y":388},
	{"key":"damping","label":"Internal damping","hint":"Wobbly to cushioned.","min":0.005,"max":0.16,"step":0.005,"x":374,"y":494},
	{"key":"weight_scale","label":"Weight","hint":"Mass relative to elasticity.","min":0.25,"max":3.0,"step":0.05,"x":746,"y":282},
	{"key":"gravity","label":"Gravity","hint":"The downward pull on every ball.","min":3.0,"max":18.0,"step":0.1,"x":746,"y":388},
	{"key":"bowl_grip","label":"Bowl grip","hint":"Sliding resistance against the bowl.","min":0.0,"max":0.3,"step":0.005,"x":746,"y":494},
	{"key":"rotation_speed","label":"Rotation speed","hint":"How quickly A / D orbits the bowl.","min":15.0,"max":150.0,"step":1.0,"x":374,"y":602,"page":1},
	{"key":"min_elevation","label":"Minimum trajectory","hint":"Lowest angle available with S.","min":-35.0,"max":75.0,"step":1.0,"x":374,"y":282,"page":1},
	{"key":"max_elevation","label":"Maximum trajectory","hint":"Highest angle available with W.","min":-30.0,"max":80.0,"step":1.0,"x":746,"y":282,"page":1},
	{"key":"trajectory_speed","label":"Trajectory adjustment","hint":"How quickly W / S changes the angle.","min":5.0,"max":100.0,"step":1.0,"x":374,"y":388,"page":1},
	{"key":"throw_speed","label":"Launch speed","hint":"Faster throws travel further.","min":2.0,"max":12.0,"step":0.1,"x":746,"y":388,"page":1},
	{"key":"camera_height","label":"Camera height angle","hint":"Low side view to overhead view.","min":20.0,"max":70.0,"step":0.5,"x":374,"y":494,"page":1},
	{"key":"camera_offset","label":"Camera side offset","hint":"Negative moves to the opposite side.","min":-65.0,"max":65.0,"step":1.0,"x":746,"y":494,"page":1}]

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Composite each portion before fading so overlapping dots retain one outline
	# and a uniform opacity. Both groups sit below the HUD and modal backdrop.
	for hidden in [true,false]:
		var group := CanvasGroup.new()
		group.self_modulate.a=0.18 if hidden else 1.0
		get_parent().add_child(group)
		get_parent().move_child(group,get_index())
		var drawing := Node2D.new()
		group.add_child(drawing)
		drawing.draw.connect(_draw_aim.bind(drawing,hidden))
		aim_groups.append(group)
		aim_layers.append(drawing)
	menu_controls=_group(self)
	_button(menu_controls,"Play",Rect2(136,500,314,62),func(): game.restart(),true,22)
	_button(menu_controls,"Options",Rect2(136,578,314,52),func(): game.open_options(),false,18)
	play_controls=_group(self)
	_button(play_controls,"Ⅱ   Pause",Rect2(1270,34,132,44),func(): game.toggle_pause())
	modal_blocker=_group(self)
	modal_blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	pause_controls=_group(modal_blocker)
	_button(pause_controls,"Resume",Rect2(558,359,324,54),func(): game.toggle_pause(),true,18)
	_button(pause_controls,"Options",Rect2(558,428,324,48),func(): game.open_options(),false,16)
	_button(pause_controls,"Dev tweaks",Rect2(558,491,324,48),func(): game.open_dev_tweaks(),false,16)
	_button(pause_controls,"New bowl",Rect2(558,554,324,48),func(): game.request_new_bowl(),false,16)
	_button(pause_controls,"Main menu",Rect2(558,617,324,48),func(): game.show_main_menu(),false,16)
	end_controls=_group(modal_blocker)
	_button(end_controls,"New bowl",Rect2(558,405,324,54),func(): game.request_new_bowl(),true,18)
	_button(end_controls,"Options",Rect2(558,474,324,48),func(): game.open_options(),false,16)
	_button(end_controls,"Main menu",Rect2(558,537,324,48),func(): game.show_main_menu(),false,16)
	reset_controls=_group(modal_blocker)
	_button(reset_controls,"Cancel",Rect2(508,482,198,52),func(): game.cancel_new_bowl(),false,16)
	_button(reset_controls,"Reset round",Rect2(734,482,198,52),func(): game.restart(),true,16)
	options_controls=_group(modal_blocker)
	_button(options_controls,"×",Rect2(1042,105,40,40),func(): game.close_options(),false,24)
	for i in 3:
		var page := i
		option_tabs.append(_button(options_controls,"",Rect2(374+i*356,194,342,42),func():
			if game.screen==game.Screen.DEV_TWEAKS: dev_page=page; option_page=page
			else: option_page=page+2
			sync_options(),false,16))
	for i in 3:
		var index := i
		material_buttons.append(_button(options_controls,["Balloon","Foam","Dough"][i],Rect2(374+i*232,254,218,43),func(): game.set_material(index),false,16))
	for spec in slider_specs:
		if spec.get("page",0)==0: spec.y+=48
		_slider(spec)
	lab_button=_button(options_controls,"Collision lab",Rect2(374,648,326,44),func(): game.toggle_lab(); sync_options(),false,16)
	lab_button.tooltip_text="Disable merging and the spill limit."
	slow_button=_button(options_controls,"Slow motion",Rect2(746,648,326,44),func(): game.slow_motion=not game.slow_motion; sync_options(),false,16)
	slow_button.tooltip_text="Watch collisions at quarter speed."
	smart_button=_button(options_controls,"Smart trajectory",Rect2(746,602,326,44),func(): game.smart_trajectory=not game.smart_trajectory; game._update_aim(); sync_options(),false,16)
	smart_button.tooltip_text="Stop the guide at the first predicted contact with a ball."
	for spec in performance_specs:
		var setting: Dictionary=spec
		var button := _button(options_controls,spec.label,Rect2(spec.x,spec.y+16,326,44),func():
			var current: int=setting.values.find(game.get(setting.key))
			game.set_performance_option(setting.key,setting.values[(current+1)%setting.values.size()]),false,16)
		button.tooltip_text=spec.hint
		performance_buttons[spec.key]=button
	_button(options_controls,"Reset defaults",Rect2(374,751,172,43),func():
		if game.screen==game.Screen.DEV_TWEAKS: game.reset_dev_tweaks()
		else: game.reset_options(),false,14)
	_button(options_controls,"Done",Rect2(909,751,163,43),func(): game.close_options(),true,16)
	mobile_ui=load("res://scripts/mobile_ui.gd").new()
	mobile_ui.game=game
	mobile_ui.host=self
	add_child(mobile_ui)
	sync_screen()
	sync_options()

func _group(parent: Control) -> Control:
	var group := Control.new()
	group.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(group)
	group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return group

func _style(color: Color,border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.border_color=border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style

func _button(parent: Control,text: String,rect: Rect2,callback: Callable,primary: bool=false,font_size: int=14) -> Button:
	var button := Button.new()
	button.text=text
	button.position=rect.position
	button.size=rect.size
	button.add_theme_font_size_override("font_size",font_size)
	button.add_theme_color_override("font_color",Color("14282b") if primary else INK)
	button.add_theme_color_override("font_hover_color",Color("14282b") if primary else INK)
	button.add_theme_color_override("font_pressed_color",Color("14282b") if primary else INK)
	button.add_theme_stylebox_override("normal",_style(ACCENT,ACCENT) if primary else _style(Color("20363c"),Color("354b51")))
	button.add_theme_stylebox_override("hover",_style(Color("cfefd0"),Color("cfefd0")) if primary else _style(Color("2c454a"),Color("718b85")))
	button.add_theme_stylebox_override("pressed",_style(Color("94c5a0"),ACCENT) if primary else _style(Color("304b46"),ACCENT))
	var focus := _style(Color.TRANSPARENT,ACCENT)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus",focus)
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _slider(spec: Dictionary) -> void:
	var slider := HSlider.new()
	slider.position=Vector2(spec.x,spec.y+17)
	slider.size=Vector2(322,28)
	slider.min_value=spec.min
	slider.max_value=spec.max
	slider.step=spec.step
	slider.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	slider.tooltip_text=spec.hint
	slider.add_theme_stylebox_override("slider",_style(Color("31474c"),Color("31474c")))
	slider.add_theme_stylebox_override("grabber_area",_style(Color("709d84"),Color("709d84")))
	slider.add_theme_stylebox_override("grabber_area_highlight",_style(ACCENT,ACCENT))
	var key: String=spec.key
	slider.value_changed.connect(func(value):
		if spec.get("page",0)>=2: game.set_performance_option(key,value)
		elif _option_owner(key)==game: game.set_play_option(key,value)
		else: game.sim.set(key,value)
		if key in ["stiffness","recovery","damping"]: game.material_index=-1
		sync_options())
	options_controls.add_child(slider)
	sliders[key]=slider

func sync_screen() -> void:
	if not is_instance_valid(menu_controls): return
	menu_controls.visible=game.screen==game.Screen.MENU
	play_controls.visible=game.screen==game.Screen.PLAY
	modal_blocker.visible=game.screen in [game.Screen.PAUSE,game.Screen.OPTIONS,game.Screen.DEV_TWEAKS,game.Screen.GAME_OVER,game.Screen.CONFIRM_RESET]
	pause_controls.visible=game.screen==game.Screen.PAUSE
	options_controls.visible=game.screen in [game.Screen.OPTIONS,game.Screen.DEV_TWEAKS]
	end_controls.visible=game.screen==game.Screen.GAME_OVER
	reset_controls.visible=game.screen==game.Screen.CONFIRM_RESET
	if game.mobile_mode:
		menu_controls.hide()
		play_controls.hide()
		modal_blocker.hide()
	if is_instance_valid(mobile_ui): mobile_ui.sync_screen()
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus): focus.release_focus()
	sync_options()
	queue_redraw()

func _option_owner(key: String) -> Object:
	return game.sim if key in ["stiffness","recovery","damping","weight_scale","gravity","bowl_grip"] else game

func sync_options() -> void:
	if is_instance_valid(mobile_ui): mobile_ui.sync_values()
	for key in sliders: sliders[key].set_value_no_signal(_option_owner(key).get(key))
	for spec in slider_specs:
		var slider: HSlider=sliders[spec.key]
		slider.visible=spec.get("page",0)==option_page
		slider.editable=not spec.get("desktop",false) or game.desktop_effects
		slider.modulate=Color.WHITE if slider.editable else Color(1,1,1,0.3)
	for i in option_tabs.size():
		var dev: bool=game.screen==game.Screen.DEV_TWEAKS
		option_tabs[i].visible=game.screen in [game.Screen.DEV_TWEAKS,game.Screen.OPTIONS] and (not dev or i<2)
		option_tabs[i].position=Vector2(374+i*(356 if dev else 238),194)
		option_tabs[i].size=Vector2(342 if dev else 222,42)
		option_tabs[i].text=(["Material & lab","Throw & camera",""] if dev else ["Performance","Tidal lighting","Post-processing"])[i]
		option_tabs[i].modulate=ACCENT if i+(0 if dev else 2)==option_page else Color.WHITE
	for i in material_buttons.size():
		material_buttons[i].visible=option_page==0
		material_buttons[i].modulate=ACCENT if i==game.material_index else Color.WHITE
		material_buttons[i].text=["Balloon","Foam","Dough"][i]+("   •" if i==game.material_index else "")
	if is_instance_valid(lab_button):
		lab_button.visible=option_page==0
		slow_button.visible=option_page==0
		lab_button.text="Collision lab     "+("ON" if game.lab_mode else "OFF")
		lab_button.modulate=ACCENT if game.lab_mode else Color.WHITE
		slow_button.text="Slow motion     "+("0.25×" if game.slow_motion else "1×")
		slow_button.modulate=ACCENT if game.slow_motion else Color.WHITE
	if is_instance_valid(smart_button):
		smart_button.visible=option_page==1
		smart_button.text="Smart trajectory     "+("ON" if game.smart_trajectory else "OFF")
		smart_button.modulate=ACCENT if game.smart_trajectory else Color.WHITE
	for spec in performance_specs:
		if not performance_buttons.has(spec.key): continue
		var button: Button=performance_buttons[spec.key]
		button.visible=option_page==spec.get("page",2)
		button.text=spec.choices[spec.values.find(game.get(spec.key))]+"   ›"
		button.disabled=spec.get("desktop",false) and not game.desktop_effects
		if button.disabled: button.text="Desktop only"
	queue_redraw()

func show_score(at: Vector3,points_awarded: int,color: Color) -> void:
	score_popups.append({"at":at,"points":points_awarded,"color":color.lightened(0.45),"time":0.0})

func show_merge_stars(at: Vector3,tier: int) -> void:
	if game.merge_effects==0: return
	# Deterministic cosmetic variation never consumes the gameplay random stream.
	for i in 12:
		if game.merge_effects==1 and i%2==1: continue
		var theta := TAU*i/12.0+tier*0.43
		var speed := 1.5+(i%3)*0.4
		var velocity := Vector3(cos(theta)*speed,1.2+(i%4)*0.35,sin(theta)*speed)
		merge_stars.append({"at":at,"velocity":velocity,"time":0.0,"life":0.75+(i%3)*0.12,"rotation":theta,"size":12.0+(i%3)*3.0,"spark":i%3==2})

func clear_scores() -> void:
	score_popups.clear()
	merge_stars.clear()
	notice_time=0

func show_notice(text: String) -> void:
	notice=text
	notice_time=3.0

func _process(delta: float) -> void:
	for i in aim_layers.size():
		aim_groups[i].visible=game.aim_visible and (i==1 or not game.smart_trajectory)
		aim_layers[i].queue_redraw()
	if not game.paused:
		for i in range(merge_stars.size()-1,-1,-1):
			merge_stars[i].time+=delta
			if merge_stars[i].time>=merge_stars[i].life: merge_stars.remove_at(i)
		for i in range(score_popups.size()-1,-1,-1):
			score_popups[i].time+=delta
			if score_popups[i].time>=1.4: score_popups.remove_at(i)
		notice_time=maxf(0,notice_time-delta)
	queue_redraw()

func text_at(text: String,at: Vector2,size_px: int,color: Color=INK) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func centered(text: String,at: Vector2,size_px: int,color: Color=INK) -> void:
	text_at(text,at-Vector2(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x*0.5,0),size_px,color)

func panel(rect: Rect2,color: Color,radius: int=20) -> void:
	var style := _style(color,Color("31464b"))
	style.set_corner_radius_all(radius)
	draw_style_box(style,rect)

func _draw() -> void:
	if not game: return
	if game.mobile_mode:
		_draw_merge_stars()
		_draw_score_popups()
		return
	var menu_backdrop: bool=game.screen==game.Screen.MENU or (game.screen==game.Screen.OPTIONS and game.options_return==game.Screen.MENU)
	if menu_backdrop: _draw_menu()
	else: _draw_game()
	if modal_blocker.visible:
		draw_rect(Rect2(0,0,1440,900),Color(0.018,0.035,0.045,0.77))
		match game.screen:
			game.Screen.OPTIONS,game.Screen.DEV_TWEAKS: _draw_options()
			game.Screen.CONFIRM_RESET:
				panel(Rect2(460,290,520,292),PANEL,24)
				centered("Start a new bowl?",Vector2(720,354),32)
				centered("This will reset the current round.",Vector2(720,400),17)
				centered("Your score and all balls will be cleared.",Vector2(720,430),14,MUTED)
			game.Screen.PAUSE:
				panel(Rect2(504,230,432,487),PANEL,24)
				centered("Paused",Vector2(720,298),36)
				centered("Your bowl can wait.",Vector2(720,330),15,MUTED)
			game.Screen.GAME_OVER:
				panel(Rect2(504,230,432,412),PANEL,24)
				centered("Bowl over",Vector2(720,295),36)
				centered("%04d" % game.score,Vector2(720,350),36,ACCENT)
				centered("A sphere escaped the bowl.",Vector2(720,379),14,MUTED)

func _draw_menu() -> void:
	for i in 3:
		draw_circle(Vector2(147+i*30,222),7,SoftBall.COLORS[i])
	text_at("SOFT",Vector2(130,315),76)
	text_at("MOUNTAIN",Vector2(130,399),76)
	text_at("Tidal Glow · a living pool of soft light.",Vector2(136,444),19,MUTED)

func _draw_game() -> void:
	_draw_merge_stars()
	if game.show_fps: text_at("%d FPS" % Engine.get_frames_per_second(),Vector2(1290,855),13,MUTED)
	centered("%04d" % game.score,Vector2(720,85),48)
	centered("POINTS",Vector2(720,112),11,MUTED)
	draw_line(Vector2(82,212),Vector2(82,742),Color("3a5457"),1)
	for i in 8:
		var y := 742.0-i*75.0
		var radius := 11.0+i*2.0
		draw_circle(Vector2(82,y),radius+5,Color("20343a"))
		_cell_icon(Vector2(82,y),radius,SoftBall.COLORS[i])
		if i<7:
			draw_line(Vector2(78,y-35),Vector2(82,y-39),MUTED,1)
			draw_line(Vector2(82,y-39),Vector2(86,y-35),MUTED,1)
	centered("NEXT",Vector2(1346,303),11,MUTED)
	for i in 3:
		var y := 345.0+i*66
		draw_circle(Vector2(1346,y),24,Color("20343a"))
		_cell_icon(Vector2(1346,y),20-i*2,SoftBall.COLORS[game.queue[i]])
	centered("A / D  rotate     W / S  trajectory     Space / Click  toss     Scroll  zoom     Esc  pause",Vector2(720,855),13,MUTED)
	if notice_time>0: centered(notice,Vector2(720,817),14,ACCENT)
	_draw_score_popups()

func _draw_score_popups() -> void:
	for popup in score_popups:
		var at: Vector3=popup.at+Vector3.UP*(0.4+popup.time*0.95)
		if game.camera.is_position_behind(at): continue
		var screen_position: Vector2=game.camera.unproject_position(at)
		var alpha := 1.0-smoothstep(0.35,1.4,popup.time)
		var size_px := int(lerpf(31,24,minf(1,popup.time*5)))
		var text := "+%d" % popup.points
		var origin := screen_position-Vector2(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x*0.5,0)
		draw_string_outline(font,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,5,Color(0.04,0.08,0.08,alpha*0.85))
		var color: Color=popup.color
		color.a=alpha
		text_at(text,origin,size_px,color)

func _star_world(star: Dictionary,time: float) -> Vector3:
	return star.at+star.velocity*time+Vector3.DOWN*time*time*1.6

func _draw_merge_stars() -> void:
	for star in merge_stars:
		var time: float=star.time
		var world := _star_world(star,time)
		if game.camera.is_position_behind(world): continue
		var head: Vector2=game.camera.unproject_position(world)
		var alpha := (1.0-smoothstep(star.life*0.48,star.life,time))*smoothstep(0.0,0.06,time)
		var radius: float=star.size*lerpf(1.0,0.45,time/star.life)
		# Layered, tapered trails give the shooting-star colour without relying
		# on renderer-specific bloom. Their origin remains attached to the merge.
		if not star.spark and game.merge_effects==2:
			for segment in 6:
				var t0 := maxf(0,time-0.3+segment*0.3/6.0)
				var t1 := maxf(0,time-0.3+(segment+1)*0.3/6.0)
				var a: Vector2=game.camera.unproject_position(_star_world(star,t0))
				var b: Vector2=game.camera.unproject_position(_star_world(star,t1))
				var progress := (segment+1)/6.0
				var trail := Color("9858ff").lerp(Color("ff8ac7"),progress)
				trail.a=alpha*progress*0.14
				draw_line(a,b,trail,radius*1.9*progress,true)
				trail.a=alpha*progress*0.8
				draw_line(a,b,trail,radius*0.85*progress,true)
		if star.spark:
			draw_circle(head,3.5,Color(0.74,0.54,1.0,alpha),true,-1,true)
			draw_circle(head,6.5,Color(0.65,0.32,1.0,alpha*0.15),true,-1,true)
			continue
		var outline := PackedVector2Array()
		for corner in 10:
			var theta: float=corner*PI/5.0+star.rotation+time*1.7
			outline.append(head+Vector2(cos(theta),sin(theta))*radius*(1.0 if corner%2==0 else 0.48))
		var glow := PackedVector2Array()
		for point in outline: glow.append(head+(point-head)*1.22)
		draw_colored_polygon(glow,Color(1.0,0.72,0.24,alpha*0.18))
		draw_colored_polygon(outline,Color(1.0,0.86,0.38,alpha))
		draw_circle(head+Vector2(-0.2,-0.25)*radius,radius*0.22,Color(1.0,0.98,0.75,alpha*0.8),true,-1,true)

func _draw_aim(canvas: Node2D,hidden: bool) -> void:
	if not game.aim_visible: return
	var outline := Color("152b32")
	var fill := Color("fff2ca")
	var points := PackedVector2Array()
	var radii := PackedFloat32Array()
	var indices := PackedInt32Array()
	var view: Vector3=game.camera.basis.z
	for i in game.trajectory.size():
		var world: Vector3=game.trajectory[i]
		if game.camera.is_position_behind(world) or AimPreview.occluded(world,view,game.sim.balls)!=hidden: continue
		points.append(game.camera.unproject_position(world))
		radii.append(2.8 if i%3==0 else 2.0)
		indices.append(i)
	# A short lead-in joins the ball-center path to the actual surface contact.
	var contact: Vector3=game.landing_marker+game.landing_normal*0.045
	if game.aim_hit and not game.camera.is_position_behind(contact) and AimPreview.occluded(contact,view,game.sim.balls)==hidden:
		points.append(game.camera.unproject_position(contact))
		radii.append(1.3)
		indices.append(game.trajectory.size())
	# Draw the complete silhouette first, then all fills. Dense clusters become
	# one outlined shape; adjacent dots never paint dark rings over one another.
	for pass_index in 2:
		var border := 1.4 if pass_index==0 else 0.0
		var color := outline if pass_index==0 else fill
		for i in points.size():
			if i>0 and indices[i]==indices[i-1]+1 and (indices[i]==game.trajectory.size() or points[i].distance_to(points[i-1])<radii[i]+radii[i-1]+1.0):
				canvas.draw_line(points[i-1],points[i],color,(minf(radii[i],radii[i-1])+border)*2.0,true)
			canvas.draw_circle(points[i],radii[i]+border,color,true,-1,true)
	if not game.aim_hit: return
	# The marker lies on the hit surface, rather than on the floor behind the pile.
	var normal: Vector3=game.landing_normal
	var axis := normal.cross(Vector3.RIGHT if absf(normal.x)<0.9 else Vector3.FORWARD).normalized()
	var other := normal.cross(axis).normalized()
	var ring := PackedVector3Array()
	var visible: Array[bool]=[]
	for i in 49:
		var theta := TAU*i/48.0
		var world: Vector3=game.landing_marker+normal*0.045+(axis*cos(theta)+other*sin(theta))*0.16
		ring.append(world)
		visible.append(not game.camera.is_position_behind(world) and AimPreview.occluded(world,view,game.sim.balls)==hidden)
	for pass_index in 2:
		for i in 48:
			if visible[i] and visible[i+1]:
				canvas.draw_line(game.camera.unproject_position(ring[i]),game.camera.unproject_position(ring[i+1]),outline if pass_index==0 else fill,4.5 if pass_index==0 else 1.8,true)

func _cell_icon(at: Vector2,radius: float,color: Color) -> void:
	draw_circle(at,radius,Color(color.r,color.g,color.b,0.13))
	draw_arc(at,radius,0,TAU,40,Color(0.85,0.96,0.91,0.55),1.0,true)
	draw_circle(at,radius*0.73,color)
	draw_circle(at+Vector2(-0.22,-0.27)*radius,radius*0.16,Color(1,1,1,0.22))

func _draw_options() -> void:
	panel(Rect2(326,80,788,749),PANEL,24)
	var dev: bool=game.screen==game.Screen.DEV_TWEAKS
	text_at("Dev tweaks" if dev else "Options",Vector2(374,141),36)
	text_at("Shape the way things feel." if dev else "Performance and display.",Vector2(376,172),15,MUTED)
	if option_page>=2:
		for spec in performance_specs:
			if spec.get("page",2)!=option_page: continue
			text_at(spec.label,Vector2(spec.x,spec.y),16)
			text_at(spec.hint,Vector2(spec.x,spec.y+84),12,MUTED)
		text_at("Current frame rate: %d FPS" % Engine.get_frames_per_second(),Vector2(374,669),15,ACCENT)
		if option_page==2: text_at("Try lower ball detail and shadows off first.",Vector2(746,669),12,MUTED)
		elif option_page==3:
			text_at("Forward+ desktop" if game.desktop_effects else "Browser / Compatibility",Vector2(746,423),18,ACCENT)
			text_at("Full: 44 balls + 2 merge lights." if game.desktop_effects else "Full: 4 lights. Reduced: 2 lights.",Vector2(746,457),13,MUTED)
			text_at("Reduced uses up to 16 lights." if game.desktop_effects else "Backlit tissue keeps the browser lightweight.",Vector2(374,457),13,MUTED)
			text_at("Tune bloom and ball brightness in Post-processing.",Vector2(374,570),15,MUTED)
		elif option_page==4:
			text_at("Cast light uses the Living lights setting.",Vector2(746,611),12,MUTED)
			text_at("Bloom and exposure require desktop Forward+." if not game.desktop_effects else "Bloom sliders apply when Bloom is on.",Vector2(746,635),12,MUTED)
	if option_page==1: text_at("Stop at the first predicted contact.",Vector2(746,670),12,MUTED)
	for spec in slider_specs:
		if spec.get("page",0)!=option_page: continue
		text_at(spec.label,Vector2(spec.x,spec.y),16)
		var value: float=_option_owner(spec.key).get(spec.key)
		var display: String
		match spec.key:
			"ball_glow","ball_light_strength","exposure": display="%.2f×" % value
			"bloom_threshold": display="%.2f" % value
			"weight_scale": display="%.2f×" % value
			"gravity": display="%.1f m/s²" % value
			"rotation_speed","trajectory_speed": display="%.0f°/s" % value
			"min_elevation","max_elevation","camera_offset": display="%.0f°" % value
			"camera_height": display="%.1f°" % value
			"throw_speed": display="%.1f m/s" % value
			_: display="%.1f%%" % (value*100)
		if spec.get("desktop",false) and not game.desktop_effects: display="Desktop only"
		var width := font.get_string_size(display,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		text_at(display,Vector2(spec.x+322-width,spec.y),13,ACCENT)
		text_at(spec.hint,Vector2(spec.x,spec.y+68),12,MUTED)
	draw_line(Vector2(374,702),Vector2(1072,702),Color("31464b"))
	text_at("Settings apply immediately.",Vector2(374,729),12,MUTED)
