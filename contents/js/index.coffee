## defined variables and functions

ViewModel = 
	user: {}
	open: ko.observableArray()
	closed: ko.observableArray()
	isAdmin: ko.observable(false)
	whichButton: (d, e) ->
		console.log e
		console.log d
		# left click
		if e.button == 0
			window.location = "/messages/?id="+d._id
		else
			window.open "/messages/?id="+d._id

openIterator = (ticket, callback) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	ticket.friendlyStatus = gd.userstatus[ +ticket.status ] or null
	ticket.friendlyStatusCSS = gd.userstatusCSS[ +ticket.status ] or null
	callback null, ticket

closedIterator = (ticket, callback) ->
	ticket.friendlyDate = moment(+ticket.modified).format('LL') or null
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
			window.location.replace "/login/"
		else
			ViewModel.user = userdata
			socket.emit 'isAdmin', (err, res) ->
				ViewModel.isAdmin(res)
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
			ticket._id = id
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

	socket.on('ticketDeleted', (id) ->
		ViewModel.open.remove( (item) ->
			return item._id == id
		)
	)