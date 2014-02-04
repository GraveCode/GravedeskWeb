## defined variables and functions

urlvars = {}

class ViewModel
	constructor: ->
		@priorityOptions = []
		@statusOptions = []
		@groupOptions = []
		@statuses = {}
		@alert = ko.observable()
		@success = ko.observable(false)
		@user = {}
		@ticket = ko.observable()
		@messages = ko.observableArray()
		@isAdmin = ko.observable(false)
		@isTech = ko.observable(false)
		@isAllowed = ko.computed =>
			return @isAdmin() or @isTech() 
		@closed = ko.computed =>
			if @ticket()?.closed
				return true
			else 
				return false
		@userMsg = ko.observable()
		@adminMsgPrivate = ko.observable(false)
		@adminMsgClose = ko.observable(false)
		@newRecipient = ko.validatedObservable
			name: ko.observable("")
			email: ko.observable("").extend { email: true, required: true }
		@messageToDelete = ko.observable()

	addRecipient: =>
		if @newRecipient().isValid()
			# add new name to ticket names array for future use
			if @newRecipient().name()
				@ticket().names[@newRecipient().email()] = @newRecipient().name()
			# format and add recipient to list
			temp = recipientIterator @newRecipient().email()
			@ticket().recipientsList.push temp
			# reset fields
			@newRecipient().email("")
			@newRecipient().email.isModified(false)
			@newRecipient().name("")
			# push changes to world
			@updateTicket()


	addUserMsg: ->
		self = @
		names = @ticket().names
		names[@user.emails[0].value] = @user.displayName		
		message = 
			from: @user.emails[0].value
			private: false
			text: @userMsg()
			fromuser: true
			ticketid: @ticket()._id
		socket.emit 'addMessage', message, names, false, (err) ->
			if err 
				console.log err
				viewmodel.alert "Sorry, was unable to add reply to the ticket - please try again later."
				setTimeout ( ->
					viewmodel.alert null
				), 5000
			else
				self.userMsg(null)

	addAdminMsg: ->
		self = @
		timestamp = Date.now()
		names = @ticket().names
		names[@user.emails[0].value] = @user.displayName
		message =
				from: @user.emails[0].value
				private: @adminMsgPrivate()
				text: @userMsg()
				fromuser: false
				ticketid: @ticket()._id

		socket.emit 'addMessage', message, names, self.adminMsgClose(), (err) ->
			if err 
				console.log err
				viewmodel.alert "Unable to add message."
				setTimeout ( ->
					viewmodel.alert null
				), 5000
			else
				if self.adminMsgClose()
					# also close ticket
					self.customClose self.userMsg()
				self.userMsg(null)
				self.adminMsgPrivate(false)
				self.adminMsgClose(false)

	toggleClosed: =>
		self = @
		newClose = !self.ticket().closed
		self.ticket().closed = newClose
		self.updateTicket()

	standardClose: =>
		self = @
		socket.emit 'closeWithEmail', urlvars.id, null
		self.toggleClosed()

	customClose: (message) =>
		self = @
		socket.emit 'closeWithEmail', urlvars.id, message
		self.toggleClosed()


	closefirstModal: ->
		$('#firstModal').foundation('reveal', 'close')

	opensecondModal: (item) =>
		$('#secondModal').foundation('reveal', 'open')	
		subitem = 
			id: item._id
			rev: item._rev 
			from: item.displayName()
		@messageToDelete subitem

	closesecondModal: ->
		$('#secondModal').foundation('reveal', 'close')		

	deleteMessage: ->
		@closesecondModal()
		id = @messageToDelete().id
		# remove message from view
		@messages.remove (item) ->
			return item._id == id
		socket.emit 'deleteMessage', @messageToDelete(), (err) ->
			if err
				console.log err
				viewmodel.alert "Unable to delete message!"
				setTimeout ( ->
					viewmodel.alert null
				), 5000

	updateMessage: (message) =>
		self = @
		index = @messages.indexOf message
		cleanmsg = ko.toJS message
		delete cleanmsg.Colour
		delete cleanmsg.displayName
		delete cleanmsg.friendlyDate
		socket.emit 'updateMessage', cleanmsg, (err, m) ->
			if err
				console.log err
				viewmodel.alert "Unable to update message!"
				setTimeout ( ->
					viewmodel.alert null
				), 5000
			else
				messageIterator m, (err, result) ->
					self.messages.replace(self.messages()[index], result)
					self.success true
					self.alert "Message was changed."
					setTimeout ( ->
						self.alert null
						self.success false
					), 2000



	updateTicket: =>
		self = @
		ticket = ko.toJS self.ticket()
		ticket.priority = self.priorityOptions.indexOf ticket.friendlyPriority
		ticket.status = self.statusOptions.indexOf ticket.friendlyStatus
		ticket.group = self.groupOptions.indexOf ticket.friendlyGroup
		
		cleanRecipientsList = (item) ->
			return item.email 

		ticket.recipients = ticket.recipientsList.map cleanRecipientsList

		delete ticket.friendlyDate
		delete ticket.friendlyGroup
		delete ticket.friendlyStatus
		delete ticket.friendlyStatusCSS
		delete ticket.friendlyPriority
		delete ticket.friendlyPriorityCSS
		delete ticket.recipientsList
		delete ticket.attachments

		socket.emit 'updateTicket', ticket, (err, t) ->
			if err 
				console.log err
				self.alert "Unable to save ticket changes!"
				setTimeout ( ->
					viewmodel.alert null
				), 5000
			else 
				self.ticket ticketIterator(t)
				self.success true
				self.alert "Ticket updated!"
				setTimeout ( ->
					self.alert null
					self.success false
				), 2000
		return true

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

	deleteRecipient: (entry) =>
		@ticket().recipientsList.remove(entry)
		@updateTicket()
		return false

	loadFrame: (o, e) =>
		e.currentTarget.contentWindow.document.write o.html()
		e.currentTarget.contentWindow.document.body.style.fontFamily = "helvetica, arial, sans-serif"
		e.currentTarget.style.height = e.currentTarget.contentWindow.document.body.scrollHeight + "px"
		console.log e.currentTarget.contentWindow.document.body

viewmodel = new ViewModel

getUrlVars = ->
	window.location.href.replace(/[?&]+([^=&]+)=([^&]*)/g, (m, key, value) ->
		urlvars[key] = value
	)

recipientIterator = (recipient) ->
	result =
		email: recipient
		name: ko.computed ->
			return viewmodel.ticket()?.names[recipient] or null
	return result

ticketIterator = (ticket) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	ticket.title = ko.observable(ticket.title)
	ticket.title.subscribe ->
		viewmodel.updateTicket()

	ticket.friendlyPriority = ko.observable( viewmodel.statuses.priority[ +ticket.priority ] or null )
	ticket.friendlyPriorityCSS = ko.observable( viewmodel.statuses.priorityCSS[ +ticket.priority ] or null )
	ticket.friendlyPriority.subscribe ->
		viewmodel.updateTicket()

	ticket.friendlyGroup = ko.observable( viewmodel.groupOptions[ +ticket.group ] or null )
	ticket.friendlyGroup.subscribe ->
		group = viewmodel.groupOptions.indexOf(viewmodel.ticket().friendlyGroup())
		# if in personal group, flag ticket
		if group == 0
			viewmodel.ticket().personal = viewmodel.user.emails[0].value
		else
			viewmodel.ticket().personal = null

		viewmodel.updateTicket()

	if viewmodel.isAdmin() or viewmodel.isTech()
		ticket.friendlyStatus = ko.observable( viewmodel.statuses.adminstatus[ +ticket.status ] or null )
		ticket.friendlyStatusCSS = ko.observable( viewmodel.statuses.adminstatusCSS[ +ticket.status ] or null )
	else
		ticket.friendlyStatus = ko.observable( viewmodel.statuses.userstatus[ +ticket.status ] or null )
		ticket.friendlyStatusCSS = ko.observable( viewmodel.statuses.userstatusCSS[ +ticket.status ] or null )

	ticket.attachments = ko.observableArray()
	if ticket?._attachments
		for k, v of ticket._attachments
			ticket.attachments.push k

	ticket.friendlyStatus.subscribe ->
		viewmodel.updateTicket()		

	tempArray = ticket.recipients.map recipientIterator
	ticket.recipientsList = ko.observableArray tempArray
	return ticket

messageIterator = (message, callback) ->
	message.friendlyDate = ko.observable( moment(+message.date).fromNow() or null )
	message.displayName = ko.computed ->
	 viewmodel.ticket()?.names[message.from] or message.from

	message.Colour = ko.computed( ->
		if message.fromuser
			return "fromuser"
		else if message.private
			return "private"
		else
			return "fromadmin"
	)
	message.html = ko.observable message.html
	message.text = ko.observable message.text
	message.text.subscribe ->
		viewmodel.updateMessage message
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
	
	getUrlVars()
	# check we have an id
	if urlvars?.id
	# set ticket cookie
		$.cookie 'ticketID', urlvars.id, { expires: 7, path: '/' }

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
			viewmodel.groupOptions = results.statics.groups
			viewmodel.statusOptions = results.statics.statuses.adminstatus
			viewmodel.priorityOptions = results.statics.statuses.priority
			viewmodel.statuses = results.statics.statuses
			if urlvars?.id
				# if ID get messages for that ID
				getMessages()
				ko.applyBindings viewmodel
				window.setInterval ->
					updateDates()
				, (1000 * 10)
	


	socket.on('ticketUpdated', (id, ticket) ->
		# check if ticket is relevent to me
		if id is viewmodel.ticket()._id
			viewmodel.ticket ticketIterator(ticket) 
			viewmodel.success true
			viewmodel.alert "Ticket update received."
			setTimeout ( ->
				viewmodel.alert null
				viewmodel.success false
			), 2000
	)

	socket.on('ticketDeleted', (id) ->
		# check if ticket is relevent to me
		if id is viewmodel.ticket()._id
			window.location.replace "/"
	)

	socket.on('messageAdded', (id, message) ->
		# check if message is relevent to me
		if id is viewmodel.ticket()._id
			if !message.private or viewmodel.isAdmin() or viewmodel.isTech()
				messageIterator message, (err, result) ->
					viewmodel.messages.push result
	)

	socket.on('messageDeleted', (id) ->
		viewmodel.messages.remove (item) ->
			return item._id == id
	)

	socket.on('messageUpdated', (id, message) ->
		# check if message is relevant to me
		if id is viewmodel.ticket()._id
			if !message.private or viewmodel.isAdmin() or viewmodel.isTech()
				viewmodel.messages.remove (item) -> 
					return item._id == message._id
				async.waterfall([
					(cb) ->
						messageIterator message, cb
					, (newmsg, cb) ->
						viewmodel.messages.push newmsg
						viewmodel.messages.sort (left, right) ->
							if left.date > right.date
								return 1
							else if left.date < right.date
								return -1
							else
								return 0
						cb null
				], (err) ->
					if err
						console.log err
					else
						viewmodel.success true
						viewmodel.alert "A message was changed."
						setTimeout ( ->
								viewmodel.alert null
								viewmodel.success false
						), 2000
				)

	)
