extends AutoworkTest

var port = 8083

func before_all():
	ENetClient.disconnect_from_server()
	if ENetServer.is_server_active():
		ENetServer.stop_server()
	ENetServer.create_server(port, 32, 2)
	
	watch_signals(ENetServer)
	watch_signals(ENetClient)
	
	ENetClient.connect_to_server("127.0.0.1", port)
	await wait_for_signal(ENetClient, "connected_to_server", 5.0)
	await wait_for_signal(ENetServer, "peer_authenticated", 5.0)

func after_all():
	ENetClient.disconnect_from_server()
	if ENetServer.is_server_active():
		ENetServer.stop_server()

func test_001_server_broadcast():
	var pkt_data = "Hello Clients"
	ENetServer.broadcast_packet(pkt_data, 0, true)
	
	# Wait for ENetClient to get packet.
	# Assuming it has a packet_received signal! Will be verified.
	await wait_for_signal(ENetClient, "packet_received", 5.0)
	var pkt1 = get_signal_parameters(ENetClient, "packet_received")
	assert_not_null(pkt1, "Client should receive broadcast")
	if pkt1 != null:
		assert_eq(pkt1[0], pkt_data, "Payload matches")

func test_002_client_send_packet():
	var payload = {"message": "Hello Server"}
	ENetClient.send_packet(payload, 0, true)
	
	await wait_for_signal(ENetServer, "packet_received", 5.0)
	var args = get_signal_parameters(ENetServer, "packet_received")
	assert_not_null(args, "Server should receive packet from client")
	if args != null:
		var pkt = args[1]
		assert_eq(pkt.message, "Hello Server", "Server received correct message")

func test_003_send_packet_to_multiple():
	var peers = ENetServer.get_peers()
	assert_eq(peers.size(), 1, "Should have 1 peer")
	
	var peer_ids = []
	for p in peers:
		peer_ids.append(p.get_peer_id())
		
	ENetServer.send_packet_to_multiple(peer_ids, "Multi msg", 0, true)
	await wait_for_signal(ENetClient, "packet_received", 5.0)
	var args = get_signal_parameters(ENetClient, "packet_received")
	assert_not_null(args, "Client should receive multi-targeted message")



func test_004_broadcast_with_exclude():
	var peers = ENetServer.get_peers()
	assert_gt(peers.size(), 0, "Have peers to exclude")
	
	var exclude_arr: Array[int] = [peers[0].get_peer_id()]
	ENetServer.send_packet_to_all("Hidden msg", 0, true, exclude_arr)
	
	var before_count = get_signal_emit_count(ENetClient, "packet_received")
	# Small wait to see if client incorrectly receives it
	await wait_for_signal(ENetClient, "packet_received", 1.0)
	var after_count = get_signal_emit_count(ENetClient, "packet_received")
	assert_eq(after_count, before_count, "Client should NOT receive the broadcast packet since it was excluded")

func test_005_send_raw_packet():
	var byte_arr = PackedByteArray([0x01, 0x02, 0x03, 0x04])
	ENetClient.send_raw_packet(byte_arr, 0, true)
	
	await wait_for_signal(ENetServer, "raw_packet_received", 5.0)
	var args = get_signal_parameters(ENetServer, "raw_packet_received")
	assert_not_null(args, "Server should receive the raw byte packet directly")
	if args != null and args.size() > 1:
		var pkt = args[1] # raw payload
		assert_eq(typeof(pkt), TYPE_PACKED_BYTE_ARRAY, "Server payload should be decoded as an unaltered byte array")
		if typeof(pkt) == TYPE_PACKED_BYTE_ARRAY:
			assert_eq(pkt.size(), byte_arr.size(), "Byte array lengths should match natively")

func test_006_server_send_packet():
	var peers = ENetServer.get_peers()
	assert_gt(peers.size(), 0, "Should have 1 peer directly")
	if peers.size() > 0:
		var target_peer = peers[0].get_peer_id()
		var target_payload = "Single Peer Msg"
		
		ENetServer.send_packet(target_peer, target_payload, 0, true)
		
		await wait_for_signal(ENetClient, "packet_received", 5.0)
		var args = get_signal_parameters(ENetClient, "packet_received")
		assert_not_null(args, "Client should explicitly map dispatched server packet exclusively")
		if args != null:
			assert_eq(args[0], "Single Peer Msg", "Decoded peer-specific payload effectively matched")
