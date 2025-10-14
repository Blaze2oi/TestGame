extends Node

# ============================================
# REWARD FUNCTION DEFINITIONS
# ============================================
# You can define multiple reward strategies here and switch between them

enum RewardStrategy {
	SIMPLE,           # Basic rewards for collecting apples
	DISTANCE_BASED,   # Rewards based on distance to nearest apple
	EXPLORATION,      # Encourages exploring the map
	SPEED_RUN,        # Rewards fast completion
	SURVIVAL,         # Penalizes death heavily, rewards staying alive
	CUSTOM            # Your own custom reward function
}

# ============================================
# CONFIGURATION - Set your active strategy here
# ============================================
@export var active_strategy: RewardStrategy = RewardStrategy.DISTANCE_BASED

# Reward value presets for each strategy
var reward_configs = {
	RewardStrategy.SIMPLE: {
		"collect_apple": 10.0,
		"move_toward": 0.0,
		"move_away": 0.0,
		"time_penalty": -0.01,
		"death": -5.0,
		"jump": 0.0,
		"idle_penalty": 0.0,
		"exploration_bonus": 0.0,
		"height_bonus": 0.0
	},
	RewardStrategy.DISTANCE_BASED: {
		"collect_apple": 20.0,
		"move_toward": 0.5,      # Strong reward for moving closer
		"move_away": -1.0,       # Penalty for moving away
		"time_penalty": -0.02,
		"death": -10.0,
		"jump": -0.05,           # Small penalty to avoid excessive jumping
		"idle_penalty": -0.1,
		"exploration_bonus": 0.0,
		"height_bonus": 0.05
	},
	RewardStrategy.EXPLORATION: {
		"collect_apple": 15.0,
		"move_toward": 0.1,
		"move_away": 0.0,
		"time_penalty": -0.005,
		"death": -8.0,
		"jump": 0.0,
		"idle_penalty": -0.2,
		"exploration_bonus": 0.3,  # Reward for visiting new areas
		"height_bonus": 0.1        # Reward for reaching high places
	},
	RewardStrategy.SPEED_RUN: {
		"collect_apple": 30.0,
		"move_toward": 1.0,
		"move_away": -0.5,
		"time_penalty": -0.1,      # Heavy time penalty
		"death": -20.0,
		"jump": 0.0,
		"idle_penalty": -0.5,
		"exploration_bonus": 0.0,
		"height_bonus": 0.0
	},
	RewardStrategy.SURVIVAL: {
		"collect_apple": 5.0,
		"move_toward": 0.05,
		"move_away": 0.0,
		"time_penalty": 0.01,      # Reward for staying alive longer!
		"death": -50.0,            # Huge death penalty
		"jump": -0.1,              # Discourage risky jumps
		"idle_penalty": 0.0,
		"exploration_bonus": 0.0,
		"height_bonus": -0.05      # Penalty for being high (risky)
	},
	RewardStrategy.CUSTOM: {
		# ✨ DEFINE YOUR OWN REWARDS HERE ✨
		"collect_apple": 15.0,
		"move_toward": 0.2,
		"move_away": -0.1,
		"time_penalty": -0.01,
		"death": -10.0,
		"jump": 0.0,
		"idle_penalty": 0.0,
		"exploration_bonus": 0.0,
		"height_bonus": 0.0
	}
}

# Track visited positions for exploration bonus
var visited_positions = {}
var grid_size: int = 50  # Size of grid cells for tracking exploration

# ============================================
# MAIN REWARD CALCULATION
# ============================================
func calculate_reward(player: CharacterBody2D, 
					  collected_apple: bool,
					  prev_distance: float,
					  curr_distance: float,
					  prev_velocity: Vector2,
					  highest_y: float) -> float:
	
	var config = reward_configs[active_strategy]
	var reward = 0.0
	
	# 1. APPLE COLLECTION REWARD
	if collected_apple:
		reward += config["collect_apple"]
		print("🍎 Collected apple! Reward: ", config["collect_apple"])
	
	# 2. DISTANCE-BASED REWARDS
	if curr_distance < prev_distance:
		reward += config["move_toward"]
	elif curr_distance > prev_distance:
		reward += config["move_away"]
	
	# 3. TIME PENALTY (or bonus for survival)
	reward += config["time_penalty"]
	
	# 4. DEATH PENALTY
	if player.position.y > 700:
		reward += config["death"]
		print("💀 Player died! Penalty: ", config["death"])
	
	# 5. JUMP PENALTY (to avoid spammy jumping)
	if abs(player.velocity.y - prev_velocity.y) > 300:  # Detected a jump
		reward += config["jump"]
	
	# 6. IDLE PENALTY (encourage movement)
	if abs(player.velocity.x) < 10:  # Nearly standing still
		reward += config["idle_penalty"]
	
	# 7. EXPLORATION BONUS
	var grid_pos = _get_grid_position(player.position)
	if not visited_positions.has(grid_pos):
		visited_positions[grid_pos] = true
		reward += config["exploration_bonus"]
	
	# 8. HEIGHT BONUS (or penalty)
	if player.position.y < highest_y:
		reward += config["height_bonus"]
	
	return reward

# ============================================
# CUSTOM REWARD FUNCTIONS
# ============================================
# Add your own reward calculation methods here!

# Example: Reward based on velocity (encourages fast movement)
func calculate_velocity_reward(player: CharacterBody2D) -> float:
	return abs(player.velocity.x) * 0.01

# Example: Reward for staying on platforms (not in air)
func calculate_grounded_reward(player: CharacterBody2D) -> float:
	return 0.1 if player.is_on_floor() else -0.05

# Example: Combo reward (collect multiple apples quickly)
var last_collection_time: float = 0.0
var combo_multiplier: float = 1.0

func calculate_combo_reward(collected_apple: bool, current_time: float) -> float:
	if collected_apple:
		if current_time - last_collection_time < 2.0:  # Within 2 seconds
			combo_multiplier = min(combo_multiplier + 0.5, 3.0)  # Max 3x
		else:
			combo_multiplier = 1.0
		
		last_collection_time = current_time
		return 10.0 * combo_multiplier
	
	return 0.0

# Example: Progressive difficulty reward (later apples worth more)
func calculate_progressive_reward(apples_collected: int) -> float:
	return 5.0 + (apples_collected * 2.0)  # Each apple worth more

# ============================================
# HELPER FUNCTIONS
# ============================================
func _get_grid_position(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(pos.x / grid_size),
		int(pos.y / grid_size)
	)

func reset_exploration():
	visited_positions.clear()
	combo_multiplier = 1.0
	last_collection_time = 0.0

# ============================================
# REWARD SHAPING UTILITIES
# ============================================

# Normalize rewards to a specific range
func normalize_reward(reward: float, min_val: float = -1.0, max_val: float = 1.0) -> float:
	return clamp(reward, min_val, max_val)

# Apply reward scaling based on training progress
func scale_reward_by_progress(reward: float, episode: int, max_episodes: int = 1000) -> float:
	var progress = float(episode) / max_episodes
	# Gradually reduce rewards as agent improves (curriculum learning)
	return reward * (1.0 - progress * 0.5)

# Dense reward shaping: give continuous feedback
func dense_distance_reward(distance: float, max_distance: float = 1000.0) -> float:
	# Inverse distance reward (closer = better)
	return (max_distance - distance) / max_distance

# Sparse reward: only reward at specific milestones
func sparse_milestone_reward(apples_collected: int, milestones: Array = [3, 6, 10]) -> float:
	if apples_collected in milestones:
		return 20.0
	return 0.0

# ============================================
# DEBUGGING & VISUALIZATION
# ============================================
func print_reward_breakdown(reward_components: Dictionary):
	print("=== Reward Breakdown ===")
	for key in reward_components.keys():
		if reward_components[key] != 0:
			print("  ", key, ": ", reward_components[key])
	print("  Total: ", sum_dict_values(reward_components))
	print("=======================")

func sum_dict_values(dict: Dictionary) -> float:
	var total = 0.0
	for value in dict.values():
		total += value
	return total

# Get current strategy name
func get_strategy_name() -> String:
	match active_strategy:
		RewardStrategy.SIMPLE:
			return "Simple"
		RewardStrategy.DISTANCE_BASED:
			return "Distance-Based"
		RewardStrategy.EXPLORATION:
			return "Exploration"
		RewardStrategy.SPEED_RUN:
			return "Speed Run"
		RewardStrategy.SURVIVAL:
			return "Survival"
		RewardStrategy.CUSTOM:
			return "Custom"
		_:
			return "Unknown"
