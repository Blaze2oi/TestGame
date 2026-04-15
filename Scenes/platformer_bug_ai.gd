extends AIController2D

@onready var player = $".."

func get_obs() -> Dictionary:
	# The AI sees its speed and position
	var obs = [
		player.velocity.x / 500.0,
		player.velocity.y / 1000.0,
		player.position.x / 2000.0
	]
	return {"obs": obs}

func get_action_space() -> Dictionary:
	return {
		"move_x": {"size": 1, "action_type": "continuous"}, # -1.0 to 1.0
		"jump": {"size": 2, "action_type": "discrete"}      # 0 (No) or 1 (Yes)
	}

func set_action(action) -> void:
	QAManager.log_action(action)
	
	var x_input = action["move_x"][0]
	
	var jump_choice = action["jump"]
	if typeof(jump_choice) == TYPE_ARRAY:
		jump_choice = jump_choice[0]
		
	var jump_input = (jump_choice == 1)
	
	# Send actions to the player
	player.ai_drive(x_input, jump_input)

func get_reward() -> float:
	# Reward the AI for moving fast and jumping a lot to stress-test the physics
	var reward_val = abs(player.velocity.x) / 100.0
	if not player.is_on_floor():
		reward_val += 0.5 
	return reward_val
