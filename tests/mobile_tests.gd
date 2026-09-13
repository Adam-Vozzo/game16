extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS: " if ok else "FAIL: ",text)
func run() -> void:
	root.size=Vector2i(390,844)
	root.content_scale_size=root.size
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.mobile_mode=true
	game.restart()
	await process_frame
	var ui: Control=game.hud.mobile_ui
	ui.layout_zones()
	check(ui.visible and not game.hud.play_controls.visible,"Phone uses the mobile HUD instead of scaled desktop controls")
	var fit := true
	for rect in ui.zones.values(): fit=fit and rect.size.x>=44 and rect.size.y>=44 and Rect2(Vector2.ZERO,ui.size).encloses(rect)
	check(fit,"Portrait controls fit and exceed 44-pixel touch targets")
	var angle: float=game.angle
	var elevation: float=game.throw_elevation
	ui.pointer_down(0,ui.zones.right.get_center())
	ui.pointer_down(1,ui.zones.raise.get_center())
	ui.apply_holds(0.2)
	check(game.angle>angle and game.throw_elevation>elevation,"Two fingers rotate and adjust trajectory simultaneously")
	ui.pointer_up(0,ui.zones.right.get_center())
	angle=game.angle
	elevation=game.throw_elevation
	ui.apply_holds(0.2)
	check(game.angle==angle and game.throw_elevation>elevation,"Releasing rotation leaves the other finger's trajectory hold active")
	ui.release_all()
	game.cooldown=0
	var count: int=game.sim.balls.size()
	ui.pointer_down(2,ui.zones.toss.get_center())
	ui.apply_holds(2)
	check(game.sim.balls.size()==count,"Holding Toss does not charge or repeat throws")
	ui.pointer_up(2,ui.zones.toss.get_center())
	check(game.sim.balls.size()==count+1,"Releasing Toss produces exactly one ball")
	ui.pointer_up(2,ui.zones.toss.get_center())
	check(game.sim.balls.size()==count+1,"Duplicate release cannot throw again")
	game.cooldown=0
	ui.pointer_down(3,ui.zones.toss.get_center())
	ui.pointer_up(3,ui.zones.toss.get_center(),true)
	check(game.sim.balls.size()==count+1,"Canceled touch never throws")
	ui.pointer_down(4,ui.zones.left.get_center())
	var drag := InputEventScreenDrag.new()
	drag.index=4
	drag.position=Vector2(100,100)
	ui._input(drag)
	check(ui.pointers.is_empty(),"Sliding off a control cancels its hold")
	var touch := InputEventScreenTouch.new()
	touch.index=5
	touch.position=ui.zones.toss.get_center()
	touch.pressed=true
	ui._input(touch)
	touch.pressed=false
	ui._input(touch)
	check(game.sim.balls.size()==count+2,"Real screen-touch events route to the toss control")
	game.cooldown=0
	var mouse := InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	mouse.device=InputEvent.DEVICE_ID_EMULATION
	game._unhandled_input(mouse)
	check(game.sim.balls.size()==count+2,"Touch-emulated mouse and bowl taps cannot accidentally toss")
	ui.pointer_down(6,ui.zones.right.get_center())
	game.toggle_pause()
	angle=game.angle
	ui.apply_holds(1)
	check(ui.pointers.is_empty() and game.angle==angle,"Pause releases holds and blocks movement")
	game.open_options()
	check(ui.buttons.has("ball_detail") and ui.menu.visible,"Phone options expose working performance controls")
	ui.buttons.ball_detail.pressed.emit()
	check(game.ball_detail==0,"Mobile performance button updates the game")
	game.hud.option_page=4
	ui.sync_screen()
	ui.values.ball_glow.slider.value=2.0
	check(game.ball_glow==2.0 and ui.values.bloom_intensity.slider.editable==game.desktop_effects,"Phone Effects controls apply supported settings")
	game.close_options()
	game.toggle_pause()
	ui.pointer_down(7,ui.zones.raise.get_center())
	root.size=Vector2i(844,390)
	root.content_scale_size=root.size
	game.mobile_mode=true
	game.hud.sync_screen()
	await process_frame
	ui.layout_zones()
	fit=true
	for rect in ui.zones.values(): fit=fit and rect.size.y>=44 and Rect2(Vector2.ZERO,ui.size).encloses(rect)
	check(fit and ui.pointers.is_empty(),"Landscape controls fit and resizing clears held touches")
	game.mobile_mode=false
	root.content_scale_size=Vector2i(1440,900)
	game.hud.sync_screen()
	check(not ui.visible and game.hud.play_controls.visible,"Leaving the breakpoint restores desktop controls")
	game.free()
	print("MOBILE RESULT: ",checks-failures,"/",checks," passed")
	quit(0 if failures==0 else 1)
