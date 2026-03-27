extends GutTest

var port = 8084
var echo_received = false
var last_echo_payload: Dictionary = {}

func before_all():
	ENetServer.create_server(port, 32, 2)
	
	watch_signals(ENetServer)
	watch_signals(ENetClient)
	
	ENetServer.register_event("echo", Callable(self, "_on_echo"))
	
	ENetClient.connect_to_server("127.0.0.1", port)
	await wait_for_signal(ENetClient.connected_to_server, 5.0)

func after_all():
	ENetClient.disconnect_from_server()
	if ENetServer.has_event("echo"):
		ENetServer.unregister_event("echo")
	if ENetServer.is_server_active():
		ENetServer.stop_server()

func _on_echo(peer: ENetServerPeer, payload: Dictionary, channel: int):
	echo_received = true
	last_echo_payload = payload
	ENetServer.trigger_event(peer.get_peer_id(), "echo_reply", payload, channel, true)

func test_001_trigger_event_from_client():
	echo_received = false
	var ev_packet = {"_event": "echo", "msg": "test ping"}
	ENetClient.send_packet(ev_packet, 0, true)
	
	await wait_for_signal(ENetServer.custom_event_received, 5.0)
	var args = get_signal_parameters(ENetServer, "custom_event_received")
	assert_not_null(args, "Server should emit custom_event_received")
	assert_true(echo_received, "Callable for event 'echo' should be executed")
	assert_eq(last_echo_payload.msg, "test ping", "Payload should be passed to handler")

func test_002_trigger_event_from_server():
	var ev_packet = {"_event": "echo", "msg": "test ping"}
	ENetClient.send_packet(ev_packet, 0, true)

	await wait_for_signal(ENetClient.packet_received, 5.0)
	var args = get_signal_parameters(ENetClient, "packet_received")
	assert_not_null(args, "Client should receive the reply packet")
	if args != null:
		var pkt = args[0]
		assert_true(pkt is Dictionary, "Received packet is a Dictionary")
		assert_eq(pkt.get("_event", ""), "echo_reply", "It's an echo_reply event")
		assert_eq(pkt.get("msg", ""), "test ping", "Payload preserved")

func test_003_unregistered_event():
	var ev_packet = {"_event": "ghost_event", "msg": "spooky"}
	ENetClient.send_packet(ev_packet, 0, true)
	
	await wait_for_signal(ENetServer.unknown_event_received, 5.0)
	var args = get_signal_parameters(ENetServer, "unknown_event_received")
	assert_not_null(args, "Server should emit unknown_event_received for unregistered event string")

func test_004_unregister_event():
	assert_true(ENetServer.has_event("echo"), "Event echo is registered initially")
	ENetServer.unregister_event("echo")
	assert_false(ENetServer.has_event("echo"), "Event echo is removed from registry")
