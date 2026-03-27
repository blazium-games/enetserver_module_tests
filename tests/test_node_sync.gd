extends GutTest

var port = 8093

func before_all():
	ENetServer.create_server(port, 32, 2)
	watch_signals(ENetServer)
	watch_signals(ENetClient)

func after_all():
	ENetClient.disconnect_from_server()
	if ENetServer.is_server_active():
		ENetServer.stop_server()

func test_001_node_state_sync():
	var err = ENetClient.connect_to_server("127.0.0.1", port)
	await wait_for_signal(ENetClient.connected_to_server, 5.0)
	
	var node = Node2D.new()
	node.position = Vector2(100, 200)
	node.name = "TestSyncNode"
	add_child(node)
	
	# Send from Server to Client
	var peers = ENetServer.get_peers()
	assert_gt(peers.size(), 0, "Server has peer")
	if peers.size() > 0:
		ENetServer.send_node_state(peers[0].get_peer_id(), node, 0, 0)
		
		await wait_for_signal(ENetClient.packet_received, 5.0)
		var args = get_signal_parameters(ENetClient, "packet_received")
		assert_not_null(args, "Client received node state packet")
		if args != null:
			var dict = args[0]
			assert_true(dict is Dictionary, "Node state parsed into Dictionary")
			# Depending on ENetPacketUtils implementation, verify dict.
	
	# Send to all
	ENetServer.send_node_to_all(node, 0, 0)
	await wait_for_signal(ENetClient.packet_received, 5.0)
	var args_all = get_signal_parameters(ENetClient, "packet_received")
	assert_not_null(args_all, "Client received send_node_to_all state packet")
	
	# Client send_node_state
	node.name = "ClientNode"
	ENetClient.send_node_state(node, 0, 0)
	await wait_for_signal(ENetServer.packet_received, 5.0)
	var s_args = get_signal_parameters(ENetServer, "packet_received")
	assert_not_null(s_args, "Server received node state packet from client")
	
	node.queue_free()
