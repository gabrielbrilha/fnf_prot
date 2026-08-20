extends Node

# Listens for text commands from an external program (e.g. the future EEG
# bridge) over UDP and turns them into the same input actions the keyboard
# produces, so the rest of the game needs no changes to "hear" them.

const LISTEN_PORT: int = 5005

# message received over UDP -> input action fired
const COMMAND_TO_ACTION: Dictionary = {
	"left": "button_Q",
	"right": "button_R",
}

var socket := PacketPeerUDP.new()

# actions pressed this frame that must be released on the next one, so each
# packet registers as a single "just pressed" instead of a held button
var _to_release: Array[String] = []

func _ready() -> void:
	var err := socket.bind(LISTEN_PORT)
	if err != OK:
		push_error("UDPInput: could not bind UDP port %d (error %d)" % [LISTEN_PORT, err])

func _process(_delta: float) -> void:
	# release whatever was pressed on the previous frame first
	for action in _to_release:
		_send_action(action, false)
	_to_release.clear()

	while socket.get_available_packet_count() > 0:
		var msg := socket.get_packet().get_string_from_utf8().strip_edges().to_lower()
		print("recebido: ", msg)
		if COMMAND_TO_ACTION.has(msg):
			var action: String = COMMAND_TO_ACTION[msg]
			_send_action(action, true)
			_to_release.append(action)

func _send_action(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
