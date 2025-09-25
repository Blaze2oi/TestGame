# RL Test Plugin

Drop `addons/rl_test_plugin` into your Godot project's `res://addons/` folder. Enable the plugin in Project -> Plugins. Add the `RLAgentTester` node to your main scene (or autoload it). Ensure you have `godot_rl_agents` available as a dependency (either placed under `res://addons/godot_rl_agents` or installed in Python and accessible).

### Requirements
- Godot 4 (recommended). Minimal adjustments for Godot 3 may be needed.
- Python 3.8+
- `godot_rl_agents` Python package (for training/eval) and its Godot addon present if you want tight integration.

### Quick start
1. Enable plugin in Editor.
2. Add `RLAgentTester` node to your scene and configure `max_steps`, etc.
3. Open the RL Test Dock (right dock), click `Start Training` to launch `godot_rl_agents.train`. The plugin will write reports to `user://rl_reports`.

### Notes
- The plugin provides sensible defaults and wrappers, but you should update `config/rl_config.json` to match your game's sensors/actions.
- The plugin calls the external Python module `godot_rl_agents`. You must have that module installed and available on `python3 -m` path, or change the dock commands to call your local scripts.
