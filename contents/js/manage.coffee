## defined variables and functions

class ViewModel
	constructor: ->
		@user = {}
		@statuses = {}
		@tickets = ko.observableArray()
		@groupList = []
		@groupCounts = ko.observableArray()
		@groupBrackets = ko.computed =>
			output = []
			output.push " (" + count + ")" for count in @groupCounts()
			return output

		@group = ko.observable(1)
		@alert = ko.observable()
		@success = ko.observable(false)
		@dateDirection = -1
		@subjectDirection = 1
		@fromDirection = 1
		@statusDirection = 1
		@priorityDirection = -1
		@createdDirection = -1
		@sorted = ko.observable false
		@isAdmin = ko.observable false
		@isTech = ko.observable false
		@isAllowed = ko.computed =>
			return @isAdmin() or @isTech() 
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
					if item.title and (item.title.toLowerCase().search(filter) >= 0)
						return true
					if item.submitter and (item.submitter.toLowerCase().search(filter) >= 0)
						return true
					if item.friendlyPriority and (item.friendlyPriority.toLowerCase().search(filter) >= 0)
						return true
					if item.friendlyStatus and (item.friendlyStatus.toLowerCase().search(filter) >= 0)
						return true
					if item.createdDate() and (item.createdDate().toLowerCase().search(filter) >= 0)
						return true

					return false

		@start = null
		@currentPage = ko.observable(0)
		@pageSize = ko.observable()
		@pageArray = ko.observableArray()
		@paginated = ko.computed =>
			return +@pageSize() > 0
		@pageSizeOptions = [5,10,15,17,20,25,50]

			
	changeGroup: (newGroup) =>
		newGroupIndex = @groupList.indexOf newGroup
		# set cookie for group
		$.cookie 'group', newGroupIndex, { expires: 365 }
		@group newGroupIndex
		@start = null
		@currentPage 0
		@getTickets()

	sortByPriority: ->
		self = @
		self.sorted true
		self.tickets.sort (a, b) ->
			(a.priority - b.priority) * self.priorityDirection
		self.priorityDirection = -self.priorityDirection
		
	sortByStatus: ->
		self = @
		self.sorted true
		self.tickets.sort (a, b) ->
			(a.status - b.status) * self.statusDirection
		self.statusDirection = -self.statusDirection

	sortByFrom: ->
		self = @
		self.sorted true
		self.tickets.sort (a, b) ->
			x = a.submitter.toLowerCase()
			y = b.submitter.toLowerCase()
			if x > y
				return 1 * self.fromDirection
			else if x < y
				return -1 * self.fromDirection
			else
				return 0
		self.fromDirection = -self.fromDirection

	sortBySubject: ->
		self = @
		self.sorted true
		self.tickets.sort (a, b) ->
			x = a.title.toLowerCase()
			y = b.title.toLowerCase()
			if x > y
				return 1 * self.subjectDirection
			else if x < y
				return -1 * self.subjectDirection
			else
				return 0
		self.subjectDirection = -self.subjectDirection

	sortByDate: ->
		self = @
		self.sorted true
		self.tickets.sort (a, b) ->
			(a.modified - b.modified) * self.dateDirection
		self.createdDirection = -self.dateDirection

	sortByCreated: ->
		self = @
		self.sorted true
		self.tickets.sort (a, b) ->
			(a.created - b.created) * self.createdDirection
		self.createdDirection = -self.createdDirection

	defaultSort: ->
		self = @
		# if closed view, sort only by creation date
		if +viewmodel.ticketType() == 1
			self.createdDirection = -1
			self.sortByCreated()
		else
			# sort by priority/creation date
			self.tickets.sort (a, b) ->
				return (if a.priority is b.priority then b.created - a.created else b.priority - a.priority)
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
					self.getTickets()


	closefirstModal: =>
		$('#firstModal').foundation('reveal', 'close')	
		@toggleSelect()

	getTickets: (group) =>
		self = @
		# get ticket counts
		self.getTicketCounts()
		# get tickets via socket.io
		socket.emit 'getAllTickets', +self.group(), +self.ticketType(), +self.pageSize(), self.start, (err, tickets) ->
			if err
				console.log err
				self.alert err
			else
				async.map tickets, ticketsIterator, (err, results) ->
					if err
						console.log err
					else
						self.tickets results
						self.sorted false

	getTicketCounts: =>
		self = @
		socket.emit 'getTicketCounts', +self.ticketType(), (err, res) ->
			if err
				console.log err
			else
				self.groupCounts res
				self.getTicketPages()

	getTicketPages: =>
		self = @
		if self.paginated() and self.groupCounts()[self.group()] > 0
			socket.emit 'getTicketPages', +self.pageSize(), self.groupCounts()[+self.group()], +self.group(), +self.ticketType(), (err, res) ->
				if err
					console.log err
				else
					self.pageArray res

	gotoPage: (d, i) =>
		@start = d
		@currentPage i
		@getTickets()
		return

	gotoNextPage: =>
		if @currentPage() + 1 < @pageArray().length
			@currentPage(@currentPage() + 1)
			@start = @pageArray()[@currentPage()]
			@getTickets()

	gotoPrevPage: =>
		if @currentPage() > 0
			@currentPage(@currentPage() - 1)
			@start = @pageArray()[@currentPage()]
			@getTickets()

	pageReload: =>
		self = @
		subscription = self.pageArray.subscribe( ->
			# check we're not viewing past the end of the page list
			if self.currentPage() < self.pageArray().length
				self.start = self.pageArray()[self.currentPage()]
				self.getTickets()
			# check we have a valid page array
			else if self.pageArray().length > 0
				self.start = self.pageArray()[0]
				self.currentPage 0
				self.getTickets()

			subscription.dispose()
		)
		self.getTicketCounts()

viewmodel = new ViewModel

ticketsIterator = (ticket, callback) -> 
	ticket.friendlyDate = ko.observable ( moment(+ticket.modified).fromNow() or "" )
	ticket.createdDate = ko.observable ( moment(+ticket.created).format('L') or "" )
	if ticket.closed
		ticket.friendlyStatus = "Closed"
		ticket.friendlyStatusCSS = "secondary"
	else	
		ticket.friendlyStatus = viewmodel.statuses.adminstatus[ +ticket.status ] or "unknown"
		ticket.friendlyStatusCSS = viewmodel.statuses.adminstatusCSS[ +ticket.status ] or ""

	ticket.friendlyPriority = viewmodel.statuses.priority[ +ticket.priority ] or "unknown"
	ticket.friendlyPriorityCSS = viewmodel.statuses.priorityCSS[ +ticket.priority ] or ""
	ticket.submitter = ticket.names[ticket.recipients[0]] or ticket.recipients[0] or ""
	ticket.toDelete = ko.observable(false)

	callback null, ticket


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

	# reset ticketID cookie so don't get redirected later
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
			viewmodel.groupList = results.statics.groups

			# read cookie for group, closed/open and tickets/page; if set, update viewmodel
			cookieGroup = + $.cookie 'group'
			if !isNaN cookieGroup
				viewmodel.group cookieGroup

			cookieType = $.cookie 'ticketType'
			if cookieType
				viewmodel.ticketType cookieType

			cookiePagesize = $.cookie 'pageSize'
			if cookiePagesize
				viewmodel.pageSize cookiePagesize
			else
				viewmodel.getTickets()

			viewmodel.pageSize.subscribe( ->
				$.cookie 'pageSize', (viewmodel.pageSize() or 0), {expires: 365 }
				viewmodel.start = null
				viewmodel.currentPage 0
				viewmodel.getTickets()
				viewmodel.sorted false
			)

			# update tickets when ticketType changed
			viewmodel.ticketType.subscribe( ->
				# set cookie
				$.cookie 'ticketType', viewmodel.ticketType(), { expires: 365 }
				viewmodel.start = null
				viewmodel.currentPage 0
				viewmodel.getTickets()
				viewmodel.sorted false
			) 

			# data all ready, apply viewmodel
			ko.applyBindings viewmodel
			# update friendly date every 10 seconds
			window.setInterval ->
				updateDates()
			, (1000*10)

	# process socket.io events

	socket.on 'ticketAdded', (id, ticket) ->
		# update ticket counts
		viewmodel.getTicketCounts()
		# check if we're displaying the group the ticket belongs to and we're not viewing closed tickets
		if +viewmodel.group() == +ticket.group and +viewmodel.ticketType() != 1
			if viewmodel.paginated()
				viewmodel.pageReload()
			else
				ticket._id = id 
				ticketsIterator ticket, (err, newTicket) ->
					if !err 
						# add new ticket to array
						viewmodel.tickets.unshift newTicket
						if !viewmodel.sorted()
							viewmodel.defaultSort()
			
			viewmodel.success true
			viewmodel.alert "New ticket received."
			setTimeout ( ->
				viewmodel.alert null
				viewmodel.success false
			), 2000
	
	socket.on 'ticketUpdated', (id, ticket) ->
		if viewmodel.paginated()
			viewmodel.pageReload()
		else
			# remove old ticket (if any)
			viewmodel.tickets.remove (item) ->
				return item._id == id
			# update ticket counts
			viewmodel.getTicketCounts()
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


	socket.on 'ticketDeleted', (id) ->
		viewmodel.tickets.remove (item) ->
			return item._id == id
		# update ticket counts
		viewmodel.getTicketCounts()
		if viewmodel.paginated()
			viewmodel.pageReload()

