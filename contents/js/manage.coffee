## defined variables and functions

class ViewModel
	constructor: ->
		@user = {}
		@tickets = ko.observableArray()
		@groupOptions = ko.observableArray(gd.groups)
		@group = ko.observable(0)
		@alert = ko.observable()
		@success = ko.observable(false)
		@dateDirection = -1
		@subjectDirection = -1
		@fromDirection = -1
		@statusDirection = -1
		@priorityDirection = -1
		@sorted = ko.observable(false)
		@isAdmin = ko.observable(false)
		@ticketType = ko.observable("open")
		@hidePriority = ko.computed(=>
			if @ticketType() == "closed" 
				return true
			else 
				return false
		)
		@hideSelect = ko.observable(true)
		@toggleSelectText = ko.computed =>
			if @hideSelect()
				return "show bulk delete"
			else
				return "cancel delete"

	changeGroup: (newGroup) =>
		newGroupIndex = gd.groups.indexOf newGroup
		@group newGroupIndex
		getTickets newGroupIndex

	sortByPriority: ->
		self = @
		self.sorted true
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
		self.sorted true
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
		self.sorted true
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
		self.sorted true
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
		self.sorted true
		self.dateDirection = -self.dateDirection
		self.tickets.sort (a, b) ->
			if a.modified > b.modified
				return 1 * self.dateDirection
			else if a.modified < b.modified
				return -1 * self.dateDirection
			else
				return 0

	defaultSort: ->
		self = @
		self.dateDirection = 1
		self.priorityDirection = 1
		self.sortByDate()
		self.sortByPriority()
		self.sorted false

	toggleSelect: ->
		self = @
		self.hideSelect !self.hideSelect()

	whichButton: (d, e) =>
		# ignore clicks if bulk delete mode
		if @hideSelect()
			# left click
			if e.button == 0
				window.location = "/messages/?id="+d._id
			else
				window.open "/messages/?id="+d._id
	

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
			# update tickets when ticketType changed
			viewmodel.ticketType.subscribe( ->
				getTickets viewmodel.group()
				viewmodel.sorted false
			) 
			ko.applyBindings viewmodel
			# update friendly date every 10 seconds
			window.setInterval ->
				updateDates()
			, (1000*10)


	socket.on 'ticketAdded', (id, ticket) ->
		# check if we're displaying the group the ticket belongs to!
		if +viewmodel.group() == +ticket.group
			ticket._id = id
			ticketsIterator ticket, (err, newTicket) ->
				if !err 
					# add new ticket to array
					viewmodel.tickets.unshift newTicket
					viewmodel.success true
					viewmodel.alert "New ticket received."
					setTimeout ( ->
						viewmodel.alert null
						viewmodel.success false
					), 2000
					if !viewmodel.sorted()
						viewmodel.defaultSort()
	
	socket.on 'ticketUpdated', (id, ticket) ->
		# check if we're displaying the group the ticket belongs to!
		if +viewmodel.group() == +ticket.group
			# remove old ticket
			viewmodel.tickets.remove (item) ->
				return item._id == id
			#insert new ticket
			ticketsIterator ticket, (err, newTicket) ->
				if !err 
					# add updated ticket to array
					viewmodel.tickets.unshift newTicket
					viewmodel.success true
					viewmodel.alert 'The ticket with subject "' + ticket.title + '" has been updated.'
					setTimeout ( ->
						viewmodel.alert null
						viewmodel.success false
					), 2000
					if !viewmodel.sorted()
						viewmodel.defaultSort()

	socket.on 'ticketDeleted', (id) ->
		viewmodel.tickets.remove (item) ->
			return item._id == id

