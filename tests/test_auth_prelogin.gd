extends AutoworkTest

var port = 8092

func before_all():
	ENetClient.disconnect_from_server()
	if ENetServer.is_server_active():
		ENetServer.stop_server()
	ENetServer.set_authentication_mode(ENetServer.AUTH_PRELOGIN_ONLY)
	ENetServer.create_server(port, 32, 2)
	watch_signals(ENetServer)
	watch_signals(ENetClient)

func after_all():
	ENetClient.disconnect_from_server()
	if ENetServer.is_server_active():
		ENetServer.stop_server()

func test_001_manual_prelogin_auth():
	ENetClient.connect_to_server("127.0.0.1", port)
	await wait_for_signal(ENetClient, "connected_to_server", 5.0)
	
	# Send prelogin packet
	ENetClient.send_packet({"username": "admin"}, 0, true)
	
	await wait_for_signal(ENetServer, "peer_prelogin", 5.0)
	var prelogin_args = get_signal_parameters(ENetServer, "peer_prelogin")
	assert_not_null(prelogin_args, "Server should receive prelogin signal")
	
	if prelogin_args != null:
		var peer: ENetServerPeer = prelogin_args[0]
		var data: Dictionary = prelogin_args[1]
		assert_eq(data.get("username"), "admin", "Prelogin data mapped")
		
		# Reject it just to test rejection manual API
		peer.reject("Invalid permissions")
		
		await wait_for_signal(ENetServer, "peer_disconnected", 5.0)
		var disc_args = get_signal_parameters(ENetServer, "peer_disconnected")
		assert_not_null(disc_args, "Peer should be disconnected after reject()")
		assert_eq(disc_args[1], "Invalid permissions", "Reason matches reject reason")

func test_002_manual_auth_success():
	# Disconnect residual client state
	ENetClient.disconnect_from_server()
	
	ENetClient.connect_to_server("127.0.0.1", port)
	await wait_for_signal(ENetClient, "connected_to_server", 5.0)
	
	ENetClient.send_packet({"username": "good"}, 0, true)
	await wait_for_signal(ENetServer, "peer_prelogin", 5.0)
	
	var prelogin_args = get_signal_parameters(ENetServer, "peer_prelogin")
	assert_not_null(prelogin_args, "Server should receive prelogin signal event 2")
	if prelogin_args != null:
		var peer: ENetServerPeer = prelogin_args[0]
		peer.authenticate() # Manual API
		
		await wait_for_signal(ENetServer, "peer_authenticated", 5.0)
		var auth_args = get_signal_parameters(ENetServer, "peer_authenticated")
		assert_not_null(auth_args, "Peer should emit peer_authenticated after manual authenticate()")
		assert_eq(peer.get_auth_state(), ENetServerPeer.AUTH_APPROVED, "State updated")
