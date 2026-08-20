extends Node

# Wizard-of-Oz remote control.
#
# Runs a tiny HTTP server inside the game so a researcher on ANOTHER computer can
# enable/disable cheat mode from a web page, without touching the participant's
# machine.
#
#  * The game hosts BOTH the control-panel page (GET /) and the command endpoints
#    (GET /state, GET /cheat). Serving the page from the game itself means the
#    experimenter only needs the participant's IP + this port, needs no software
#    installed, and there are no cross-origin/CORS problems
#    because the page and the API share one origin.
#  * Plain HTTP request/response over TCPServer, not WebSockets: toggling a
#    boolean doesn't need a persistent socket. The panel just polls /state every
#    second to reflect the live value. Far less code, and robust.
#  * Every toggle routes through GameState.set_cheat_mode() -- the SAME entry
#    point the local spacebar uses -- so remote and local are identical (incl.
#    the combo reset). This module never reimplements game logic.
#
# Security: this opens a port on the participant's machine. Intended for a
# trusted lab LAN. Set ACCESS_TOKEN to require a shared secret in the URL, and
# leave ENABLED = false in builds given to participants to take home.

const ENABLED := true       # false = don't open the port at all
const PORT := 8080          # experimenter opens http://<participant-ip>:8080/
const ACCESS_TOKEN := ""    # if non-empty, command requests need ?token=<this>

var _server := TCPServer.new()
var _clients: Array = []     # each: { "peer": StreamPeerTCP, "buf": PackedByteArray }

func _ready() -> void:
	if not ENABLED:
		return
	var err := _server.listen(PORT)          # bind_address defaults to "*" = all interfaces
	if err == OK:
		print("RemoteControl: control panel on http://<this-machine-ip>:%d/" % PORT)
	else:
		push_error("RemoteControl: could not listen on port %d (error %d)" % [PORT, err])

func _process(_delta: float) -> void:
	if not ENABLED:
		return

	# accept any newly-arrived connections
	while _server.is_connection_available():
		var peer := _server.take_connection()
		peer.set_no_delay(true)
		_clients.append({"peer": peer, "buf": PackedByteArray()})

	# service in-progress connections; keep the ones still sending their request
	var keep: Array = []
	for c in _clients:
		if _service_client(c):
			keep.append(c)
	_clients = keep

# Returns true to keep the client for next frame, false once handled/closed.
func _service_client(c: Dictionary) -> bool:
	var peer: StreamPeerTCP = c["peer"]
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false

	var available := peer.get_available_bytes()
	if available > 0:
		var chunk = peer.get_data(available)   # [error, PackedByteArray]
		if chunk[0] == OK:
			# PackedByteArray is a value type, so append to a local and write back
			var buf: PackedByteArray = c["buf"]
			buf.append_array(chunk[1])
			c["buf"] = buf

	var text: String = c["buf"].get_string_from_utf8()
	if text.find("\r\n\r\n") == -1:
		return true                            # headers not fully received yet

	_handle_request(peer, text)
	peer.disconnect_from_host()
	return false

func _handle_request(peer: StreamPeerTCP, raw: String) -> void:
	# First line looks like: "GET /path?query HTTP/1.1"
	var request_line := raw.split("\r\n")[0]
	var pieces := request_line.split(" ")
	var target := pieces[1] if pieces.size() >= 2 else "/"

	var path := target
	var query := ""
	var q := target.find("?")
	if q != -1:
		path = target.substr(0, q)
		query = target.substr(q + 1)
	var params := _parse_query(query)

	# optional shared-token gate (the panel page itself stays open so it can prompt)
	if ACCESS_TOKEN != "" and path != "/" and params.get("token", "") != ACCESS_TOKEN:
		_send(peer, 403, "text/plain", "forbidden")
		return

	match path:
		"/":
			_send(peer, 200, "text/html; charset=utf-8", PANEL_HTML)
		"/state":
			_send_state(peer)
		"/cheat":
			if params.has("on"):
				GameState.set_cheat_mode(params["on"] == "1" or params["on"] == "true")
			elif params.has("toggle"):
				GameState.set_cheat_mode(not GameState.cheat_mode)
			_send_state(peer)
		"/external":
			# toggle external-input mode: local keyboard off, only the panel plays
			if params.has("on"):
				GameState.set_external_input(params["on"] == "1" or params["on"] == "true")
			elif params.has("toggle"):
				GameState.set_external_input(not GameState.external_input)
			_send_state(peer)
		"/press":
			# a lane "keypress" from the panel's arrow pad. Routed as a signal
			# (not an Input event) so it stays distinct from the real keyboard
			# and never awards score/combo. Ignored unless external mode is on.
			var key: String = params.get("key", "").to_upper()
			if GameState.external_input and key in ["Q", "W", "E", "R"]:
				Signals.ExternalKeyPressed.emit("button_" + key)
			_send_state(peer)
		_:
			_send(peer, 404, "text/plain", "not found")

func _send_state(peer: StreamPeerTCP) -> void:
	_send(peer, 200, "application/json", JSON.stringify({
		"cheat": GameState.cheat_mode,
		"external": GameState.external_input,
	}))

func _send(peer: StreamPeerTCP, code: int, content_type: String, body: String) -> void:
	var reason: String = {200: "OK", 403: "Forbidden", 404: "Not Found"}.get(code, "OK")
	var body_bytes := body.to_utf8_buffer()
	var header := "HTTP/1.1 %d %s\r\n" % [code, reason]
	header += "Content-Type: %s\r\n" % content_type
	header += "Content-Length: %d\r\n" % body_bytes.size()
	header += "Cache-Control: no-store\r\n"
	header += "Connection: close\r\n\r\n"
	peer.put_data(header.to_utf8_buffer())
	peer.put_data(body_bytes)

func _parse_query(query: String) -> Dictionary:
	var out := {}
	for pair in query.split("&", false):
		var kv := pair.split("=")
		if kv.size() == 2:
			out[kv[0]] = kv[1].uri_decode()
		elif kv.size() == 1 and kv[0] != "":
			out[kv[0]] = ""
	return out

# The experimenter control panel, served at GET /. Self-contained (inline CSS/JS),
# same-origin with the endpoints, so fetch() to /state and /cheat just works.
const PANEL_HTML := """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Experimenter Control Panel</title>
<style>
  :root { color-scheme: dark;
          /* lane colours, matching the in-game arrows */
          --q:#f2c21c; --w:#22d3e0; --e:#35c740; --r:#e01fa0; }
  * { box-sizing:border-box; }
  body { font-family: system-ui, sans-serif; background:#12121a; color:#eee;
         margin:0; padding:1.5rem 1rem; display:flex; flex-direction:column;
         align-items:center; gap:1.25rem; -webkit-user-select:none; user-select:none;
         touch-action:manipulation; }
  h1 { font-size:1.3rem; font-weight:600; margin:0; text-align:center; }
  .status { font-size:1.4rem; font-weight:700; padding:.7rem 1.4rem; border-radius:12px;
            min-width:13rem; text-align:center; letter-spacing:1px; }
  .status.on  { background:#1f7a33; color:#fff; }
  .status.off { background:#333; color:#aaa; }
  #status.lost{ background:#7a1f1f; color:#fff; }
  .row { display:flex; gap:.75rem; flex-wrap:wrap; justify-content:center; }
  button { font-size:1rem; padding:.8rem 1.2rem; border:0; border-radius:10px;
           cursor:pointer; color:#fff; background:#555; }
  button.primary { background:#1f7a33; }
  button:active { transform:translateY(1px); }
  #conn { font-size:.85rem; color:#888; }

  /* arrow pad: shown only while external-input mode is on */
  #pad { display:none; width:100%; max-width:520px; }
  #pad.show { display:block; }
  .padnote { font-size:.85rem; color:#9a9aa8; text-align:center; margin:0 0 .6rem; }
  .arrows { display:grid; grid-template-columns:repeat(4, 1fr); gap:.6rem; }
  .arrow { position:relative; aspect-ratio:1/1; border-radius:16px;
           border:3px solid rgba(255,255,255,.15);
           display:flex; align-items:center; justify-content:center;
           font-size:clamp(2rem, 12vw, 4rem); line-height:1; color:#12121a;
           font-weight:900; cursor:pointer; transition:filter .06s, transform .06s;
           filter:brightness(.82) saturate(.9); }
  .arrow small { position:absolute; bottom:6px; right:9px;
                 font-size:.8rem; font-weight:700; color:rgba(0,0,0,.55); }
  .arrow.q { background:var(--q); }
  .arrow.w { background:var(--w); }
  .arrow.e { background:var(--e); }
  .arrow.r { background:var(--r); }
  .arrow.active { filter:brightness(1.15) saturate(1.1);
                  transform:scale(.94); border-color:#fff; }
</style>
</head>
<body>
  <h1>Experimenter Control Panel</h1>

  <div id="status" class="status off">CHEAT: OFF</div>
  <div class="row">
	<button id="cheatOn" class="primary">Enable cheat</button>
	<button id="cheatOff">Disable cheat</button>
  </div>

  <div id="extStatus" class="status off">EXTERNAL INPUT: OFF</div>
  <div class="row">
	<button id="extOn" class="primary">Enable external input</button>
	<button id="extOff">Disable external input</button>
  </div>

  <div id="pad">
	<p class="padnote">Play with keys Q / W / E / R or tap the arrows.
      The in-game keyboard is disabled; these presses don't score.</p>
	<div class="arrows">
	  <div class="arrow q" data-key="Q">&#8592;<small>Q</small></div>
	  <div class="arrow w" data-key="W">&#8595;<small>W</small></div>
	  <div class="arrow e" data-key="E">&#8593;<small>E</small></div>
	  <div class="arrow r" data-key="R">&#8594;<small>R</small></div>
    </div>
  </div>

  <div id="conn">connecting...</div>
<script>
  // If ACCESS_TOKEN is set on the server, put the same value here.
  const TOKEN = "";
  const tok = () => TOKEN ? ("&token=" + encodeURIComponent(TOKEN)) : "";

  const statusEl  = document.getElementById("status");
  const extEl     = document.getElementById("extStatus");
  const padEl     = document.getElementById("pad");
  const connEl    = document.getElementById("conn");
  const arrows    = {};
  document.querySelectorAll(".arrow").forEach(a => arrows[a.dataset.key] = a);

  function render(st) {
	statusEl.className = "status " + (st.cheat ? "on" : "off");
	statusEl.textContent = "CHEAT: " + (st.cheat ? "ON" : "OFF");
	extEl.className = "status " + (st.external ? "on" : "off");
	extEl.textContent = "EXTERNAL INPUT: " + (st.external ? "ON" : "OFF");
	padEl.classList.toggle("show", !!st.external);
  }
  function setConn(ok) {
	connEl.textContent = ok ? "connected to game" : "no connection to game";
	if (!ok) { statusEl.className = "status lost"; statusEl.textContent = "DISCONNECTED"; }
  }

  async function cmd(url) {
    try {
	  const sep = url.includes("?") ? "&" : "?";
	  const r = await fetch(url + sep + "_=" + Date.now() + tok());
      render(await r.json());
      setConn(true);
    } catch (e) { setConn(false); }
  }
  const setCheat    = on => cmd("/cheat?on=" + (on ? 1 : 0));
  const setExternal = on => cmd("/external?on=" + (on ? 1 : 0));
  const poll        = ()  => cmd("/state");

  // Fire-and-forget lane press (kept snappy; errors just drop the connection dot).
  function press(key) {
	fetch("/press?key=" + key + "&_=" + Date.now() + tok()).catch(() => setConn(false));
  }

  document.getElementById("cheatOn").onclick  = () => setCheat(true);
  document.getElementById("cheatOff").onclick = () => setCheat(false);
  document.getElementById("extOn").onclick    = () => setExternal(true);
  document.getElementById("extOff").onclick   = () => setExternal(false);

  // Touch / mouse on the pad. pointerdown = press (no click delay on mobile).
  Object.entries(arrows).forEach(([key, el]) => {
	const down = ev => { ev.preventDefault(); el.classList.add("active"); press(key); };
	const up   = () => el.classList.remove("active");
	el.addEventListener("pointerdown", down);
	el.addEventListener("pointerup", up);
	el.addEventListener("pointerleave", up);
	el.addEventListener("pointercancel", up);
  });

  // Keyboard Q/W/E/R drives the same lanes (only while the pad is visible).
  document.addEventListener("keydown", ev => {
    if (ev.repeat) return;
    const key = ev.key.toUpperCase();
	if (!padEl.classList.contains("show") || !arrows[key]) return;
	arrows[key].classList.add("active");
    press(key);
  });
  document.addEventListener("keyup", ev => {
    const el = arrows[ev.key.toUpperCase()];
	if (el) el.classList.remove("active");
  });

  poll();
  setInterval(poll, 1000);   // reflect live state (and act as a heartbeat)
</script>
</body>
</html>
"""
