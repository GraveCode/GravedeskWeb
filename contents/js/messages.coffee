## defined variables and functions

urlvars = {}

getUrlVars = ->
  window.location.href.replace(/[?&]+([^=&]+)=([^&]*)/g, (m, key, value) ->
    urlvars[key] = value
  )

ViewModel = 
	user: {}
	ticket: ko.observable()
	messages: ko.observableArray()

# initial ticket get
getMessages = ->
	# get tickets via socket.io
	socket.emit 'getMessages', urlvars.id, (err, ticket, messages) ->
		if err
			console.log err
		else
			ViewModel.ticket(ticket)
			console.log ticket
			ViewModel.messages(messages)
			console.log messages

## once all code loaded, get to work!
$(document).ready ->
	# get user data
	$.ajax(url: "/node/getuser").done (userdata) ->
		unless userdata
			# not logged in, redirect to login
			window.location.replace "/node/google"
		else
			ViewModel.user = userdata
			getUrlVars()
			# check we have an id
			if urlvars?.id
				getMessages()
