class_name SoftSimulation
extends RefCounted
## Fixed 180 Hz particle integration; structural/volume constraints and two-way
## deformable contact patches. The COM axis is an approximate contact normal,
## appropriate for these convex, sphere-like bodies (not arbitrary concave meshes).

signal merged(at: Vector3, tier: int, points_awarded: int)
signal spilled

const SUBSTEPS := 3
const ITERATIONS := 2
const MAX_BALLS := 44
var topology := SoftGeometry.cage()
var balls: Array[SoftBall] = []
var stiffness := 0.10
var recovery := 0.004
var damping := 0.085
var gravity := 9.8
var merges_enabled := true
var bowl_enabled := true
var spill_enabled := true
var floor_height := -3.0
var contacts_this_step := 0
var visual_parent: Node3D

func spawn(tier: int, at: Vector3, velocity: Vector3 = Vector3.ZERO) -> SoftBall:
	var ball := SoftBall.new(tier,at,velocity,topology)
	balls.append(ball)
	if is_instance_valid(visual_parent): ball.create_visual(visual_parent)
	return ball

func clear() -> void:
	for ball in balls: ball.dispose()
	balls.clear()

func step(delta: float) -> void:
	var dt := delta/SUBSTEPS
	contacts_this_step = 0
	for ball in balls: ball.age += delta
	for substep in SUBSTEPS:
		for ball in balls: ball.integrate(dt,gravity,damping)
		for iteration in ITERATIONS:
			for ball in balls:
				ball.constrain(stiffness,recovery)
				_environment(ball)
			for a in balls.size():
				for b in range(a+1,balls.size()):
					var first := balls[a]
					var second := balls[b]
					if not first.alive or not second.alive: continue
					if first.center.distance_squared_to(second.center) > pow(first.bound+second.bound+0.08,2): continue
					if _contact(first,second):
						contacts_this_step += 1
						if merges_enabled and first.tier == second.tier and first.tier < SoftBall.RADII.size()-1 and minf(first.age,second.age) > 0.22:
							first.alive = false
							second.alive = false
							_merge(first,second)
		# Defer all mutation of the active collection until pair iteration finishes.
		for ball in balls: ball.finish_substep()
		_flush_merges()
		for ball in balls: ball.update_center()
	for ball in balls:
		if ball.center.y < -0.6 and Vector2(ball.center.x,ball.center.z).length() > 4.15 and ball.age > 1.6:
			ball.escaped_time += delta
		else: ball.escaped_time = 0.0
		if spill_enabled and ball.escaped_time > 0.65:
			spill_enabled = false
			spilled.emit()

var pending_merges: Array[Dictionary] = []

func _merge(a: SoftBall,b: SoftBall) -> void:
	pending_merges.append({"a":a,"b":b,"at":(a.center+b.center)*0.5,"velocity":(a.velocity+b.velocity)*0.5,"tier":a.tier+1})

func _flush_merges() -> void:
	for merge in pending_merges:
		balls.erase(merge.a)
		balls.erase(merge.b)
		merge.a.dispose()
		merge.b.dispose()
		var child := spawn(merge.tier,merge.at,merge.velocity)
		# The larger shell can initially intersect supports and adjacent balls.
		# Let it de-penetrate without converting that correction into a launch.
		child.merge_settle_remaining=SoftBall.MERGE_SETTLE_SECONDS
		child.age = 0.0
		merged.emit(merge.at,merge.tier,10*(1 << merge.tier))
	pending_merges.clear()

func _environment(ball: SoftBall) -> void:
	for i in ball.points.size():
		var p := ball.points[i]
		var radial := Vector2(p.x,p.z).length()
		var height := floor_height
		var normal := Vector3.UP
		if bowl_enabled and radial < 4.23 and p.y > -0.4:
			height = 0.075*radial*radial
			normal = Vector3(-0.15*p.x,1,-0.15*p.z).normalized()
		if p.y < height+0.018:
			var penetration := (height+0.018-p.y)*normal.y
			ball.points[i] += normal*penetration
			var motion := ball.points[i]-ball.previous[i]
			var tangent := motion-normal*motion.dot(normal)
			ball.previous[i] += tangent*0.065

func _contact(a: SoftBall,b: SoftBall) -> bool:
	var offset := b.center-a.center
	var distance := offset.length()
	var normal := offset/distance if distance > 0.00001 else Vector3.RIGHT
	var max_a := -INF
	var min_b := INF
	for p in a.points: max_a = maxf(max_a,p.dot(normal))
	for p in b.points: min_b = minf(min_b,p.dot(normal))
	var overlap := max_a-min_b+0.018
	if overlap <= 0.0: return false
	# Protect direct neighbours too, so the new shell cannot kick the pile apart.
	# Do not propagate the timer: ordinary collisions resume after the birth window.
	if a.merge_settle_remaining>0.0 or b.merge_settle_remaining>0.0:
		a.stabilize_this_substep=true
		b.stabilize_this_substep=true
	# Resolve a patch of shell vertices against a shared separating plane.
	# Equal/opposite corrections conserve the pair's mass-weighted center.
	var plane := (max_a*b.mass+min_b*a.mass)/(a.mass+b.mass)
	var correction_a := PackedFloat32Array()
	var correction_b := PackedFloat32Array()
	var sum_a := 0.0
	var sum_b := 0.0
	for p in a.points:
		var depth := maxf(0.0,p.dot(normal)-plane+0.009)
		correction_a.append(depth)
		sum_a += depth
	for p in b.points:
		var depth := maxf(0.0,plane-p.dot(normal)+0.009)
		correction_b.append(depth)
		sum_b += depth
	var balance := (sum_a*a.mass-sum_b*b.mass)/(a.mass+b.mass)/a.points.size()
	for i in a.points.size(): a.points[i] += normal*(balance-correction_a[i])*0.9
	for i in b.points.size(): b.points[i] += normal*(balance+correction_b[i])*0.9
	return true
