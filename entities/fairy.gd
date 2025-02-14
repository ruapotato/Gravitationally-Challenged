extends Node3D

@onready var mesh = $mesh
@onready var audio_player = $mesh/AudioStreamPlayer3D
var rng = RandomNumberGenerator.new()

var player
var level_loader
var target_pos := Vector3.ZERO
var velocity := Vector3.ZERO
var trail_distance = 1.5
var circle_radius = 1.0
var max_speed = 3.0
var acceleration = 15.0
var deceleration = 8.0
var idle_time = 0.0
var circle_time = 0.0
var last_player_pos = Vector3.ZERO
var circle_bob_time = 0.0
var is_speaking = false
var current_insult = 1
var total_insults = 44
var color_shift_time = 0.0

func _ready() -> void:
	player = get_parent()
	level_loader = player.get_parent()
	remove_child(mesh)
	level_loader.call_deferred("add_child", mesh)
	rng.randomize()
	
	# Setup 3D audio system
	audio_player.finished.connect(_on_audio_finished)
	
	call_deferred("init_message")

func insult():
	is_speaking = true
	var audio_stream = load("res://AI_GEN/insult/" + str(current_insult) + ".wav")
	if current_insult >= total_insults:
		audio_stream = load("res://AI_GEN/just_wow.wav")
		current_insult = 1
	else:
		current_insult += 1
	
	audio_player.stream = audio_stream
	audio_player.play()

func init_message():
	is_speaking = true
	audio_player.stream = load("res://AI_GEN/start_up.wav")
	audio_player.play()
	print("Hi")

func key_spawn_message():
	is_speaking = true
	audio_player.stream = load("res://AI_GEN/100_clover.wav")
	audio_player.play()

func _on_audio_finished():
	is_speaking = false

func hsv_to_rgb(h: float, s: float, v: float) -> Color:
	var hi = int(h * 6.0) % 6
	var f = h * 6.0 - float(hi)
	var p = v * (1.0 - s)
	var q = v * (1.0 - f * s)
	var t = v * (1.0 - (1.0 - f) * s)
	
	match hi:
		0: return Color(v, t, p)
		1: return Color(q, v, p)
		2: return Color(p, v, t)
		3: return Color(p, q, v)
		4: return Color(t, p, v)
		_: return Color(v, p, q)

func update_color(delta: float):
	if not is_speaking:
		return
		
	# Shift color while speaking
	color_shift_time += delta * 0.5
	var hue = fmod(color_shift_time, 1.0)
	var color = hsv_to_rgb(hue, 0.7, 0.9)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_color.a = 0.7
	material.emission_enabled = true
	material.emission = color * 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	
	mesh.set_surface_override_material(0, material)

func _process(delta: float) -> void:
	update_color(delta)
	
	var player_pos = player.global_position
	if player.gravity_scale < 0:
		player_pos.y -= 2
	var player_moving = (player_pos - last_player_pos).length() > 0.01
	last_player_pos = player_pos
	circle_bob_time += delta * 3.0
	
	if is_speaking:
		var player_facing = -player.transform.basis.z
		target_pos = player_pos + player_facing * 1.0
		target_pos.y = player_pos.y + 1.0
		velocity = velocity.lerp((target_pos - mesh.global_position) * 5.0, delta * 20.0)
	else:
		if player_moving:
			idle_time = 0.0
			var player_facing = -player.transform.basis.z
			target_pos = player_pos + player_facing * trail_distance
			target_pos.y = player_pos.y + 1.5
		else:
			idle_time += delta
			if idle_time > 0.5:
				circle_time += delta * (1.5 + sin(circle_bob_time) * 0.3)
				target_pos = player_pos + Vector3(
					cos(circle_time) * (circle_radius + sin(circle_bob_time * 0.7) * 0.2),
					1.5 + sin(circle_bob_time) * 0.2,
					sin(circle_time) * (circle_radius + sin(circle_bob_time * 0.7) * 0.2)
				)
	
	mesh.global_position += velocity * delta
	
	var look_target = player_pos + Vector3.UP * 0.5
	var current_look = mesh.global_transform.looking_at(look_target, Vector3.UP)
	mesh.transform = mesh.transform.interpolate_with(current_look, delta * 5.0)
