extends AutoworkTest

var port = 8091

func before_all():
	ENetClient.disconnect_from_server()
	if ENetServer.is_server_active():
		ENetServer.stop_server()
	ENetServer.create_server(port, 32, 2)
	watch_signals(ENetServer)
	watch_signals(ENetClient)

func after_all():
	ENetClient.disconnect_from_server()
	if ENetServer.is_server_active():
		ENetServer.stop_server()

func test_001_peer_state_and_info():
	ENetClient.connect_to_server("127.0.0.1", port)
	await wait_for_signal(ENetServer, "peer_authenticated", 5.0)
	
	var peers = ENetServer.get_peers()
	assert_eq(peers.size(), 1, "Should have exactly 1 peer")
	if peers.size() == 1:
		var peer: ENetServerPeer = peers[0]
		assert_eq(peer.get_remote_address(), "127.0.0.1", "Remote address should match loopback")
		assert_true(peer.get_remote_port() > 0, "Remote port should be valid")
		assert_eq(peer.get_connection_state(), ENetServerPeer.STATE_AUTHENTICATED, "Connection state should be authenticated")
		assert_eq(peer.get_auth_state(), ENetServerPeer.AUTH_APPROVED, "Auth state should be approved")
		assert_true(peer.get_connection_time() >= 0.0, "Connection time should be valid")
		assert_true(peer.get_ping() >= 0, "Ping should be valid")
		assert_true(peer.get_statistic(0) >= 0.0, "Statistics packet loss is valid")

func test_002_peer_custom_data():
	var peers = ENetServer.get_peers()
	assert_eq(peers.size(), 1, "Should have 1 peer connected from previous test")
	if peers.size() == 1:
		var peer = peers[0]
		peer.set_custom_data({"account_id": 100})
		var retrieved = peer.get_custom_data()
		assert_eq(retrieved["account_id"], 100, "Should store and retrieve custom data")

func test_003_peer_send_packet():
	var peers = ENetServer.get_peers()
	assert_eq(peers.size(), 1, "Should have 1 peer directly mapped")
	if peers.size() == 1:
		var peer: ENetServerPeer = peers[0]
		peer.send_packet({"test": true}, 0, true)
		
		await wait_for_signal(ENetClient, "packet_received", 5.0)
		var args = get_signal_parameters(ENetClient, "packet_received")
		assert_not_null(args, "Client should explicitly map dispatched ENetServerPeer packet")
		if args != null:
			var dict = args[0]
			assert_true(typeof(dict) == TYPE_DICTIONARY, "Decoded payload type check cleanly")
			if typeof(dict) == TYPE_DICTIONARY:
				assert_true(dict.has("test"), "Payload correctly matched natively")

func test_004_peer_send_raw_packet():
	var peers = ENetServer.get_peers()
	assert_eq(peers.size(), 1, "Should have 1 peer mapped directly")
	if peers.size() == 1:
		var peer: ENetServerPeer = peers[0]
		var byte_arr = PackedByteArray([0x10, 0x20, 0x30])
		peer.send_raw_packet(byte_arr, 0, true)
		
		await wait_for_signal(ENetClient, "raw_packet_received", 5.0)
		var args = get_signal_parameters(ENetClient, "raw_packet_received")
		assert_not_null(args, "Client securely evaluating raw packet limits exactly")
		if args != null:
			var pkt = args[0]
			assert_eq(typeof(pkt), TYPE_PACKED_BYTE_ARRAY, "Client decoded byte array natively mapped")
			if typeof(pkt) == TYPE_PACKED_BYTE_ARRAY:
				assert_eq(pkt.size(), byte_arr.size(), "Uncompressed Native array length matching securely")
