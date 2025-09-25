extends Node

@export var max_steps: int = 1000
@export var capture_fail_screenshot: bool = true
@export var screenshot_path: String = "user://rl_screenshots/"

var step_count: int = 0
var env_bridge = null
var report_manager = null

func _ready():
	# Try to locate godot_rl_agents environment bridge if present
	env_bridge = get_node_or_null("/root/GodotRL")
	# instantiate report manager
	report_manager = preload('res://addons/rl_test_plugin/report_manager.gd').new()
	add_child(report_manager)

func reset():
	step_count = 0
	# If godot_rl_agents is installed it will provide a reset; otherwise fallback
	if env_bridge and env_bridge.has_method("reset"):
		env_bridge.reset()
	else:
		# Try to reload the scene as a reset fallback
		var cur = get_tree().current_scene
		if cur:
			var path = cur.filename
			if path != "":
				get_tree().change_scene_to_file(path)

func step(action):
	step_count += 1
	if env_bridge and env_bridge.has_method("step"):
		env_bridge.step(action)
	else:
		# Fallback: if user provides apply_action in their Player node
		if has_node("Player") and get_node("Player").has_method("apply_action"):
			get_node("Player").apply_action(action)

func get_observation() -> Array:
	if env_bridge and env_bridge.has_method("get_observation"):
		return env_bridge.get_observation()
	# Fallback example observation
	var obs = []
	if has_node("Player"):
		var p = get_node("Player")
		obs.append(p.global_position.x)
		obs.append(p.global_position.y)
	return obs

func get_reward() -> float:
	if env_bridge and env_bridge.has_method("get_reward"):
		return env_bridge.get_reward()
	# Example reward heuristic (user should customize)
	if has_node("Player") and get_node("Player").has_method("at_goal") and get_node("Player").at_goal():
		return 10.0
	return -0.01

func is_done() -> bool:
	if step_count >= max_steps:
		return true
	if env_bridge and env_bridge.has_method("is_done"):
		return env_bridge.is_done()
	if has_node("Player") and get_node("Player").has_method("is_dead") and get_node("Player").is_dead():
		return true
	return false

func _on_episode_end():
	var total_reward = 0.0
	if env_bridge and env_bridge.has_method("get_cumulative_reward"):
		total_reward = env_bridge.get_cumulative_reward()
	var success = true
	if env_bridge and env_bridge.has_method("did_fail"):
		success = not env_bridge.did_fail()
	report_manager.log_episode(success, step_count, total_reward)
	if not success and capture_fail_screenshot:
		var filename = "%sfail_ep_%d.png".sprintf([screenshot_path, report_manager.episode_count])
		report_manager.capture_screenshot(filename)
