extends Control

@onready var btn_train = $VBox/StartButton
@onready var btn_eval = $VBox/EvalButton
@onready var btn_stop = $VBox/StopButton
@onready var log_box = $VBox/LogLabel

func _ready():
	btn_train.pressed.connect(_on_train)
	btn_eval.pressed.connect(_on_eval)
	btn_stop.pressed.connect(_on_stop)

func _append_log(msg: String) -> void:
	var now = Time.get_datetime_dict_from_system()
	var timestamp = "%04d-%02d-%02d %02d:%02d:%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]


func _on_train():
	_append_log("Starting training via godot_rl_agents...")
	# Launch python - rely on user having python + godot_rl_agents installed
	var cmd = "python3"
	var args = ["-m", "godot_rl_agents.train", "--env_path", ProjectSettings.globalize_path("res://"), "--config", "res://addons/rl_test_plugin/config/rl_config.json"]
	var exit_code = OS.execute(cmd, args, false, [])
	_append_log("Train process launched (exit code: %d)" % exit_code)

func _on_eval():
	_append_log("Starting evaluation via godot_rl_agents...")
	var cmd = "python3"
	var args = ["-m", "godot_rl_agents.eval", "--env_path", ProjectSettings.globalize_path("res://"), "--config", "res://addons/rl_test_plugin/config/rl_config.json", "--num_episodes", "20"]
	var exit_code = OS.execute(cmd, args, false, [])
	_append_log("Eval process launched (exit code: %d)" % exit_code)

func _on_stop():
	_append_log("Stop requested — please stop the Python process manually or close the training script.")
	# Note: Stopping external process programmatically can be added later
