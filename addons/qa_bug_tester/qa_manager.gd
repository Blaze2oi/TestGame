extends Node

var action_history: Array = []
var max_history_size: int = 60
var caught_bugs: Array = []

# --- LOCALHOST SERVER VARIABLES ---
var tcp_server: TCPServer
var server_port: int = 8081

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("QA Manager is actively watching for bugs...")

	tcp_server = TCPServer.new()
	if tcp_server.listen(server_port) == OK:
		print("🌐 LIVE WEB DASHBOARD RUNNING AT: http://localhost:%d" % server_port)
	else:
		print("❌ Failed to start web server on port %d" % server_port)

func _process(_delta):
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

		if request.begins_with("GET /resume"):
			get_tree().paused = false
			print("▶️ Game unpaused from web dashboard.")
			var res = "HTTP/1.1 302 Found\r\nLocation: /\r\nConnection: close\r\n\r\n"
			peer.put_data(res.to_utf8_buffer())

		elif request.begins_with("GET /stop"):
			print("🛑 Stop Testing requested. Saving final report and shutting down.")
			_save_final_session_report()
			var stop_html = "<html><body style='background:#0c0c10;color:#e4e4e7;font-family:sans-serif;text-align:center;padding:60px'>"
			stop_html += "<h2 style='color:#f87171'>Testing stopped</h2>"
			stop_html += "<p style='color:#71717a;margin-top:12px'>Final report saved. You can close this tab.</p>"
			stop_html += "</body></html>"
			var res = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\nConnection: close\r\n\r\n" + stop_html
			peer.put_data(res.to_utf8_buffer())
			peer.disconnect_from_host()
			OS.delay_msec(500)
			get_tree().quit()
			return

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
	var timestamp = "%04d-%02d-%02d_%02d-%02d-%02d" % [
		time_dict.year, time_dict.month, time_dict.day,
		time_dict.hour, time_dict.minute, time_dict.second
	]

	DirAccess.make_dir_recursive_absolute("user://bug_reports")
	var file_name = "user://bug_reports/FINAL_SUMMARY_" + timestamp + ".json"
	var file = FileAccess.open(file_name, FileAccess.WRITE)
	if file:
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
	if get_tree().paused:
		return

	print("🚨 BUG CAUGHT: ", bug_type, ". Check localhost dashboard.")
	get_tree().paused = true

	var time_dict = Time.get_datetime_dict_from_system()
	var timestamp = "%04d-%02d-%02d %02d:%02d:%02d" % [
		time_dict.year, time_dict.month, time_dict.day,
		time_dict.hour, time_dict.minute, time_dict.second
	]

	caught_bugs.insert(0, {
		"time": timestamp,
		"type": bug_type,
		"desc": description,
		"context": JSON.stringify(context, "\t"),
		"actions": JSON.stringify(action_history, "\t")
	})

# --- HTML DASHBOARD GENERATOR ---
# IMPORTANT: All HTML is built with string concatenation, never GDScript's % operator.
# CSS properties like "width:100%" or "letter-spacing:0.5px" contain bare % characters
# which GDScript treats as format specifiers and replaces with garbage if % is used
# on the whole string. Keep dynamic values injected via concatenation only.
func _generate_dashboard_html() -> String:
	var is_paused   = get_tree().paused
	var bug_count   = str(caught_bugs.size())
	var action_count = str(action_history.size())

	var seen_types: Dictionary = {}
	for bug in caught_bugs:
		seen_types[bug["type"]] = true
	var unique_types = str(seen_types.size())

	# ---- CSS (pure static block, safe as a raw string) ----
	var css = "<style>"
	css += "* { box-sizing:border-box; margin:0; padding:0; }"
	css += "body { font-family:'Segoe UI',system-ui,sans-serif; background:#0c0c10; color:#e4e4e7; min-height:100vh; }"
	css += ".topbar { background:#111118; border-bottom:1px solid #27272a; padding:12px 24px; display:flex; align-items:center; justify-content:space-between; position:sticky; top:0; z-index:10; }"
	css += ".btn { padding:7px 16px; border-radius:6px; font-size:13px; font-weight:500; cursor:pointer; text-decoration:none; display:inline-flex; align-items:center; gap:6px; border:none; }"
	css += ".btn-stop { background:#dc2626; color:#fff; }"
	css += ".btn-resume { background:#16a34a; color:#fff; }"
	css += ".stat-card { background:#18181b; border:1px solid #27272a; border-radius:8px; padding:14px 16px; }"
	css += ".stat-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:12px; margin-bottom:24px; }"
	css += ".stat-label { font-size:11px; color:#71717a; text-transform:uppercase; letter-spacing:0.5px; margin-bottom:6px; }"
	css += ".stat-value { font-size:22px; font-weight:600; color:#f4f4f5; }"
	css += ".dot { width:8px; height:8px; border-radius:50%; display:inline-block; margin-right:6px; }"
	css += ".dot-green { background:#22c55e; }"
	css += ".dot-red { background:#ef4444; }"
	css += ".bug-card { background:#18181b; border:1px solid #3f3f46; border-left:3px solid #ef4444; border-radius:8px; margin-bottom:12px; overflow:hidden; }"
	css += ".bug-header { padding:14px 16px 10px; display:flex; justify-content:space-between; align-items:flex-start; gap:12px; }"
	css += ".bug-type { font-size:13px; font-weight:600; color:#fca5a5; }"
	css += ".bug-time { font-size:11px; color:#52525b; margin-top:2px; }"
	css += ".bug-desc { padding:0 16px 12px; font-size:13px; color:#a1a1aa; line-height:1.5; }"
	css += ".bug-data { background:#09090b; border-top:1px solid #27272a; padding:12px 16px; }"
	css += ".data-label { font-size:11px; color:#52525b; text-transform:uppercase; letter-spacing:0.5px; margin-bottom:6px; }"
	css += ".pre-ctx { font-family:Consolas,monospace; font-size:12px; color:#86efac; white-space:pre-wrap; word-break:break-all; line-height:1.6; margin:0; }"
	css += ".pre-act { font-family:Consolas,monospace; font-size:12px; color:#93c5fd; white-space:pre-wrap; word-break:break-all; line-height:1.6; margin:0; }"
	css += ".badge-err { background:#450a0a; color:#f87171; font-size:11px; font-weight:600; padding:2px 8px; border-radius:4px; white-space:nowrap; }"
	css += ".section-title { font-size:13px; font-weight:600; color:#a1a1aa; text-transform:uppercase; letter-spacing:0.5px; }"
	css += ".paused-banner { background:#450a0a; border-bottom:1px solid #7f1d1d; padding:14px 24px; display:flex; align-items:center; justify-content:space-between; }"
	css += ".paused-text { font-size:13px; color:#fca5a5; font-weight:500; }"
	css += ".paused-label { font-weight:700; color:#f87171; margin-right:8px; }"
	css += ".main { padding:24px; max-width:960px; margin:0 auto; }"
	css += ".empty-state { text-align:center; padding:60px 24px; color:#52525b; }"
	css += ".empty-title { font-size:15px; color:#71717a; margin-bottom:6px; }"
	css += "</style>"

	# ---- <head> ----
	var head = "<!DOCTYPE html><html><head><title>GlitchCraft QA</title>"
	if not is_paused:
		head += "<meta http-equiv='refresh' content='2'>"
	head += css + "</head>"

	# ---- Topbar ----
	var dot_class   = "dot-red" if is_paused else "dot-green"
	var status_text = "Paused" if is_paused else "Monitoring"
	var topbar = "<body><div class='topbar'>"
	topbar += "<div style='display:flex;align-items:center;gap:10px;'>"
	topbar += "<svg width='18' height='18' viewBox='0 0 18 18' fill='none'>"
	topbar += "<circle cx='9' cy='9' r='8' stroke='#6366f1' stroke-width='1.5'/>"
	topbar += "<path d='M6 9h6M9 6v6' stroke='#6366f1' stroke-width='1.5' stroke-linecap='round'/>"
	topbar += "</svg>"
	topbar += "<span style='font-size:15px;font-weight:600;color:#f4f4f5;'>GlitchCraft QA</span>"
	topbar += "<span class='dot " + dot_class + "'></span>"
	topbar += "<span style='font-size:12px;color:#71717a;'>" + status_text + "</span>"
	topbar += "</div>"
	topbar += "<a href='/stop' class='btn btn-stop'>&#9632; Stop Testing</a>"
	topbar += "</div>"

	# ---- Paused banner ----
	var banner = ""
	if is_paused:
		banner = "<div class='paused-banner'>"
		banner += "<div class='paused-text'><span class='paused-label'>⚠ ENGINE PAUSED</span>Bug detected — review below and resume when ready.</div>"
		banner += "<a href='/resume' class='btn btn-resume'>&#9654; Resume</a>"
		banner += "</div>"

	# ---- Stats row ----
	var state_color = "#f87171" if is_paused else "#4ade80"
	var state_text  = "Paused" if is_paused else "Running"

	var stats = "<div class='main'><div class='stat-grid'>"
	stats += "<div class='stat-card'><div class='stat-label'>Bugs caught</div>"
	stats += "<div class='stat-value' style='color:#f87171;'>" + bug_count + "</div></div>"
	stats += "<div class='stat-card'><div class='stat-label'>Actions logged</div>"
	stats += "<div class='stat-value'>" + action_count + "</div></div>"
	stats += "<div class='stat-card'><div class='stat-label'>Unique bug types</div>"
	stats += "<div class='stat-value' style='color:#fbbf24;'>" + unique_types + "</div></div>"
	stats += "<div class='stat-card'><div class='stat-label'>Engine state</div>"
	stats += "<div class='stat-value' style='color:" + state_color + ";'>" + state_text + "</div></div>"
	stats += "</div>"
	stats += "<div style='margin-bottom:14px;'><span class='section-title'>Bug reports</span></div>"

	# ---- Bug cards ----
	var cards = ""
	if caught_bugs.is_empty():
		cards = "<div class='empty-state'>"
		cards += "<div style='font-size:28px;margin-bottom:12px;'>&#10003;</div>"
		cards += "<div class='empty-title'>No bugs caught yet</div>"
		cards += "<div style='font-size:13px;'>Let the AI keep driving...</div>"
		cards += "</div>"
	else:
		for bug in caught_bugs:
			cards += "<div class='bug-card'>"
			cards += "<div class='bug-header'>"
			cards += "<div><div class='bug-type'>" + bug["type"] + "</div>"
			cards += "<div class='bug-time'>" + bug["time"] + "</div></div>"
			cards += "<span class='badge-err'>Error</span>"
			cards += "</div>"
			cards += "<div class='bug-desc'>" + bug["desc"] + "</div>"
			cards += "<div class='bug-data'>"
			cards += "<div class='data-label'>Context</div>"
			cards += "<pre class='pre-ctx'>" + bug["context"] + "</pre>"
			
			# --- CHANGED: Wrapped the action log in a collapsible <details> tag ---
			cards += "<details style='margin-top:12px;'>"
			cards += "<summary class='data-label' style='cursor:pointer; user-select:none; outline:none;'>▶ View Action History (Click to expand)</summary>"
			cards += "<pre class='pre-act' style='margin-top:8px;'>" + bug["actions"] + "</pre>"
			cards += "</details>"
			# -----------------------------------------------------------------------
			
			cards += "</div></div>"

	return head + topbar + banner + stats + cards + "</div></body></html>"
