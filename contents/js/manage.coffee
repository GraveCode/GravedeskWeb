## defined variables and functions

ViewModel = 
	user: {}
	open: ko.observableArray()

openIterator = (ticket, callback) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	ticket.friendlyStatus = gd.adminstatus[ +ticket.status ] or null
	ticket.friendlyStatusCSS = gd.adminstatusCSS[ +ticket.status ] or null
	ticket.owner = ticket.names[ticket.recipients[0]] or ticket.recipients[0] or null
	ticket.gotoMessages = -> 
		window.location = "/messages/?id="+ticket._id
	callback null, ticket


# initial ticket get
getTickets = (group) ->
	# get tickets via socket.io
	socket.emit 'getOpenTickets', group, (err, tickets) ->
		if err
			console.log err
		else
			async.map tickets, openIterator, (err, results) ->
				ViewModel.open(results) 

## once all code loaded, get to work!
$(document).ready ->

	# get user data
	$.ajax(url: "/node/getuser").done (userdata) ->
		unless userdata
			# not logged in, redirect to login
			window.location.replace "/login/"
		else
			ViewModel.user = userdata
			getTickets(0)
			ko.applyBindings ViewModel


	socket.on('ticketAdded', (id, ticket) ->
		openIterator ticket, (err, newTicket) ->
			# add new ticket to array
			ViewModel.open.unshift newTicket
	)

	socket.on('ticketUpdated', (id, ticket) ->
		getTickets(0)
	)

