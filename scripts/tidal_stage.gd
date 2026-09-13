class_name TidalStage
extends RefCounted

static func decorate(parent: Node3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed=831
	var sphere := SphereMesh.new()
	sphere.radial_segments=12
	sphere.rings=6
	sphere.radius=1.0
	sphere.height=2.0
	var rocks := MultiMesh.new()
	rocks.transform_format=MultiMesh.TRANSFORM_3D
	rocks.use_colors=true
	rocks.mesh=sphere
	rocks.instance_count=84
	for i in 84:
		var theta := TAU*i/84.0+random.randf_range(-0.025,0.025)
		var size := random.randf_range(0.10,0.23)
		var basis := Basis.from_euler(Vector3(random.randf(),theta,random.randf())).scaled(Vector3(size*1.3,size*0.7,size))
		var radial := random.randf_range(4.26,4.4)
		rocks.set_instance_transform(i,Transform3D(basis,Vector3(cos(theta)*radial,1.29+random.randf_range(-0.03,0.03),sin(theta)*radial)))
		rocks.set_instance_color(i,Color("293149").lerp(Color("514364"),random.randf()*0.7))
	var rock_material := SoftGeometry.material(Color.WHITE,0.6)
	rock_material.vertex_color_use_as_albedo=true
	rock_material.vertex_color_is_srgb=true
	_instance(parent,rocks,rock_material)
	# Small blunt coral branches stay outside the playable rim.
	var branches := MultiMesh.new()
	branches.transform_format=MultiMesh.TRANSFORM_3D
	branches.use_colors=true
	branches.mesh=sphere
	branches.instance_count=48
	for i in 48:
		var cluster := i/6
		var theta := TAU*cluster/8.0+0.23
		var spread := random.randf_range(-0.2,0.2)
		var at := Vector3(cos(theta+spread)*4.46,1.25,sin(theta+spread)*4.46)
		var height := random.randf_range(0.12,0.28)
		var basis := Basis.from_euler(Vector3(spread,theta,spread)).scaled(Vector3(0.045,height,0.055))
		branches.set_instance_transform(i,Transform3D(basis,at+Vector3.UP*height*0.6))
		branches.set_instance_color(i,Color("7678a7").lerp(Color("c887b6"),random.randf()))
	var coral_material := SoftGeometry.material(Color.WHITE,0.46)
	coral_material.vertex_color_use_as_albedo=true
	coral_material.vertex_color_is_srgb=true
	_instance(parent,branches,coral_material)

static func _instance(parent: Node3D,multimesh: MultiMesh,material: Material) -> void:
	var node := MultiMeshInstance3D.new()
	node.multimesh=multimesh
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
