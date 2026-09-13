class_name SoftGeometry
extends RefCounted
## Closed, welded icosphere: 42 particles, 80 faces, 120 structural edges.

static func cage() -> Dictionary:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var vertices := PackedVector3Array([
		Vector3(-1,t,0),Vector3(1,t,0),Vector3(-1,-t,0),Vector3(1,-t,0),
		Vector3(0,-1,t),Vector3(0,1,t),Vector3(0,-1,-t),Vector3(0,1,-t),
		Vector3(t,0,-1),Vector3(t,0,1),Vector3(-t,0,-1),Vector3(-t,0,1)])
	for i in vertices.size(): vertices[i] = vertices[i].normalized()
	var faces := PackedInt32Array([0,11,5,0,5,1,0,1,7,0,7,10,0,10,11,1,5,9,5,11,4,11,10,2,10,7,6,7,1,8,3,9,4,3,4,2,3,2,6,3,6,8,3,8,9,4,9,5,2,4,11,6,2,10,8,6,7,9,8,1])
	var cache := {}
	var refined := PackedInt32Array()
	for f in range(0,faces.size(),3):
		var a := faces[f]
		var b := faces[f+1]
		var c := faces[f+2]
		var mids: Array[int] = []
		for edge in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
			var key := Vector2i(mini(edge.x,edge.y),maxi(edge.x,edge.y))
			if not cache.has(key):
				cache[key] = vertices.size()
				vertices.append((vertices[key.x]+vertices[key.y]).normalized())
			mids.append(cache[key])
		refined.append_array(PackedInt32Array([a,mids[0],mids[2],b,mids[1],mids[0],c,mids[2],mids[1],mids[0],mids[1],mids[2]]))
	var edges := PackedVector2Array()
	cache.clear()
	for f in range(0,refined.size(),3):
		for j in 3:
			var a := refined[f+j]
			var b := refined[f+(j+1)%3]
			var key := Vector2i(mini(a,b),maxi(a,b))
			if not cache.has(key):
				cache[key] = true
				edges.append(Vector2(key.x,key.y))
	return {"vertices":vertices,"faces":refined,"edges":edges}

static func material(color: Color, roughness: float = 0.38) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

static func cell_shell(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://shaders/cell_shell.gdshader")
	mat.set_shader_parameter("tint",color)
	return mat

static func cell_core(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://shaders/cell_core.gdshader")
	mat.set_shader_parameter("tint",color)
	return mat

static func bowl_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Cross section travels from inner center, over a thick lip, to outer base.
	var section: Array[Vector2] = [Vector2(0,0)]
	for i in range(1,25):
		var r := 4.2 * i / 24.0
		section.append(Vector2(r,0.075*r*r))
	section.append(Vector2(4.29,1.32))
	section.append(Vector2(4.34,1.23))
	for i in range(24,-1,-1):
		var r := 4.2 * i / 24.0
		section.append(Vector2(r,0.075*r*r-0.20))
	for j in range(section.size()-1):
		for i in 128:
			var a := TAU*i/128.0
			var b := TAU*(i+1)/128.0
			var p := Vector3(cos(a)*section[j].x,section[j].y,sin(a)*section[j].x)
			var q := Vector3(cos(b)*section[j].x,section[j].y,sin(b)*section[j].x)
			var r := Vector3(cos(a)*section[j+1].x,section[j+1].y,sin(a)*section[j+1].x)
			var s := Vector3(cos(b)*section[j+1].x,section[j+1].y,sin(b)*section[j+1].x)
			for v in [p,q,r,q,s,r]: st.add_vertex(v)
	st.generate_normals()
	return st.commit()
