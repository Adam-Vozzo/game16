extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for preset in [[0.22,0.008,0.045],[0.30,0.003,0.12],[0.10,0.004,0.085]]:
		for tier in [0,3,5,6]:
			var sim := SoftSimulation.new()
			sim.stiffness=preset[0]
			sim.recovery=preset[1]
			sim.damping=preset[2]
			sim.bowl_enabled=false
			sim.floor_height=0
			sim.spill_enabled=false
			var radius := SoftBall.RADII[tier]
			var a := sim.spawn(tier,Vector3(-radius,radius,0))
			var b := sim.spawn(tier,Vector3(radius,radius,0))
			a.age=1
			b.age=1
			var peak_speed := 0.0
			var peak_height := 0.0
			for frame in 180:
				sim.step(1.0/60.0)
				for ball in sim.balls:
					if ball.tier==tier+1:
						peak_speed=maxf(peak_speed,ball.velocity.y)
						peak_height=maxf(peak_height,ball.center.y)
			var passed := sim.balls.size()==1 and peak_speed<1.0 and peak_height<SoftBall.RADII[tier+1]*1.25
			if not passed: failures+=1
			print("PASS" if passed else "FAIL"," rest merge tier=",tier," preset=",preset," peak upward speed=",snappedf(peak_speed,0.01)," height=",snappedf(peak_height,0.01))
	_test_crowded_merge()
	_test_airborne_merge()
	print("MERGE REGRESSIONS: ",failures," failures")
	quit(0 if failures==0 else 1)

func check(passed: bool,label: String) -> void:
	if not passed: failures+=1
	print("PASS" if passed else "FAIL"," ",label)

func _test_crowded_merge() -> void:
	var sim := SoftSimulation.new()
	sim.spill_enabled=false
	var radius := SoftBall.RADII[5]
	var a := sim.spawn(5,Vector3(-radius,1.5,0))
	var b := sim.spawn(5,Vector3(radius,1.5,0))
	a.age=1
	b.age=1
	var neighbours: Array[SoftBall]=[
		sim.spawn(3,Vector3(0,1.3,-1.95)),
		sim.spawn(4,Vector3(0,1.6,2.15)),
		sim.spawn(2,Vector3(0,3.4,0))]
	var peak_neighbour_speed := 0.0
	var peak_child_speed := 0.0
	for frame in 180:
		sim.step(1.0/60.0)
		for neighbour in neighbours: peak_neighbour_speed=maxf(peak_neighbour_speed,neighbour.velocity.y)
		for ball in sim.balls:
			if ball.tier==6: peak_child_speed=maxf(peak_child_speed,ball.velocity.y)
	check(sim.balls.size()==4,"Crowded bowl produces one merge without losing neighbours")
	check(peak_neighbour_speed<1.5 and peak_child_speed<1,"Crowded merge limits upward launch of both child and neighbours")
	var healthy := true
	for ball in sim.balls:
		if not ball.center.is_finite() or absf(ball.volume()/ball.rest_volume-1)>0.15: healthy=false
	check(healthy,"Crowded merge maintains finite positions and volume")
	print("Crowded peak upward speed: child=",peak_child_speed," neighbours=",peak_neighbour_speed)

func _test_airborne_merge() -> void:
	var sim := SoftSimulation.new()
	sim.gravity=0
	sim.bowl_enabled=false
	sim.floor_height=-100
	sim.spill_enabled=false
	var a := sim.spawn(1,Vector3(-0.49,5,0),Vector3(0,0,-3))
	var b := sim.spawn(1,Vector3(0.49,5,0),Vector3(0,0,-3))
	a.age=1
	b.age=1
	for frame in 6: sim.step(1.0/60.0)
	check(sim.balls.size()==1 and sim.balls[0].velocity.z< -2.8,"Airborne merge preserves genuine inherited travel")
	for frame in 36: sim.step(1.0/60.0)
	check(sim.balls[0].merge_settle_remaining==0 and not sim.balls[0].stabilize_this_substep,"Merge guard expires and ordinary physics resumes")
