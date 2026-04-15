extends Node

var action_history: Array = []
var max_history_size: int = 60
var caught_bugs: Array = [] # Stores all bugs caught in this session

# --- LOCALHOST SERVER VARIABLES ---
var tcp_server: TCPServer
var server_port: int = 8081

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS 
	print("QA Manager is actively watching for bugs...")
	
	# Start the local HTTP Server
	tcp_server = TCPServer.new()
	if tcp_server.listen(server_port) == OK:
		print("🌐 LIVE WEB DASHBOARD RUNNING AT: http://localhost:%d" % server_port)
	else:
		print("❌ Failed to start web server on port %d" % server_port)

func _process(_delta):
	# Listen for web browser requests every frame
	if tcp_server and tcp_server.is_connection_available():
		var peer: StreamPeerTCP = tcp_server.take_connection()
		_handle_web_request(peer)

func _handle_web_request(peer: StreamPeerTCP):
	peer.poll()
	OS.delay_msec(10)
	peer.poll()
	
	var bytes = peer.get_available_bytes()
	if bytes > 0:
		var request = peer.get_utf8_string(bytes)
		
		# --- 1. RESUME BUTTON CLICKED ---
		if request.begins_with("GET /resume"):
			get_tree().paused = false
			print("▶️ Game unpaused from web dashboard.")
			var res = "HTTP/1.1 302 Found\r\nLocation: /\r\nConnection: close\r\n\r\n"
			peer.put_data(res.to_utf8_buffer())
			
		# --- 2. STOP TESTING BUTTON CLICKED ---
		elif request.begins_with("GET /stop"):
			print("🛑 Stop Testing requested. Saving final report and shutting down.")
			_save_final_session_report()
			
			# Tell the browser the test is over
			var html = "<!DOCTYPE html><html><body style='background-color:#0f0f14; color:#e4e4e7; font-family:sans-serif; text-align:center; padding:50px;'><h1>🛑 Testing Stopped</h1><p>Final report saved to your user:// folder. You can close this tab and the Python terminal.</p></body></html>"
			var res = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\nConnection: close\r\n\r\n" + html
			peer.put_data(res.to_utf8_buffer())
			peer.disconnect_from_host()
			
			# Wait a fraction of a second to ensure the browser gets the message, then quit Godot
			OS.delay_msec(500)
			get_tree().quit()
			return # Exit the function so we don't try to disconnect again below
		
		# --- 3. NORMAL PAGE LOAD ---
		else:
			var html = _generate_dashboard_html()
			var res = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\nConnection: close\r\n\r\n" + html
			peer.put_data(res.to_utf8_buffer())
			
	peer.disconnect_from_host()

func _save_final_session_report() -> void:
	if caught_bugs.is_empty():
		print("No bugs to save for final report.")
		return
		
	var time_dict = Time.get_datetime_dict_from_system()
	var timestamp = "%04d-%02d-%02d_%02d-%02d-%02d" % [time_dict.year, time_dict.month, time_dict.day, time_dict.hour, time_dict.minute, time_dict.second]
	
	var file_name = "user://bug_reports/FINAL_SUMMARY_%s.json" % timestamp
	var file = FileAccess.open(file_name, FileAccess.WRITE)
	if file:
		# Save the entire array of bugs caught in this session into one file
		file.store_string(JSON.stringify(caught_bugs, "\t"))
		file.close()
		print("💾 Final Session Summary saved to: ", file_name)

# --- BUG TRACKING LOGIC ---
func log_action(action_data):
	action_history.append(action_data)
	if action_history.size() > max_history_size:
		action_history.pop_front()

func assert_rule(condition: bool, bug_type: String, description: String, context: Dictionary = {}) -> void:
	if not condition:
		_trigger_bug_report(bug_type, description, context)

func _trigger_bug_report(bug_type: String, description: String, context: Dictionary) -> void:
	if get_tree().paused: return 

	print("🚨 BUG CAUGHT: ", bug_type, ". Check localhost dashboard.")
	get_tree().paused = true
	
	var time_dict = Time.get_datetime_dict_from_system()
	var timestamp = "%04d-%02d-%02d %02d:%02d:%02d" % [
		time_dict.year, time_dict.month, time_dict.day,
		time_dict.hour, time_dict.minute, time_dict.second
	]
	
	# Add the bug to the top of our list
	caught_bugs.insert(0, {
		"time": timestamp,
		"type": bug_type,
		"desc": description,
		"context": JSON.stringify(context, "\t"),
		"actions": JSON.stringify(action_history, "\t")
	})

# --- HTML DASHBOARD GENERATOR ---
func _generate_dashboard_html() -> String:
	var html = """
	<!DOCTYPE html>
	<html>
	<head>
		<title>QA Bug Watchdog</title>
		<meta http-equiv="refresh" content="2">
		<style>
			body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0f0f14; color: #e4e4e7; padding: 20px; }
			.header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #27272a; padding-bottom: 10px; margin-bottom: 20px;}
			.card { background-color: #18181b; padding: 20px; border-radius: 8px; border-left: 5px solid #ef4444; margin-bottom: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.5); }
			h1 { color: #f87171; margin: 0; }
			.type { font-size: 1.2em; font-weight: bold; color: #fca5a5; }
			.time { color: #a1a1aa; font-size: 0.9em; margin-bottom: 10px; }
			pre { background-color: #09090b; padding: 15px; border-radius: 5px; color: #86efac; overflow-x: auto; }
			.btn { background-color: #3b82f6; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; font-weight: bold; display: inline-block; cursor: pointer; border: none; }
			.btn:hover { background-color: #2563eb; }
			.btn-stop { background-color: #dc2626; margin-left: 10px; }
			.btn-stop:hover { background-color: #b91c1c; }
			.paused-banner { background-color: #ef4444; color: white; padding: 15px; text-align: center; font-weight: bold; border-radius: 5px; margin-bottom: 20px; }
		</style>
	</head>
	<body>
		<div class="header">
			<h1>🕷️ GlitchCraft Bug Report Dashboard</h1>
			<div>
				<span style="color: #34d399; margin-right: 15px;">Status: Monitoring...</span>
				<a href="/stop" class="btn btn-stop">🛑 Stop Testing</a>
			</div>
		</div>
	"""
	
	if get_tree().paused:
		html += """
		<div class="paused-banner">
			⚠️ ENGINE PAUSED - BUG DETECTED ⚠️<br><br>
			<a href="/resume" class="btn" style="margin-top: 10px;">▶️ Unpause Engine & Resume</a>
		</div>
		"""
		
	if caught_bugs.is_empty():
		html += "<h3>No bugs caught yet. Let the AI keep driving!</h3>"
	else:
		for bug in caught_bugs:
			html += """
			<div class="card">
				<div class="type">%s</div>
				<div class="time">Time: %s</div>
				<p><strong>Description:</strong> %s</p>
				<p><strong>Context Data:</strong></p>
				<pre>%s</pre>
			</div>
			""" % [bug["type"], bug["time"], bug["desc"], bug["context"]]
			
	html += "</body></html>"
	return html
