extends RigidBody3D

@onready var cam_piv = $piv
@onready var camera_arm = $piv/SpringArm3D
@onready var camera = $piv/SpringArm3D/Camera3D
@onready var mesh = $mesh
@onready var leg_animator = $mesh/LegAnimator
@onready var sword = $mesh/sword
@onready var die_sound = $mesh/player_sounds/die
@onready var flip_sound = $mesh/player_sounds/flip
@onready var dash_sound = $mesh/player_sounds/dash
@onready var check_point_sound = $mesh/player_sounds/check_point_sound
@onready var collision_shape = $CollisionShape3D
@onready var fairy = $fairy

# Movement constants
const MOVEMENT_FORCE = 250.0
const MAX_VELOCITY = 3.0
const MAX_FALL_VELOCITY = 15.0
const FRICTION_FORCE = 5.0
const CAMERA_LERP_SPEED = 0.1
const MIN_ZOOM = 1.0
const MAX_ZOOM = 10.0
const LERP_VAL = 0.15
const GRAVITY_SCALE = 1.0
const ROTATION_SPEED = 10.0
const MIN_STRETCH = 1.0
const MAX_STRETCH = 1.1
const STRETCH_SPEED = 8.0
const KNOCKDOWN_DURATION = 3.0
const KNOCKDOWN_ROTATION_SPEED = 5.0
const INVULNERABILITY_DURATION = 3.0
const ACCELERATION_TIME = 1.7  # Time to reach max speed
const INITIAL_MOVEMENT_FORCE = 70.0  # Starting force
const MAX_MOVEMENT_FORCE = 250.0  # Maximum force (original MOVEMENT_FORCE value)
const DASH_FORCE = 8.0
const DASH_DURATION = 0.5
const DASH_COOLDOWN = 1.0
const DASH_ROTATION_SPEED = .1  # Speed of the forward roll
const DASH_ROTATION = PI/2  # 90 degree rotation down

var insults: Resource
# State handling
enum ActionState {IDLE, WALK, KNOCKDOWN}
var action_state = ActionState.IDLE
var gravity_inverted: bool = false
var knockdown_timer: float = 0.0
var is_knocked_down: bool = false
var initial_knockdown_rotation: Vector3
var target_knockdown_rotation: Vector3
var is_invulnerable: bool = false
var invulnerability_timer: float = 0.0
var initial_mesh_position: Vector3
var current_movement_force = INITIAL_MOVEMENT_FORCE
var is_accelerating = false
var acceleration_timer = 0.0
var mesh_height
var level_loader


# Movement and visual variables
var saved_check_point = Vector3(0,0,0)
var saved_check_point_gravity = GRAVITY_SCALE
var base_mesh_scale: Vector3
var current_stretch: float = MIN_STRETCH
var target_mesh_transform: Transform3D
var last_movement_direction: Vector3 = Vector3.FORWARD
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var can_dash: bool = true
var initial_dash_rotation: Vector3
var target_dash_rotation: Vector3
var current_dash_rotation: float = 0.0
var is_grounded: bool = false
var has_air_dash: bool = true  # New variable to track available air dash


func _ready() -> void:
	# Configure RigidBody properties 
	camera_arm.add_excluded_object(self)
	camera_arm.add_excluded_object(mesh)
	camera_arm.add_excluded_object(sword)
	lock_rotation = true
	freeze = false
	contact_monitor = true
	linear_damp = 0.01
	angular_damp = 0.0
	can_sleep = false
	gravity_scale = GRAVITY_SCALE
	mesh_height = collision_shape.shape.height
	level_loader = get_parent()	
	
	base_mesh_scale = mesh.scale
	initial_mesh_position = mesh.position
	
	load_check_point()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	cam_piv.top_level = true
	cam_piv.position = Vector3.ZERO
	
	update_target_mesh_transform(Vector3.FORWARD)
	
	if !leg_animator:
		var leg_anim = preload("res://entities/legs.gd").new()
		leg_anim.name = "LegAnimator"
		mesh.add_child(leg_anim)
		leg_animator = leg_anim


func start_knockdown() -> void:
	if not is_knocked_down and not is_invulnerable:
		die_sound.play()
		fairy.insult()
		
		is_knocked_down = true
		action_state = ActionState.KNOCKDOWN
		knockdown_timer = 0.0
		
		initial_knockdown_rotation = mesh.rotation
		target_knockdown_rotation = initial_knockdown_rotation
		target_knockdown_rotation += Vector3(0, 0, PI/2 if gravity_inverted else -PI/2)
		
		lock_rotation = true
		freeze = true

func process_knockdown(delta: float) -> void:
	if is_knocked_down:
		knockdown_timer += delta
		
		if knockdown_timer <= KNOCKDOWN_DURATION:
			var progress = min(knockdown_timer / 0.5, 1.0)
			mesh.rotation = initial_knockdown_rotation.lerp(target_knockdown_rotation, ease(progress, delta))
			
			var height_adjustment = Vector3(0, -mesh_height if not gravity_inverted else mesh_height, 0)
			mesh.position = initial_mesh_position.lerp(initial_mesh_position + height_adjustment, ease(progress, delta))
		else:
			is_knocked_down = false
			freeze = false
			start_invulnerability()
			action_state = ActionState.IDLE
			mesh.rotation = initial_knockdown_rotation
			mesh.position = initial_mesh_position
			load_check_point()


func start_dash() -> void:
	if not is_dashing and not is_knocked_down:
		# Ground dash
		if is_grounded and can_dash:
			execute_dash()
		# Air dash
		elif not is_grounded and has_air_dash:
			has_air_dash = false  # Consume air dash
			execute_dash()



func check_ground_contact(state: PhysicsDirectBodyState3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	
	# Make check distance dynamic based on velocity, but with a minimum
	var vertical_speed = abs(state.linear_velocity.y)
	var check_distance = max(1.0, vertical_speed * state.step * 2.0)
	
	# Determine ray direction based on gravity
	var ray_direction = Vector3.DOWN if not gravity_inverted else Vector3.UP
	
	# Use global position
	var base_origin = global_position
	
	# More comprehensive ray pattern for better coverage
	var ray_offsets = [
		Vector3.ZERO,              # Center
		Vector3(0.3, 0, 0),       # Right
		Vector3(-0.3, 0, 0),      # Left
		Vector3(0, 0, 0.3),       # Front
		Vector3(0, 0, -0.3),      # Back
		Vector3(0.3, 0, 0.3),     # Front-Right
		Vector3(-0.3, 0, 0.3),    # Front-Left
		Vector3(0.3, 0, -0.3),    # Back-Right
		Vector3(-0.3, 0, -0.3),   # Back-Left
	]
	
	# Try multiple heights for more reliable detection
	var height_offsets = [-0.1, 0.0, 0.1]
	
	for height in height_offsets:
		for offset in ray_offsets:
			var adjusted_origin = base_origin + Vector3(0, height, 0)
			var ray_start = adjusted_origin + offset
			var ray_end = ray_start + (ray_direction * check_distance)
			
			var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			query.exclude = [self]
			
			var collision = space_state.intersect_ray(query)
			if collision:
				return true
	
	return false


func execute_dash() -> void:
	dash_sound.play()
	is_dashing = true
	dash_timer = 0.0
	dash_direction = last_movement_direction
	can_dash = false  # Consume ground dash ability and start cooldown
	
	# Set up rotation for the dash
	initial_dash_rotation = mesh.rotation
	target_dash_rotation = initial_dash_rotation
	if gravity_inverted:
		target_dash_rotation += Vector3(DASH_ROTATION, 0, 0)
	else:
		target_dash_rotation += Vector3(-DASH_ROTATION, 0, 0)
	current_dash_rotation = 0.0

func process_dash(delta: float) -> void:
	if is_dashing:
		dash_timer += delta
		
		# Calculate rotation progress
		var rotation_progress = dash_timer / DASH_DURATION
		rotation_progress = ease(rotation_progress, 0.1)  # Smooth out the rotation
		
		# Update mesh rotation during dash
		mesh.rotation = initial_dash_rotation.lerp(target_dash_rotation, rotation_progress)
		
		if dash_timer >= DASH_DURATION:
			is_dashing = false
			dash_timer = 0.0
			# Reset mesh rotation to normal
			mesh.rotation = initial_dash_rotation
			dash_cooldown_timer = 0.0  # Start the cooldown when dash ends
	
	# Handle cooldown timer
	if not can_dash:
		dash_cooldown_timer += delta
		if dash_cooldown_timer >= DASH_COOLDOWN:
			can_dash = true


func start_invulnerability() -> void:
	check_point_sound.play()
	is_invulnerable = true
	invulnerability_timer = 0.0

func process_invulnerability(delta: float) -> void:
	if is_invulnerable:
		invulnerability_timer += delta
		if invulnerability_timer >= INVULNERABILITY_DURATION:
			is_invulnerable = false
		
		if mesh:
			mesh.visible = fmod(invulnerability_timer, 0.2) < 0.1


func update_target_mesh_transform(velocity: Vector3) -> void:
	if is_knocked_down:
		return
		
	if is_dashing:
		return  # Don't update mesh transform during dash
	
	var speed = velocity.length() / MAX_VELOCITY
	current_stretch = lerp(current_stretch, lerp(MIN_STRETCH, MAX_STRETCH, speed), get_physics_process_delta_time() * STRETCH_SPEED)
	
	if velocity.length_squared() > 0.01:
		last_movement_direction = velocity.normalized()
	
	# Create the base transform for movement direction
	var look_basis = Basis.looking_at(last_movement_direction, Vector3.UP)
	
	# Create stretch transform
	var stretch = Transform3D()
	stretch = stretch.scaled(Vector3(1, 1, current_stretch))
	
	# Create flip transform for inverted gravity
	var flip = Transform3D()
	if gravity_inverted:
		flip = flip.rotated(Vector3.RIGHT, PI)
		flip = flip.rotated(Vector3.UP, PI)
	
	# Combine all transformations
	target_mesh_transform = Transform3D(look_basis, mesh.position) * stretch * flip
	
	# Only animate legs when grounded
	if is_grounded:
		leg_animator.animate_legs(get_physics_process_delta_time(), speed)


func update_mesh_transform(delta: float) -> void:
	if not is_knocked_down:
		mesh.transform = mesh.transform.interpolate_with(target_mesh_transform, delta * ROTATION_SPEED)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_knocked_down:
		return
		
	# Update grounded state
	var was_grounded = is_grounded
	is_grounded = check_ground_contact(state)
	
	# Reset abilities when landing
	if is_grounded and not was_grounded:
		has_air_dash = true
	
	var current_velocity = state.linear_velocity
	
	var vertical_velocity = Vector3(0, current_velocity.y, 0)
	var horizontal_velocity = Vector3(current_velocity.x, 0, current_velocity.z)
	
	# Handle dash movement
	if is_dashing:
		horizontal_velocity = dash_direction * DASH_FORCE
		state.linear_velocity = horizontal_velocity  # Remove vertical velocity while dashing
		return
	
	# Get input and handle direction based on gravity
	var input_dir = Input.get_vector("left", "right", "up", "down") 
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	direction = direction.rotated(Vector3.UP, cam_piv.rotation.y)
	
	# Handle acceleration
	if direction:
		if !is_accelerating:
			is_accelerating = true
			acceleration_timer = 0.0
			current_movement_force = INITIAL_MOVEMENT_FORCE
		else:
			acceleration_timer += state.step
			var t = min(acceleration_timer / ACCELERATION_TIME, 1.0)
			# Use ease_in interpolation for smoother acceleration
			t = ease(t, 2.0)  # You can adjust the ease value for different acceleration curves
			current_movement_force = lerp(INITIAL_MOVEMENT_FORCE, MAX_MOVEMENT_FORCE, t)
	else:
		is_accelerating = false
		acceleration_timer = 0.0
		current_movement_force = INITIAL_MOVEMENT_FORCE
	
	# Wall collision prediction for next physics frame
	var space_state = get_world_3d().direct_space_state
	var prediction_distance = abs(vertical_velocity.y) * state.step  # Look ahead one physics frame
	var ray_origin = global_position
	
	# Create multiple raycasts in the fall direction for better collision detection
	var rays = [
		Vector3(0, sign(vertical_velocity.y), 0),  # Center
		Vector3(0.3, sign(vertical_velocity.y), 0),  # Right
		Vector3(-0.3, sign(vertical_velocity.y), 0),  # Left
		Vector3(0, sign(vertical_velocity.y), 0.3),  # Front
		Vector3(0, sign(vertical_velocity.y), -0.3)  # Back
	]
	
	var closest_collision_point = null
	var closest_collision_distance = INF
	
	# Check each ray for collision
	for ray_offset in rays:
		var ray_end = ray_origin + (ray_offset.normalized() * prediction_distance)
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.exclude = [self]
		
		var collision = space_state.intersect_ray(query)
		if collision:
			var collision_point = collision.position
			var distance = ray_origin.distance_to(collision_point)
			if distance < closest_collision_distance:
				closest_collision_distance = distance
				closest_collision_point = collision_point
	
	# If collision detected, handle it
	if closest_collision_point != null:
		# Move slightly back from collision point to prevent clipping
		var safe_position = closest_collision_point
		if gravity_inverted:
			safe_position.y -= mesh_height/1.4
		else:
			safe_position.y += mesh_height/1.4
		state.transform.origin = safe_position
		vertical_velocity = Vector3.ZERO
	
	# Handle horizontal movement
	if direction:
		var movement_ray_end = ray_origin + direction * (MAX_VELOCITY * state.step + 0.1)
		var movement_query = PhysicsRayQueryParameters3D.create(ray_origin, movement_ray_end)
		movement_query.exclude = [self]
		
		var movement_collision = space_state.intersect_ray(movement_query)
		
		if !movement_collision:
			if action_state == ActionState.IDLE:
				action_state = ActionState.WALK
			# Apply force with current acceleration
			state.apply_central_force(direction * current_movement_force)
		else:
			var safe_position = movement_collision.position - (direction * 0.01)
			horizontal_velocity = Vector3.ZERO
			if action_state == ActionState.WALK:
				action_state = ActionState.IDLE
	else:
		if action_state == ActionState.WALK:
			action_state = ActionState.IDLE
		# Instant stop when no input
		horizontal_velocity = Vector3.ZERO
	
	if horizontal_velocity.length() > MAX_VELOCITY:
		horizontal_velocity = horizontal_velocity.normalized() * MAX_VELOCITY
	
	if abs(vertical_velocity.y) > MAX_FALL_VELOCITY:
		vertical_velocity.y = MAX_FALL_VELOCITY * sign(vertical_velocity.y)
	
	state.linear_velocity = horizontal_velocity + vertical_velocity
	
	update_target_mesh_transform(horizontal_velocity)
	update_mesh_transform(state.step)



func flip_gravity() -> void:
	linear_velocity.y = 0
	flip_sound.play()
	gravity_inverted = !gravity_inverted
	gravity_scale = -gravity_scale
	update_target_mesh_transform(last_movement_direction)
	leg_animator.flip_gravity()

func load_check_point():
	global_position = saved_check_point
	if saved_check_point_gravity != gravity_scale:
		flip_gravity()

func save_check_point(to_this_point):
	if to_this_point != saved_check_point:
		check_point_sound.play()
		saved_check_point = to_this_point
		saved_check_point_gravity = gravity_scale

func die():
	if not is_invulnerable:
		start_knockdown()

func update_camera(delta: float) -> void:
	cam_piv.global_position = global_position
	camera_arm.position = Vector3(0, 0.44, 0)  # Keep camera height consistent

func _unhandled_input(event: InputEvent) -> void:
	if is_knocked_down:
		return
		
	if event is InputEventMouseMotion and not level_loader.paused:
		cam_piv.rotate_y(-event.relative.x * 0.005)
		camera_arm.rotate_x(-event.relative.y * 0.005)
		camera_arm.rotation.x = clamp(camera_arm.rotation.x, -PI/2.1, PI/2.1)
	
	elif event.is_action_pressed("reverse"):
		flip_gravity()
	
	elif event.is_action_pressed("zoom_in"):
		camera_arm.spring_length = clamp(camera_arm.spring_length - 0.1, MIN_ZOOM, MAX_ZOOM)
	
	elif event.is_action_pressed("zoom_out"):
		camera_arm.spring_length = clamp(camera_arm.spring_length + 0.1, MIN_ZOOM, MAX_ZOOM)
			
	elif event.is_action_pressed("pause"):
		if level_loader.paused:
			level_loader.hide_menu()
		else:
			level_loader.show_menu()
	
	elif event.is_action_pressed("swipe"):
		sword.swipe()
		
	elif event.is_action_pressed("dash"):
		start_dash()
		
		
func _process(delta: float) -> void:
	update_camera(delta)
	if is_knocked_down:
		process_knockdown(delta)
	process_invulnerability(delta)
	process_dash(delta) 
