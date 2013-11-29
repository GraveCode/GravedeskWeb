## defined variables and functions

class ViewModel
	constructor: ->
		@user = {}
		@tickets = ko.observableArray()
		@groupOptions = ko.observableArray(gd.groups)
		@group = ko.observable(0)
		@alert = ko.observable()
		@dateDirection = -1
		@subjectDirection = -1
		@fromDirection = -1
		@statusDirection = -1
		@priorityDirection = -1
		@isAdmin = ko.observable(false)
		@ticketType = ko.observable("open")
		@hidePriority = ko.computed(=>
			if @ticketType() == "closed" 
				return true
			else 
				return false
		)

	changeGroup: (newGroup) =>
		newGroupIndex = gd.groups.indexOf newGroup
		@group newGroupIndex
		getTickets newGroupIndex

	sortByPriority: ->
		self = @
		self.priorityDirection = -self.priorityDirection
		self.tickets.sort (a, b) ->
			if a.priority > b.priority
				return 1 * self.priorityDirection
			else if a.priority < b.priority
				return -1 * self.priorityDirection
			else
				return 0
		
	sortByStatus: ->
		self = @
		self.statusDirection = -self.statusDirection
		self.tickets.sort (a, b) ->
			if a.status > b.status
				return 1 * self.statusDirection
			else if a.status < b.status
				return -1 * self.statusDirection
			else
				return 0

	sortByFrom: ->
		self = @
		self.fromDirection = -self.fromDirection
		self.tickets.sort (a, b) ->
			x = a.owner.toLowerCase()
			y = b.owner.toLowerCase()
			if x > y
				return 1 * self.fromDirection
			else if x < y
				return -1 * self.fromDirection
			else
				return 0

	sortBySubject: ->
		self = @
		self.subjectDirection = -self.subjectDirection
		self.tickets.sort (a, b) ->
			x = a.title.toLowerCase()
			y = b.title.toLowerCase()
			if x > y
				return 1 * self.subjectDirection
			else if x < y
				return -1 * self.subjectDirection
			else
				return 0

	sortByDate: ->
		self = @
		self.dateDirection = -self.dateDirection
		self.tickets.sort (a, b) ->
			if a.modified > b.modified
				return 1 * self.dateDirection
			else if a.modified < b.modified
				return -1 * self.dateDirection
			else
				return 0


viewmodel = new ViewModel

ticketsIterator = (ticket, callback) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	if ticket.closed
		ticket.friendlyStatus = "Closed"
		ticket.friendlyStatusCSS = "secondary"
	else	
		ticket.friendlyStatus = gd.adminstatus[ +ticket.status ] or null
		ticket.friendlyStatusCSS = gd.adminstatusCSS[ +ticket.status ] or null

	ticket.friendlyPriority = gd.priority[ +ticket.priority ] or null
	ticket.friendlyPriorityCSS = gd.priorityCSS[ +ticket.priority ] or null
	ticket.owner = ticket.names[ticket.recipients[0]] or ticket.recipients[0] or null
	ticket.gotoMessages = -> 
		window.location = "/messages/?id="+ticket._id
	callback null, ticket

getTickets = (group) ->
	# get tickets via socket.io
	socket.emit 'getAllTickets', group, viewmodel.ticketType(), (err, tickets) ->
		if err
			console.log err
			viewmodel.alert err
		else
			async.map tickets, ticketsIterator, (err, results) ->
				if err
					console.log err
				else
					viewmodel.tickets results

# update friendlyDates in viewmodel
updateDates = ->
	iterator = (item, callback) ->
		date = moment(+item.modified).fromNow() or null
		item.friendlyDate date
		callback null

	async.each viewmodel.tickets(), iterator, (err) ->
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
			socket.emit 'isAdmin', (err, res) ->
				viewmodel.isAdmin(res)
			getTickets viewmodel.group()
			viewmodel.ticketType.subscribe( ->
				getTickets viewmodel.group()
			) 
			ko.applyBindings viewmodel
			# update friendly date every 10 seconds
			window.setInterval ->
				updateDates()
			, (1000*10)


	socket.on('ticketAdded', (id, ticket) ->
		ticket._id = id
		ticketsIterator ticket, (err, newTicket) ->
			# add new ticket to array
			viewmodel.tickets.unshift newTicket
			viewmodel.priorityDirection = 1
			viewmodel.sortByPriority()
	)

	socket.on('ticketUpdated', (id, ticket) ->
		getTickets viewmodel.group() 
	)

	socket.on('ticketDeleted', (id) ->
		viewmodel.tickets.remove( (item) ->
			return item._id == id
		)
	)

