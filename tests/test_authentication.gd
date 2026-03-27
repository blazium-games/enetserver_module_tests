extends GutTest

var port = 8085

func before_all():
	ENetServer.set_authentication_mode(ENetServer.AUTH_CUSTOM)
	ENetServer.set_custom_authenticator(Callable(self, "_custom_auth"))
	ENetServer.create_server(port, 32, 2)
	
	watch_signals(ENetServer)
	watch_signals(ENetClient)

func after_all():
	ENetClient.disconnect_from_server()
	if ENetServer.is_server_active():
		ENetServer.stop_server()

func _custom_auth(peer: ENetServerPeer, login_data: Dictionary) -> bool:
	print(">>> Custom auth called with: ", login_data)
	if login_data.has("token") and login_data["token"] == "secret":
		print(">>> Auth successful")
		return true
	print(">>> Auth rejected")
	return false

func test_001_authentication_success_and_fail():
	# Success path
	ENetClient.connect_to_server("127.0.0.1", port)
	await wait_for_signal(ENetClient.connected_to_server, 5.0)
	
	var err = ENetClient.send_packet({"token": "secret"}, 0, true)
	assert_eq(err, OK, "Packet sent successfully")
	
	await wait_for_signal(ENetServer.peer_authenticated, 5.0)
	var auth_args = get_signal_parameters(ENetServer, "peer_authenticated")
	assert_not_null(auth_args, "Server should authenticate peer with valid token")
	assert_eq(ENetServer.get_authenticated_peer_count(), 1, "Should have 1 authenticated peer")
	
	ENetClient.disconnect_from_server()
	await wait_for_signal(ENetClient.disconnected_from_server, 5.0)
	
	# Fail path
	ENetClient.connect_to_server("127.0.0.1", port)
	await wait_for_signal(ENetClient.connected_to_server, 5.0)
	
	var err_fail = ENetClient.send_packet({"token": "wrong"}, 0, true)
	assert_eq(err_fail, OK, "Packet sent successfully")
	
	await wait_for_signal(ENetServer.peer_disconnected, 5.0)
	var args = get_signal_parameters(ENetServer, "peer_disconnected")
	assert_not_null(args, "Server should disconnect peer that failed auth")
	assert_eq(args[1], "Authentication failed", "Reason should be auth failure")

