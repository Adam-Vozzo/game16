extends SceneTree

var checks := 0
var failures := 0

func check(passed: bool,label: String) -> void:
	checks+=1
	if not passed: failures+=1
	print("PASS: " if passed else "FAIL: ",label)

func _initialize() -> void:
	var sim := SoftSimulation.new()
	sim.bowl_enabled=false
	sim.floor_height=-100
	sim.gravity=0
	sim.merges_enabled=false
	var obstacle := sim.spawn(3,Vector3.ZERO)
	var origin := Vector3(0,0,4)
	var velocity := Vector3(0,0,-6.4)
	var before := obstacle.points.duplicate()
	var result := AimPreview.trace(sim,origin,velocity,SoftBall.RADII[0])
	check(result.hit and result.ball==obstacle,"Preview detects the first ball instead of continuing to the bowl")
	check(result.center.z>obstacle.radius and result.point.z>0.7 and result.normal.z>0.8,"Impact center accounts for the thrown radius and marker lies on the hit shell")
	check(obstacle.points==before and obstacle.age==0 and sim.balls.size()==1,"Preview leaves the live simulation unchanged")
	var through := AimPreview.trace(sim,origin,velocity,SoftBall.RADII[0],false)
	check(not through.hit and through.ball==null and through.center.z<0,"Normal trajectory continues through the ball without predicting its collision")
	var incoming := sim.spawn(0,origin,velocity)
	for frame in 120:
		sim.step(1.0/60.0)
		if sim.contacts_this_step>0: break
	check(incoming.center.distance_to(result.center)<0.06,"Predicted contact agrees with a live stationary-body collision")
	sim.clear()
	var far := sim.spawn(3,Vector3(0,0,-3))
	var near := sim.spawn(2,Vector3(0,0,1))
	result=AimPreview.trace(sim,origin,velocity,SoftBall.RADII[0])
	check(result.ball==near and result.ball!=far,"Nearest contact wins regardless of collection order")
	sim.clear()
	obstacle=sim.spawn(3,Vector3.ZERO)
	var round := AimPreview.trace(sim,Vector3(4,0,0),Vector3(-6.4,0,0),SoftBall.RADII[0])
	for i in obstacle.points.size(): obstacle.points[i]*=Vector3(0.3,1.0,1.6)
	obstacle.update_center()
	result=AimPreview.trace(sim,Vector3(4,0,0),Vector3(-6.4,0,0),SoftBall.RADII[0])
	check(result.center.x<round.center.x-0.35,"Preview follows a squashed shell instead of its bounding sphere")
	check(AimPreview.occluded(Vector3(0,0,-3),Vector3.BACK,sim.balls),"Trajectory behind a ball is hidden")
	check(AimPreview.occluded(Vector3.ZERO,Vector3.BACK,sim.balls),"Trajectory inside a deformed ball is classified as occluded")
	check(not AimPreview.occluded(Vector3(0,0,3),Vector3.BACK,sim.balls),"Trajectory in front of a ball stays visible")
	check(not AimPreview.occluded(Vector3(0.65,0,-3),Vector3.BACK,sim.balls),"Occlusion respects the deformed silhouette")
	sim.clear()
	sim.gravity=9.8
	sim.bowl_enabled=true
	sim.floor_height=-3
	result=AimPreview.trace(sim,Vector3(0,3,0),Vector3.ZERO,SoftBall.RADII[0])
	check(result.hit and result.ball==null and absf(result.point.y)<0.001,"Empty-bowl marker lies on the actual bowl surface")
	check(absf(result.center.y-SoftBall.RADII[0]-AimPreview.SKIN)<0.002,"Bowl contact accounts for the thrown shell and solver margin")
	sim.spawn(3,Vector3(0,1.2,0))
	through=AimPreview.trace(sim,Vector3(0,3,0),Vector3.ZERO,SoftBall.RADII[0],false)
	check(through.ball==null and through.point.is_equal_approx(result.point) and through.center.is_equal_approx(result.center),"Normal mode keeps the same bowl endpoint with or without a pile")
	sim.bowl_enabled=false
	sim.floor_height=-100
	sim.gravity=0
	result=AimPreview.trace(sim,Vector3(0,3,0),Vector3.RIGHT,SoftBall.RADII[0])
	check(not result.hit and result.path.size()==721,"An unobstructed flight has a bounded preview without a false impact")
	print("AIM RESULT: ",checks-failures,"/",checks," passed")
	quit(0 if failures==0 else 1)
