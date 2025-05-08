extends CharacterBody3D

#Node references
@onready var head = $Head
@onready var camera = $Head/Camera
@onready var standing_collision = $StandingCollision
@onready var crouching_collision = $CrouchingCollision
@onready var height_check = $HeightCheck
@onready var footstep_audio = $FootstepAudio
@onready var interact_ray = $Head/Camera/InteractRay

#Movement settings
@export_category("Movement")
@export var walk_speed = 5.0
@export var sprint_speed = 10.0
@export var crouching_speed = 3.0
@export var jump_velocity = 5.0
@export var movement_lerp_speed = 15.0
@export var crouch_lerp_speed = 8.0

#Headbob settings
@export_category("Headbob")
@export var headbob_frequency = 2.0
@export var headbob_amplitude = 0.04
@export var headbob_time = 0.0

#Holding objects settings
@export_category("Holding objects")
@export var throw_force = 0.4
@export var follow_speed = 5.0
@export var follow_distance = 2.5
@export var max_distance_from_camera = 5.0
@export var drop_below_player = false
@export var ground: RayCast3D

const mouse_sensitivity = 0.15

var current_speed = walk_speed
var move_direction = Vector3.ZERO
var head_height = 0.5
var crouch_height = 0.0
var footstep_can_play = true
var footstep_landed = false
var held_object: RigidBody3D

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta):
	handle_holding_object()
	apply_gravity(delta)
	handle_crouch(delta)
	handle_jump()
	handle_movement(delta)
	apply_headbob(delta)
	handle_footsteps()
	move_and_slide()

func apply_gravity(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

func handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		print("Jump")

func handle_crouch(delta):
	var is_crouching = Input.is_action_pressed("crouch")

	if is_crouching:
		current_speed = crouching_speed
		head.position.y = lerp(head.position.y, crouch_height, delta * crouch_lerp_speed)
		standing_collision.disabled = true
		crouching_collision.disabled = false
		print("Crouching")
	else:
		if not height_check or not height_check.is_colliding():
			head.position.y = lerp(head.position.y, head_height, delta * crouch_lerp_speed)
			standing_collision.disabled = false
			crouching_collision.disabled = true
			current_speed = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
			print("Standing")
		else:
			print("Can't stand up")

func handle_movement(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move_direction = lerp(move_direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * movement_lerp_speed)

	if move_direction:
		velocity.x = move_direction.x * current_speed
		velocity.z = move_direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

func apply_headbob(delta):
	headbob_time += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = get_headbob_position(headbob_time)

func get_headbob_position(time):
	var pos = Vector3.ZERO
	pos.y = sin(time * headbob_frequency) * headbob_amplitude
	pos.x = cos(time * headbob_frequency / 2) * headbob_amplitude

	var threshold = -headbob_amplitude * 0.001
	if pos.y > threshold:
		footstep_can_play = true
	elif pos.y < threshold and footstep_can_play:
		footstep_can_play = false
		footstep_audio.play()

	return pos

func handle_footsteps():
	if not footstep_landed and is_on_floor():
		footstep_audio.play()
	elif footstep_landed and not is_on_floor():
		footstep_audio.play()
	footstep_landed = is_on_floor()

func pick_object(body: RigidBody3D):
	if body:
		held_object = body

func drop_object():
	held_object = null

func throw_object():
	if held_object:
		var object = held_object
		drop_object()
		object.apply_central_impulse(-camera.global_transform.basis.z * throw_force * 10)

func handle_holding_object():
	if Input.is_action_just_pressed("throw_object") and held_object:
		throw_object()

	if Input.is_action_just_pressed("use"):
		if held_object:
			drop_object()
		elif interact_ray.is_colliding() and interact_ray.get_collider() is RigidBody3D:
			pick_object(interact_ray.get_collider())

	if held_object:
		var target_pos = camera.global_transform.origin + camera.global_basis * Vector3(0, 0, -follow_distance)
		var object_pos = held_object.global_transform.origin
		held_object.linear_velocity = (target_pos - object_pos) * follow_speed

		held_object.global_transform = held_object.global_transform.looking_at(camera.global_transform.origin, Vector3.UP)

		if held_object.global_position.distance_to(camera.global_position) > max_distance_from_camera:
			drop_object()

		if drop_below_player and ground.is_colliding() and ground.get_collider() == held_object:
			drop_object()
