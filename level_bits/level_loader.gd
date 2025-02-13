extends Node3D
@onready var load_to_point = $loaded_level
@onready var player = $player
@onready var pause_menu = $pause_menu
@onready var key_scene = preload("res://level_bits/key.tscn")

var init_save_location = "hub"
var active_save_num = 1
var level_keys_list = []
var config = ConfigFile.new()
var loaded_level = "hub"
var clover = 0
var clover_key_given = false
var paused = false

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

func add_clover(count=1):
	clover += count

func save_game() -> void:
	var save_path = "user://save_" + str(active_save_num) + ".cfg"
	config.set_value("Level", "current_level", loaded_level)
	config.set_value("Progress", "completed_levels", level_keys_list)
	config.save(save_path)

func hide_menu():
	if pause_menu.visible:
		pause_menu.hide()
		Engine.time_scale = 1.0
		paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func show_menu():
	if not pause_menu.visible:
		pause_menu.show()
		Engine.time_scale = 0.001
		paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func load_level(level_name: String) -> void:
	clover = 0
	clover_key_given = false
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

func beat_level(key_name) -> void:
	if not level_keys_list.has(key_name):
		level_keys_list.append(key_name)
		save_game()
	load_level("hub")

func get_key_count() -> int:
	return level_keys_list.size()

func spawn_clover_key():
	var spawn_location = player.global_position
	if player.gravity_scale > 0:
		spawn_location.y += 2
	else:
		spawn_location.y -= 1
	
	var new_key = key_scene.instantiate()
	new_key.name = loaded_level + "_coverkey"
	load_to_point.add_child(new_key)
	new_key.global_position = spawn_location
	player.fairy.say("A new key! It spawned thanks to the 100 clover you collected!")
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not clover_key_given and clover >= 100:
		clover_key_given = true
		spawn_clover_key()
