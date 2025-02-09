extends Node3D

@onready var left_leg = null
@onready var right_leg = null

const LEG_SPEED = 8.0  # Speed of leg swing
const MAX_ANGLE = PI/10  # Maximum swing angle 
const LEG_LENGTH = 0.32  # Length of each leg
const RESET_SPEED = 5.0  # Speed at which legs return to neutral

var time: float = 0.0
var current_speed: float = 0.0
var gravity_inverted: bool = false
var target_rotation = Vector3.ZERO
var level_loader
var player
var cam_arm

func _ready():
	level_loader = find_root()
	player = level_loader.find_child("player")
	cam_arm = player.find_child("SpringArm3D")
	
	# Create the leg meshes if they don't exist
	if !left_leg:
		left_leg = create_leg_mesh("left_leg", -0.1)  # Offset to the left
	if !right_leg:
		right_leg = create_leg_mesh("right_leg", 0.1)  # Offset to the right
	
	cam_arm.add_excluded_object(self)

func find_root(node=get_tree().root) -> Node:
	if node.name.to_lower() == "level_loader":
		return node
	for child in node.get_children():
		var found = find_root(child)
		if found:
			return found
	return null



func create_leg_mesh(name: String, offset: float) -> Node3D:
	# Create a root node for the leg system
	var root = Node3D.new()
	root.name = name
	add_child(root)
	
	# Position the root with x offset for leg spacing
	root.position = Vector3(offset, 0, 0)
	
	# Create the leg mesh
	var leg = MeshInstance3D.new()
	leg.name = "mesh"
	
	# Create a capsule mesh for the leg
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.03
	capsule.height = LEG_LENGTH
	leg.mesh = capsule
	
	# Create an unshaded black material
	var material = StandardMaterial3D.new()
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.BLACK
	
	# Apply the material to the leg mesh
	leg.material_override = material
	
	# Position the leg mesh
	leg.position = Vector3(0, -LEG_LENGTH/2, 0)
	root.add_child(leg)
	
	# Create foot (horizontal part of the L)
	var foot = MeshInstance3D.new()
	foot.name = "foot"
	
	# Create capsule mesh for foot
	var foot_capsule = CapsuleMesh.new()
	foot_capsule.radius = 0.03  # Same as leg
	foot_capsule.height = 0.15   # Length of foot
	foot.mesh = foot_capsule
	
	# Use same material for foot
	foot.material_override = material
	
	# Position and rotate the foot to make L shape pointing forward
	foot.position = Vector3(0, -LEG_LENGTH, -0.05)
	foot.scale = Vector3(1,1,.8)
	foot.rotation_degrees = Vector3(90, 0, 0)  # Added 180 degrees Y rotation to flip it around
	root.add_child(foot)
	
	return root
	
	
func animate_legs(delta: float, speed: float):
	time += delta * LEG_SPEED * speed
	
	# Smoothly adjust animation speed based on movement speed
	current_speed = lerp(current_speed, speed, delta * 5.0)
	
	if current_speed > 0.02:
		# Walking animation
		# Left leg swing
		var left_phase = time
		# Right leg swing (offset by PI radians = 180 degrees)
		var right_phase = time + PI
		
		# Calculate angles with opposite phases
		var left_angle = sin(left_phase) * MAX_ANGLE
		var right_angle = sin(right_phase) * MAX_ANGLE
		
		# Rotate around X axis for forward/backward motion
		# When gravity is inverted, we need to invert the rotation angle
		var rotation_multiplier = -1.0 if gravity_inverted else 1.0
		left_leg.rotation = Vector3(left_angle * rotation_multiplier, 0, 0)
		right_leg.rotation = Vector3(right_angle * rotation_multiplier, 0, 0)
	else:
		# Return legs to neutral position when not moving
		# Use exponential interpolation for smoother transition
		left_leg.rotation = left_leg.rotation.lerp(Vector3.ZERO, delta * RESET_SPEED)
		right_leg.rotation = right_leg.rotation.lerp(Vector3.ZERO, delta * RESET_SPEED)
		
		# Reset the time when stopped to ensure animations start from a consistent position
		time = 0.0

func flip_gravity():
	gravity_inverted = !gravity_inverted
	
	for leg in [left_leg, right_leg]:
		var mesh = leg.get_node("mesh")
		
		# When gravity is flipped, we want to:
		# 1. Keep the pivot at the top of the leg (where it connects to the body)
		# 2. Rotate the leg 180 degrees to point in the right direction
		if gravity_inverted:
			# Keep pivot at top, just rotate the mesh 180 degrees
			mesh.rotation = Vector3(PI, 0, 0)
			# Keep the mesh position relative to the pivot point
			mesh.position.y = -LEG_LENGTH/2
		else:
			# Return to normal orientation
			mesh.rotation = Vector3.ZERO
			mesh.position.y = -LEG_LENGTH/2
