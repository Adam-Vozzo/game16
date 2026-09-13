extends Node3D

enum Screen { MENU, PLAY, PAUSE, OPTIONS, GAME_OVER }
const MATERIALS := [[0.22,0.008,0.045],[0.30,0.003,0.12],[0.10,0.004,0.085]]
const MIN_ELEVATION := -12.0
const MAX_ELEVATION := 68.0
const THROW_SPEED := 6.4
var screen := Screen.MENU
var options_return := Screen.MENU
var sim := SoftSimulation.new()
var camera: Camera3D
var hud: Control
var queue: Array[int] = [0,1,0]
var rng := RandomNumberGenerator.new()
var score := 0
var paused: bool:
	get: return screen!=Screen.PLAY
var game_over := false
var lab_mode := false
var slow_motion := false
var material_index := 2
var angle := 0.22
var zoom := 11.8
var target := Vector3(0,0.65,0)
var launch := Vector3.ZERO
var throw_elevation := 24.0
var cooldown := 0.0
var held: MeshInstance3D
var target_ring: MeshInstance3D
var trajectory: Array[MeshInstance3D] = []
var effects: Array[Dictionary] = []
var sound: AudioStreamPlayer
var screenshot_frame := -1
var frame := 0
var demo := false
var demo_timer := 0.0
var simulation_accumulator := 0.0
var capture_name := "prototype"

func _ready() -> void:
	rng.randomize()
	_build_stage()
	sim.visual_parent = self
	sim.merged.connect(_on_merge)
	sim.spilled.connect(func(): game_over=true; set_screen(Screen.GAME_OVER))
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = load("res://scripts/hud.gd").new()
	hud.game = self
	layer.add_child(hud)
	sound = AudioStreamPlayer.new()
	sound.volume_db = -16
	add_child(sound)
	set_material(material_index)
	restart()
	# Settle the decorative bowl once before showing the main menu.
	for i in 100: sim.step(1.0/60.0)
	set_screen(Screen.MENU)
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo": demo=true
		if arg.begins_with("--capture-name="): capture_name=arg.get_slice("=",1).validate_filename()
		if arg.begins_with("--capture-frame="): screenshot_frame=int(arg.get_slice("=",1))
	if demo:
		rng.seed=16
		restart()
	if "--options" in OS.get_cmdline_user_args(): open_options()

func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0e1b23")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8d8df")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.5
	environment.environment = env
	add_child(environment)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	camera.far = 100
	add_child(camera)
	_update_camera()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-53,-30,0)
	light.light_color = Color("fff3dc")
	light.light_energy = 0.65
	light.shadow_enabled = true
	light.light_angular_distance = 1.5
	light.directional_shadow_max_distance = 30
	add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-5,6,-3)
	fill.light_color = Color("96c9d5")
	fill.light_energy = 0.45
	fill.omni_range = 15
	add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	ground.mesh = plane
	ground.position.y = -0.72
	ground.material_override = SoftGeometry.material(Color("132730"),0.86)
	add_child(ground)
	var pedestal := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.8
	cylinder.bottom_radius = 2.95
	cylinder.height = 0.48
	cylinder.radial_segments = 96
	pedestal.mesh = cylinder
	pedestal.position.y = -0.48
	pedestal.material_override = SoftGeometry.material(Color("243d45"),0.65)
	add_child(pedestal)
	var bowl := MeshInstance3D.new()
	bowl.mesh = SoftGeometry.bowl_mesh()
	var mat := SoftGeometry.material(Color("9cbbba"),0.29)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bowl.material_override = mat
	add_child(bowl)
	var rim := _ring(4.2,0.035,Color("c4d7cf"))
	rim.position.y = 1.323
	add_child(rim)
	var foot_ring := _ring(2.95,0.012,Color("547777"))
	foot_ring.position.y = -0.69
	add_child(foot_ring)
	held = MeshInstance3D.new()
	add_child(held)
	target_ring = _ring(0.27,0.015,Color("d3ecd0"))
	add_child(target_ring)
	for i in 22:
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.024 if i%3 else 0.036
		sphere.height = sphere.radius*2
		sphere.radial_segments = 8
		sphere.rings = 4
		dot.mesh = sphere
		var dot_mat := SoftGeometry.material(Color("c3dec3"))
		dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dot.material_override = dot_mat
		add_child(dot)
		trajectory.append(dot)
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _ring(radius: float,thickness: float,color: Color) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius-thickness
	torus.outer_radius = radius+thickness
	torus.rings = 96
	torus.ring_segments = 8
	result.mesh = torus
	result.material_override = SoftGeometry.material(color)
	return result

func set_screen(value: Screen) -> void:
	screen=value
	_update_camera()
	if is_instance_valid(hud): hud.sync_screen()

func open_options() -> void:
	if screen==Screen.OPTIONS: return
	options_return=screen
	set_screen(Screen.OPTIONS)

func close_options() -> void:
	set_screen(options_return)

func show_main_menu() -> void:
	set_screen(Screen.MENU)

func restart() -> void:
	sim.clear()
	score=0
	game_over=false
	throw_elevation=24.0
	simulation_accumulator=0
	cooldown=0.3
	sim.spill_enabled=not lab_mode
	queue.assign([0,1,0])
	for effect in effects: effect.node.queue_free()
	effects.clear()
	hud.clear_scores()
	sim.spawn(2,Vector3(-0.7,1.3,-0.65))
	sim.spawn(1,Vector3(0.95,1.0,0.1))
	sim.spawn(0,Vector3(-1.25,0.9,0.65))
	_update_held()
	set_screen(Screen.PLAY)

func _update_held() -> void:
	var sphere := SphereMesh.new()
	sphere.radius=SoftBall.RADII[queue[0]]
	sphere.height=sphere.radius*2
	sphere.radial_segments=32
	sphere.rings=16
	held.mesh=sphere
	held.material_override=SoftGeometry.material(SoftBall.COLORS[queue[0]],0.31)

func _update_camera() -> void:
	camera.position=Vector3(sin(angle)*15,12,cos(angle)*15)
	camera.look_at(Vector3(0,0.5,0))
	var menu_backdrop := screen==Screen.MENU or (screen==Screen.OPTIONS and options_return==Screen.MENU)
	camera.position+=camera.basis.x*(-3.55 if menu_backdrop else 0.0)
	camera.size=13.5 if menu_backdrop else zoom
	launch=Vector3(sin(angle)*5.05,3.25,cos(angle)*5.05)

func orbit(amount: float) -> void:
	angle+=amount
	_update_camera()

func _input(event: InputEvent) -> void:
	# Escape works even while a slider has keyboard focus.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_P]:
		toggle_pause()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if paused: return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT and event.pressed: toss()
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom=clampf(zoom-0.5,10.5,17)
			_update_camera()
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom=clampf(zoom+0.5,10.5,17)
			_update_camera()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE: toss()

func adjust_elevation(amount: float) -> void:
	throw_elevation=clampf(throw_elevation+amount,MIN_ELEVATION,MAX_ELEVATION)

func _launch_velocity() -> Vector3:
	var pitch := deg_to_rad(throw_elevation)
	return Vector3(-sin(angle),0,-cos(angle))*cos(pitch)*THROW_SPEED+Vector3.UP*sin(pitch)*THROW_SPEED

func _landing_time(velocity: Vector3) -> float:
	# Intersect the ballistic center path with the bowl profile plus ball radius.
	var origin_xz := Vector2(launch.x,launch.z)
	var speed_xz := Vector2(velocity.x,velocity.z)
	var a := -sim.gravity*0.5-0.075*speed_xz.length_squared()
	var b := velocity.y-0.15*origin_xz.dot(speed_xz)
	var c := launch.y-0.075*origin_xz.length_squared()-SoftBall.RADII[queue[0]]
	return maxf(0.05,(-b-sqrt(maxf(0,b*b-4*a*c)))/(2*a))

func toss() -> void:
	if paused or game_over or cooldown>0: return
	if sim.balls.size() >= SoftSimulation.MAX_BALLS:
		hud.show_notice("Lab capacity reached. Start a new bowl from Pause.")
		return
	sim.spawn(queue.pop_front(),launch,_launch_velocity())
	queue.append(rng.randi_range(0,2) if rng.randf()>0.4 else 0)
	_update_held()
	cooldown=0.65
	_tone(220,0.08)

func toggle_pause() -> void:
	match screen:
		Screen.PLAY: set_screen(Screen.PAUSE)
		Screen.PAUSE: set_screen(Screen.PLAY)
		Screen.OPTIONS: close_options()

func toggle_lab() -> void:
	lab_mode=not lab_mode
	sim.merges_enabled=not lab_mode
	sim.spill_enabled=not lab_mode
	if lab_mode and game_over:
		game_over=false
		if screen==Screen.OPTIONS and options_return==Screen.GAME_OVER: options_return=Screen.PAUSE
		if screen==Screen.GAME_OVER: set_screen(Screen.PAUSE)

func set_material(index: int) -> void:
	material_index=index
	var values: Array = MATERIALS[index]
	sim.stiffness=values[0]
	sim.recovery=values[1]
	sim.damping=values[2]
	hud.sync_options()

func reset_options() -> void:
	sim.weight_scale=1.0
	sim.gravity=9.8
	sim.bowl_grip=0.065
	slow_motion=false
	if lab_mode: toggle_lab()
	set_material(2)

func _physics_process(delta: float) -> void:
	if not paused and not game_over:
		simulation_accumulator+=delta*(0.25 if slow_motion else 1.0)
		while simulation_accumulator>=1.0/60.0 and not paused:
			sim.step(1.0/60.0)
			simulation_accumulator-=1.0/60.0

func _process(delta: float) -> void:
	frame+=1
	if not paused:
		cooldown=maxf(0,cooldown-delta)
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): orbit(-delta*0.9)
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): orbit(delta*0.9)
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): adjust_elevation(delta*32)
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): adjust_elevation(-delta*32)
	for ball in sim.balls: ball.update_visual()
	held.position=launch
	var show_aim := screen==Screen.PLAY or screen==Screen.PAUSE or (screen==Screen.OPTIONS and options_return==Screen.PAUSE)
	held.visible=show_aim and not game_over and cooldown<=0
	var velocity := _launch_velocity()
	var flight := _landing_time(velocity)
	for i in trajectory.size():
		var t := flight*(i+1)/float(trajectory.size())
		trajectory[i].position=launch+velocity*t+Vector3.DOWN*sim.gravity*t*t*0.5
		trajectory[i].visible=show_aim and not game_over
	target=launch+velocity*flight+Vector3.DOWN*sim.gravity*flight*flight*0.5
	target_ring.visible=show_aim and not game_over
	target_ring.position=Vector3(target.x,0.075*(target.x*target.x+target.z*target.z)+0.04,target.z)
	for i in range(effects.size()-1,-1,-1):
		if not paused: effects[i].time+=delta
		var effect: Dictionary=effects[i]
		var node: MeshInstance3D=effect.node
		node.scale=Vector3.ONE*(1+effect.time*3)
		if not paused: node.position.y+=delta*0.5
		node.transparency=minf(1,effect.time*1.6)
		if effect.time>0.6:
			node.queue_free()
			effects.remove_at(i)
	if demo and not paused and not game_over:
		demo_timer+=delta
		if demo_timer>1.0:
			demo_timer=0
			orbit(rng.randf_range(-0.5,0.5))
			throw_elevation=rng.randf_range(5,48)
			toss()
	if screenshot_frame>0 and frame==screenshot_frame:
		_capture.call_deferred()

func _on_merge(at: Vector3,tier: int,points_awarded: int) -> void:
	score+=points_awarded
	hud.show_score(at,points_awarded,SoftBall.COLORS[tier])
	var ring := _ring(SoftBall.RADII[tier]*0.7,0.035,SoftBall.COLORS[tier])
	add_child(ring)
	ring.position=at
	effects.append({"node":ring,"time":0.0})
	_tone(330*pow(1.18,tier),0.18)

func _tone(frequency: float,duration: float) -> void:
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	var data := PackedByteArray()
	data.resize(int(22050*duration)*2)
	for i in data.size()/2:
		var t := i/22050.0
		var envelope := sin(PI*t/duration)*exp(-t*12)
		var sample := sin(TAU*frequency*t+0.3*sin(TAU*frequency*0.5*t))*envelope
		data.encode_s16(i*2,int(sample*16000))
	stream.data=data
	sound.stream=stream
	sound.play()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://captures")
	get_viewport().get_texture().get_image().save_png("res://captures/%s.png" % capture_name)
	print("CAPTURE_SAVED frame=",frame," balls=",sim.balls.size()," score=",score)
	get_tree().quit()
