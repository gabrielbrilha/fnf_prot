extends Node

# Sends event markers from the game to the Nautilus BCI suite so their timings
# land in the BIDS `_events.tsv`, time-synchronised with the EEG.
#
# Markers go out as UDP/JSON packets to `udp_to_lsl_bridge.py`
# Payload shape expected by the bridge: { "name": "<marker>", "duration": <seconds> }
#
# Registered as the "BCIMarkers" autoload, so any script can emit a marker with
# BCIMarkers.send_bci_marker("Song_Start"); duration defaults to 0
#
# If the bridge isn't running this quietly no-ops: UDP sends to a dead port are
# harmless, so the game plays normally with or without the BCI suite attached.

const ENABLED := true             # false = don't open the socket / send anything
const BRIDGE_HOST := "127.0.0.1"  # where udp_to_lsl_bridge.py is listening
const BRIDGE_PORT := 9000         # bridge default

# lane input action -> arrow direction used in every marker name
const DIRECTION := {
	"button_Q": "Left",
	"button_W": "Down",
	"button_E": "Up",
	"button_R": "Right",
}

var _udp := PacketPeerUDP.new()
var _connected := false

func _ready() -> void:
	if not ENABLED:
		return
	var err := _udp.connect_to_host(BRIDGE_HOST, BRIDGE_PORT)
	if err == OK:
		_connected = true
		print("BCIMarkers: sending markers to %s:%d" % [BRIDGE_HOST, BRIDGE_PORT])
		# initial marker so the bridge terminal confirms the link is live
		send_bci_marker("Game_Started")
	else:
		push_error("BCIMarkers: could not open UDP to %s:%d (error %d)"
			% [BRIDGE_HOST, BRIDGE_PORT, err])

# Arrow direction ("Left"/"Down"/"Up"/"Right") for a lane input action
func direction_of(action: String) -> String:
	return DIRECTION.get(action, "")

# Send one BIDS marker. `duration` is in seconds; 0.0 = instantaneous
func send_bci_marker(marker_name: String, duration: float = 0.0) -> void:
	if not _connected:
		return
	var payload := {"name": marker_name, "duration": duration}
	_udp.put_packet(JSON.stringify(payload).to_utf8_buffer())
