class_name SoftBall
extends RefCounted
## A volumetric particle body. Rendering and contact use these same particles.
## No rigid sphere collision proxy or canned squash animation.

const COLORS: Array[Color] = [Color("7ed9ad"),Color("ffad87"),Color("a6a0ef"),Color("f1cf75"),Color("7bc7e8"),Color("e58caf"),Color("b3d77b"),Color("f28076")]
const RADII: Array[float] = [0.39,0.49,0.62,0.78,0.98,1.24,1.56,1.97]

var tier: int
var radius: float
var mass: float
var points := PackedVector3Array()
var previous := PackedVector3Array()
var rest := PackedVector3Array()
var faces := PackedInt32Array()
var edges := PackedVector2Array()
var lengths := PackedFloat32Array()
var gradients := PackedVector3Array()
var center := Vector3.ZERO
var velocity := Vector3.ZERO
var rest_volume: float
var bound: float
var age := 0.0
var previous_dt := 1.0/180.0
var escaped_time := 0.0
var alive := true
var mesh_instance: MeshInstance3D
var render_edges := PackedVector2Array()
var render_indices := PackedInt32Array()

func _init(level: int, origin: Vector3, initial_velocity: Vector3, topology: Dictionary) -> void:
	tier = clampi(level,0,RADII.size()-1)
	radius = RADII[tier]
	mass = pow(radius/RADII[0],3.0)
	faces = topology.faces
	edges = topology.edges
	for v in topology.vertices:
		rest.append(v*radius)
		points.append(origin+v*radius)
		previous.append(origin+v*radius-initial_velocity/180.0)
	center = origin
	velocity = initial_velocity
	bound = radius
	for e in edges: lengths.append(rest[int(e.x)].distance_to(rest[int(e.y)]))
	gradients.resize(points.size())
	rest_volume = volume()
	_build_render_topology()

func volume() -> float:
	var value := 0.0
	for f in range(0,faces.size(),3):
		value += (points[faces[f]]-center).dot((points[faces[f+1]]-center).cross(points[faces[f+2]]-center))/6.0
	return value

func update_center() -> void:
	center = Vector3.ZERO
	for p in points: center += p
	center /= points.size()
	bound = 0.0
	for p in points: bound = maxf(bound,p.distance_to(center))

func integrate(dt: float, gravity: float, damping: float) -> void:
	var mean_motion := Vector3.ZERO
	var time_ratio := dt/previous_dt
	for i in points.size(): mean_motion += (points[i]-previous[i])*time_ratio
	mean_motion /= points.size()
	velocity = mean_motion/dt
	# Damp internal motion strongly, translation very lightly; piles can still roll.
	for i in points.size():
		var motion := (points[i]-previous[i])*time_ratio
		var old := points[i]
		points[i] += mean_motion*0.999 + (motion-mean_motion)*(1.0-damping) + Vector3.DOWN*gravity*dt*dt
		previous[i] = old
	previous_dt = dt

func constrain(stiffness: float, recovery: float) -> void:
	# Distance constraints distribute a local dent through the shell.
	for e in edges.size():
		var a := int(edges[e].x)
		var b := int(edges[e].y)
		var delta := points[b]-points[a]
		var length := delta.length()
		if length > 0.00001:
			var correction := delta*((length-lengths[e])/length)*stiffness*0.5
			points[a] += correction
			points[b] -= correction
	update_center()
	# Signed closed-mesh volume constraint, using the actual per-vertex gradients.
	gradients.fill(Vector3.ZERO)
	var current_volume := 0.0
	for f in range(0,faces.size(),3):
		var a := faces[f]
		var b := faces[f+1]
		var c := faces[f+2]
		var p := points[a]-center
		var q := points[b]-center
		var r := points[c]-center
		current_volume += p.dot(q.cross(r))/6.0
		gradients[a] += q.cross(r)/6.0
		gradients[b] += r.cross(p)/6.0
		gradients[c] += p.cross(q)/6.0
	var denominator := 0.0
	for g in gradients: denominator += g.length_squared()
	if denominator > 0.0000001:
		var lambda := clampf((rest_volume-current_volume)/denominator,-radius,radius)*0.65
		for i in points.size(): points[i] += gradients[i]*lambda
	# Rotation-invariant radial recovery. Low enough for sustained contact dents.
	for i in points.size():
		var offset := points[i]-center
		var length := offset.length()
		if length > 0.00001:
			points[i] += offset/length*(radius-length)*recovery

func _build_render_topology() -> void:
	var cache := {}
	for f in range(0,faces.size(),3):
		var a := faces[f]
		var b := faces[f+1]
		var c := faces[f+2]
		var mids: Array[int] = []
		for edge in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
			var key := Vector2i(mini(edge.x,edge.y),maxi(edge.x,edge.y))
			if not cache.has(key):
				cache[key] = points.size()+render_edges.size()
				render_edges.append(Vector2(key.x,key.y))
			mids.append(cache[key])
		# Godot uses clockwise front faces; the simulation uses outward CCW faces.
		render_indices.append_array(PackedInt32Array([a,mids[2],mids[0],b,mids[0],mids[1],c,mids[1],mids[2],mids[0],mids[2],mids[1]]))

func create_visual(parent: Node3D) -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.material_override = SoftGeometry.material(COLORS[tier],0.31)
	parent.add_child(mesh_instance)
	update_visual()

func update_visual() -> void:
	if not is_instance_valid(mesh_instance): return
	var vertices := points.duplicate()
	for e in render_edges:
		var a := points[int(e.x)]
		var b := points[int(e.y)]
		var mid := (a+b)*0.5
		# Curved interpolation of the cage, with only a small surface offset.
		vertices.append(mid+(mid-center).normalized()*a.distance_to(b)*0.065)
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for f in range(0,render_indices.size(),3):
		var a := render_indices[f]
		var b := render_indices[f+1]
		var c := render_indices[f+2]
		var normal := (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for i in normals.size(): normals[i] = normals[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = render_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh_instance.mesh = mesh

func dispose() -> void:
	alive = false
	if is_instance_valid(mesh_instance): mesh_instance.queue_free()
