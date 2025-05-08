extends CharacterBody3D

@onready var head = $Head
@onready var camera = $Head/Camera
@onready var standing_collision = $StandingCollision
@onready var crouching_collision = $CrouchingCollision
@onready var height_check = $HeightCheck
@onready var footstep_audio = $FootstepAudio

const mouse_sensitivity = 0.15

@export var walk_speed = 5.0
@export var spring_speed = 10.0
@export var crouching_speed = 3.0
@export var jump_velocity = 5.0
@export var movement_lerp_speed = 15.0
@export var crouch_lerp_speed = 8.0
@export var headbob_frequency = 2.0
@export var headbob_amplitude = 0.04
@export var headbob_time = 0.0

var current_speed = walk_speed
var move_direction = Vector3.ZERO
var head_height = 0.5
var crouch_height = 0.0
var footstep_can_play = true
var footstep_landed

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
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_pressed("crouch"):
		if standing_collision and crouching_collision and head:
			current_speed = crouching_speed
			head.position.y = lerp(head.position.y, crouch_height, delta * crouch_lerp_speed)

			standing_collision.disabled = true
			crouching_collision.disabled = false

			print("crouching")
			print("head.position.y:", head.position.y)
	else:
		if not height_check or not height_check.is_colliding():
			if standing_collision and crouching_collision and head:
				head.position.y = lerp(head.position.y, head_height, delta * crouch_lerp_speed)

				standing_collision.disabled = false
				crouching_collision.disabled = true

				print("standing up")
				print("head.position.y:", head.position.y)

				if Input.is_action_pressed("sprint"):
					current_speed = spring_speed
				else:
					current_speed = walk_speed
		else:
			print("can't stand up")

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		print("jump")

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move_direction = lerp(move_direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * movement_lerp_speed)

	if move_direction:
		velocity.x = move_direction.x * current_speed
		velocity.z = move_direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	headbob_time += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = headbob(headbob_time)
	
	if not footstep_landed and is_on_floor():
		footstep_audio.play()
	elif footstep_landed and not is_on_floor():
		footstep_audio.play()
	footstep_landed = is_on_floor()

	move_and_slide()
	
func headbob(time):
	var headbob_position = Vector3.ZERO
	headbob_position.y = sin(time * headbob_frequency) * headbob_amplitude
	headbob_position.x = cos(time * headbob_frequency / 2) * headbob_amplitude
	
	var footstep_threshold = -headbob_amplitude * 0.001
	if headbob_position.y > footstep_threshold:
		footstep_can_play = true
	elif headbob_position.y < footstep_threshold and footstep_can_play:
		footstep_can_play = false
		footstep_audio.play()
		
	return headbob_position
