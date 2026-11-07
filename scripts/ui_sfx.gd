extends Node

const MIX_RATE := 22050

var _click: AudioStreamWAV
var _hover: AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_click = _blip(0.09, 760.0, 1180.0, 0.45)
	_hover = _blip(0.05, 1500.0, 1600.0, 0.12)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)
	_scan(get_tree().root)


func _scan(node: Node) -> void:
	for child in node.get_children():
		_on_node_added(child)
		_scan(child)


func _on_node_added(node: Node) -> void:
	if not node is BaseButton or node.has_meta("ui_sfx"):
		return
	node.set_meta("ui_sfx", true)
	node.pressed.connect(_play.bind(_click, -4.0))
	node.mouse_entered.connect(func(): if not node.disabled: _play(_hover, -16.0))


func _play(stream: AudioStreamWAV, volume: float) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume
	p.pitch_scale = randf_range(0.97, 1.03)
	p.play()


func _blip(seconds: float, from_hz: float, to_hz: float, volume: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var k := t / seconds
		phase += TAU * lerpf(from_hz, to_hz, k) / MIX_RATE
		var env := minf(t / 0.003, 1.0) * exp(-6.0 * k)
		var s := (sin(phase) + 0.3 * sin(phase * 2.0)) * env * volume
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav
