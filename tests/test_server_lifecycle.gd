extends GutTest

var port = 8080

func before_all():
	# ENetServer is a singleton
	assert_not_null(ENetServer, "ENetServer singleton should be available")

func after_all():
	if ENetServer.is_server_active():
		ENetServer.stop_server()

func test_001_server_creation():
	var err = ENetServer.create_server(port, 32, 2)
	assert_eq(err, OK, "Server should start without errors")
	assert_true(ENetServer.is_server_active(), "Server should be active after creation")
	assert_eq(ENetServer.get_local_port(), port, "Local port should match requested port")

func test_002_server_stop():
	ENetServer.stop_server()
	assert_false(ENetServer.is_server_active(), "Server should not be active after stop_server is called")

func test_003_server_restart():
	var err = ENetServer.create_server(port + 1, 32, 2)
	assert_eq(err, OK, "Server should be able to restart on a new port")
	assert_true(ENetServer.is_server_active(), "Server should be active")
	ENetServer.stop_server()
