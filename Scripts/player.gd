extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 900.0

# Jump polish settings
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var jump_cut_multiplier: float = 0.5

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# --- AI VARIABLES ---
var is_ai_driving: bool = true
var ai_x_input: float = 0.0
var ai_jump_input: bool = false
var _ai_jump_prev: bool = false  # FIX: track previous frame to detect release edge

# Collectibles
var collected_items: Dictionary = {}
@export var required_items_for_progress: Dictionary = {"Fruit": 5}

signal item_collected(item_id, current_count)
signal can_progress_level(can_progress)

func _ready():
	for item_id in required_items_for_progress.keys():
		collected_items[item_id] = 0
	check_level_progress()

func ai_drive(x_input: float, jump_input: bool):
	ai_x_input = x_input
	ai_jump_input = jump_input

func _physics_process(delta: float) -> void:
	var current_dir := 0.0
	var wants_to_jump := false
	var released_jump := false

	# --- 1. INPUT SWITCH ---
	if is_ai_driving:
		current_dir = ai_x_input
		wants_to_jump = ai_jump_input
		# FIX: released_jump should only fire on the falling EDGE (true→false transition),
		# not every frame ai_jump_input is false (which was causing constant jump cuts).
		released_jump = _ai_jump_prev and not ai_jump_input
		_ai_jump_prev = ai_jump_input
	else:
		current_dir = Input.get_axis("Left", "Right")
		wants_to_jump = Input.is_action_just_pressed("Jump")
		released_jump = Input.is_action_just_released("Jump")

	# --- 2. APPLY MOVEMENT ---
	velocity.x = current_dir * speed

	if not is_on_floor():
		velocity.y += gravity * delta

	# --- COYOTE TIME ---
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	# --- JUMP BUFFER ---
	if wants_to_jump:
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# --- PERFORM JUMP ---
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0

	# --- VARIABLE JUMP HEIGHT ---
	if released_jump and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

	# --- 3. EXECUTE PHYSICS ---
	move_and_slide()

	# Optional: Flip sprite
	if current_dir != 0:
		var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite:
			sprite.flip_h = current_dir < 0


# -------------------------------
# Collectible System
# -------------------------------
func collect_item(item_id: String, value: int):
	if collected_items.has(item_id):
		collected_items[item_id] += value
		print("Collected ", value, " of ", item_id, ". Total: ", collected_items[item_id])
		emit_signal("item_collected", item_id, collected_items[item_id])

		# FIX: Use get_node_or_null for safety instead of assuming the node exists
		var world := get_tree().current_scene
		if world:
			var label := world.get_node_or_null("CanvasLayer/ItemCounter") as Label
			if label:
				label.text = "Items: " + str(collected_items[item_id])

		check_level_progress()
	else:
		print("Warning: Collected unknown item_id: ", item_id)

func check_level_progress():
	var all_required_met := true
	for item_id in required_items_for_progress.keys():
		var count: int = collected_items.get(item_id, 0)
		if count < required_items_for_progress[item_id]:
			all_required_met = false
			break

	emit_signal("can_progress_level", all_required_met)
	if all_required_met:
		print("All required items collected! Player can now progress.")
	else:
		print("Still need to collect more items to progress.")

func _on_Collectable_collected(item_id: String, value: int):
	collect_item(item_id, value)
