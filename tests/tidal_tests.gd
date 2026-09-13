extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS: " if ok else "FAIL: ",label)
func visible_lights(game: Node3D) -> int:
	var count := 0
	for lamp in game.tidal.lamps:
		if lamp.visible: count+=1
	return count
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.set_process(false)
	game.restart()
	for i in 12: game.sim.spawn(i%8,Vector3(i*0.1,2,0))
	game.set_performance_option("lighting_quality",2)
	game.tidal.update(0.1)
	check(visible_lights(game)==game.tidal.lamps.size() and game.tidal.lamps.size()<=8,"A crowded pile respects the fixed platform light budget")
	game.set_performance_option("lighting_quality",1)
	game.tidal.update(0)
	check(visible_lights(game)==game.tidal.lamps.size()/2,"Reduced lighting halves the active light budget")
	game.set_performance_option("lighting_quality",0)
	game.tidal.update(0)
	check(visible_lights(game)==0,"Living lights Off disables every pooled lamp")
	game.set_performance_option("lighting_quality",2)
	var before: PackedVector3Array=game.sim.balls[0].points.duplicate()
	game.tidal.burst(Vector3(1,2,3),3)
	game.tidal.update(0.1)
	check(game.tidal.lamps[0].position==Vector3(1,2.3,3) and game.sim.balls[0].points==before,"Merge pulse lights the merge position without moving bodies")
	game.toggle_pause()
	var time: float=game.tidal.time
	var age: float=game.tidal.pulses[0].age
	game.tidal.update(2)
	check(game.tidal.time==time and game.tidal.pulses[0].age==age,"Pause freezes filaments, caustics and merge light pulses")
	game.toggle_pause()
	game.tidal.update(1)
	check(game.tidal.pulses.is_empty(),"Merge lights expire")
	game.tidal.burst(Vector3.ZERO,1)
	game.restart()
	check(game.tidal.pulses.is_empty(),"New bowl clears merge light effects")
	var ball: SoftBall=game.sim.balls[0]
	var pattern := ball.render_colors.duplicate()
	for i in ball.points.size(): ball.points[i]*=Vector3(1.2,0.7,1.1)
	ball.update_center()
	ball.update_visual()
	check(ball.render_colors==pattern and ball.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR].size()==642,"Filament coordinates remain attached to the deforming cage")
	ball.set_render_detail(0)
	check(ball.render_colors.size()==42 and ball.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR].size()==42,"Low detail retains valid filament coordinates")
	game.toggle_pause()
	game.open_options()
	game.hud.option_tabs[1].pressed.emit()
	check(game.hud.performance_buttons.sss_enabled.visible and not game.hud.sliders.stiffness.visible,"Tidal lighting controls remain separate from Dev tweaks")
	game.set_performance_option("sss_enabled",true)
	game.set_performance_option("bloom_enabled",true)
	check(game.sss_enabled==game.desktop_effects and game.environment_settings.glow_enabled==game.desktop_effects,"Scattering and bloom are enabled only with Forward+")
	check(game.hud.performance_buttons.sss_enabled.disabled==not game.desktop_effects,"Unsupported desktop effects are clearly disabled in Compatibility")
	game.set_performance_option("sss_enabled",false)
	game.set_performance_option("bloom_enabled",false)
	check(not game.sss_enabled and not game.environment_settings.glow_enabled,"Desktop scattering and bloom can be switched off independently")
	game.free()
	print("TIDAL RESULT: ",checks-failures,"/",checks," passed")
	quit(0 if failures==0 else 1)
