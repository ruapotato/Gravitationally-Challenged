extends Node3D

@onready var load_to_point = $loaded_level
@onready var player = $player

var startup_load = "hub"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_level(startup_load)


func load_level(level_name: String) -> void:
	# First, remove any existing children from the load point
	for child in load_to_point.get_children():
		child.queue_free()
	
	# Construct the path to the level scene
	var level_path = "res://levels/" + level_name + ".tscn"
	
	# Load and instantiate the new level
	var level_resource = load(level_path)
	if level_resource:
		var level_instance = level_resource.instantiate()
		load_to_point.add_child(level_instance)
	else:
		push_error("Failed to load level: " + level_path)
	
	player.global_position = Vector3(0,0,0)
	player.angular_velocity = Vector3(0,0,0)
	player.linear_velocity = Vector3(0,0,0)
	player.save_check_point(Vector3(0,0,0))
	if player.gravity_scale < 0:
		player.flip_gravity()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
