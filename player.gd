extends RigidBody3D

@onready var cam_piv = $piv
@onready var camera_arm = $piv/SpringArm3D
@onready var camera = $piv/SpringArm3D/Camera3D
@onready var mesh = $mesh
@onready var leg_animator = $mesh/LegAnimator

# Movement constants
const MOVEMENT_FORCE = 140.0
const FRICTION_FORCE = 10.0
const MAX_VELOCITY = 1.0
const CAMERA_LERP_SPEED = 0.1
const MIN_ZOOM = 1.0
const MAX_ZOOM = 10.0
const LERP_VAL = 0.15
const GRAVITY_SCALE = 3.0
const ROTATION_SPEED = 10.0
const MIN_STRETCH = 0.7
const MAX_STRETCH = 0.8
const STRETCH_SPEED = 8.0

# State handling
enum ActionState {IDLE, WALK}
var action_state = ActionState.IDLE
var gravity_inverted: bool = false

# Camera variables
var camera_original_position: Vector3
var camera_original_rotation: Vector3
var target_camera_rotation: Vector3
var current_camera_height: float = 0.44

# Movement and visual variables
var saved_check_point = Vector3(0,0,0)
var saved_check_point_gravity = GRAVITY_SCALE
var base_mesh_scale: Vector3
var current_stretch: float = MIN_STRETCH
var target_mesh_transform: Transform3D
var last_movement_direction: Vector3 = Vector3.FORWARD  # Store last movement direction

func _ready() -> void:
	# Configure RigidBody properties
	camera_arm.add_excluded_object(mesh)
	lock_rotation = true
	freeze = false
	contact_monitor = true
	linear_damp = 1.0
	angular_damp = 0.0
	can_sleep = false
	gravity_scale = GRAVITY_SCALE
	
	# Store the original mesh scale
	base_mesh_scale = mesh.scale
	
	load_check_point()
	
	# Set up camera
	camera_arm.spring_length = (MIN_ZOOM + MAX_ZOOM) / 2
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_original_position = camera_arm.position
	camera_original_rotation = camera_arm.rotation
	target_camera_rotation = cam_piv.rotation
	
	# Set up pivot at player's position
	cam_piv.top_level = true
	cam_piv.position = Vector3.ZERO
	
	# Initialize mesh transform
	update_target_mesh_transform(Vector3.FORWARD)
	
	# Ensure the leg animator exists
	if !leg_animator:
		var leg_anim = preload("res://legs.gd").new()
		leg_anim.name = "LegAnimator"
		mesh.add_child(leg_anim)
		leg_animator = leg_anim

func update_target_mesh_transform(velocity: Vector3) -> void:
	var speed = velocity.length() / MAX_VELOCITY
	current_stretch = lerp(current_stretch, lerp(MIN_STRETCH, MAX_STRETCH, speed), get_physics_process_delta_time() * STRETCH_SPEED)
	
	# Update last movement direction if we have significant velocity
	if velocity.length_squared() > 0.01:
		last_movement_direction = velocity.normalized()
	
	# Always use the last valid movement direction for the look basis
	var look_basis = Basis.looking_at(last_movement_direction, Vector3.UP)
	
	# Create stretch transform
	var stretch = Transform3D()
	stretch = stretch.scaled(Vector3(1, 1, current_stretch))
	
	# Create flip transform
	var flip = Transform3D()
	if gravity_inverted:
		flip = flip.rotated(Vector3.RIGHT, PI)
		flip = flip.rotated(Vector3.UP, PI)
	
	# Combine transformations
	target_mesh_transform = Transform3D(look_basis, mesh.position) * stretch * flip
	
	# Animate legs based on current speed
	leg_animator.animate_legs(get_physics_process_delta_time(), speed)

func update_mesh_transform(delta: float) -> void:
	mesh.transform = mesh.transform.interpolate_with(target_mesh_transform, delta * ROTATION_SPEED)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var current_velocity = state.linear_velocity
	var current_speed = current_velocity.length()
	
	# Get input direction, flipping horizontal controls when inverted
	var input_dir := Input.get_vector("left", "right", "up", "down") if !gravity_inverted else Input.get_vector("right", "left", "up", "down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	# Rotate direction based on camera
	direction = direction.rotated(Vector3.UP, cam_piv.rotation.y)
	
	if direction:
		if action_state == ActionState.IDLE:
			action_state = ActionState.WALK
			
		# Apply movement force
		state.apply_central_force(direction * MOVEMENT_FORCE)
	else:
		if action_state == ActionState.WALK:
			action_state = ActionState.IDLE
	
	# Apply friction to horizontal movement only
	var horizontal_velocity = Vector3(current_velocity.x, 0, current_velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, FRICTION_FORCE * state.step)
	state.linear_velocity.x = horizontal_velocity.x
	state.linear_velocity.z = horizontal_velocity.z
	
	# Limit maximum horizontal velocity
	if horizontal_velocity.length() > MAX_VELOCITY:
		horizontal_velocity = horizontal_velocity.normalized() * MAX_VELOCITY
		state.linear_velocity.x = horizontal_velocity.x
		state.linear_velocity.z = horizontal_velocity.z
	
	# Update target mesh transform
	update_target_mesh_transform(horizontal_velocity)
	# Update actual mesh transform
	update_mesh_transform(state.step)

func flip_gravity() -> void:
	# Update gravity state
	gravity_inverted = !gravity_inverted
	gravity_scale = -gravity_scale
	
	# Update target rotation for camera, preserving Y rotation
	target_camera_rotation = cam_piv.rotation
	target_camera_rotation.z = float(gravity_inverted) * PI
	
	# Update mesh transform using last known direction
	update_target_mesh_transform(last_movement_direction)
	
	# Flip the legs
	leg_animator.flip_gravity()

func load_check_point():
	global_position = saved_check_point
	if saved_check_point_gravity != gravity_scale:
		flip_gravity()

func save_check_point(to_this_point):
	if to_this_point != saved_check_point:
		saved_check_point = to_this_point

func die():
	load_check_point()

func update_camera(delta: float) -> void:
	# Keep pivot exactly at player center
	cam_piv.global_position = global_position
	
	# Smoothly interpolate camera height
	var target_height = 0.44 * (1 if !gravity_inverted else -1)
	current_camera_height = lerp(current_camera_height, target_height, delta * 5.0)
	camera_arm.position = Vector3(0, current_camera_height, 0)
	
	# Smoothly interpolate camera rotation
	var current_rot = cam_piv.rotation
	current_rot.z = lerp_angle(current_rot.z, target_camera_rotation.z, delta * 5.0)
	cam_piv.rotation = current_rot

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Adjust mouse X input based on gravity orientation
		var mouse_x_multiplier = -1.0 if !gravity_inverted else 1.0
		cam_piv.rotate_y(event.relative.x * 0.005 * mouse_x_multiplier)
		
		# Y rotation (up/down) stays consistent
		camera_arm.rotate_x(-event.relative.y * 0.005)
		camera_arm.rotation.x = clamp(camera_arm.rotation.x, -PI/3, PI/3)
		
		# Update target rotation to include new Y rotation
		target_camera_rotation.y = cam_piv.rotation.y
	
	elif event.is_action_pressed("reverse"):
		flip_gravity()
	
	elif event.is_action_pressed("zoom_in"):
		camera_arm.spring_length = clamp(camera_arm.spring_length - 0.1, MIN_ZOOM, MAX_ZOOM)
	
	elif event.is_action_pressed("zoom_out"):
		camera_arm.spring_length = clamp(camera_arm.spring_length + 0.1, MIN_ZOOM, MAX_ZOOM)
			
	elif event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	update_camera(delta)
