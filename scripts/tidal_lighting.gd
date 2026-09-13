class_name TidalLighting
extends Node3D
## Full desktop coverage includes every body and two simultaneous merge pulses.
const MERGE_LIGHT_CAP := 2
const DESKTOP_LIGHT_CAP := SoftSimulation.MAX_BALLS + MERGE_LIGHT_CAP
const DESKTOP_REDUCED_CAP := 16
var game: Node3D
var time := 0.0
var lamps: Array[OmniLight3D] = []
var pulses: Array[Dictionary] = []

func _ready() -> void:
	for i in (DESKTOP_LIGHT_CAP if game.desktop_effects else 4):
		var lamp := OmniLight3D.new()
		lamp.shadow_enabled=false
		lamp.light_specular=0.2
		lamp.omni_attenuation=1.4
		lamp.visible=false
		add_child(lamp)
		lamps.append(lamp)

func burst(at: Vector3,tier: int) -> void:
	if game.lighting_quality==0 or game.merge_effects==0: return
	if pulses.size()==MERGE_LIGHT_CAP: pulses.pop_front()
	pulses.append({"at":at,"color":SoftBall.COLORS[tier],"age":0.0})

func clear() -> void:
	pulses.clear()
	for lamp in lamps: lamp.visible=false

func update(delta: float) -> void:
	if not game.paused:
		var dt := delta*(0.25 if game.slow_motion else 1.0)
		time+=dt
		for i in range(pulses.size()-1,-1,-1):
			pulses[i].age+=dt
			if pulses[i].age>=0.85: pulses.remove_at(i)
	RenderingServer.global_shader_parameter_set("tidal_time",time)
	if game.lighting_quality==0 or game.ball_light_strength<=0.0:
		for lamp in lamps: lamp.visible=false
		return
	var budget := lamps.size()
	if game.lighting_quality==1: budget=DESKTOP_REDUCED_CAP if game.desktop_effects else 2
	var cursor := 0
	for pulse in pulses:
		if cursor>=budget or game.merge_effects==0: break
		var strength := pow(1.0-pulse.age/0.85,2.0)
		_place(cursor,pulse.at+Vector3.UP*0.3,pulse.color,2.3*strength,4.0)
		cursor+=1
	# Stable tier priority keeps the largest organisms lighting the pool.
	var bodies: Array[SoftBall]=game.sim.balls.duplicate()
	bodies.sort_custom(func(a,b): return a.tier>b.tier)
	for ball in bodies:
		if cursor>=budget: break
		var breath := 0.88+sin(time*1.7+ball.tier)*0.12
		_place(cursor,ball.center+Vector3.UP*ball.radius*0.4,SoftBall.COLORS[ball.tier],0.65*breath,ball.radius*1.7+1.5)
		cursor+=1
	for i in range(cursor,lamps.size()): lamps[i].visible=false

func _place(index: int,at: Vector3,color: Color,energy: float,radius: float) -> void:
	var lamp := lamps[index]
	lamp.visible=true
	lamp.position=at
	lamp.light_color=color
	lamp.light_energy=energy*game.ball_light_strength
	lamp.omni_range=radius
