## defined variables and functions

ViewModel = 
	user: {}
	open: ko.observableArray()
	closed: ko.observableArray()

status = ["Accepted", "In progress", "Needs response"]
statusCSS = ["secondary", "success", "alert"]

openIterator = (ticket, callback) -> 
	ticket.value.friendlyDate = ko.observable( moment(+ticket.value.modified).fromNow() or null )
	ticket.value.friendlyStatus = status[ +ticket.value.status ] or null
	ticket.value.friendlyStatusCSS = statusCSS[ +ticket.value.status ] or null
	ticket.gotoMessages = -> window.location = "/messages/?id="+ticket.id
	callback null, ticket

closedIterator = (ticket, callback) ->
	ticket.value.friendlyDate = moment(+ticket.value.modified).format('Do MMMM YYYY') or null
	ticket.gotoMessages = -> window.location = "/messages/?id="+ticket.id
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
			ko.applyBindings ViewModel

# update friendlyDates in viewmodel
updateDates = ->
	iterator = (item, callback) ->
		date = moment(+item.value.modified).fromNow() or null
		item.value.friendlyDate(date)
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
			# update friendly date every 30 seconds
			window.setInterval ->
				updateDates()
			, (1000*30)

	socket.on('ticketAdded', (id, ticket) ->
		# check if ticket belongs to me
		if ticket.recipients.indexOf ViewModel.user.emails[0].value >= 0
			model = 
				value: ticket
				id: id
			openIterator model, (err, newTicket) ->
				# add new ticket to array
				ViewModel.open.unshift newTicket
	)

