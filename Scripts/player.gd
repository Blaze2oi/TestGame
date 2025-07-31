extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 900.0

# Dictionary to store collected item counts (e.g., {"coin": 5, "gem": 2})
var collected_items: Dictionary = {}

# Dictionary to store required counts for level progression (e.g., {"coin": 10, "gem": 3})
# You'll need to set these values per level or as global game data.
@export var required_items_for_progress: Dictionary = {"coin": 5} # Example: 5 coins to progress

signal item_collected(item_id, current_count)
signal can_progress_level(can_progress)

func _ready():
	# Initialize collected items to 0 for all expected item types
	for item_id in required_items_for_progress.keys():
		collected_items[item_id] = 0
	check_level_progress() # Initial check

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

func collect_item(item_id: String, value: int):
	if collected_items.has(item_id):
		collected_items[item_id] += value
		print("Collected ", value, " of ", item_id, ". Total: ", collected_items[item_id])
		emit_signal("item_collected", item_id, collected_items[item_id])
		check_level_progress()
	else:
		print("Warning: Collected unknown item_id: ", item_id)

func check_level_progress():
	var all_required_met = true
	for item_id in required_items_for_progress.keys():
		if collected_items.has(item_id) and collected_items[item_id] < required_items_for_progress[item_id]:
			all_required_met = false
			break
		elif not collected_items.has(item_id):
			# If an item is required but not yet in collected_items, it's not met
			all_required_met = false
			break

	emit_signal("can_progress_level", all_required_met)
	if all_required_met:
		print("All required items collected! Player can now progress.")
	else:
		print("Still need to collect more items to progress.")

# This method is for your collectable to call when it's picked up
func _on_Collectable_collected(item_id: String, value: int):
	collect_item(item_id, value)
