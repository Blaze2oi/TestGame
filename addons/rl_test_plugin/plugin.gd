extends EditorPlugin

var dock

func _enter_tree():
	# Load dock panel UI
	dock = preload("res://addons/rl_test_plugin/ui/rl_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	# Register custom node type
	var script = preload("res://addons/rl_test_plugin/rl_agent_tester.gd")
	var icon = preload("res://addons/rl_test_plugin/icon.png")
	add_custom_type("RLAgentTester", "Node", script, icon)

func _exit_tree():
	if dock and is_instance_valid(dock):
		remove_control_from_docks(dock)
	remove_custom_type("RLAgentTester")
