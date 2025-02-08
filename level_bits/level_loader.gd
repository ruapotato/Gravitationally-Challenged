extends Node3D
@onready var load_to_point = $loaded_level
@onready var player = $player
var init_save_location = "hub"
var active_save_num = 1
var level_keys_list = []
var config = ConfigFile.new()
var loaded_level = "hub"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_save_data()
	load_level(loaded_level)

func load_save_data() -> void:
	# First load which save file we're using
	var active_save_config = ConfigFile.new()
	if active_save_config.load("user://active_save.cfg") == OK:
		active_save_num = active_save_config.get_value("Save", "active_save", 1)
	
	# Then load the specific save file
	var save_path = "user://save_" + str(active_save_num) + ".cfg"
	if config.load(save_path) == OK:
		# Load existing save data
		loaded_level = config.get_value("Level", "current_level", "hub")
		level_keys_list = config.get_value("Progress", "completed_levels", [])
	else:
		# Create new save file with initial location
		loaded_level = init_save_location
		config.set_value("Level", "current_level", init_save_location)
		config.set_value("Progress", "completed_levels", level_keys_list)
		config.save(save_path)

func save_game() -> void:
	var save_path = "user://save_" + str(active_save_num) + ".cfg"
	config.set_value("Level", "current_level", loaded_level)
	config.set_value("Progress", "completed_levels", level_keys_list)
	config.save(save_path)

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
		# Update current level
		loaded_level = level_name
		save_game()
	else:
		push_error("Failed to load level: " + level_path)
	
	player.global_position = Vector3(0,0,0)
	player.angular_velocity = Vector3(0,0,0)
	player.linear_velocity = Vector3(0,0,0)
	player.save_check_point(Vector3(0,0,0))
	if player.gravity_scale < 0:
		player.flip_gravity()

func beat_level() -> void:
	if not level_keys_list.has(loaded_level):
		level_keys_list.append(loaded_level)
		save_game()
	load_level("hub")

func get_key_count() -> int:
	return level_keys_list.size()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
