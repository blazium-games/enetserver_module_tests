extends AutoworkTest

var port = 8090

func after_each():
	if ENetServer.is_server_active():
		ENetServer.stop_server()
	ENetClient.disconnect_from_server()
	ENetServer.set_compression_mode(0)
	ENetClient.set_compression_mode(0)

func test_001_poll_rates():
	ENetServer.set_poll_rate(25)
	assert_eq(ENetServer.get_poll_rate(), 25, "Server poll rate should be 25")
	ENetServer.set_poll_rate(0) # Should hit MAX(1, p_rate_ms) clamp
	assert_eq(ENetServer.get_poll_rate(), 1, "Server poll rate should clamp to 1")
	
	ENetClient.set_poll_rate(15)
	assert_eq(ENetClient.get_poll_rate(), 15, "Client poll rate should be 15")

func test_002_auth_timeouts():
	ENetServer.set_authentication_timeout(15.5)
	assert_eq(ENetServer.get_authentication_timeout(), 15.5, "Server auth timeout should match")

func test_003_compression_modes():
	ENetServer.create_server(port, 32, 2)
	assert_eq(ENetServer.get_local_port(), port, "Server should expose local port")
	
	ENetServer.set_compression_mode(1) # ENET_COMPRESSION_FASTLZ
	ENetClient.set_compression_mode(1)
	
	var err = ENetClient.connect_to_server("127.0.0.1", port)
	assert_eq(err, OK, "Client connects with fastlz compression enabled")
	
	await wait_for_signal(ENetServer, "packet_received", 5.0) # wait briefly to ensure no crash, or just pass
	
	ENetClient.disconnect_from_server()

func test_004_auth_timeout_disconnects_peer():
	ENetServer.set_authentication_mode(ENetServer.AUTH_PRELOGIN_ONLY)
	ENetServer.set_authentication_timeout(1.0) # 1 second
	ENetServer.create_server(port, 32, 2)
	
	watch_signals(ENetServer)
	ENetClient.connect_to_server("127.0.0.1", port)
	
	await wait_for_signal(ENetServer, "peer_disconnected", 3.0)
	var args = get_signal_parameters(ENetServer, "peer_disconnected")
	assert_not_null(args, "Server should disconnect peer after timeout")
	if args != null:
		assert_eq(args[1], "Authentication timeout", "Reason should be timeout")
	
	ENetClient.disconnect_from_server()
