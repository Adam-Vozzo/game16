class_name AimPreview
extends RefCounted
## A read-only first-contact estimate against the current soft-body pile.
## Uses the solver's shell support test and airborne timestep; no world mutation.

const DT := 1.0/180.0
const SKIN := 0.018

static func trace(sim: SoftSimulation,origin: Vector3,velocity: Vector3,radius: float) -> Dictionary:
	var offsets := PackedVector3Array()
	for vertex in sim.topology.vertices: offsets.append(vertex*radius)
	var path := PackedVector3Array([origin])
	var at := origin
	for step in 720:
		velocity=velocity*0.999+Vector3.DOWN*sim.gravity*DT
		var next := at+velocity*DT
		var fraction := 2.0
		var hit_ball: SoftBall
		for ball in sim.balls:
			if not ball.alive or not _touches_ball(next,offsets,radius,ball): continue
			var low := 0.0
			var high := 1.0
			for refinement in 8:
				var mid := (low+high)*0.5
				if _touches_ball(at.lerp(next,mid),offsets,radius,ball): high=mid
				else: low=mid
			if high<fraction:
				fraction=high
				hit_ball=ball
		if not _environment_contact(next,offsets,sim).is_empty():
			var low := 0.0
			var high := 1.0
			for refinement in 8:
				var mid := (low+high)*0.5
				if not _environment_contact(at.lerp(next,mid),offsets,sim).is_empty(): high=mid
				else: low=mid
			if high<fraction:
				fraction=high
				hit_ball=null
		if fraction<=1.0:
			var center := at.lerp(next,fraction)
			path.append(center)
			var contact := _ball_surface(center,hit_ball) if hit_ball else _environment_contact(center,offsets,sim)
			return {"path":path,"center":center,"point":contact.point,"normal":contact.normal,"ball":hit_ball,"hit":true}
		at=next
		path.append(at)
	return {"path":path,"center":at,"point":at,"normal":Vector3.UP,"ball":null,"hit":false}

static func _touches_ball(at: Vector3,offsets: PackedVector3Array,radius: float,ball: SoftBall) -> bool:
	var delta := ball.center-at
	if delta.length_squared()>pow(radius+ball.bound+0.08,2): return false
	var normal := delta.normalized() if delta.length_squared()>0.000001 else Vector3.RIGHT
	var support := -INF
	var surface := INF
	for offset in offsets: support=maxf(support,offset.dot(normal))
	for point in ball.points: surface=minf(surface,(point-at).dot(normal))
	return support-surface+SKIN>=0.0

static func _environment_contact(at: Vector3,offsets: PackedVector3Array,sim: SoftSimulation) -> Dictionary:
	var depth := -INF
	var result := {}
	for offset in offsets:
		var point := at+offset
		var height := sim.floor_height
		var normal := Vector3.UP
		if sim.bowl_enabled and Vector2(point.x,point.z).length()<4.23 and point.y> -0.4:
			height=0.075*(point.x*point.x+point.z*point.z)
			normal=Vector3(-0.15*point.x,1,-0.15*point.z).normalized()
		var penetration := height+SKIN-point.y
		if penetration>=0.0 and penetration>depth:
			depth=penetration
			result={"point":Vector3(point.x,height,point.z),"normal":normal}
	return result

static func _ball_surface(from: Vector3,ball: SoftBall) -> Dictionary:
	var direction := (ball.center-from).normalized()
	var distance := INF
	var result := {"point":ball.center-direction*ball.radius,"normal":-direction}
	for face in range(0,ball.faces.size(),3):
		var a := ball.points[ball.faces[face]]
		var b := ball.points[ball.faces[face+1]]
		var c := ball.points[ball.faces[face+2]]
		var hit: Variant=Geometry3D.ray_intersects_triangle(from,direction,a,b,c)
		if hit!=null and from.distance_squared_to(hit)<distance:
			distance=from.distance_squared_to(hit)
			result={"point":hit,"normal":(b-a).cross(c-a).normalized()}
	return result

static func occluded(point: Vector3,toward_camera: Vector3,balls: Array[SoftBall]) -> bool:
	# Orthographic camera rays are parallel. Test the actual cage, not its opaque core.
	for ball in balls:
		if not ball.alive: continue
		var delta := ball.center-point
		var along := delta.dot(toward_camera)
		if along+ball.bound<0.0: continue
		if (delta-toward_camera*along).length_squared()>ball.bound*ball.bound: continue
		for face in range(0,ball.faces.size(),3):
			var hit: Variant=Geometry3D.ray_intersects_triangle(point+toward_camera*0.025,toward_camera,ball.points[ball.faces[face]],ball.points[ball.faces[face+1]],ball.points[ball.faces[face+2]])
			if hit!=null: return true
	return false
