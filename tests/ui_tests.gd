extends SceneTree
## Exercise menu transitions, modal isolation, throwing, popups, and live tuning.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(passed: bool,label: String) -> void:
	checks+=1
	if not passed: failures+=1
	print("PASS: " if passed else "FAIL: ",label)

func key_event(code: Key,pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	return event

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.set_process(false)
	check(game.screen==game.Screen.MENU and game.paused,"Startup shows main menu with simulation paused")
	check(game.material_index==2 and is_equal_approx(game.sim.stiffness,0.1),"Dough remains the default")
	var count: int=game.sim.balls.size()
	game.toss()
	check(game.sim.balls.size()==count,"Main menu cannot throw into its backdrop")
	game.open_options()
	check(game.screen==game.Screen.OPTIONS and game.hud.modal_blocker.visible,"Main menu opens shared options modal")
	game.hud.sliders.weight_scale.value=2.0
	game.hud.sliders.rotation_speed.value=100.0
	var masses_updated := true
	for ball in game.sim.balls:
		if not is_equal_approx(ball.mass,ball.base_mass*2): masses_updated=false
	check(masses_updated,"Weight updates mass of every existing body")
	game.hud.lab_button.pressed.emit()
	game.hud.slow_button.pressed.emit()
	check(game.lab_mode and not game.sim.merges_enabled and not game.sim.spill_enabled,"Collision lab disables merging and spill loss")
	check(game.slow_motion,"Options toggles quarter-speed simulation")
	game.close_options()
	check(game.screen==game.Screen.MENU,"Options returns to the main menu when opened there")
	game.hud.menu_controls.get_child(0).pressed.emit()
	check(game.screen==game.Screen.PLAY and not game.paused,"Play starts a fresh round")
	check(game.lab_mode and game.slow_motion and game.sim.weight_scale==2,"Starting a round preserves chosen options")
	check(game.rotation_speed==100.0,"Starting a round preserves the rotation speed selected in Options")
	var initial_angle: float=game.angle
	Input.parse_input_event(key_event(KEY_D,true))
	Input.flush_buffered_events()
	game._process(0.25)
	Input.parse_input_event(key_event(KEY_D,false))
	Input.flush_buffered_events()
	check(is_equal_approx(game.angle-initial_angle,deg_to_rad(25)),"Rotation input uses the speed selected in Options")
	var side_distance: float=absf(game.camera.basis.x.dot(game.launch))
	game.orbit(1.7)
	check(side_distance>1.5 and is_equal_approx(absf(game.camera.basis.x.dot(game.launch)),side_distance),"Camera keeps the throw visibly to one side throughout rotation")
	check(is_equal_approx(game.sim.balls[0].mass,game.sim.balls[0].base_mass*2),"New bodies inherit current weight")
	game.reset_options()
	check(game.rotation_speed==game.DEFAULT_ROTATION_SPEED and game.hud.sliders.rotation_speed.value==game.DEFAULT_ROTATION_SPEED,"Reset defaults restores rotation speed and its slider")
	check(not game.lab_mode and not game.slow_motion and game.sim.weight_scale==1 and game.sim.gravity==9.8 and game.sim.bowl_grip==0.065,"Reset defaults restores material and lab settings")
	var gameplay_camera: Transform3D=game.camera.transform
	game.toggle_pause()
	var before: Vector3=game.sim.balls[0].center
	game._physics_process(0.1)
	check(game.paused and game.sim.balls[0].center==before,"Pause freezes physics")
	game.open_options()
	Input.parse_input_event(key_event(KEY_A,true))
	Input.flush_buffered_events()
	game._process(0.25)
	Input.parse_input_event(key_event(KEY_A,false))
	Input.flush_buffered_events()
	check(game.camera.transform.is_equal_approx(gameplay_camera),"Pause and Options preserve the camera angle and block rotation")
	count=game.sim.balls.size()
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	game._unhandled_input(click)
	game._unhandled_input(key_event(KEY_SPACE,true))
	check(game.sim.balls.size()==count,"Options blocks click and keyboard throws")
	game.toggle_pause()
	check(game.screen==game.Screen.PAUSE,"Escape from in-game options returns to Pause")
	game.toggle_pause()
	check(game.screen==game.Screen.PLAY,"Resume returns to gameplay")
	var pitch: float=game.throw_elevation
	Input.parse_input_event(key_event(KEY_W,true))
	Input.flush_buffered_events()
	game._process(0.25)
	Input.parse_input_event(key_event(KEY_W,false))
	Input.flush_buffered_events()
	check(game.throw_elevation>pitch,"Holding W raises the trajectory")
	pitch=game.throw_elevation
	Input.parse_input_event(key_event(KEY_S,true))
	Input.flush_buffered_events()
	game._process(0.25)
	Input.parse_input_event(key_event(KEY_S,false))
	Input.flush_buffered_events()
	check(game.throw_elevation<pitch,"Holding S lowers the trajectory")
	game.adjust_elevation(1000)
	check(game.throw_elevation==game.MAX_ELEVATION,"Trajectory has a safe upper limit")
	game.adjust_elevation(-1000)
	check(game.throw_elevation==game.MIN_ELEVATION,"Trajectory has a safe lower limit")
	game.throw_elevation=24
	var launch_velocity: Vector3=game._launch_velocity()
	var motion := InputEventMouseMotion.new()
	motion.position=Vector2(100,100)
	motion.relative=Vector2(300,100)
	game._unhandled_input(motion)
	check(game._launch_velocity()==launch_velocity,"Mouse movement no longer changes aim")
	game.cooldown=0
	count=game.sim.balls.size()
	game._unhandled_input(click)
	check(game.sim.balls.size()==count+1,"Mouse press throws immediately")
	click.pressed=false
	game._unhandled_input(click)
	game._process(1)
	check(game.sim.balls.size()==count+1,"Release and holding time do not create or charge another shot")
	game._unhandled_input(key_event(KEY_SPACE,true))
	check(game.sim.balls.size()==count+2,"Space press throws immediately")
	var repeat := key_event(KEY_SPACE,true)
	repeat.echo=true
	game.cooldown=0
	game._unhandled_input(repeat)
	check(game.sim.balls.size()==count+2,"Key repeat cannot auto-fire")
	var merge_at := Vector3(1,2,3)
	game._on_merge(merge_at,2,40)
	check(game.score==40 and game.hud.score_popups.size()==1 and game.hud.score_popups[0].at==merge_at,"Merge score popup starts at the world-space merge location")
	game.hud._process(0.5)
	game.toggle_pause()
	game.hud._process(0.5)
	check(game.hud.score_popups[0].time==0.5,"Pause freezes floating score animation")
	game.toggle_pause()
	game.hud._process(1)
	check(game.hud.score_popups.is_empty(),"Floating scores expire after rising and fading")
	game.toggle_pause()
	game.hud.pause_controls.get_child(2).pressed.emit()
	check(game.screen==game.Screen.PLAY and game.score==0 and game.sim.balls.size()==3,"New bowl from pause resets the round")
	game.game_over=true
	game.set_screen(game.Screen.GAME_OVER)
	game.open_options()
	game.toggle_lab()
	game.close_options()
	check(game.screen==game.Screen.PAUSE and not game.game_over,"Enabling collision lab can recover an ended round")
	game.show_main_menu()
	check(game.screen==game.Screen.MENU and game.hud.menu_controls.visible,"Main menu can be reopened")
	game.reset_options()
	game.game_over=true
	game.open_options()
	game.toggle_lab()
	game.close_options()
	check(game.screen==game.Screen.MENU,"Lab toggle from the main menu keeps the correct return screen")
	game.free()
	_test_materials()
	print("UI / MATERIAL RESULT: ",checks-failures,"/",checks," passed")
	quit(0 if failures==0 else 1)

func _test_materials() -> void:
	var centers: Array[float]=[]
	for weight in [0.25,3.0]:
		var sim := SoftSimulation.new()
		sim.bowl_enabled=false
		sim.spill_enabled=false
		sim.merges_enabled=false
		sim.floor_height=0
		sim.weight_scale=weight
		var ball := sim.spawn(3,Vector3(0,2,0))
		for frame in 180: sim.step(1.0/60.0)
		centers.append(ball.center.y)
		check(ball.center.is_finite() and absf(ball.volume()/ball.rest_volume-1)<0.2,"Weight %.2fx stays stable under gravity" % weight)
	check(centers[1]<centers[0]-0.01,"Heavier material compresses more under its own load")
	var falls: Array[float]=[]
	for weight in [0.25,3.0]:
		var sim := SoftSimulation.new()
		sim.bowl_enabled=false
		sim.floor_height=-100
		sim.weight_scale=weight
		var ball := sim.spawn(0,Vector3(0,10,0))
		for frame in 15: sim.step(1.0/60.0)
		falls.append(ball.center.y)
	check(absf(falls[0]-falls[1])<0.001,"Weight does not change free-fall acceleration")
