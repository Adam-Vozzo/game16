extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    game.restart()
    game.sim.clear()
    game.sim.spawn(5,Vector3(0,1.7,-0.4))
    game.sim.spawn(4,Vector3(1.2,1.1,0.9))
    game.sim.spawn(2,Vector3(-1.1,0.9,1.0))
    game.sim.spawn(1,Vector3(-1.5,0.7,-0.6))
    game.sim.spawn(0,Vector3(0.1,0.7,1.8))
    for i in 150: game.sim.step(1.0/60.0)
    for ball in game.sim.balls: ball.update_visual()
    game.cooldown=0
    game._process(0)
    var shots: Array[Image]=[]
    var valid := true
    for enabled in [false,true]:
        game.set_performance_option("sss_enabled",enabled)
        for i in 8: await process_frame
        await RenderingServer.frame_post_draw
        var shot := root.get_texture().get_image()
        shot.save_png("res://captures/tidal-sss-"+("on" if enabled else "off")+".png")
        shots.append(shot)
        # Both switch positions must yield valid lit tissue, not NaN/black cores.
        for ball in game.sim.balls:
            var at: Vector2=game.camera.unproject_position(ball.center)
            var pixel := shot.get_pixel(int(at.x),int(at.y))
            valid = valid and maxf(pixel.r,maxf(pixel.g,pixel.b))>0.04
    var difference := 0.0
    var changed := 0
    for y in range(250,620,2):
        for x in range(450,1000,2):
            var a := shots[0].get_pixel(x,y)
            var b := shots[1].get_pixel(x,y)
            var d := absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
            difference+=d
            if d>0.004: changed+=1
    print("SSS VISUAL CHECK: Forward+=",game.desktop_effects," changed samples=",changed," summed RGB delta=",difference)
    game.open_options()
    game.hud.option_tabs[1].pressed.emit()
    for i in 4: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://captures/tidal-lighting-options.png")
    quit(0 if valid and changed>0 and game.desktop_effects else 1)
