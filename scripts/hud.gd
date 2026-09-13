extends Control
## A quiet play HUD, with development controls in a shared options modal.

const INK := Color("edf2ec")
const MUTED := Color("8da5a6")
const ACCENT := Color("b8e6bd")
const PANEL := Color("15282f")
var game: Node3D
var font: Font = ThemeDB.fallback_font
var menu_controls: Control
var play_controls: Control
var modal_blocker: Control
var pause_controls: Control
var options_controls: Control
var end_controls: Control
var material_buttons: Array[Button] = []
var sliders: Dictionary = {}
var lab_button: Button
var slow_button: Button
var score_popups: Array[Dictionary] = []
var notice := ""
var notice_time := 0.0
var slider_specs := [
	{"key":"stiffness","label":"Firmness","hint":"Yielding to springy.","min":0.06,"max":0.6,"step":0.01,"x":374,"y":282},
	{"key":"recovery","label":"Shape recovery","hint":"How quickly a dent rounds out.","min":0.001,"max":0.035,"step":0.001,"x":374,"y":388},
	{"key":"damping","label":"Internal damping","hint":"Wobbly to cushioned.","min":0.005,"max":0.16,"step":0.005,"x":374,"y":494},
	{"key":"weight_scale","label":"Weight","hint":"Mass relative to elasticity.","min":0.25,"max":3.0,"step":0.05,"x":746,"y":282},
	{"key":"gravity","label":"Gravity","hint":"The downward pull on every ball.","min":3.0,"max":18.0,"step":0.1,"x":746,"y":388},
	{"key":"bowl_grip","label":"Bowl grip","hint":"Sliding resistance against the bowl.","min":0.0,"max":0.3,"step":0.005,"x":746,"y":494}]

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_button(pause_controls,"New bowl",Rect2(558,491,324,48),func(): game.restart(),false,16)
	_button(pause_controls,"Main menu",Rect2(558,554,324,48),func(): game.show_main_menu(),false,16)
	end_controls=_group(modal_blocker)
	_button(end_controls,"New bowl",Rect2(558,405,324,54),func(): game.restart(),true,18)
	_button(end_controls,"Options",Rect2(558,474,324,48),func(): game.open_options(),false,16)
	_button(end_controls,"Main menu",Rect2(558,537,324,48),func(): game.show_main_menu(),false,16)
	options_controls=_group(modal_blocker)
	_button(options_controls,"×",Rect2(1042,105,40,40),func(): game.close_options(),false,24)
	for i in 3:
		var index := i
		material_buttons.append(_button(options_controls,["Balloon","Foam","Dough"][i],Rect2(374+i*232,197,218,43),func(): game.set_material(index),false,16))
	for spec in slider_specs: _slider(spec)
	lab_button=_button(options_controls,"Collision lab",Rect2(374,602,326,44),func(): game.toggle_lab(); sync_options(),false,16)
	slow_button=_button(options_controls,"Slow motion",Rect2(746,602,326,44),func(): game.slow_motion=not game.slow_motion; sync_options(),false,16)
	_button(options_controls,"Reset defaults",Rect2(374,751,172,43),func(): game.reset_options(),false,14)
	_button(options_controls,"Done",Rect2(909,751,163,43),func(): game.close_options(),true,16)
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
		game.sim.set(key,value)
		if key in ["stiffness","recovery","damping"]: game.material_index=-1
		sync_options())
	options_controls.add_child(slider)
	sliders[key]=slider

func sync_screen() -> void:
	if not is_instance_valid(menu_controls): return
	menu_controls.visible=game.screen==game.Screen.MENU
	play_controls.visible=game.screen==game.Screen.PLAY
	modal_blocker.visible=game.screen in [game.Screen.PAUSE,game.Screen.OPTIONS,game.Screen.GAME_OVER]
	pause_controls.visible=game.screen==game.Screen.PAUSE
	options_controls.visible=game.screen==game.Screen.OPTIONS
	end_controls.visible=game.screen==game.Screen.GAME_OVER
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus): focus.release_focus()
	sync_options()
	queue_redraw()

func sync_options() -> void:
	for key in sliders: sliders[key].set_value_no_signal(game.sim.get(key))
	for i in material_buttons.size():
		material_buttons[i].modulate=ACCENT if i==game.material_index else Color.WHITE
		material_buttons[i].text=["Balloon","Foam","Dough"][i]+("   •" if i==game.material_index else "")
	if is_instance_valid(lab_button):
		lab_button.text="Collision lab     "+("ON" if game.lab_mode else "OFF")
		lab_button.modulate=ACCENT if game.lab_mode else Color.WHITE
		slow_button.text="Slow motion     "+("0.25×" if game.slow_motion else "1×")
		slow_button.modulate=ACCENT if game.slow_motion else Color.WHITE
	queue_redraw()

func show_score(at: Vector3,points_awarded: int,color: Color) -> void:
	score_popups.append({"at":at,"points":points_awarded,"color":color.lightened(0.45),"time":0.0})

func clear_scores() -> void:
	score_popups.clear()
	notice_time=0

func show_notice(text: String) -> void:
	notice=text
	notice_time=3.0

func _process(delta: float) -> void:
	if not game.paused:
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
	var menu_backdrop: bool=game.screen==game.Screen.MENU or (game.screen==game.Screen.OPTIONS and game.options_return==game.Screen.MENU)
	if menu_backdrop: _draw_menu()
	else: _draw_game()
	if modal_blocker.visible:
		draw_rect(Rect2(0,0,1440,900),Color(0.018,0.035,0.045,0.77))
		match game.screen:
			game.Screen.OPTIONS: _draw_options()
			game.Screen.PAUSE:
				panel(Rect2(504,230,432,424),PANEL,24)
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
	text_at("A small experiment in squishy things.",Vector2(136,444),19,MUTED)

func _draw_game() -> void:
	centered("%04d" % game.score,Vector2(720,85),48)
	centered("POINTS",Vector2(720,112),11,MUTED)
	draw_line(Vector2(82,212),Vector2(82,742),Color("3a5457"),1)
	for i in 8:
		var y := 742.0-i*75.0
		var radius := 11.0+i*2.0
		draw_circle(Vector2(82,y),radius+5,Color("20343a"))
		draw_circle(Vector2(82,y),radius,SoftBall.COLORS[i])
		draw_circle(Vector2(78,y-5),radius*0.24,Color(1,1,1,0.17))
		text_at("%02d" % (i+1),Vector2(118,y+4),11,MUTED)
		if i<7:
			draw_line(Vector2(78,y-35),Vector2(82,y-39),MUTED,1)
			draw_line(Vector2(82,y-39),Vector2(86,y-35),MUTED,1)
	centered("NEXT",Vector2(1346,303),11,MUTED)
	for i in 3:
		var y := 345.0+i*66
		draw_circle(Vector2(1346,y),24,Color("20343a"))
		draw_circle(Vector2(1346,y),18-i*2,SoftBall.COLORS[game.queue[i]])
		centered(str(game.queue[i]+1),Vector2(1385,y+4),11,MUTED)
	centered("A / D  rotate     W / S  trajectory     Space / Click  toss     Scroll  zoom     Esc  pause",Vector2(720,855),13,MUTED)
	if notice_time>0: centered(notice,Vector2(720,817),14,ACCENT)
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

func _draw_options() -> void:
	panel(Rect2(326,80,788,749),PANEL,24)
	text_at("Options",Vector2(374,141),36)
	text_at("Shape the way things feel.",Vector2(376,172),15,MUTED)
	for spec in slider_specs:
		text_at(spec.label,Vector2(spec.x,spec.y),16)
		var value: float=game.sim.get(spec.key)
		var display: String
		match spec.key:
			"weight_scale": display="%.2f×" % value
			"gravity": display="%.1f m/s²" % value
			_: display="%.1f%%" % (value*100)
		var width := font.get_string_size(display,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		text_at(display,Vector2(spec.x+322-width,spec.y),13,ACCENT)
		text_at(spec.hint,Vector2(spec.x,spec.y+68),12,MUTED)
	text_at("Disable merging and the spill limit.",Vector2(382,671),12,MUTED)
	text_at("Watch collisions at quarter speed.",Vector2(754,671),12,MUTED)
	draw_line(Vector2(374,702),Vector2(1072,702),Color("31464b"))
	text_at("Changes apply to every ball.",Vector2(374,729),12,MUTED)
