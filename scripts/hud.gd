extends Control
## Fixed design coordinates are scaled by the project's canvas_items stretch.

const INK := Color("edf2ec")
const MUTED := Color("829a9e")
const ACCENT := Color("b8e6bd")
var game: Node3D
var font: Font = ThemeDB.fallback_font
var material_buttons: Array[Button] = []
var sliders: Array[HSlider] = []
var pause_button: Button
var sandbox_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_button("NEW BOWL",Rect2(1200,32,202,42),func(): game.restart())
	for i in 3:
		var index := i
		material_buttons.append(_button(["BALLOON","FOAM","DOUGH"][i],Rect2(1138+i*87,401,80,34),func(): game.set_material(index)))
	_slider(Rect2(1141,483,240,24),0.06,0.6,0.01,0.22,func(v): game.sim.stiffness=v)
	_slider(Rect2(1141,557,240,24),0.001,0.035,0.001,0.008,func(v): game.sim.recovery=v)
	_slider(Rect2(1141,631,240,24),0.005,0.16,0.005,0.045,func(v): game.sim.damping=v)
	sandbox_button = _button("COLLISION LAB   /   OFF",Rect2(1138,700,258,38),func(): game.toggle_lab())
	pause_button = _button("II   PAUSE",Rect2(1138,748,123,38),func(): game.toggle_pause())
	_button("0.25x  SLOW",Rect2(1273,748,123,38),func(): game.slow_motion=not game.slow_motion)
	_button("A   /   ROTATE LEFT",Rect2(34,723,186,36),func(): game.orbit(-0.3))
	_button("ROTATE RIGHT   /   D",Rect2(868,723,186,36),func(): game.orbit(0.3))
	_button("TOSS   /   SPACE",Rect2(445,710,218,49),func(): game.toss())

func _slider(rect: Rect2,lo: float,hi: float,increment: float,value: float,callback: Callable) -> void:
	var slider := HSlider.new()
	slider.position = rect.position
	slider.size = rect.size
	slider.min_value = lo
	slider.max_value = hi
	slider.step = increment
	slider.value = value
	slider.value_changed.connect(callback)
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(slider)
	sliders.append(slider)

func _button(text: String,rect: Rect2,callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size",12)
	button.add_theme_color_override("font_color",INK)
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("263b41") if state in ["hover","pressed"] else Color("182b32")
		style.border_color = Color("526d70") if state == "hover" else Color("344a50")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state,style)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	add_child(button)
	return button

func _process(_delta: float) -> void:
	queue_redraw()
	if game:
		pause_button.text = "RESUME" if game.paused else "II   PAUSE"
		sandbox_button.text = "COLLISION LAB   /   ON" if game.lab_mode else "COLLISION LAB   /   OFF"
		for i in material_buttons.size(): material_buttons[i].modulate = ACCENT if i == game.material_index else Color.WHITE

func text_at(text: String,at: Vector2,size_px: int,color: Color = INK) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func panel(rect: Rect2,color: Color,radius: int = 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style,rect)

func _draw() -> void:
	if not game: return
	text_at("S O F T   M O U N T A I N",Vector2(34,53),25)
	text_at("A small experiment in squishy things.",Vector2(35,81),14,MUTED)
	panel(Rect2(34,108,171,28),Color("1c3438"),14)
	draw_circle(Vector2(48,122),3,ACCENT)
	text_at("PHYSICS PLAYGROUND",Vector2(60,126),10,ACCENT)
	draw_line(Vector2(1100,110),Vector2(1100,788),Color("2a3b42"),1)
	text_at("YOUR BOWL",Vector2(1138,135),12,MUTED)
	text_at("%04d" % game.score,Vector2(1136,191),48)
	text_at("POINTS",Vector2(1140,217),11,MUTED)
	text_at("%02d" % game.sim.balls.size(),Vector2(1300,185),31)
	text_at("IN PLAY",Vector2(1301,211),11,MUTED)
	draw_line(Vector2(1138,240),Vector2(1396,240),Color("2a3b42"))
	text_at("UP NEXT",Vector2(1138,272),12,MUTED)
	for i in 3:
		var x := 1170.0+i*87.0
		var tier: int = game.queue[i]
		draw_circle(Vector2(x,314),20+i*-2,SoftBall.COLORS[tier])
		draw_circle(Vector2(x-5,308),5,Color(1,1,1,0.25))
		text_at(str(tier+1),Vector2(x-4,350),12,MUTED)
	text_at("MATERIAL FEEL",Vector2(1138,387),12,MUTED)
	text_at("Firmness",Vector2(1140,468),14)
	text_at("%d%%" % roundi(inverse_lerp(0.06,0.6,game.sim.stiffness)*100),Vector2(1350,468),12,ACCENT)
	text_at("soft",Vector2(1140,523),11,MUTED)
	text_at("springy",Vector2(1345,523),11,MUTED)
	text_at("Shape recovery",Vector2(1140,548),14)
	text_at("slow",Vector2(1140,597),11,MUTED)
	text_at("quick",Vector2(1354,597),11,MUTED)
	text_at("Internal damping",Vector2(1140,622),14)
	text_at("wobbly",Vector2(1140,671),11,MUTED)
	text_at("doughy",Vector2(1345,671),11,MUTED)
	text_at("%s  /  %d FPS" % ["SLOW MOTION" if game.slow_motion else "LIVE SIMULATION",Engine.get_frames_per_second()],Vector2(1138,818),11,MUTED)
	text_at("3D  •  SOFT BODY  •  PROTOTYPE 01",Vector2(1138,847),10,MUTED)
	panel(Rect2(34,788,1020,78),Color("14262d"))
	text_at("GROW TOGETHER",Vector2(54,816),11,MUTED)
	text_at("Same tier → next tier",Vector2(54,844),13)
	for i in 8:
		var x := 290.0+i*93.0
		var r := 9.0+i*1.65
		draw_circle(Vector2(x,818),r,SoftBall.COLORS[i])
		text_at("%02d" % (i+1),Vector2(x-7,853),11,MUTED)
		if i < 7: text_at("›",Vector2(x+42,823),17,Color("435a60"))
	var message: String = game.message if game.message_time > 0 else "Aim into the bowl. Hold & release to lob."
	text_at(message,Vector2(310,679),17,ACCENT if game.message_time>0 else INK)
	text_at("A / D  orbit     •     Right-drag  look     •     Scroll  zoom     •     R  restart",Vector2(274,699),11,MUTED)
	if game.charging:
		panel(Rect2(430,646,247,6),Color("2e444a"),3)
		panel(Rect2(430,646,247*game.charge,6),ACCENT,3)
	if game.lab_mode:
		text_at("COLLISION LAB  /  merges disabled, no spill limit",Vector2(300,155),13,ACCENT)
	if game.paused or game.game_over:
		panel(Rect2(295,286,520,213),Color(0.045,0.075,0.09,0.96),20)
		text_at("BOWL FULL" if game.game_over else "TAKE A BREATHER",Vector2(355,350),31)
		text_at("A sphere escaped. Your score: %d" % game.score if game.game_over else "Your squishy little world is on hold.",Vector2(355,390),17,MUTED)
		text_at("Press R to start a new bowl." if game.game_over else "Press P or the Resume button to continue.",Vector2(355,439),14,ACCENT)
