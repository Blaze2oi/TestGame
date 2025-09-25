extends Node

var episode_count: int = 0
var csv_file: File = null

func _init():
	var dir = Directory.new()
	if not dir.dir_exists("user://rl_reports"):
		dir.make_dir_recursive("user://rl_reports")
	csv_file = File.new()
	var csv_path = "user://rl_reports/rl_test_report.csv"
	csv_file.open(csv_path, File.WRITE)
	csv_file.store_line("episode,success,steps,total_reward")
	csv_file.flush()

func log_episode(success: bool, steps: int, total_reward: float) -> void:
	episode_count += 1
	var line = "%d,%d,%d,%.4f".sprintf([episode_count, success ? 1 : 0, steps, total_reward])
	csv_file.store_line(line)
	csv_file.flush()

func capture_screenshot(filename: String) -> void:
	# Capture current viewport
	var img = get_viewport().get_texture().get_data()
	img.flip_y()
	var saved = img.save_png(filename)
	if saved != OK:
		push_error("Failed to save screenshot: %s" % filename)
