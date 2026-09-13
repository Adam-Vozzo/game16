extends SceneTree
## Rebuild the shared boot artwork with Godot: --path . --script res://tools/generate_splash.gd
var art: Node2D
var font: Font = ThemeDB.fallback_font

func _initialize() -> void: call_deferred("generate")

func generate() -> void:
	root.size=Vector2i(1440,900)
	root.content_scale_size=Vector2i(1440,900)
	root.transparent_bg=true
	art=Node2D.new()
	root.add_child(art)
	art.draw.connect(paint)
	art.queue_redraw()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://assets")
	var result := root.get_texture().get_image().save_png("res://assets/tidal-splash.png")
	print("SPLASH ART: ",error_string(result))
	quit(result)

func label(text: String,y: float,size: int,color: Color,tracking: float=0.0) -> void:
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x+tracking*(text.length()-1)
	var x := (1440-width)*0.5
	for letter in text:
		art.draw_string(font,Vector2(x,y),letter,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
		x+=font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x+tracking

func cell(center: Vector2,radius: float,color: Color,tilt: float) -> void:
	art.draw_set_transform(center,tilt)
	# Layered translucent contours form a halo without external textures.
	for i in range(24,0,-1):
		art.draw_circle(Vector2.ZERO,radius+i*2.4,Color(color,0.006),true,-1,true)
	art.draw_circle(Vector2.ZERO,radius,Color(color,0.12),true,-1,true)
	for i in range(32,0,-1):
		var r := radius*0.85*float(i)/32.0
		art.draw_circle(Vector2(0,radius*0.025),r,Color(color,0.025),true,-1,true)
	art.draw_arc(Vector2.ZERO,radius,0,TAU,180,Color(color.lightened(0.45),0.6),1.7,true)
	art.draw_arc(Vector2.ZERO,radius*0.93,PI*1.06,PI*1.91,80,Color.WHITE*Color(1,1,1,0.45),1.0,true)
	# Curved canals run from pole to pole through the translucent body.
	for meridian in range(-4,5):
		var path := PackedVector2Array()
		for step in 81:
			var theta := PI*float(step)/80.0
			path.append(Vector2(sin(theta)*meridian*radius*0.19,-cos(theta)*radius*0.88))
		art.draw_polyline(path,Color(color,0.12),6.0,true)
		art.draw_polyline(path,Color(color.lightened(0.72),0.66),1.2,true)
		var bead := path[26+absi(meridian)*5]
		art.draw_circle(bead,2.0,Color(color.lightened(0.8),0.9),true,-1,true)
	art.draw_circle(Vector2(-radius*0.3,-radius*0.53),radius*0.09,Color(0.85,1,1,0.14),true,-1,true)
	art.draw_circle(Vector2(-radius*0.3,-radius*0.53),radius*0.04,Color(0.9,1,1,0.78),true,-1,true)
	art.draw_set_transform(Vector2.ZERO)

func paint() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=1609
	for i in 52:
		var p := Vector2(rng.randf_range(360,1080),rng.randf_range(130,540))
		var alpha := rng.randf_range(0.12,0.55)
		art.draw_circle(p,rng.randf_range(0.7,2.0),Color(0.55,0.88,1,alpha),true,-1,true)
	# A fine elliptical current grounds the floating cluster.
	art.draw_set_transform(Vector2(720,452),0,Vector2(1,0.22))
	art.draw_arc(Vector2.ZERO,258,0,TAU,180,Color(0.35,0.78,0.85,0.18),1.2,true)
	art.draw_set_transform(Vector2.ZERO)
	cell(Vector2(545,354),78,Color("aca0f3"),-0.25)
	cell(Vector2(892,374),63,Color("ffb5a0"),0.32)
	cell(Vector2(725,301),127,Color("79e4db"),0.12)
	label("S O F T   M O U N T A I N",579,43,Color("e2f6f2"))
	label("T I D A L   G L O W",623,16,Color("9dbdbf"))
	label("A living pool of soft light",677,19,Color("6f919c"))
