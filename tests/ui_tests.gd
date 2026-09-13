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
	check(not game.smart_trajectory,"Normal pass-through trajectory is the default")
	var count: int=game.sim.balls.size()
	game.toss()
	check(game.sim.balls.size()==count,"Main menu cannot throw into its backdrop")
	game.open_options()
	check(game.screen==game.Screen.OPTIONS and game.hud.modal_blocker.visible,"Main menu opens shared options modal")
	check(game.hud.performance_buttons.ball_detail.visible and game.hud.option_tabs[0].text=="Performance" and not game.hud.sliders.throw_speed.visible,"Options contains performance controls without development tabs")
	game.close_options()
	check(game.screen==game.Screen.MENU,"Options returns to the main menu")
	game.open_dev_tweaks()
	check(game.screen==game.Screen.MENU,"Dev tweaks is only opened from Pause")
	game.restart()
	game.toggle_pause()
	game.hud.pause_controls.get_child(2).pressed.emit()
	check(game.screen==game.Screen.DEV_TWEAKS and game.paused and game.hud.option_tabs[0].visible and not game.hud.performance_buttons.ball_detail.visible,"Pause opens a separate Dev tweaks modal with both development tabs")
	game.hud.option_tabs[1].pressed.emit()
	check(game.hud.sliders.throw_speed.visible and not game.hud.sliders.weight_scale.visible,"Throw and camera tab reveals its own controls")
	check(game.hud.smart_button.visible and game.hud.smart_button.text.ends_with("OFF"),"Throw and camera options show Smart trajectory off")
	game.hud.smart_button.pressed.emit()
	check(game.smart_trajectory and game.hud.smart_button.text.ends_with("ON"),"Smart trajectory can be enabled from Dev tweaks")
	game.hud.sliders.min_elevation.value=10
	game.hud.sliders.max_elevation.value=45
	game.hud.sliders.trajectory_speed.value=60
	game.hud.sliders.throw_speed.value=8
	game.hud.sliders.camera_height.value=55
	game.hud.sliders.camera_offset.value=-30
	var tuned_camera: Transform3D=game.camera.transform
	check(is_equal_approx(game._launch_velocity().length(),8.0),"Launch speed updates the actual throw velocity")
	game.hud.option_tabs[0].pressed.emit()
	check(game.hud.sliders.weight_scale.visible and not game.hud.sliders.throw_speed.visible,"Material tab keeps gameplay sliders hidden")
	game.hud.sliders.weight_scale.value=2.0
	game.hud.sliders.rotation_speed.value=100.0
	var masses_updated := true
	for ball in game.sim.balls:
		if not is_equal_approx(ball.mass,ball.base_mass*2): masses_updated=false
	check(masses_updated,"Weight updates mass of every existing body")
	game.hud.lab_button.pressed.emit()
	game.hud.slow_button.pressed.emit()
	check(game.lab_mode and not game.sim.merges_enabled and not game.sim.spill_enabled,"Collision lab disables merging and spill loss")
	check(game.slow_motion,"Dev tweaks toggles quarter-speed simulation")
	game.close_options()
	check(game.screen==game.Screen.PAUSE,"Dev tweaks returns to Pause")
	game.show_main_menu()
	game.hud.menu_controls.get_child(0).pressed.emit()
	check(game.screen==game.Screen.PLAY and not game.paused,"Play starts a fresh round")
	check(game.lab_mode and game.slow_motion and game.sim.weight_scale==2,"Starting a round preserves chosen options")
	check(game.rotation_speed==100.0,"Starting a round preserves the rotation speed selected in Dev tweaks")
	check(game.smart_trajectory,"Starting a round preserves Smart trajectory selection")
	game._process(0)
	game.hud._process(0)
	check(not game.hud.aim_groups[0].visible and game.hud.aim_groups[1].visible,"Smart mode hides occluded guide sections")
	check(game.min_elevation==10 and game.max_elevation==45 and game.throw_speed==8 and game.trajectory_speed==60 and game.camera_height==55 and game.camera_offset==-30,"New rounds preserve throw and camera settings")
	var throw_angle: float=game.throw_elevation
	Input.parse_input_event(key_event(KEY_W,true))
	Input.flush_buffered_events()
	game._process(0.1)
	Input.parse_input_event(key_event(KEY_W,false))
	Input.flush_buffered_events()
	check(is_equal_approx(game.throw_elevation-throw_angle,6),"W/S uses the selected trajectory adjustment speed")
	game.adjust_elevation(1000)
	check(game.throw_elevation==45,"Custom maximum trajectory clamps keyboard input")
	game.adjust_elevation(-1000)
	check(game.throw_elevation==10,"Custom minimum trajectory clamps keyboard input")
	game.set_play_option("min_elevation",70)
	check(game.min_elevation==40 and game.throw_elevation==40,"Crossing trajectory limits preserves a five-degree range and clamps the current shot")
	game.set_play_option("max_elevation",-30)
	check(game.max_elevation==45,"Maximum trajectory cannot cross below minimum")
	var initial_angle: float=game.angle
	Input.parse_input_event(key_event(KEY_D,true))
	Input.flush_buffered_events()
	game._process(0.25)
	Input.parse_input_event(key_event(KEY_D,false))
	Input.flush_buffered_events()
	check(is_equal_approx(game.angle-initial_angle,deg_to_rad(25)),"Rotation input uses the speed selected in Dev tweaks")
	var side_distance: float=absf(game.camera.basis.x.dot(game.launch))
	game.orbit(1.7)
	check(side_distance>1.5 and is_equal_approx(absf(game.camera.basis.x.dot(game.launch)),side_distance),"Camera keeps the throw visibly to one side throughout rotation")
	check(is_equal_approx(game.sim.balls[0].mass,game.sim.balls[0].base_mass*2),"New bodies inherit current weight")
	game.set_performance_option("ball_detail",0)
	game.reset_dev_tweaks()
	check(game.ball_detail==0,"Resetting Dev tweaks preserves performance settings")
	game.reset_options()
	game._process(0)
	game.hud._process(0)
	check(not game.smart_trajectory and game.hud.aim_groups[0].visible and is_equal_approx(game.hud.aim_groups[0].self_modulate.a,0.18),"Reset restores pass-through mode with occluded sections at eighteen percent opacity")
	check(game.min_elevation==-12 and game.max_elevation==68 and game.throw_speed==6.4 and game.trajectory_speed==32 and game.camera_height==37.5 and game.camera_offset==20,"Defaults restore every throw and camera setting")
	check(not game.camera.transform.is_equal_approx(tuned_camera),"Camera tuning affects its transform")
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
	game.open_dev_tweaks()
	game._unhandled_input(click)
	game._unhandled_input(key_event(KEY_SPACE,true))
	game._physics_process(0.1)
	check(game.sim.balls.size()==count and game.sim.balls[0].center==before,"Dev tweaks blocks throws and keeps physics paused")
	game.hud.option_tabs[1].pressed.emit()
	game.toggle_pause()
	check(game.screen==game.Screen.PAUSE,"Escape closes Dev tweaks back to Pause")
	game.open_options()
	game.close_options()
	game.open_dev_tweaks()
	check(game.hud.option_page==1 and game.hud.sliders.throw_speed.visible,"Dev tweaks remembers its tab independently of Options")
	game.close_options()
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
	check(not game.hud.merge_stars.is_empty() and game.hud.merge_stars[0].at==merge_at,"Star burst originates at the world-space merge location")
	game.hud._process(0.5)
	game.toggle_pause()
	game.hud._process(0.5)
	check(game.hud.score_popups[0].time==0.5,"Pause freezes floating score animation")
	check(game.hud.merge_stars[0].time==0.5,"Pause freezes the star burst")
	game.toggle_pause()
	game.hud._process(1)
	check(game.hud.score_popups.is_empty(),"Floating scores expire after rising and fading")
	check(game.hud.merge_stars.is_empty(),"Merge stars expire after their burst")
	game.toggle_pause()
	game.hud.pause_controls.get_child(3).pressed.emit()
	count=game.sim.balls.size()
	check(game.screen==game.Screen.CONFIRM_RESET and game.score==40,"New bowl asks before resetting the current score")
	game._unhandled_input(click)
	game._unhandled_input(key_event(KEY_SPACE,true))
	game._physics_process(1)
	check(game.sim.balls.size()==count and game.score==40,"Reset warning freezes the round and blocks throws")
	game.hud.reset_controls.get_child(0).pressed.emit()
	check(game.screen==game.Screen.PAUSE and game.score==40 and game.sim.balls.size()==count,"Cancel keeps the current bowl intact")
	game.request_new_bowl()
	game.toggle_pause()
	check(game.screen==game.Screen.PAUSE and game.score==40,"Escape cancels the reset warning")
	game.request_new_bowl()
	game.hud.reset_controls.get_child(1).pressed.emit()
	check(game.screen==game.Screen.PLAY and game.score==0 and game.sim.balls.size()==3,"Confirming New bowl resets the round")
	var ball: SoftBall=game.sim.balls[0]
	ball.points[0]+=Vector3(0.04,-0.08,0.03)
	ball.update_center()
	ball.update_visual()
	check(ball.core_instance.mesh==ball.mesh_instance.mesh and ball.core_instance.scale==Vector3.ONE*SoftBall.CORE_SCALE and ball.mesh_instance.position==ball.center,"Cell layers share the deformed mesh and remain centered together")
	game.game_over=true
	game.set_screen(game.Screen.GAME_OVER)
	game.hud.end_controls.get_child(0).pressed.emit()
	check(game.screen==game.Screen.CONFIRM_RESET,"New bowl also warns after game over")
	game.cancel_new_bowl()
	check(game.screen==game.Screen.GAME_OVER,"Cancel returns to the game-over screen")
	game.open_options()
	game.toggle_lab()
	game.close_options()
	check(game.screen==game.Screen.PAUSE and not game.game_over,"Enabling collision lab can recover an ended round")
	game.show_main_menu()
	check(game.screen==game.Screen.MENU and game.hud.menu_controls.visible,"Main menu can be reopened")
	game.reset_dev_tweaks()
	game.game_over=true
	game.open_options()
	game.toggle_lab()
	game.close_options()
	check(game.screen==game.Screen.MENU,"Lab toggle from the main menu keeps the correct return screen")
	game.free()
	_test_throw_preview()
	_test_materials()
	print("UI / MATERIAL RESULT: ",checks-failures,"/",checks," passed")
	quit(0 if failures==0 else 1)

func _test_throw_preview() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.restart()
	game.sim.clear()
	var valid := true
	for speed in [2.0,6.4,12.0]:
		game.throw_speed=speed
		for pitch in [-35.0,24.0,80.0]:
			game.throw_elevation=pitch
			var velocity: Vector3=game._launch_velocity()
			var preview := AimPreview.trace(game.sim,game.launch,velocity,SoftBall.RADII[game.queue[0]])
			var end: Vector3=preview.point
			var surface: float=0.075*(end.x*end.x+end.z*end.z) if Vector2(end.x,end.z).length()<4.23 else game.sim.floor_height
			if not preview.hit or not end.is_finite() or absf(end.y-surface)>0.001: valid=false
	check(valid,"Preview finds finite surface contacts across the launch-speed and trajectory ranges")
	game.throw_elevation=24.0
	var velocity: Vector3=game._launch_velocity()
	valid=true
	for height in [20.0,70.0]:
		for offset in [-65.0,0.0,65.0]:
			game.set_play_option("camera_height",height)
			game.set_play_option("camera_offset",offset)
			if not game.camera.transform.is_finite() or not game._launch_velocity().is_equal_approx(velocity): valid=false
	check(valid,"Extreme camera settings stay finite and leave the throw direction unchanged")
	game.free()

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
