## defined variables and functions

adminstatus = ["New / Unread", "Note added", "Waiting on user", "Awaiting 3rd party"]
adminstatusCSS = ["alert", "success", "secondary", "secondary"]

ViewModel = 
	user: {}
	open: ko.observableArray()

openIterator = (ticket, callback) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	ticket.friendlyStatus = adminstatus[ +ticket.status ] or null
	ticket.friendlyStatusCSS = adminstatusCSS[ +ticket.status ] or null
	ticket.gotoMessages = -> 
		window.location = "/messages/?id="+ticket._id
	callback null, ticket


# initial ticket get
getTickets = (group) ->
	# get tickets via socket.io
	socket.emit 'getTickets', group, (err, tickets) ->
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

