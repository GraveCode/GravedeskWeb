## defined variables and functions

class ViewModel
	constructor: ->
		@user = {}
		@open = ko.observableArray()
		@groupOptions = ko.observableArray(gd.groups)
		@group = ko.observable(0)
		@alert = ko.observable()

	changeGroup: (newGroup) =>
		newGroupIndex = gd.groups.indexOf newGroup
		@group newGroupIndex
		getTickets newGroupIndex
		return

viewmodel = new ViewModel

openIterator = (ticket, callback) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	ticket.friendlyStatus = gd.adminstatus[ +ticket.status ] or null
	ticket.friendlyStatusCSS = gd.adminstatusCSS[ +ticket.status ] or null
	ticket.owner = ticket.names[ticket.recipients[0]] or ticket.recipients[0] or null
	ticket.gotoMessages = -> 
		window.location = "/messages/?id="+ticket._id
	callback null, ticket

getTickets = (group) ->
	# get tickets via socket.io
	socket.emit 'getOpenTickets', group, (err, tickets) ->
		if err
			console.log err
		else
			async.map tickets, openIterator, (err, results) ->
				viewmodel.open results

# update friendlyDates in viewmodel
updateDates = ->
	iterator = (item, callback) ->
		date = moment(+item.modified).fromNow() or null
		item.friendlyDate date
		callback null

	async.each viewmodel.open(), iterator, (err) ->
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
			viewmodel.user = userdata
			getTickets viewmodel.group() 
			ko.applyBindings viewmodel
			# update friendly date every 10 seconds
			window.setInterval ->
				updateDates()
			, (1000*10)


	socket.on('ticketAdded', (id, ticket) ->
		openIterator ticket, (err, newTicket) ->
			# add new ticket to array
			viewmodel.open.unshift newTicket
	)

	socket.on('ticketUpdated', (id, ticket) ->
		getTickets viewmodel.group() 
	)

