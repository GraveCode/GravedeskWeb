## defined variables and functions

class ViewModel
	constructor: ->
		@user = {}
		@tickets = ko.observableArray()
		@groupOptions = ko.observableArray(gd.groups)
		@groupCounts = ko.observableArray()
		@group = ko.observable(1)
		@alert = ko.observable()
		@success = ko.observable(false)
		@dateDirection = -1
		@subjectDirection = -1
		@fromDirection = -1
		@statusDirection = -1
		@priorityDirection = -1
		@createdDirection = -1
		@sorted = ko.observable(false)
		@isAdmin = ko.observable(false)
		@isTech = ko.observable(false)
		@ticketType = ko.observable "0"
		@hidePriority = ko.computed =>
			if @ticketType() == "1" 
				return true
			else 
				return false
		
		@hideSelect = ko.observable(true)
		@toggleSelectText = ko.computed =>
			if @hideSelect()
				return "Show bulk delete"
			else
				return "Cancel delete"

		@countDeletes = ko.computed =>
			iterator = (memo, item, index, array) ->
				if item.toDelete()
					return memo + 1
				else
					return memo

			count = @tickets().reduce iterator, 0
			if count == 1
				return "1 ticket"
			else
				return count + " tickets"

		@filter = ko.observable()
		@filteredTickets = ko.computed =>
			self = @
			filter = self.filter()?.toLowerCase()
			if !filter 
				return self.tickets()
			else
				# filter tickets by search terms
				return ko.utils.arrayFilter self.tickets(), (item) ->
					return (item.title.toLowerCase().search(filter) >= 0) or (item.submitter.toLowerCase().search(filter) >= 0) or (item.friendlyPriority.toLowerCase().search(filter) >= 0) or (item.friendlyStatus.toLowerCase().search(filter) >= 0) or (item.createdDate().toLowerCase().search(filter) >= 0)



	getTicketCounts: =>
		self = @
		socket.emit 'getTicketCounts', +viewmodel.ticketType(), gd.groups.length, (err, res) ->
			if err
				console.log err
			else
				self.groupCounts res	
				

	changeGroup: (newGroup) =>
		newGroupIndex = gd.groups.indexOf newGroup
		# set cookie for group
		$.cookie 'group', newGroupIndex, { expires: 365 }
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
			x = a.submitter.toLowerCase()
			y = b.submitter.toLowerCase()
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

	sortByCreated: ->
		self = @
		self.sorted true
		self.createdDirection = -self.createdDirection
		self.tickets.sort (a, b) ->
			if a.created > b.created
				return 1 * self.createdDirection
			else if a.created < b.created
				return -1 * self.createdDirection
			else
				return 0

	defaultSort: ->
		self = @
		self.dateDirection = 1
		self.sortByDate()
		if self.ticketType() == "0"
			# also sort by priority if looking at open tickets
			self.priorityDirection = 1
			self.sortByPriority()
		self.sorted false
		return true

	toggleSelect: ->
		self = @
		self.hideSelect !self.hideSelect()
		return true

	whichButton: (d, e) =>
		# ignore clicks if bulk delete mode
		if @hideSelect()
			# left click
			if e.button == 0
				window.location = "/messages/?id="+d._id
			else
				window.open "/messages/?id="+d._id
		else
			# allow click to bubble through to checkbox
			return true

	bulkDelete: ->
		self = @
		# close bulk delete modal	
		self.closefirstModal()

		toDelete = self.tickets.remove (item) -> 
			return item.toDelete()

		iterator = (item, callback) ->
			subTicket =
				"id": item._id
				"rev": item._rev
			callback null, subTicket

		async.map toDelete, iterator, (err, res) ->
			socket.emit 'bulkDelete', res, (err) ->
				if err 
					console.log err
				else
					self.getTicketCounts()


	closefirstModal: =>
		$('#firstModal').foundation('reveal', 'close')	
		@toggleSelect()


	

viewmodel = new ViewModel

ticketsIterator = (ticket, callback) -> 
	ticket.friendlyDate = ko.observable ( moment(+ticket.modified).fromNow() or null )
	ticket.createdDate = ko.observable ( moment(+ticket.created).format(' L') or null )
	if ticket.closed
		ticket.friendlyStatus = "Closed"
		ticket.friendlyStatusCSS = "secondary"
	else	
		ticket.friendlyStatus = gd.adminstatus[ +ticket.status ] or null
		ticket.friendlyStatusCSS = gd.adminstatusCSS[ +ticket.status ] or null

	ticket.friendlyPriority = gd.priority[ +ticket.priority ] or null
	ticket.friendlyPriorityCSS = gd.priorityCSS[ +ticket.priority ] or null
	ticket.submitter = ticket.names[ticket.recipients[0]] or ticket.recipients[0] or null
	ticket.toDelete = ko.observable(false)

	callback null, ticket

getTickets = (group) ->
	# get tickets via socket.io
	socket.emit 'getAllTickets', group, +viewmodel.ticketType(), (err, tickets) ->
		if err
			console.log err
			viewmodel.alert err
		else
			async.map tickets, ticketsIterator, (err, results) ->
				if err
					console.log err
				else
					viewmodel.tickets results
					viewmodel.getTicketCounts()

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
	# reset ticketID so don't get redirected
	$.removeCookie('ticketID', { path: '/' })

	# get user data
	$.ajax(url: "/node/getuser").done (userdata) ->
		unless userdata
			# not logged in, redirect to login
			window.location.replace "/login/"
		else
			viewmodel.user = userdata
			socket.emit 'isAdmin', (err, res) ->
				viewmodel.isAdmin(res)

			socket.emit 'isTech', (err, res) ->
				viewmodel.isTech(res)

			# read cookie for group, if set, update viewmodel
			cookieGroup = + $.cookie 'group'
			if !isNaN cookieGroup
				viewmodel.group cookieGroup

			cookieType = $.cookie 'ticketType'
			if cookieType
				viewmodel.ticketType cookieType

			getTickets viewmodel.group()
			# update tickets when ticketType changed
			viewmodel.ticketType.subscribe( ->
				# set cookie
				$.cookie 'ticketType', viewmodel.ticketType(), { expires: 365 }
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
		# update ticket counts
		viewmodel.getTicketCounts()
	
	socket.on 'ticketUpdated', (id, ticket) ->
		# remove old ticket (if any)
		viewmodel.tickets.remove (item) ->
			return item._id == id
		# check if we're displaying the group the ticket belongs to, and we're allowed to see it
		if (+viewmodel.group() == +ticket.group) and (+ticket.group != 0 or ticket.personal == viewmodel.user.emails[0].value)
			# check closed status matches current view
			if (ticket.closed == false and +viewmodel.ticketType() == 0) or (ticket.closed == true and +viewmodel.ticketType() == 1)
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
						if !viewmodel.sorted() and !ticket.closed
							viewmodel.defaultSort()
		# update ticket counts
		viewmodel.getTicketCounts()


	socket.on 'ticketDeleted', (id) ->
		viewmodel.tickets.remove (item) ->
			return item._id == id
		# update ticket counts
		viewmodel.getTicketCounts()

