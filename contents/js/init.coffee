$(document).ready ->

	if io?
		window.socket = io.connect(location.host,
			resource: "node/socket.io"
		)
	else
		# socket.io not available, server down
		window.location.replace "/serverdown/"	

	socket.on('connect_failed', () -> 
		window.location.replace "/serverdown/"	
	)

	socket.on('reconnect_failed', () -> 
		window.location.replace "/serverdown/"	
	)

	socket.on('error', () -> 
		window.location.replace "/node/google/"	
	)

	# start foundation scripts
	$(document).foundation()

