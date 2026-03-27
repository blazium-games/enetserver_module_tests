extends GutTest

var port = 8091

func before_all():
	ENetServer.create_server(port, 32, 2)
	watch_signals(ENetServer)
	watch_signals(ENetClient)

func after_all():
	ENetClient.disconnect_from_server()
	if ENetServer.is_server_active():
		ENetServer.stop_server()

func test_001_peer_state_and_info():
	ENetClient.connect_to_server("127.0.0.1", port)
	await wait_for_signal(ENetServer.peer_authenticated, 5.0)
	
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
