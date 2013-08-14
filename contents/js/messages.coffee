## defined variables and functions


status = ["Recorded", "In progress", "Needs response", "Awaiting 3rd party"]
adminstatus = ["New", "Note added", "Waiting on user", "Awaiting 3rd party"]
statusCSS = ["secondary", "success", "alert", "secondary"]
adminstatusCSS = ["alert", "success", "secondary", "secondary"]

urlvars = {}

getUrlVars = ->
	window.location.href.replace(/[?&]+([^=&]+)=([^&]*)/g, (m, key, value) ->
		urlvars[key] = value
	)

class ViewModel
	constructor: ->
		@alert = ko.observable()
		@user = ko.observable() 
		@ticket = ko.observable()
		@messages = ko.observableArray()
		@isAdmin = ko.observable()
		@userMsg = ko.observable()
		@adminMsg = ko.observable()
		@adminMsgPrivateValue = ko.observable("private")
		@adminMsgPrivate = ko.computed(=>
			if @adminMsgPrivateValue() is "private"
				return true
			else
				return false
		)
	addUserMsg: ->
		self = @
		names = @ticket().names
		names[@user().emails[0].value] = @user().displayName		
		message = 
			from: @user().emails[0].value
			recipients: @ticket().recipients
			names: names
			private: false
			text: @userMsg()
			fromuser: true
			ticketid: @ticket()._id
		socket.emit 'addMessage', message, (err, changedMessage, changedTicket) ->
			if err 
				console.log err
				self.alert "Sorry, was unable to add reply to the ticket - please try again later."
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
				recipients: @ticket().recipients
				names: names
				private: @adminMsgPrivate()
				text: @adminMsg()
				fromuser: false
				ticketid: @ticket()._id

		socket.emit 'addMessage', message, (err, changedMessage, changedTicket) ->
			if err 
				console.log err
				self.alert err
				setTimeout ( ->
					viewmodel.alert null
				), 5000
			else
				self.adminMsg(null)
				self.adminMsgPrivateValue("private")
				messageIterator changedMessage, (err, result) ->
					self.messages.push result	
				viewmodel.ticket ticketIterator(changedTicket) 


viewmodel = new ViewModel

ticketIterator = (ticket) -> 
	ticket.friendlyDate = ko.observable( moment(+ticket.modified).fromNow() or null )
	if viewmodel.isAdmin()
		ticket.friendlyStatus = adminstatus[ +ticket.status ]
		ticket.friendlyStatusCSS = adminstatusCSS[ +ticket.status ]
	else
		ticket.friendlyStatus = status[ +ticket.status ]
		ticket.friendlyStatusCSS = statusCSS[ +ticket.status ]
	return ticket

messageIterator = (message, callback) ->
	message.friendlyDate = ko.observable( moment(+message.date).fromNow() or null )
	message.displayName = message.names[message.from] or message.from
	message.Colour = ko.computed( ->
		if message.fromuser
			return "fromuser"
		else if message.private
			return "private"
		else
			return "fromadmin"
	)
	callback null, message

# initial ticket get
getMessages = ->
	async.waterfall([
		(cb) ->
			# get tickets via socket.io
			socket.emit 'getMessages', urlvars.id, cb

		, (ticket, messages, cb) ->
			# add knockout data to ticket, then add to view
			viewmodel.ticket ticketIterator(ticket)
			# add knockout data to messages array
			async.map messages, messageIterator, cb

		, (messages, cb) ->
			# replace messages in view
			viewmodel.messages messages	
			cb null

	], (err) ->
		console.log err if err
	)


updateDates = ->
	iterator = (item, callback) ->
		date = moment(+item.date).fromNow() or null
		item.friendlyDate(date)
		callback null

	async.each viewmodel.messages(), iterator, (err) ->
		if err
			console.log err

	date = moment( +viewmodel.ticket().modified ).fromNow() or null
	viewmodel.ticket().friendlyDate(date)

## once all code loaded, get to work!
$(document).ready ->
	async.series([
			(cb) ->
				$.ajax(url: "/node/getuser").done (userdata) ->
					unless userdata
						window.location.replace "/node/google"
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
			, (1000)
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
