extends CharacterBody3D

@onready var vulnerable_zone = $KillArea3D
@onready var player_hurt_zone = $biteArea3D
@onready var mesh = $mesh
const SPEED = 2.0
const JUMP_VELOCITY = 4.5
const CHASE_SPEED = 3.0
const SQUISH_SPEED = 6.0
const SQUISH_AMOUNT = 0.6
const DEATH_SQUISH = 0.1  # Final y-scale when dying
const DEATH_DURATION = 0.3  # Time to complete squish animation
const DEATH_WAIT = 3.0  # Time to wait before freeing

var level_loader
var player
var initial_y_scale = 1.0
var squish_time = 0.0
var is_dying = false
var death_timer = 0.0
var initial_death_scale = 1.0

func _ready() -> void:
	level_loader = find_root()
	player = level_loader.find_child("player")
	if mesh:
		initial_y_scale = mesh.scale.y
		initial_death_scale = initial_y_scale

func find_root(node=get_tree().root) -> Node:
	if node.name.to_lower() == "level_loader":
		return node
	for child in node.get_children():
		var found = find_root(child)
		if found:
			return found
	return null

func start_death_sequence():
	is_dying = true
	death_timer = 0.0
	# Disable collision and physics processing
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	# Optionally disable hurt zone during death animation
	if player_hurt_zone:
		player_hurt_zone.monitoring = false
		player_hurt_zone.monitorable = false

func process_death_animation(delta: float) -> bool:
	death_timer += delta
	
	if death_timer <= DEATH_DURATION:
		# Calculate the squish progress (0 to 1)
		var progress = death_timer / DEATH_DURATION
		# Use ease_in for smoother animation
		var squish = lerp(initial_death_scale, DEATH_SQUISH, ease(progress, delta))
		mesh.scale.y = squish
		return false
	elif death_timer >= DEATH_WAIT:
		queue_free()
		return true
	return false

func am_i_dead():
	if not is_dying and player in vulnerable_zone.get_overlapping_bodies():
		start_death_sequence()

func can_i_bite():
	if not is_dying and player in player_hurt_zone.get_overlapping_bodies():
		player.die()

func chase_player(delta: float) -> Vector3:
	if player and not is_dying:
		var direction_to_player = (player.global_position - global_position).normalized()
		direction_to_player.y = 0  # Keep movement on the horizontal plane
		
		# Look at player
		if direction_to_player.length() > 0.1:
			look_at(global_position + direction_to_player, Vector3.UP)
			rotation.x = 0  # Keep upright
			rotation.z = 0
		
		return direction_to_player
	return Vector3.ZERO

func update_squish_animation(delta: float) -> void:
	if not mesh or is_dying:
		return
	
	# Continue squish animation as long as we're moving
	if velocity.length() > 0.1:
		squish_time += delta * SQUISH_SPEED
		# Calculate squish based on continuous movement
		var vertical_squish = 1.0 + (sin(squish_time) * SQUISH_AMOUNT)
		mesh.scale.y = initial_y_scale * vertical_squish
	else:
		# Reset to normal scale when not moving
		mesh.scale.y = initial_y_scale

func _physics_process(delta: float) -> void:
	if is_dying:
		process_death_animation(delta)
		return
		
	am_i_dead()
	can_i_bite()
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Get chase direction
	var chase_direction = chase_player(delta)
	
	# Apply horizontal movement
	if chase_direction:
		velocity.x = chase_direction.x * CHASE_SPEED
		velocity.z = chase_direction.z * CHASE_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, CHASE_SPEED)
		velocity.z = move_toward(velocity.z, 0, CHASE_SPEED)
	
	# Update squish animation
	update_squish_animation(delta)
	
	move_and_slide()
