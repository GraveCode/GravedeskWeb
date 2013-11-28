## defined variables and functions

urlvars = {}

class ViewModel
	constructor: ->
		@priorityOptions = ko.observableArray(gd.priority)
		@statusOptions = ko.observableArray(gd.adminstatus)
		@groupOptions = ko.observableArray(gd.groups)
		@alert = ko.observable()
		@user = ko.observable() 
		@ticket = ko.observable()
		@messages = ko.observableArray()
		@isAdmin = ko.observable()
		@closed = ko.computed(=>
			if @ticket()?.closed
				return true
			else 
				return false
		)
		@userMsg = ko.observable()
		@adminMsg = ko.observable()
		@adminMsgPrivate = ko.observable(false)

	addUserMsg: ->
		self = @
		names = @ticket().names
		names[@user().emails[0].value] = @user().displayName		
		message = 
			from: @user().emails[0].value
			private: false
			text: @userMsg()
			fromuser: true
			ticketid: @ticket()._id
		socket.emit 'addMessage', message, names, (err, changedMessage, changedTicket) ->
			if err 
				console.log err
				viewmodel.alert "Sorry, was unable to add reply to the ticket - please try again later."
				setTimeout ( ->
					viewmodel.alert null
				), 5000
			else
				self.userMsg(null)
				messageIterator changedMessage, (err, result) ->
					self.messages.push result	
				viewmodel.ticket ticketIterator(changedTicket) 

	addAdminMsg: ->
		self = @
		timestamp = Date.now()
		names = @ticket().names
		names[@user().emails[0].value] = @user().displayName
		message =
				from: @user().emails[0].value
				private: @adminMsgPrivate()
				text: @adminMsg()
				fromuser: false
				ticketid: @ticket()._id

		socket.emit 'addMessage', message, names, (err, changedMessage, changedTicket) ->
			if err 
				console.log err
				viewmodel.alert "Unable to add message."
				setTimeout ( ->
					viewmodel.alert null
				), 5000
			else
				self.adminMsg(null)
				self.adminMsgPrivate(false)
				messageIterator changedMessage, (err, result) ->
					self.messages.push result	
				viewmodel.ticket ticketIterator(changedTicket) 

	changePriority: (newPriority) ->
		ticket = viewmodel._cleanTicket()
		ticket.priority = gd.priority.indexOf newPriority
		viewmodel._updateTicket ticket

	changeStatus: (newStatus) ->
		ticket = viewmodel._cleanTicket()
		ticket.status = gd.adminstatus.indexOf newStatus
		viewmodel._updateTicket ticket

	changeGroup: (newGroup) ->
		ticket = viewmodel._cleanTicket()
		ticket.group = gd.groups.indexOf newGroup
		viewmodel._updateTicket ticket

	toggleClosed: () ->
		ticket = viewmodel._cleanTicket()
		ticket.closed = !ticket.closed
		viewmodel._updateTicket ticket
		if ticket.closed
			window.location.replace "/manage"

	_cleanTicket: () ->
		ticket = ko.toJS viewmodel.ticket()
		delete ticket.friendlyDate
		delete ticket.friendlyStatus
		delete ticket.friendlyStatusCSS
		delete ticket.friendlyPriority
		delete ticket.friendlyPriorityCSS
		return ticket

	_updateTicket: (ticket) ->
		socket.emit 'updateTicket', ticket, (err, t) ->
			if err 
				console.log err
				viewmodel.alert "Unable to save ticket changes!"
				setTimeout ( ->
					viewmodel.alert null
				), 5000
			else 
				viewmodel.ticket ticketIterator(t)

	deleteTicket: ->
		subTicket =
			"id": @ticket()._id
			"rev": @ticket()._rev
	
		socket.emit 'deleteTicket', subTicket, (err) -> 
			if err 
				console.log err
				viewmodel.alert "Unable to delete ticket!"
				setTimeout ( ->
					viewmodel.alert null
				), 5000
			else
				window.location.replace "/manage"
	


viewmodel = new ViewModel

getUrlVars = ->
	window.location.href.replace(/[?&]+([^=&]+)=([^&]*)/g, (m, key, value) ->
		urlvars[key] = value
	)

ticketIterator = (ticket) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	ticket.title = ko.observable(ticket.title)
	ticket.title.subscribe( ->
		t = viewmodel._cleanTicket()
		viewmodel._updateTicket t
	)
	ticket.friendlyPriority = ko.observable( gd.priority[ +ticket.priority ] or null )
	ticket.friendlyPriorityCSS = ko.observable( gd.priorityCSS[ +ticket.priority ] or null )

	if ticket.closed
		ticket.friendlyStatus = ko.observable("Closed")
		ticket.friendlyStatusCSS = ko.observable("alert")
	else	
		if viewmodel.isAdmin()
			ticket.friendlyStatus = ko.observable( gd.adminstatus[ +ticket.status ] or null )
			ticket.friendlyStatusCSS = ko.observable( gd.adminstatusCSS[ +ticket.status ] or null )
		else
			ticket.friendlyStatus = ko.observable( gd.userstatus[ +ticket.status ] or null )
			ticket.friendlyStatusCSS = ko.observable( gd.userstatusCSS[ +ticket.status ] or null )
	return ticket

messageIterator = (message, callback) ->
	message.friendlyDate = ko.observable( moment(+message.date).fromNow() or null )
	message.displayName = ko.computed( ->
	 viewmodel.ticket()?.names[message.from] or message.from
	)
	message.Colour = ko.computed( ->
		if message.fromuser
			return "fromuser"
		else if message.private
			return "private"
		else
			return "fromadmin"
	)

	callback null, message

getMessages = ->
	async.waterfall([
		(cb) ->
			# get tickets via socket.io
			socket.emit 'getMessages', urlvars.id, cb

		, (ticket, messages, cb) ->
			# add knockout data to ticket, then add to view
			viewmodel.ticket ticketIterator(ticket)
			cb null, messages

		, (messages, cb) ->
			# add knockout data to messages array
			async.map messages, messageIterator, cb

		, (messages, cb) ->	
			# replace messages in view
			viewmodel.messages messages	
			cb null

	], (err) ->
		if err
			console.log err 
			viewmodel.alert err
	)


updateDates = ->
	iterator = (item, callback) ->
		date = moment(+item.date).fromNow() or null
		item.friendlyDate(date)
		callback null

	async.each viewmodel.messages(), iterator, (err) ->
		if err
			console.log err

	date = moment( +viewmodel.ticket()?.modified ).fromNow() or null
	viewmodel.ticket()?.friendlyDate(date)

## once all code loaded, get to work!
$(document).ready ->
	async.series([
			(cb) ->
				$.ajax(url: "/node/getuser").done (userdata) ->
					unless userdata
						window.location.replace "/login/"
					else
						cb null, userdata
	
			, (cb) ->
				socket.emit 'isAdmin', (res) ->
					cb null, res

	], (err, results) ->
		viewmodel.user results[0]
		viewmodel.isAdmin results[1]
		getUrlVars()
		# check we have an id
		if urlvars?.id
			getMessages()
			ko.applyBindings viewmodel
			window.setInterval ->
				updateDates()
			, (1000 * 10)
	)

	socket.on('messageAdded', (id, message) ->
		# check if message is relevent to me
		if id is viewmodel.ticket()._id
			if !message.private or viewmodel.isAdmin()
				messageIterator message, (err, result) ->
					viewmodel.messages.push result
	)

	socket.on('ticketUpdated', (id, ticket) ->
		# check if ticket is relevent to me
		if id is viewmodel.ticket()._id
			viewmodel.ticket ticketIterator(ticket) 
	)

	socket.on('ticketDeleted', (id) ->
		# check if ticket is relevent to me
		if id is viewmodel.ticket()._id
			window.location.replace "/"
	)