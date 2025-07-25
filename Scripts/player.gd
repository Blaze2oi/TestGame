extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 900.0

func _physics_process(delta: float) -> void:
	var direction = 0

	# Handle horizontal input
	if Input.is_action_pressed("Left"):
		direction -= 1
	if Input.is_action_pressed("Right"):
		direction += 1

	# Move left/right
	velocity.x = direction * speed

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Jumping
		if Input.is_action_just_pressed("Jump"):
			velocity.y = jump_velocity

	# Move the character
	move_and_slide()

	# Optional: Flip sprite
	if direction != 0 and $AnimatedSprite2D:
		$AnimatedSprite2D.flip_h = direction < 0
