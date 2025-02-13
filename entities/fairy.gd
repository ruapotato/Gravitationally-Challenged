extends Node3D

@onready var mesh = $mesh
var voices
var rng = RandomNumberGenerator.new()

var player
var level_loader
var target_pos := Vector3.ZERO
var velocity := Vector3.ZERO
var trail_distance = 1.5  # How far behind player to follow
var circle_radius = 1.0   # Circle radius when player is still
var max_speed = 3.0      # Maximum movement speed
var acceleration = 15.0   # How quickly it speeds up
var deceleration = 8.0    # How quickly it slows down
var idle_time = 0.0      # Track how long player has been still
var circle_time = 0.0    # For circular motion
var last_player_pos = Vector3.ZERO
var circle_bob_time = 0.0 # For bobbing while circling
var is_speaking = false  # Track if currently speaking

func _ready() -> void:
	player = get_parent()
	level_loader = player.get_parent()
	remove_child(mesh)
	level_loader.call_deferred("add_child", mesh)
	voices = DisplayServer.tts_get_voices_for_language("en")
	voices = filter_good_voices(voices)
	print(voices)
	rng.randomize()
	say("Use space to flip gravity. Collect keys from each level. Collect 100 clover for an additional key.")

func filter_good_voices(all_voices: Array) -> Array:
	# List of base voice modifiers we want to keep
	var good_modifiers = [
		"+male1",    # Standard male voice
		"+whisper",  # Mysterious/magical feel
		"+Half-LifeAnnouncementSystem",  # Fun robotic voice
		"+grandma",  # Warm, friendly voice
		"+Demonic",  # For dramatic moments
		"+Storm",    # Dynamic voice
		"+UniversalRobot"  # Another good robotic option
	]
	
	# Preferred English variants
	var preferred_variants = [
		"English (Great Britain)",
		"English (America)"
	]
	
	var filtered_voices = []
	
	# Only keep voices from preferred variants with good modifiers
	for voice in all_voices:
		for variant in preferred_variants:
			for modifier in good_modifiers:
				if voice.begins_with(variant) and voice.ends_with(modifier):
					filtered_voices.append(voice)
					break
	
	return filtered_voices

func generate_random_color() -> Color:
	# Generate vibrant, fairy-like colors
	var h = randf()  # Random hue
	var s = randf_range(0.7, 1.0)  # High saturation
	var v = randf_range(0.8, 1.0)  # High value for brightness
	
	# Convert HSV to RGB
	var i = floor(h * 6)
	var f = h * 6 - i
	var p = v * (1 - s)
	var q = v * (1 - f * s)
	var t = v * (1 - (1 - f) * s)
	
	var r := 0.0
	var g := 0.0
	var b := 0.0
	
	match int(i) % 6:
		0: 
			r = v; g = t; b = p
		1:
			r = q; g = v; b = p
		2:
			r = p; g = v; b = t
		3:
			r = p; g = q; b = v
		4:
			r = t; g = p; b = v
		5:
			r = v; g = p; b = q
	
	return Color(r, g, b)

func say(text: String) -> void:
	shut_up()
	var phrases = []  # Store our phrases to speak
	var current_phrase = ""
	
	# First, split into phrases
	for word in text.split(" "):
		current_phrase += word + " "
		if word.ends_with(".") or word.ends_with(","):
			if current_phrase.strip_edges() != "":
				phrases.append(current_phrase.strip_edges())
			current_phrase = ""
	
	# Add any remaining text
	if current_phrase.strip_edges() != "":
		phrases.append(current_phrase.strip_edges())
	
	# Now speak each phrase with proper timing
	for phrase in phrases:
		is_speaking = true
		var voice_id = get_fun_voice_id()
		DisplayServer.tts_speak(phrase, voice_id)
		
		# Wait for TTS to actually start before changing color
		await get_tree().create_timer(0.05).timeout
		if mesh:
			print("Color change for: ", phrase)
			mesh.set_surface_override_material(0, 
				create_material_from_color(generate_random_color()))
		
		# Wait for approximate speech duration based on phrase length
		var wait_time = 0.1 + (0.05 * phrase.length())
		await get_tree().create_timer(wait_time).timeout
		is_speaking = false

func create_material_from_color(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_color.a = .5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	material.emission = material.albedo_color
	return material

func shut_up() -> void:
	DisplayServer.tts_stop()
	is_speaking = false

func get_fun_voice_id() -> String:
	var preferred_voice = "English (Great Britain)+Half-LifeAnnouncementSystem"
	# Try to find the Half-Life voice in our available voices
	for voice in voices:
		if voice == preferred_voice:
			return voice
	# If not found, return first available voice as fallback
	return voices[0]

func _process(delta: float) -> void:
	var player_pos = player.global_position
	if player.gravity_scale < 0:
		player_pos.y -= 2
	var player_moving = (player_pos - last_player_pos).length() > 0.01
	last_player_pos = player_pos
	circle_bob_time += delta * 3.0
	
	# Calculate desired position based on speaking state
	if is_speaking:
		# Move directly in front of player when speaking
		var player_facing = -player.transform.basis.z
		target_pos = player_pos + player_facing * 1.0  # Closer distance while speaking
		target_pos.y = player_pos.y + 1.0  # Slightly lower while speaking
		velocity = velocity.lerp((target_pos - mesh.global_position) * 5.0, delta * 20.0)  # Fast movement to speaking position
	else:
		# Normal movement behavior when not speaking
		if player_moving:
			idle_time = 0.0
			var player_facing = -player.transform.basis.z
			target_pos = player_pos + player_facing * trail_distance
			target_pos.y = player_pos.y + 1.5
		else:
			idle_time += delta
			if idle_time > 0.5:  # Shorter delay before circling
				circle_time += delta * (1.5 + sin(circle_bob_time) * 0.3)  # Varying circle speed
				target_pos = player_pos + Vector3(
					cos(circle_time) * (circle_radius + sin(circle_bob_time * 0.7) * 0.2),
					1.5 + sin(circle_bob_time) * 0.2,  # Gentle bob up/down
					sin(circle_time) * (circle_radius + sin(circle_bob_time * 0.7) * 0.2)
				)
		
		# Calculate distance to target
		var to_target = target_pos - mesh.global_position
		var distance = to_target.length()
		
		# Adjust acceleration based on distance
		var current_acceleration = acceleration
		if distance > 3.0:
			current_acceleration *= 2.0  # Faster acceleration when far away
		
		# Apply acceleration towards target
		var desired_velocity = to_target.normalized() * max_speed
		if distance < 1.0:
			desired_velocity *= distance  # Slow down when close
		
		velocity = velocity.lerp(desired_velocity, delta * current_acceleration)
	
	# Apply movement to mesh
	mesh.global_position += velocity * delta
	
	# Smooth look-at with some lag
	var look_target = player_pos + Vector3.UP * 0.5
	var current_look = mesh.global_transform.looking_at(look_target, Vector3.UP)
	mesh.transform = mesh.transform.interpolate_with(current_look, delta * 5.0)
