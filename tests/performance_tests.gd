extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(passed: bool,label: String) -> void:
	checks+=1
	if not passed: failures+=1
	print("PASS: " if passed else "FAIL: ",label)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.set_process(false)
	game.open_options()
	check(game.hud.performance_buttons.ball_detail.visible and not game.hud.smart_button.visible and not game.hud.sliders.weight_scale.visible,"Options shows performance without development controls")
	var ball: SoftBall=game.sim.balls[0]
	var points := ball.points.duplicate()
	var previous := ball.previous.duplicate()
	for detail in [0,1,2,0,2]:
		game.set_performance_option("ball_detail",detail)
		check(ball.mesh_instance.mesh.surface_get_array_len(0)==[42,162,642][detail] and ball.render_indices.size()==80*3*int(pow(4,detail)),"Detail %d rebuilds the expected mesh without accumulating topology" % detail)
	check(ball.points==points and ball.previous==previous,"Changing visual detail preserves soft-body geometry and momentum")
	game.hud.performance_buttons.ball_detail.pressed.emit()
	check(game.ball_detail==0,"Ball detail button cycles from High to Low")
	game.set_performance_option("visual_rate",30)
	game.set_performance_option("shadows_enabled",false)
	game.set_performance_option("antialiasing",0)
	game.set_performance_option("merge_effects",1)
	game.set_performance_option("show_fps",true)
	check(not game.key_light.shadow_enabled and root.msaa_3d==Viewport.MSAA_DISABLED,"Shadows and edge smoothing update the renderer immediately")
	game.restart()
	ball=game.sim.balls[0]
	check(game.visual_rate==30 and not game.shadows_enabled and game.show_fps and ball.render_detail==0 and ball.mesh_instance.mesh.surface_get_array_len(0)==42,"New bowls preserve performance settings and new balls inherit detail")
	game.visual_elapsed=0.0
	game.visual_dirty=true
	var mesh := ball.mesh_instance.mesh
	game._process(1.0/60.0)
	check(ball.mesh_instance.mesh==mesh,"30 Hz animation avoids an unnecessary mesh rebuild at 60 Hz")
	game._process(1.0/60.0)
	check(ball.mesh_instance.mesh!=mesh,"30 Hz animation refreshes when its interval elapses")
	mesh=ball.mesh_instance.mesh
	game.toggle_pause()
	game._process(1.0)
	check(ball.mesh_instance.mesh==mesh,"Paused unchanged bodies do not rebuild their meshes")
	game.hud.show_merge_stars(Vector3.ZERO,2)
	check(game.hud.merge_stars.size()==6,"Reduced effects generate half as many stars")
	game.set_performance_option("merge_effects",0)
	game.hud.show_merge_stars(Vector3.ZERO,2)
	game.hud.show_score(Vector3.ZERO,40,Color.WHITE)
	check(game.hud.merge_stars.is_empty() and game.hud.score_popups.size()==1,"Effects Off removes stars while retaining score feedback")
	game.set_play_option("throw_speed",8.0)
	game.reset_options()
	check(game.throw_speed==8.0,"Resetting Options preserves development tweaks")
	check(game.ball_detail==2 and game.sim.render_detail==2 and game.visual_rate==60 and game.key_light.shadow_enabled and root.msaa_3d==Viewport.MSAA_4X and game.merge_effects==2 and not game.show_fps,"Reset defaults restores all performance controls and renderer state")
	# Rendering detail must not change the solver's result.
	var high := SoftSimulation.new()
	var low := SoftSimulation.new()
	low.render_detail=0
	for sim in [high,low]:
		sim.spawn(2,Vector3(0,1.1,0))
		sim.spawn(0,Vector3(0.15,2.2,0))
		for frame in 40: sim.step(1.0/60.0)
	check(high.balls[0].points==low.balls[0].points and high.balls[1].points==low.balls[1].points,"High and Low detail produce identical simulated collisions")
	game.free()
	print("PERFORMANCE RESULT: ",checks-failures,"/",checks," passed")
	quit(0 if failures==0 else 1)
