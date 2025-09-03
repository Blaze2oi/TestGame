extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 900.0

# Jump polish settings
@export var coyote_time: float = 0.1        # seconds after leaving ground you can still jump
@export var jump_buffer_time: float = 0.1   # seconds jump input is buffered
@export var jump_cut_multiplier: float = 0.5 # reduce upward velocity when jump released early

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Collectibles
var collected_items: Dictionary = {}
@export var required_items_for_progress: Dictionary = {"Fruit": 5}

signal item_collected(item_id, current_count)
signal can_progress_level(can_progress)

func _ready():
	for item_id in required_items_for_progress.keys():
		collected_items[item_id] = 0
	check_level_progress()

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

	# --- COYOTE TIME ---
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	# --- JUMP BUFFER ---
	if Input.is_action_just_pressed("Jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# --- Perform Jump (buffer + coyote) ---
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0   # consume buffer
		coyote_timer = 0        # consume coyote

	# --- VARIABLE JUMP HEIGHT ---
	if Input.is_action_just_released("Jump") and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

	# Move the character
	move_and_slide()

	# Optional: Flip sprite
	if direction != 0 and $AnimatedSprite2D:
		$AnimatedSprite2D.flip_h = direction < 0


# -------------------------------
# Collectible System
# -------------------------------
func collect_item(item_id: String, value: int):
	if collected_items.has(item_id):
		collected_items[item_id] += value
		print("Collected ", value, " of ", item_id, ". Total: ", collected_items[item_id])
		emit_signal("item_collected", item_id, collected_items[item_id])

		# ✅ Update UI counter
		var world = get_tree().current_scene
		if world.has_node("CanvasLayer/ItemCounter"):
			var label = world.get_node("CanvasLayer/ItemCounter") as Label
			label.text = "Items: " + str(collected_items[item_id])
		
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
			all_required_met = false
			break

	emit_signal("can_progress_level", all_required_met)
	if all_required_met:
		print("All required items collected! Player can now progress.")
	else:
		print("Still need to collect more items to progress.")

func _on_Collectable_collected(item_id: String, value: int):
	collect_item(item_id, value)
