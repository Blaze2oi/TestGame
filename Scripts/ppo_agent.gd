extends Node

# ============================================
# CONFIGURATION - Adjust these parameters
# ============================================

# Network architecture
const INPUT_SIZE = 8  # [player_x, player_y, velocity_x, velocity_y, nearest_apple_x, nearest_apple_y, nearest_apple_dist, on_floor]
const HIDDEN_SIZE = 64
const OUTPUT_SIZE = 3  # [left, right, jump]

# Training hyperparameters
@export var learning_rate: float = 0.0003
@export var gamma: float = 0.99  # Discount factor
@export var epsilon: float = 0.2  # PPO clip parameter
@export var epochs: int = 4  # PPO update epochs
@export var batch_size: int = 64

# Reward values - ADJUST THESE FOR DIFFERENT BEHAVIORS
@export var reward_collect_apple: float = 10.0
@export var reward_move_toward_apple: float = 0.1
@export var reward_time_penalty: float = -0.01
@export var reward_death: float = -5.0

# Experience buffer
var states = []
var actions = []
var rewards = []
var log_probs = []
var values = []
var dones = []

# Neural network weights (simplified - in real implementation use actual NN)
var policy_weights = {}
var value_weights = {}

var training_enabled: bool = true
var episode_reward: float = 0.0
var episode_count: int = 0

func _ready():
	initialize_networks()
	print("PPO Agent initialized")
	print("Input size: ", INPUT_SIZE)
	print("Output size: ", OUTPUT_SIZE)

# ============================================
# NEURAL NETWORK INITIALIZATION
# ============================================
func initialize_networks():
	# Initialize policy network weights randomly
	# w1: INPUT_SIZE x HIDDEN_SIZE (each row is input feature weights to all hidden neurons)
	policy_weights["w1"] = _random_matrix(HIDDEN_SIZE, INPUT_SIZE)
	policy_weights["b1"] = _random_vector(HIDDEN_SIZE)
	# w2: HIDDEN_SIZE x OUTPUT_SIZE
	policy_weights["w2"] = _random_matrix(OUTPUT_SIZE, HIDDEN_SIZE)
	policy_weights["b2"] = _random_vector(OUTPUT_SIZE)
	
	# Initialize value network weights randomly
	value_weights["w1"] = _random_matrix(HIDDEN_SIZE, INPUT_SIZE)
	value_weights["b1"] = _random_vector(HIDDEN_SIZE)
	value_weights["w2"] = _random_matrix(1, HIDDEN_SIZE)
	value_weights["b2"] = [0.0]

# ============================================
# STATE PROCESSING - Define what the agent sees
# ============================================
func get_state(player: CharacterBody2D, apples: Array) -> Array:
	var state = []
	
	# Player position (normalized to screen bounds)
	state.append(player.position.x / 1000.0)
	state.append(player.position.y / 600.0)
	
	# Player velocity (normalized)
	state.append(player.velocity.x / 200.0)
	state.append(player.velocity.y / 400.0)
	
	# Find nearest apple
	var nearest_apple = _find_nearest_apple(player, apples)
	if nearest_apple:
		var direction = nearest_apple.position - player.position
		state.append(direction.x / 1000.0)  # Relative X
		state.append(direction.y / 600.0)   # Relative Y
		state.append(direction.length() / 1000.0)  # Distance
	else:
		state.append(0.0)
		state.append(0.0)
		state.append(1.0)  # Max distance if no apples
	
	# Is on floor
	state.append(1.0 if player.is_on_floor() else 0.0)
	
	return state

# ============================================
# ACTION SELECTION - Agent decides what to do
# ============================================
func select_action(state: Array) -> Dictionary:
	# Forward pass through policy network
	var logits = _forward_policy(state)
	
	# Convert to probabilities using softmax
	var probs = _softmax(logits)
	
	# Sample action from probability distribution
	var action = _sample_action(probs)
	
	# Calculate log probability of selected action
	var log_prob = log(probs[action])
	
	# Get state value from value network
	var value = _forward_value(state)
	
	return {
		"action": action,
		"log_prob": log_prob,
		"value": value,
		"probs": probs
	}

# ============================================
# ACTION TO INPUT - Convert action to game inputs
# ============================================
func action_to_inputs(action: int) -> Dictionary:
	# Action space:
	# 0 = Move left
	# 1 = Move right
	# 2 = Jump (or jump + current direction)
	
	var inputs = {
		"left": false,
		"right": false,
		"jump": false
	}
	
	if action == 0:
		inputs["left"] = true
	elif action == 1:
		inputs["right"] = true
	elif action == 2:
		inputs["jump"] = true
		# Optionally continue moving in current direction while jumping
	
	return inputs

# ============================================
# REWARD CALCULATION - Define what's good/bad
# ============================================
func calculate_reward(player: CharacterBody2D, collected_apple: bool, 
					  prev_distance: float, curr_distance: float) -> float:
	var reward = 0.0
	
	# Big reward for collecting apple
	if collected_apple:
		reward += reward_collect_apple
	
	# Small reward for moving toward nearest apple
	if curr_distance < prev_distance:
		reward += reward_move_toward_apple
	
	# Time penalty to encourage faster completion
	reward += reward_time_penalty
	
	# Penalty for falling off screen (death)
	if player.position.y > 700:
		reward += reward_death
	
	return reward

# ============================================
# EXPERIENCE STORAGE
# ============================================
func store_experience(state: Array, action: int, reward: float, 
					  log_prob: float, value: float, done: bool):
	states.append(state)
	actions.append(action)
	rewards.append(reward)
	log_probs.append(log_prob)
	values.append(value)
	dones.append(done)
	
	episode_reward += reward

# ============================================
# PPO UPDATE - Train the agent
# ============================================
func update_policy():
	if states.size() < batch_size:
		return  # Not enough data yet
	
	print("Updating policy... Episode reward: ", episode_reward)
	
	# Calculate advantages and returns
	var advantages = _calculate_advantages()
	var returns = _calculate_returns()
	
	# PPO update for multiple epochs
	for epoch in range(epochs):
		for i in range(states.size()):
			_ppo_update_step(i, advantages[i], returns[i])
	
	# Clear experience buffer
	_clear_buffers()
	
	episode_count += 1
	print("Episode ", episode_count, " complete. Avg reward: ", episode_reward / states.size())
	episode_reward = 0.0

# ============================================
# HELPER FUNCTIONS
# ============================================

func _find_nearest_apple(player: CharacterBody2D, apples: Array):
	var nearest = null
	var min_dist = INF
	
	for apple in apples:
		if apple and is_instance_valid(apple):
			var dist = player.position.distance_to(apple.position)
			if dist < min_dist:
				min_dist = dist
				nearest = apple
	
	return nearest

func _forward_policy(state: Array) -> Array:
	# Simple 2-layer neural network forward pass
	var hidden = _relu(_matmul_vec(policy_weights["w1"], state, policy_weights["b1"]))
	var output = _matmul_vec(policy_weights["w2"], hidden, policy_weights["b2"])
	return output

func _forward_value(state: Array) -> float:
	# Value network forward pass
	var hidden = _relu(_matmul_vec(value_weights["w1"], state, value_weights["b1"]))
	var output = _matmul_vec(value_weights["w2"], hidden, value_weights["b2"])
	return output[0]

func _softmax(logits: Array) -> Array:
	var max_logit = logits.max()
	var exp_logits = []
	var sum_exp = 0.0
	
	for logit in logits:
		var exp_val = exp(logit - max_logit)
		exp_logits.append(exp_val)
		sum_exp += exp_val
	
	for i in range(exp_logits.size()):
		exp_logits[i] /= sum_exp
	
	return exp_logits

func _sample_action(probs: Array) -> int:
	var rand_val = randf()
	var cumsum = 0.0
	
	for i in range(probs.size()):
		cumsum += probs[i]
		if rand_val <= cumsum:
			return i
	
	return probs.size() - 1

func _calculate_advantages() -> Array:
	# GAE (Generalized Advantage Estimation)
	var advantages = []
	var gae = 0.0
	
	for i in range(states.size() - 1, -1, -1):
		var delta = rewards[i] - values[i]
		if i < states.size() - 1:
			delta += gamma * values[i + 1] * (1 - int(dones[i]))
		
		gae = delta + gamma * 0.95 * gae * (1 - int(dones[i]))
		advantages.insert(0, gae)
	
	return _normalize(advantages)

func _calculate_returns() -> Array:
	var returns = []
	var running_return = 0.0
	
	for i in range(states.size() - 1, -1, -1):
		running_return = rewards[i] + gamma * running_return * (1 - int(dones[i]))
		returns.insert(0, running_return)
	
	return returns

func _ppo_update_step(_idx: int, _advantage: float, _target_return: float):
	# This is a simplified placeholder for PPO update
	# In a real implementation, you would:
	# 1. Calculate new log probabilities and values
	# 2. Compute ratio = exp(new_log_prob - old_log_prob)
	# 3. Apply PPO clipping
	# 4. Update weights using gradients
	pass

func _normalize(arr: Array) -> Array:
	var mean = 0.0
	var std = 0.0
	
	for val in arr:
		mean += val
	mean /= arr.size()
	
	for val in arr:
		std += (val - mean) ** 2
	std = sqrt(std / arr.size())
	
	var normalized = []
	for val in arr:
		normalized.append((val - mean) / (std + 1e-8))
	
	return normalized

func _clear_buffers():
	states.clear()
	actions.clear()
	rewards.clear()
	log_probs.clear()
	values.clear()
	dones.clear()

# Simple matrix/vector operations
func _random_matrix(rows: int, cols: int) -> Array:
	var matrix = []
	for i in range(rows):
		var row = []
		for j in range(cols):
			row.append(randf_range(-0.1, 0.1))
		matrix.append(row)
	return matrix

func _random_vector(size: int) -> Array:
	var vec = []
	for i in range(size):
		vec.append(randf_range(-0.1, 0.1))
	return vec

func _matmul_vec(matrix: Array, vec: Array, bias: Array) -> Array:
	# matrix: rows x cols, vec: cols x 1, output: rows x 1
	var result = []
	for i in range(matrix.size()):  # For each output neuron (row)
		var sum = bias[i] if i < bias.size() else 0.0
		for j in range(vec.size()):  # For each input feature (col)
			if j < matrix[i].size():
				sum += matrix[i][j] * vec[j]
		result.append(sum)
	return result

func _relu(vec: Array) -> Array:
	var result = []
	for val in vec:
		result.append(max(0.0, val))
	return result
