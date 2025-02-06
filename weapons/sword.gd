extends Node3D

@onready var cutt_edge = $"MeshInstance3D2/Cutting Edge"

const SWORD_ANGLE = 60  # Angle to point sword outward
const SWIPE_ANGLES = [140, 0, 360]  # Counter-clockwise, clockwise, full spin
const SWIPE_DURATION = 0.25  # Slightly longer for full swipes
const RETURN_DURATION = 0.15
const COMBO_WINDOW = 0.4  # Window to input next combo

# Scale constants for each combo stage
const SCALE_DEFAULT = Vector3(1.0, 1.0, 1.0)
const SCALE_STAGE_2 = Vector3(1.4, 1.4, 1.4)
const SCALE_STAGE_3 = Vector3(1.8, 1.8, 1.8)

# Player scale constants (compress y-axis during swipes)
const PLAYER_SCALE_DEFAULT = Vector3(1.0, 1.0, 1.0)
const PLAYER_SCALE_STAGE_1 = Vector3(1.0, 0.9, 1.0)  # Slight squash
const PLAYER_SCALE_STAGE_2 = Vector3(1.0, 0.85, 1.0)  # More squash
const PLAYER_SCALE_STAGE_3 = Vector3(1.0, 0.8, 1.0)   # Most squash

# Y position offset for each stage (negative values move down)
const Y_OFFSET_DEFAULT = 0.0
const Y_OFFSET_STAGE_2 = -0.25  # Slight downward shift
const Y_OFFSET_STAGE_3 = -0.5  # More pronounced downward shift

var is_animating = false
var animation_time = 0.0
var combo_count = 0
var start_y_rotation = 0.0
var target_y_rotation = 0.0
var next_swipe_queued = false
var input_received = false  # Track if we've received an input during this swipe

# Variables for scale and position interpolation
var start_scale = SCALE_DEFAULT
var target_scale = SCALE_DEFAULT
var start_y_pos = Y_OFFSET_DEFAULT
var target_y_pos = Y_OFFSET_DEFAULT

# Variables for player scale interpolation
var player_start_scale = PLAYER_SCALE_DEFAULT
var player_target_scale = PLAYER_SCALE_DEFAULT

var level_loader
var player

func find_root(node=get_tree().root) -> Node:
	if node.name.to_lower() == "level_loader":
		return node
	for child in node.get_children():
		var found = find_root(child)
		if found:
			return found
	return null

func _ready() -> void:
	level_loader = find_root()
	player = level_loader.find_child("player")
	rotation.z = 0
	rotation.y = 0
	scale = SCALE_DEFAULT
	position.y = Y_OFFSET_DEFAULT
	if player:
		player.find_child("mesh").scale  = PLAYER_SCALE_DEFAULT
	
func swipe() -> void:
	if not is_animating:
		# Start new combo
		combo_count = 0
		start_swipe()
	elif not input_received:  # Only queue if we haven't already received input
		# Queue next swipe and mark that we've received input
		next_swipe_queued = true
		input_received = true
	
func start_swipe() -> void:
	is_animating = true
	animation_time = 0.0
	input_received = false  # Reset input flag for new swipe
	start_y_rotation = rotation.y
	rotation.z = deg_to_rad(SWORD_ANGLE)
	
	var swipe_angle = SWIPE_ANGLES[combo_count]
	target_y_rotation = start_y_rotation + deg_to_rad(swipe_angle)
	
	# Set scale and Y position based on combo stage
	start_scale = scale
	start_y_pos = position.y
	
	# Set player scale based on combo stage
	if player:
		player_start_scale = player.scale
	
	match combo_count:
		0:
			target_scale = SCALE_DEFAULT
			target_y_pos = Y_OFFSET_DEFAULT
			player_target_scale = PLAYER_SCALE_STAGE_1
		1:
			target_scale = SCALE_STAGE_2
			target_y_pos = Y_OFFSET_STAGE_2
			player_target_scale = PLAYER_SCALE_STAGE_2
		2:
			target_scale = SCALE_STAGE_3
			target_y_pos = Y_OFFSET_STAGE_3
			player_target_scale = PLAYER_SCALE_STAGE_3


func cut_stuff():
	if not player.is_knocked_down:
		for obj in cutt_edge.get_overlapping_bodies():
			if "die" in obj:
				if obj != player:
					print(obj)
					obj.die()
	
func _process(delta: float) -> void:
	if is_animating:
		cut_stuff()
		animation_time += delta
		
		if animation_time <= SWIPE_DURATION:
			# Execute the swipe
			var t = animation_time / SWIPE_DURATION
			t = ease_out_swipe(t)
			rotation.y = lerp(start_y_rotation, target_y_rotation, t)
			
			# Interpolate scale and Y position during swipe
			scale = start_scale.lerp(target_scale, t)
			position.y = lerp(start_y_pos, target_y_pos, t)
			
			# Interpolate player scale
			if player:
				player.find_child("mesh").scale  = player_start_scale.lerp(player_target_scale, t)
		else:
			# Return to neutral
			var return_progress = (animation_time - SWIPE_DURATION) / RETURN_DURATION
			
			if return_progress >= 1.0:
				is_animating = false
				rotation.y = 0.0
				rotation.z = 0.0
				
				# Check for queued swipe
				if next_swipe_queued and combo_count < 2:
					next_swipe_queued = false
					combo_count += 1
					start_swipe()
				else:
					# Reset combo if no follow-up
					combo_count = 0
					next_swipe_queued = false
					# Reset scale and position to default
					scale = SCALE_DEFAULT
					position.y = Y_OFFSET_DEFAULT
					if player:
						player.find_child("mesh").scale  = PLAYER_SCALE_DEFAULT
			else:
				var t = ease_in_out(return_progress)
				rotation.y = lerp(target_y_rotation, 0.0, t)
				rotation.z = lerp(deg_to_rad(SWORD_ANGLE), 0.0, t)
				
				# If returning to neutral and no next combo, interpolate scale and position back to default
				if not next_swipe_queued:
					scale = target_scale.lerp(SCALE_DEFAULT, t)
					position.y = lerp(target_y_pos, Y_OFFSET_DEFAULT, t)
					if player:
						player.find_child("mesh").scale  = player_target_scale.lerp(PLAYER_SCALE_DEFAULT, t)

# Custom easing function for different swipe types
func ease_out_swipe(t: float) -> float:
	match combo_count:
		0, 1:  # First two swipes use back easing
			const c1 = 1.70158
			const c3 = c1 + 1.0
			return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
		2:  # Full spin uses different easing for smooth rotation
			return 1.0 - pow(1.0 - t, 3.0)
		_:
			return t

func ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
