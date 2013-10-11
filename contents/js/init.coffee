ko.bindingHandlers.fadeVisible =
	update: (element, valueAccessor) ->
		# Whenever the value subsequently changes, slowly fade the element in or out
		value = valueAccessor()
		if ko.utils.unwrapObservable(value) then $(element).fadeIn() else $(element).fadeOut()

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

	socket.on('error', (e) -> 
		console.log 'error emitted from socket ', e 
		window.location.replace "/login/"	
	)

	# start foundation scripts
	$(document).foundation()

