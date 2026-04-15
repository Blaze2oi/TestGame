@tool
extends EditorPlugin

const AUTOLOAD_NAME = "QAManager"
const AUTOLOAD_PATH = "res://addons/qa_bug_tester/qa_manager.gd"

func _enter_tree():
	# This runs when you enable the plugin. It registers the QAManager.
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	print("QA Bug Tester Plugin Enabled. QAManager registered.")

func _exit_tree():
	# This runs when you disable the plugin. It cleans up the autoload.
	remove_autoload_singleton(AUTOLOAD_NAME)
	print("QA Bug Tester Plugin Disabled.")
