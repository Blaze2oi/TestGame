extends CharacterBody2D

# Same physics as original player
@export var speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 900.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var jump_cut_multiplier: float = 0.5

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# AI-specific
var ppo_agent: Node
var collected_items: Dictionary = {}
@export var required_items_for_progress: Dictionary = {"Fruit": 5}

# Training control
@export var use_ai: bool = true  # Toggle AI control on/off
@export var update_every_n_steps: int = 200  # Train after N steps

var step_count: int = 0
var prev_state: Array = []
var prev_action: int = 0
var prev_distance_to_apple: float = 0.0

signal item_collected(item_id, current_count)
signal can_progress_level(can_progress)

func _ready():
	# Initialize PPO agent
	ppo_agent = preload("res://Scripts/ppo_agent.gd").new()
	add_child(ppo_agent)
	
	for item_id in required_items_for_progress.keys():
		collected_items[item_id] = 0
	
	print("AI Player initialized. AI control: ", use_ai)

func _physics_process(delta: float) -> void:
	# Get all apples in scene
	var apples = _get_all_apples()
	
	# Get current state
	var current_state = ppo_agent.get_state(self, apples)
	
	var inputs = {}
	
	if use_ai:
		# AI selects action
		var action_data = ppo_agent.select_action(current_state)
		var action = action_data["action"]
		inputs = ppo_agent.action_to_inputs(action)
		
		# Calculate reward
		var collected_apple = step_count > 0 and collected_items["Fruit"] > prev_collected_count
		var curr_distance = _get_nearest_apple_distance(apples)
		var reward = ppo_agent.calculate_reward(self, collected_apple, 
												 prev_distance_to_apple, curr_distance)
		
		# Store experience
		if step_count > 0:
			var done = position.y > 700 or collected_items["Fruit"] >= required_items_for_progress["Fruit"]
			ppo_agent.store_experience(prev_state, prev_action, reward, 
									   action_data["log_prob"], action_data["value"], done)
			
			# Update policy periodically
			if step_count % update_every_n_steps == 0:
				ppo_agent.update_policy()
			
			# Reset if died or completed
			if done:
				_reset_episode()
		
		# Save state for next step
		prev_state = current_state
		prev_action = action
		prev_distance_to_apple = curr_distance
		step_count += 1
	else:
		# Manual control (original player code)
		inputs["left"] = Input.is_action_pressed("Left")
		inputs["right"] = Input.is_action_pressed("Right")
		inputs["jump"] = Input.is_action_just_pressed("Jump")
	
	# Apply inputs (same physics logic)
	_apply_movement(inputs, delta)
	
	move_and_slide()
	
	# Flip sprite based on movement
	var direction = 0
	if inputs.get("left", false):
		direction = -1
	elif inputs.get("right", false):
		direction = 1
	
	if direction != 0 and $AnimatedSprite2D:
		$AnimatedSprite2D.flip_h = direction < 0

var prev_collected_count: int = 0

func _apply_movement(inputs: Dictionary, delta: float):
	var move_direction = 0
	if inputs.get("left", false):
		move_direction -= 1
	if inputs.get("right", false):
		move_direction += 1
	
	velocity.x = move_direction * speed
	
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
	
	if inputs.get("jump", false):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
	
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0
	
	if not inputs.get("jump", false) and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

func _get_all_apples() -> Array:
	var world = get_tree().current_scene
	var apple_node = world.get_node_or_null("Apple")
	var apples = []
	
	if apple_node:
		for child in apple_node.get_children():
			if child is Area2D and is_instance_valid(child):
				apples.append(child)
	
	return apples

func _get_nearest_apple_distance(apples: Array) -> float:
	var nearest_dist = 1000.0
	
	for apple in apples:
		if apple and is_instance_valid(apple):
			var dist = position.distance_to(apple.position)
			if dist < nearest_dist:
				nearest_dist = dist
	
	return nearest_dist

func _reset_episode():
	position = Vector2(237, 497)  # Starting position
	velocity = Vector2.ZERO
	prev_collected_count = 0
	collected_items["Fruit"] = 0
	
	# Update UI
	var world = get_tree().current_scene
	if world.has_node("CanvasLayer/ItemCounter"):
		var label = world.get_node("CanvasLayer/ItemCounter") as Label
		label.text = "Items: 0"
	
	# Respawn apples (you may need to reload the scene or respawn apples manually)
	print("Episode reset")

# Collectible system (same as original)
func collect_item(item_id: String, value: int):
	if collected_items.has(item_id):
		collected_items[item_id] += value
		prev_collected_count = collected_items[item_id]
		print("AI collected ", value, " of ", item_id, ". Total: ", collected_items[item_id])
		emit_signal("item_collected", item_id, collected_items[item_id])
		
		var world = get_tree().current_scene
		if world.has_node("CanvasLayer/ItemCounter"):
			var label = world.get_node("CanvasLayer/ItemCounter") as Label
			label.text = "Items: " + str(collected_items[item_id])
		
		check_level_progress()

func check_level_progress():
	var all_required_met = true
	for item_id in required_items_for_progress.keys():
		if collected_items.has(item_id) and collected_items[item_id] < required_items_for_progress[item_id]:
			all_required_met = false
			break
	
	emit_signal("can_progress_level", all_required_met)
	if all_required_met:
		print("AI completed level!")

func _on_Collectable_collected(item_id: String, value: int):
	collect_item(item_id, value)
