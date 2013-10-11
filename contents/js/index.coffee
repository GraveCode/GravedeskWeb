## defined variables and functions

status = ["Recorded", "In progress", "Reply added", "Awaiting 3rd party"]
statusCSS = ["secondary", "success", "alert", "secondary"]

ViewModel = 
	user: {}
	open: ko.observableArray()
	closed: ko.observableArray()

openIterator = (ticket, callback) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	ticket.friendlyStatus = status[ +ticket.status ] or null
	ticket.friendlyStatusCSS = statusCSS[ +ticket.status ] or null
	ticket.gotoMessages = -> 
		window.location = "/messages/?id="+ticket._id
	callback null, ticket

closedIterator = (ticket, callback) ->
	ticket.friendlyDate = moment(+ticket.modified).format('Do MMMM YYYY') or null
	ticket.gotoMessages = ->
		window.location = "/messages/?id="+ticket._id
	callback null, ticket

# initial ticket get
getTickets = ->
	# get tickets via socket.io
	socket.emit 'getMyTickets', ViewModel.user.emails[0].value, (err, open, closed) ->
		if err
			console.log err
		else
			async.map open, openIterator, (err, results) ->
				ViewModel.open(results) 

			async.map closed, closedIterator, (err, results) ->
				ViewModel.closed(results)

# update friendlyDates in viewmodel
updateDates = ->
	iterator = (item, callback) ->
		date = moment(+item.modified).fromNow() or null
		item.friendlyDate(date)
		callback null

	async.each ViewModel.open(), iterator, (err) ->
		if err
			console.log err

## once all code loaded, get to work!
$(document).ready ->

	# get user data
	$.ajax(url: "/node/getuser").done (userdata) ->
		unless userdata
			# not logged in, redirect to login
			window.location.replace "/node/google"
		else
			ViewModel.user = userdata
			getTickets()
			ko.applyBindings ViewModel
			# update friendly date every 30 seconds
			window.setInterval ->
				updateDates()
			, (1000*10)

	socket.on('ticketAdded', (id, ticket) ->
		# check if ticket belongs to me
		i = ticket.recipients.indexOf ViewModel.user.emails[0].value
		if i >= 0
			openIterator ticket, (err, newTicket) ->
				# add new ticket to array
				ViewModel.open.unshift newTicket
	)

	socket.on('ticketUpdated', (id, ticket) ->
		# check if ticket belongs to me
		i = ticket.recipients.indexOf ViewModel.user.emails[0].value
		if i >= 0
			getTickets()
	)