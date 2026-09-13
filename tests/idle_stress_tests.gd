extends SceneTree
## A real-time, fixed-ball-count run; use Compatibility to exercise the web renderer.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(440,956)
	root.content_scale_size=root.size
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.mobile_mode=true
	game.apply_mobile_defaults()
	game.restart()
	var start := Time.get_ticks_msec()
	var snapshots: Array[Dictionary]=[]
	var last_meshes: Array=[]
	for ball in game.sim.balls: last_meshes.append(ball.mesh_instance.mesh.get_instance_id())
	var mesh_uploads := 0
	var next_sample := 10
	while Time.get_ticks_msec()-start<65000:
		await process_frame
		for i in game.sim.balls.size():
			var id: int=game.sim.balls[i].mesh_instance.mesh.get_instance_id()
			if id!=last_meshes[i]: mesh_uploads+=1; last_meshes[i]=id
		var elapsed := (Time.get_ticks_msec()-start)/1000.0
		if elapsed>=next_sample:
			var sample := {"seconds":next_sample,"balls":game.sim.balls.size(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"meshes_uploaded":mesh_uploads,"trajectory_traces":game.aim_trace_count,"fps":Engine.get_frames_per_second()}
			snapshots.append(sample)
			print("IDLE SAMPLE: ",JSON.stringify(sample))
			next_sample+=20
	var first: Dictionary=snapshots.front()
	var last: Dictionary=snapshots.back()
	var valid: bool=game.sim.balls.size()==3 and last.objects<=first.objects+20 and last.resources<=first.resources+10 and last.trajectory_traces==first.trajectory_traces
	print("IDLE RESULT: ","PASS" if valid else "FAIL","; 65 seconds without throws or extra balls")
	root.get_texture().get_image().save_png("res://captures/mobile-performance.png")
	quit(0 if valid else 1)
