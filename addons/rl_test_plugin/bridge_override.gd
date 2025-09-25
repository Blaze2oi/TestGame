extends Node

# This node can be placed at /root/GodotRL or used to wrap the official bridge
# Example hooks shown as comments

func _ready():
	pass

# Called by python bridge when a reset is requested
func bridge_reset():
	if has_method("reset"):
		call_deferred("reset")

# Called by python to request an observation
func bridge_get_observation() -> Array:
	if has_method("get_observation"):
		return call("get_observation")
	return []

# You can add more bridge_* methods to match the bridge API used by godot_rl_agents
