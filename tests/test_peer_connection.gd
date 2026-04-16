extends AutoworkTest

var port = 8082

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

func test_001_peer_connection():
	var err = ENetClient.connect_to_server("127.0.0.1", port)
	assert_eq(err, OK, "Client should initiate connection without error")
	
	await wait_for_signal(ENetServer, "peer_connecting", 5.0)
	var args = get_signal_parameters(ENetServer, "peer_connecting")
	assert_not_null(args, "Server should emit peer_connecting signal")
	
	await wait_for_signal(ENetServer, "peer_authenticated", 5.0)
	var auth_args = get_signal_parameters(ENetServer, "peer_authenticated")
	assert_not_null(auth_args, "Server should emit peer_authenticated since auth mode is NONE")
	assert_eq(ENetServer.get_peer_count(), 1, "Server should track 1 peer")

func test_002_kick_peer():
	var peers = ENetServer.get_peers()
	assert_gt(peers.size(), 0, "Should have peers to kick")
	if peers.size() > 0:
		var peer_id = peers[0].get_peer_id()
		ENetServer.kick_peer(peer_id, "Kicked for testing")
		
		await wait_for_signal(ENetServer, "peer_disconnected", 5.0)
		var args = get_signal_parameters(ENetServer, "peer_disconnected")
		assert_not_null(args, "Server should emit peer_disconnected after kicking")
		if args != null:
			assert_eq(args[1], "Kicked for testing", "Disconnect reason should match")
