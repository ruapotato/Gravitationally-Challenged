extends RigidBody3D

@onready var cam_piv = $piv
@onready var camera_arm = $piv/SpringArm3D
@onready var camera = $piv/SpringArm3D/Camera3D

# Movement constants
const MOVEMENT_FORCE = 140.0
const FRICTION_FORCE = 10.0
const MAX_VELOCITY = 1.0
const CAMERA_LERP_SPEED = 0.1
const MIN_ZOOM = 1.0
const MAX_ZOOM = 10.0
const LERP_VAL = 0.15
const GRAVITY_SCALE = 3.0

# State handling
enum ActionState {IDLE, WALK}
var action_state = ActionState.IDLE
var gravity_inverted: bool = false

# Camera variables
var camera_original_position: Vector3
var camera_original_rotation: Vector3
var target_camera_rotation: Vector3
var current_camera_height: float = 0.44

func _ready() -> void:
	# Configure RigidBody properties
	lock_rotation = true
	freeze = false
	contact_monitor = true
	linear_damp = 1.0
	angular_damp = 0.0
	can_sleep = false
	gravity_scale = GRAVITY_SCALE
	
	# Set up camera
	camera_arm.spring_length = (MIN_ZOOM + MAX_ZOOM) / 2
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_original_position = camera_arm.position
	camera_original_rotation = camera_arm.rotation
	target_camera_rotation = cam_piv.rotation
	
	# Set up pivot at player's position
	cam_piv.top_level = true
	cam_piv.position = Vector3.ZERO

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

func flip_gravity() -> void:
	# Update gravity state
	gravity_inverted = !gravity_inverted
	gravity_scale = -gravity_scale
	
	# Update target rotation, preserving Y rotation
	target_camera_rotation = cam_piv.rotation
	target_camera_rotation.z = float(gravity_inverted) * PI

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
	horizontal_velocity = Vector3(state.linear_velocity.x, 0, state.linear_velocity.z)
	if horizontal_velocity.length() > MAX_VELOCITY:
		horizontal_velocity = horizontal_velocity.normalized() * MAX_VELOCITY
		state.linear_velocity.x = horizontal_velocity.x
		state.linear_velocity.z = horizontal_velocity.z

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
