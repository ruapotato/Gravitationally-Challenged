extends CharacterBody3D


@onready var vulnerable_zone = $KillArea3D
@onready var player_hurt_zone = $biteArea3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var level_loader
var player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	level_loader = find_root()
	player = level_loader.find_child("player")


func find_root(node=get_tree().root) -> Node:
	if node.name.to_lower() == "level_loader":
		return node
	for child in node.get_children():
		var found = find_root(child)
		if found:
			return found
	return null

func am_i_dead():
	if player in vulnerable_zone.get_overlapping_bodies():
		queue_free()

func can_i_bite():
	if player in player_hurt_zone.get_overlapping_bodies():
		player.die()

func _physics_process(delta: float) -> void:
	am_i_dead()
	can_i_bite()
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
