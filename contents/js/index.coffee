## defined variables and functions

viewmodel = 
	user: {}
	open: ko.observableArray()
	closed: ko.observableArray()
	loaded: ko.observable(false)
	isAdmin: ko.observable(false)
	isTech: ko.observable(false)
	alert: ko.observable("Loading your tickets...")
	success: ko.observable(false)
	statuses: {}
	whichButton: (d, e) ->
		# left click
		if e.button == 0
			window.location = "/messages/?id="+d._id
		else
			window.open "/messages/?id="+d._id

openIterator = (ticket, callback) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	ticket.friendlyStatus = viewmodel.statuses.userstatus[ +ticket.status ] or null
	ticket.friendlyStatusCSS = viewmodel.statuses.userstatusCSS[ +ticket.status ] or null
	callback null, ticket

closedIterator = (ticket, callback) ->
	ticket.friendlyDate = moment(+ticket.modified).format('LL') or null
	callback null, ticket

# initial ticket get
getTickets = ->
	# get tickets via socket.io
	socket.emit 'getMyTickets', viewmodel.user.emails[0].value, (err, open, closed) ->
		if err
			console.log err
		else
			viewmodel.success true
			viewmodel.alert "Your tickets found."
			setTimeout ( ->
				viewmodel.alert null
				viewmodel.success false
			), 1000

			async.map open, openIterator, (err, results) ->
				viewmodel.open(results) 

			async.map closed, closedIterator, (err, results) ->
				viewmodel.closed(results)
				viewmodel.loaded true

# update friendlyDates in viewmodel
updateDates = ->
	iterator = (item, callback) ->
		date = moment(+item.modified).fromNow() or null
		item.friendlyDate(date)
		callback null

	async.each viewmodel.open(), iterator, (err) ->
		if err
			console.log err

## once all code loaded, get to work!
$(document).ready ->
	# reset ticketID so don't get redirected
	$.removeCookie('ticketID', { path: '/' })

	async.series {
		userdata: (callback) ->
			$.ajax(url: "/node/getuser").done (data) ->
				unless data
					# not logged in, redirect to login
					window.location.replace "/login/"
				else
					callback null, data					

		statics: (callback) ->
			socket.emit 'getStatics', callback
							
	}, (err, results) ->
		if err
			# unable to confirm if admin or get setup data
			console.log "Startup failed."
			viewmodel.alert "Startup failed."
		else
			# populate viewmodel with static data
			viewmodel.user = results.userdata
			viewmodel.isAdmin results.statics.isAdmin
			viewmodel.isTech results.statics.isTech
			viewmodel.statuses = results.statics.statuses
			ko.applyBindings viewmodel
			getTickets()

			# update friendly date every 10 seconds
			window.setInterval ->
				updateDates()
			, (1000*10)

	socket.on 'ticketAdded', (id, ticket) ->
		# check if ticket belongs to me
		i = ticket.recipients.indexOf viewmodel.user.emails[0].value
		if i >= 0
			ticket._id = id
			openIterator ticket, (err, newTicket) ->
				# add new ticket to array
				viewmodel.open.unshift newTicket

	socket.on 'ticketUpdated', (id, ticket) ->
		# check if ticket belongs to me
		i = ticket.recipients.indexOf viewmodel.user.emails[0].value
		if i >= 0
			# refresh ticket list
			getTickets()
		else
			# in case it used to be visible to us, remove it
			viewmodel.open.remove (item) ->
				return item._id == id

	socket.on 'ticketDeleted', (id) ->
		viewmodel.open.remove (item) ->
			return item._id == id
