extends GutTest

var port = 8083

func before_all():
	ENetServer.create_server(port, 32, 2)
	
	watch_signals(ENetServer)
	watch_signals(ENetClient)
	
	ENetClient.connect_to_server("127.0.0.1", port)
	await wait_for_signal(ENetClient.connected_to_server, 5.0)

func after_all():
	ENetClient.disconnect_from_server()
	if ENetServer.is_server_active():
		ENetServer.stop_server()

func test_001_server_broadcast():
	var pkt_data = "Hello Clients"
	ENetServer.broadcast_packet(pkt_data, 0, true)
	
	# Wait for ENetClient to get packet.
	# Assuming it has a packet_received signal! Will be verified.
	await wait_for_signal(ENetClient.packet_received, 5.0)
	var pkt1 = get_signal_parameters(ENetClient, "packet_received")
	assert_not_null(pkt1, "Client should receive broadcast")
	if pkt1 != null:
		assert_eq(pkt1[0], pkt_data, "Payload matches")

func test_002_client_send_packet():
	var payload = {"message": "Hello Server"}
	ENetClient.send_packet(payload, 0, true)
	
	await wait_for_signal(ENetServer.packet_received, 5.0)
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
	await wait_for_signal(ENetClient.packet_received, 5.0)
	var args = get_signal_parameters(ENetClient, "packet_received")
	assert_not_null(args, "Client should receive multi-targeted message")

func test_004_broadcast_with_exclude():
	var peers = ENetServer.get_peers()
	assert_gt(peers.size(), 0, "Have peers to exclude")
	
	var exclude_arr: Array[int] = [peers[0].get_peer_id()]
	ENetServer.send_packet_to_all("Hidden msg", 0, true, exclude_arr)
	
	var sig_res = await wait_for_signal(ENetClient.packet_received, 1.0)
	assert_true(sig_res == null or not sig_res, "Client should NOT receive the broadcast packet since it was excluded")
