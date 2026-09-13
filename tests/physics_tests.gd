extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures.append(label)
		printerr("FAIL: ",label)
	else: print("PASS: ",label)

func tick(sim: SoftSimulation,count: int) -> void:
	for i in count: sim.step(1.0/60.0)

func free_sim() -> SoftSimulation:
	var sim := SoftSimulation.new()
	sim.gravity=0
	sim.floor_height=-100
	sim.bowl_enabled=false
	sim.spill_enabled=false
	sim.merges_enabled=false
	return sim

func deformation(ball: SoftBall) -> float:
	var result := 0.0
	for p in ball.points: result=maxf(result,absf(p.distance_to(ball.center)-ball.radius)/ball.radius)
	return result

func run() -> void:
	var sim := free_sim()
	var ball := sim.spawn(2,Vector3.ZERO)
	check(ball.points.size()==42 and ball.faces.size()==240,"Closed 42-particle cage / 80 triangles")
	check(ball.rest_volume>0,"Consistent outward winding and positive volume")
	tick(sim,120)
	check(deformation(ball)<0.01,"Unloaded body retains its rest shape")
	check(ball.center.length()<0.001,"Internal constraints do not translate a resting body")

	sim=free_sim()
	var a := sim.spawn(1,Vector3(-0.85,0,0),Vector3(3,0,0))
	var b := sim.spawn(2,Vector3(0.85,0,0),Vector3(-1.5,0,0))
	var peak := 0.0
	var contact_frames := 0
	for i in 100:
		sim.step(1.0/60.0)
		peak=maxf(peak,maxf(deformation(a),deformation(b)))
		if sim.contacts_this_step>0: contact_frames+=1
	check(contact_frames>0,"Different tiers make physical contact")
	check(sim.balls.size()==2,"Different tiers never merge")
	check(peak>0.04,"Impact physically deforms shell by more than 4 percent")
	check(a.center.x<b.center.x,"Head-on bodies do not pass through one another")
	tick(sim,400)
	check(deformation(a)<peak*0.6,"Body recovers after resistance is removed")
	check(absf(a.volume()/a.rest_volume-1)<0.15,"Volume is retained after a collision")
	print("Collision peak deformation=",snappedf(peak,0.001)," recovery=",snappedf(deformation(a),0.001))

	sim=free_sim()
	sim.merges_enabled=true
	a=sim.spawn(0,Vector3(-0.39,0,0))
	b=sim.spawn(0,Vector3(0.39,0,0))
	a.age=1
	b.age=1
	tick(sim,2)
	check(sim.balls.size()==1 and sim.balls[0].tier==1,"Matching pair merges exactly once into next tier")
	check(sim.pending_merges.is_empty(),"Merge queue drains without stale bodies")

	sim=free_sim()
	sim.merges_enabled=true
	for i in 3:
		var item := sim.spawn(0,Vector3((i-1)*0.68,0,0))
		item.age=1
	tick(sim,1)
	check(sim.balls.size()==2,"Three-body contact consumes each parent at most once")

	sim=free_sim()
	sim.merges_enabled=true
	a=sim.spawn(7,Vector3(-1.97,0,0))
	b=sim.spawn(7,Vector3(1.97,0,0))
	a.age=1
	b.age=1
	tick(sim,20)
	check(sim.balls.size()==2,"Maximum tier remains physical without indexing past tier table")

	sim=SoftSimulation.new()
	sim.merges_enabled=false
	sim.spill_enabled=false
	for i in 15:
		sim.spawn(i%4,Vector3(sin(i*2.4)*1.6,1.5+i*0.75,cos(i*2.4)*1.6))
	var start := Time.get_ticks_msec()
	tick(sim,360)
	var finite := true
	var retained := 0
	var max_error := 0.0
	for item in sim.balls:
		if not item.center.is_finite() or item.bound>5: finite=false
		if item.center.y>0: retained+=1
		max_error=maxf(max_error,absf(item.volume()/item.rest_volume-1))
	check(finite,"15-body drop and stack stays finite over 6 seconds")
	check(retained>=13,"Bowl catches and retains the mixed-tier pile")
	check(max_error<0.35,"Loaded pile preserves useful volume")
	print("Stack: ",Time.get_ticks_msec()-start," ms / 360 ticks; retained=",retained," max volume error=",snappedf(max_error,0.001))

	sim=free_sim()
	a=sim.spawn(0,Vector3.ZERO,Vector3(3,0,0))
	sim.step(1.0/60.0)
	var x := a.center.x
	sim.step(1.0/240.0)
	check(a.center.x-x<0.02,"Slow motion rescales existing particle velocity")

	sim=SoftSimulation.new()
	var spills: Array[int]=[0]
	sim.spilled.connect(func(): spills[0]+=1)
	a=sim.spawn(0,Vector3(6,-1,0))
	a.age=2
	tick(sim,100)
	check(spills[0]==1,"Escaped body triggers exactly one game-over event")
	sim.clear()
	check(sim.balls.is_empty(),"Restart releases the simulation bodies")
	print("RESULT: ",checks-failures.size(),"/",checks," passed")
	quit(0 if failures.is_empty() else 1)
